import json
import logging
from datetime import datetime

from odoo import http, fields
from odoo.http import request, Response

_logger = logging.getLogger(__name__)


class ExternalAPIController(http.Controller):
    """
    External API Controller for handling requests from external systems.
    """

    # ==================== Helper Methods ====================

    def _get_api_key(self):
        """Get API Key from configuration"""
        try:
            config = request.env['api.config'].sudo().search([], limit=1)
            return config.api_key if config else False
        except:
            return False

    def _authenticate(self):
        """Authenticate the request using API Key"""
        api_key = request.httprequest.headers.get('X-API-Key')
        if not api_key:
            return False, "API Key is required in header 'X-API-Key'"

        valid_key = self._get_api_key()
        if not valid_key:
            return False, "API not configured. Please contact administrator."

        if api_key != valid_key:
            return False, "Invalid API Key"

        return True, None

    def _json_response(self, data, status=200):
        """Create JSON response"""
        return Response(
            json.dumps(data, ensure_ascii=False, default=str),
            content_type='application/json; charset=utf-8',
            status=status
        )

    def _get_json_data(self):
        """Get JSON data from request - compatible with Odoo 18"""
        try:
            # Try new way first (Odoo 18)
            if hasattr(request, 'get_json_data'):
                return request.get_json_data()
            # Try jsonrequest (older versions)
            elif hasattr(request, 'jsonrequest'):
                return request.jsonrequest
            # Fallback: parse from httprequest
            else:
                data = request.httprequest.get_data(as_text=True)
                if data:
                    json_data = json.loads(data)
                    # Handle jsonrpc format
                    if 'params' in json_data:
                        return json_data.get('params', {})
                    return json_data
                return {}
        except Exception as e:
            _logger.error(f"Error parsing JSON: {str(e)}")
            return {}

    def _log_request(self, endpoint, method, request_data, response_data, status, error=None):
        """Log API request for monitoring"""
        try:
            request.env['api.log'].sudo().create({
                'endpoint': endpoint,
                'method': method,
                'request_data': json.dumps(request_data, ensure_ascii=False, default=str) if request_data else '',
                'response_data': json.dumps(response_data, ensure_ascii=False, default=str) if response_data else '',
                'status_code': status,
                'error_message': error,
                'ip_address': request.httprequest.remote_addr,
                'request_date': fields.Datetime.now(),
            })
        except Exception as e:
            _logger.error(f"Failed to log API request: {str(e)}")

    # ==================== Health Check ====================

    @http.route('/api/v1/health', type='http', auth='public', methods=['GET'], csrf=False)
    def health_check(self, **kwargs):
        """API Health Check"""
        return self._json_response({
            'success': True,
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0',
            'database': request.env.cr.dbname if request.env.cr else 'N/A'
        }, 200)

    # ==================== Order Endpoints ====================

    @http.route('/api/v1/orders', type='http', auth='public', methods=['POST'], csrf=False)
    def create_order(self, **kwargs):
        """
        Create a new Sales Order

        Expected JSON body:
        {
            "external_order_id": "EXT-12345",
            "customer": {
                "name": "Customer Name",
                "email": "customer@email.com",
                "phone": "0501234567",
                "mobile": "0501234567"
            },
            "order_lines": [
                {"sku": "PROD-001", "quantity": 2, "price": 100.00}
            ],
            "notes": "Order notes"
        }
        """
        endpoint = '/api/v1/orders'

        try:
            # Authenticate
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'POST', {}, response, 401, error_msg)
                return self._json_response(response, 401)

            # Get JSON data
            data = self._get_json_data()

            if not data:
                response = {'success': False, 'error': 'Invalid or empty JSON data'}
                self._log_request(endpoint, 'POST', {}, response, 400, 'Invalid JSON')
                return self._json_response(response, 400)

            # Validate required fields
            if not data.get('customer'):
                response = {'success': False, 'error': 'Customer information is required'}
                self._log_request(endpoint, 'POST', data, response, 400, 'Missing customer')
                return self._json_response(response, 400)

            if not data.get('order_lines'):
                response = {'success': False, 'error': 'Order lines are required'}
                self._log_request(endpoint, 'POST', data, response, 400, 'Missing order_lines')
                return self._json_response(response, 400)

            # Find or create customer
            Partner = request.env['res.partner'].sudo()
            customer_data = data.get('customer', {})

            partner = None
            if customer_data.get('email'):
                partner = Partner.search([('email', '=', customer_data['email'])], limit=1)

            if not partner and customer_data.get('phone'):
                partner = Partner.search([('phone', '=', customer_data['phone'])], limit=1)

            if not partner and customer_data.get('mobile'):
                partner = Partner.search([('mobile', '=', customer_data['mobile'])], limit=1)

            # Create new partner if not found
            if not partner:
                # Get or create 'website' tag
                PartnerTag = request.env['res.partner.category'].sudo()
                website_tag = PartnerTag.search([('name', '=', 'website')], limit=1)
                if not website_tag:
                    website_tag = PartnerTag.create({'name': 'website'})

                # Get country if provided
                country = False
                if customer_data.get('country_code'):
                    country = request.env['res.country'].sudo().search([
                        ('code', '=', customer_data['country_code'].upper())
                    ], limit=1)

                partner_vals = {
                    'name': customer_data.get('name', 'Unknown Customer'),
                    'email': customer_data.get('email'),
                    'phone': customer_data.get('phone'),
                    'mobile': customer_data.get('mobile') or customer_data.get('phone'),
                    'street': customer_data.get('address'),
                    'city': customer_data.get('city'),
                    'country_id': country.id if country else False,
                    'category_id': [(6, 0, [website_tag.id])],
                }
                partner = Partner.create(partner_vals)

            # Prepare order lines
            order_lines = []
            invalid_products = []
            Product = request.env['product.product'].sudo()

            for line in data.get('order_lines', []):
                sku = line.get('sku')

                product = Product.search([
                    '|',
                    ('default_code', '=', sku),
                    ('barcode', '=', sku)
                ], limit=1)

                if not product:
                    invalid_products.append(sku)
                    continue

                line_vals = {
                    'product_id': product.id,
                    'product_uom_qty': line.get('quantity', 1),
                    'price_unit': line.get('price', product.list_price),
                    'discount': line.get('discount', 0),
                }
                order_lines.append((0, 0, line_vals))

            if not order_lines:
                response = {
                    'success': False,
                    'error': 'No valid products found',
                    'invalid_skus': invalid_products
                }
                self._log_request(endpoint, 'POST', data, response, 400, 'No valid products')
                return self._json_response(response, 400)

            # Create Sale Order
            SaleOrder = request.env['sale.order'].sudo()
            order_vals = {
                'partner_id': partner.id,
                'order_line': order_lines,
                'client_order_ref': data.get('external_order_id'),
                'note': data.get('notes'),
            }

            order = SaleOrder.create(order_vals)

            response = {
                'success': True,
                'data': {
                    'order_id': order.id,
                    'order_name': order.name,
                    'external_order_id': data.get('external_order_id'),
                    'customer_id': partner.id,
                    'amount_total': order.amount_total,
                    'status': order.state,
                    'created_at': order.create_date.isoformat() if order.create_date else None,
                },
                'message': 'Order created successfully'
            }

            if invalid_products:
                response['warnings'] = {
                    'invalid_skus': invalid_products,
                    'message': f'{len(invalid_products)} product(s) not found and skipped'
                }

            self._log_request(endpoint, 'POST', data, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error creating order via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'POST', {}, response, 500, str(e))
            return self._json_response(response, 500)

    @http.route('/api/v1/orders/<int:order_id>/confirm', type='http', auth='public', methods=['POST'], csrf=False)
    def confirm_order(self, order_id, **kwargs):
        """Confirm a sales order"""
        endpoint = f'/api/v1/orders/{order_id}/confirm'

        try:
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'POST', {}, response, 401, error_msg)
                return self._json_response(response, 401)

            order = request.env['sale.order'].sudo().browse(order_id)

            if not order.exists():
                response = {'success': False, 'error': 'Order not found'}
                self._log_request(endpoint, 'POST', {}, response, 404, 'Order not found')
                return self._json_response(response, 404)

            if order.state != 'draft':
                response = {'success': False, 'error': f'Order cannot be confirmed. Current state: {order.state}'}
                self._log_request(endpoint, 'POST', {}, response, 400, 'Invalid state')
                return self._json_response(response, 400)

            order.action_confirm()

            response = {
                'success': True,
                'data': {
                    'order_id': order.id,
                    'order_name': order.name,
                    'status': order.state,
                },
                'message': 'Order confirmed successfully'
            }
            self._log_request(endpoint, 'POST', {}, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error confirming order via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'POST', {}, response, 500, str(e))
            return self._json_response(response, 500)

    @http.route('/api/v1/orders/<int:order_id>/status', type='http', auth='public', methods=['GET'], csrf=False)
    def get_order_status(self, order_id, **kwargs):
        """Get order status and details"""
        endpoint = f'/api/v1/orders/{order_id}/status'

        try:
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'GET', {}, response, 401, error_msg)
                return self._json_response(response, 401)

            order = request.env['sale.order'].sudo().browse(order_id)

            if not order.exists():
                response = {'success': False, 'error': 'Order not found'}
                self._log_request(endpoint, 'GET', {}, response, 404, 'Order not found')
                return self._json_response(response, 404)

            delivery_status = None
            if order.picking_ids:
                picking = order.picking_ids[0]
                delivery_status = {
                    'picking_name': picking.name,
                    'state': picking.state,
                    'scheduled_date': picking.scheduled_date.isoformat() if picking.scheduled_date else None,
                }

            response = {
                'success': True,
                'data': {
                    'order_id': order.id,
                    'order_name': order.name,
                    'external_order_id': order.client_order_ref,
                    'status': order.state,
                    'amount_total': order.amount_total,
                    'invoice_status': order.invoice_status,
                    'delivery': delivery_status,
                    'created_at': order.create_date.isoformat() if order.create_date else None,
                }
            }
            self._log_request(endpoint, 'GET', {}, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error getting order status via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'GET', {}, response, 500, str(e))
            return self._json_response(response, 500)

    # ==================== Stock Endpoints ====================

    @http.route('/api/v1/stock', type='http', auth='public', methods=['GET'], csrf=False)
    def get_all_stock(self, **kwargs):
        """Get stock levels for all products"""
        endpoint = '/api/v1/stock'
        params = dict(kwargs)

        try:
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'GET', params, response, 401, error_msg)
                return self._json_response(response, 401)

            domain = [('type', '=', 'product'), ('active', '=', True)]

            if kwargs.get('sku'):
                domain.append(('default_code', 'ilike', kwargs['sku']))

            if kwargs.get('category'):
                domain.append(('categ_id.name', 'ilike', kwargs['category']))

            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))

            Product = request.env['product.product'].sudo()
            total_count = Product.search_count(domain)
            products = Product.search(domain, limit=limit, offset=offset, order='default_code')

            stock_data = []
            for product in products:
                stock_data.append({
                    'id': product.id,
                    'sku': product.default_code or '',
                    'barcode': product.barcode or '',
                    'name': product.name,
                    'category': product.categ_id.name if product.categ_id else '',
                    'qty_available': product.qty_available,
                    'virtual_available': product.virtual_available,
                    'free_qty': product.free_qty,
                    'outgoing_qty': product.outgoing_qty,
                    'incoming_qty': product.incoming_qty,
                    'uom': product.uom_id.name if product.uom_id else '',
                    'list_price': product.list_price,
                    'last_updated': product.write_date.isoformat() if product.write_date else None,
                })

            response = {
                'success': True,
                'data': {
                    'total_count': total_count,
                    'limit': limit,
                    'offset': offset,
                    'products': stock_data,
                }
            }
            self._log_request(endpoint, 'GET', params, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error getting stock via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'GET', params, response, 500, str(e))
            return self._json_response(response, 500)

    @http.route('/api/v1/stock/<string:sku>', type='http', auth='public', methods=['GET'], csrf=False)
    def get_product_stock(self, sku, **kwargs):
        """Get stock for a specific product by SKU"""
        endpoint = f'/api/v1/stock/{sku}'

        try:
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'GET', {}, response, 401, error_msg)
                return self._json_response(response, 401)

            Product = request.env['product.product'].sudo()
            product = Product.search([
                '|',
                ('default_code', '=', sku),
                ('barcode', '=', sku)
            ], limit=1)

            if not product:
                response = {'success': False, 'error': f'Product with SKU/Barcode "{sku}" not found'}
                self._log_request(endpoint, 'GET', {}, response, 404, 'Product not found')
                return self._json_response(response, 404)

            warehouses = request.env['stock.warehouse'].sudo().search([])
            warehouse_stock = []

            for wh in warehouses:
                product_wh = product.with_context(warehouse=wh.id)
                warehouse_stock.append({
                    'warehouse_id': wh.id,
                    'warehouse_name': wh.name,
                    'qty_available': product_wh.qty_available,
                    'free_qty': product_wh.free_qty,
                })

            response = {
                'success': True,
                'data': {
                    'id': product.id,
                    'sku': product.default_code or '',
                    'barcode': product.barcode or '',
                    'name': product.name,
                    'category': product.categ_id.name if product.categ_id else '',
                    'qty_available': product.qty_available,
                    'virtual_available': product.virtual_available,
                    'free_qty': product.free_qty,
                    'outgoing_qty': product.outgoing_qty,
                    'incoming_qty': product.incoming_qty,
                    'uom': product.uom_id.name if product.uom_id else '',
                    'list_price': product.list_price,
                    'stock_by_warehouse': warehouse_stock,
                    'last_updated': product.write_date.isoformat() if product.write_date else None,
                }
            }
            self._log_request(endpoint, 'GET', {}, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error getting product stock via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'GET', {}, response, 500, str(e))
            return self._json_response(response, 500)

    # ==================== Product Endpoints ====================

    @http.route('/api/v1/products', type='http', auth='public', methods=['GET'], csrf=False)
    def get_products(self, **kwargs):
        """Get all products"""
        endpoint = '/api/v1/products'
        params = dict(kwargs)

        try:
            is_valid, error_msg = self._authenticate()
            if not is_valid:
                response = {'success': False, 'error': error_msg}
                self._log_request(endpoint, 'GET', params, response, 401, error_msg)
                return self._json_response(response, 401)

            domain = []

            if kwargs.get('type'):
                domain.append(('type', '=', kwargs['type']))

            if kwargs.get('category'):
                domain.append(('categ_id.name', 'ilike', kwargs['category']))

            if kwargs.get('active'):
                active = kwargs['active'].lower() == 'true'
                domain.append(('active', '=', active))

            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))

            Product = request.env['product.product'].sudo()
            total_count = Product.search_count(domain)
            products = Product.search(domain, limit=limit, offset=offset)

            products_data = []
            for product in products:
                products_data.append({
                    'id': product.id,
                    'sku': product.default_code or '',
                    'barcode': product.barcode or '',
                    'name': product.name,
                    'type': product.type,
                    'category': product.categ_id.name if product.categ_id else '',
                    'list_price': product.list_price,
                    'standard_price': product.standard_price,
                    'uom': product.uom_id.name if product.uom_id else '',
                    'active': product.active,
                })

            response = {
                'success': True,
                'data': {
                    'total_count': total_count,
                    'limit': limit,
                    'offset': offset,
                    'products': products_data,
                }
            }
            self._log_request(endpoint, 'GET', params, response, 200)
            return self._json_response(response, 200)

        except Exception as e:
            _logger.exception("Error getting products via API")
            response = {'success': False, 'error': str(e)}
            self._log_request(endpoint, 'GET', params, response, 500, str(e))
            return self._json_response(response, 500)