# models/stock_card_report.py
# ✅ الملف المصحح النهائي - حل مشكلة product_ids مع NewId في Odoo 18

from odoo import models, fields, api
from odoo.models import NewId
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import logging

_logger = logging.getLogger(__name__)


class StockCardWizard(models.TransientModel):
    _name = 'stock.card.wizard'
    _description = 'Stock Card Report Wizard'
    _rec_name = 'report_type'

    report_type = fields.Selection([
        ('stock_card', 'Stock Card'),
        ('stock_value', 'Stock Value'),
    ], string='Report Type', default='stock_card', required=True)

    date_filter = fields.Selection([
        ('today', 'Today'),
        ('this_week', 'This Week'),
        ('this_month', 'This Month'),
        ('this_quarter', 'This Quarter'),
        ('this_year', 'This Year'),
        ('last_month', 'Last Month'),
        ('last_quarter', 'Last Quarter'),
        ('last_year', 'Last Year'),
        ('all', 'All Time'),
        ('custom', 'Custom Range'),
    ], string='Period', default='this_year')

    date_from = fields.Date('From Date', compute='_compute_dates', store=True, readonly=False)
    date_to = fields.Date('To Date', compute='_compute_dates', store=True, readonly=False)

    product_ids = fields.Many2many(
        'product.product',
        string='Products',
    )

    category_ids = fields.Many2many(
        'product.category',
        string='Product Categories'
    )

    remark_type_ids = fields.Many2many(
        'product.remark.type',
        string='Remark Types',
        help='Filter by remark types'
    )

    location_ids = fields.Many2many(
        'stock.location',
        string='Locations',
        domain=[('usage', '=', 'internal')]
    )

    search_text = fields.Char('Search', help='Search in product name or code')
    report_html = fields.Html('Report Results', sanitize=False)
    last_update = fields.Datetime('Last Update', readonly=True)

    @api.model
    def default_get(self, fields_list):
        res = super().default_get(fields_list)
        try:
            self.env['product.remark.type'].check_access_rights('read')
        except Exception as e:
            _logger.warning(f"No access to remark type model: {str(e)}")
            if 'remark_type_ids' in res:
                del res['remark_type_ids']
        return res

    @api.model
    def create(self, vals):
        record = super().create(vals)
        record._update_report()
        return record

    def _update_report(self):
        for wizard in self:
            try:
                data = wizard.get_report_data()
                if wizard.report_type == 'stock_value':
                    wizard.report_html = wizard._generate_stock_value_html(data)
                else:
                    wizard.report_html = wizard._generate_html_report(data)
                wizard.last_update = fields.Datetime.now()
            except Exception as e:
                _logger.error(f"Error updating report: {str(e)}")
                wizard.report_html = f'<div style="color: red;">Error: {str(e)}</div>'

    @api.depends('date_filter')
    def _compute_dates(self):
        for wizard in self:
            today = fields.Date.today()
            if wizard.date_filter == 'today':
                wizard.date_from = today
                wizard.date_to = today
            elif wizard.date_filter == 'this_week':
                wizard.date_from = today - relativedelta(days=today.weekday())
                wizard.date_to = today
            elif wizard.date_filter == 'this_month':
                wizard.date_from = today.replace(day=1)
                wizard.date_to = today
            elif wizard.date_filter == 'this_quarter':
                quarter_start_month = ((today.month - 1) // 3) * 3 + 1
                wizard.date_from = today.replace(month=quarter_start_month, day=1)
                wizard.date_to = today
            elif wizard.date_filter == 'this_year':
                wizard.date_from = today.replace(month=1, day=1)
                wizard.date_to = today
            elif wizard.date_filter == 'last_month':
                first_day_this_month = today.replace(day=1)
                wizard.date_to = first_day_this_month - relativedelta(days=1)
                wizard.date_from = wizard.date_to.replace(day=1)
            elif wizard.date_filter == 'last_quarter':
                quarter_start_month = ((today.month - 1) // 3) * 3 + 1
                this_quarter_start = today.replace(month=quarter_start_month, day=1)
                wizard.date_to = this_quarter_start - relativedelta(days=1)
                wizard.date_from = wizard.date_to.replace(month=((wizard.date_to.month - 1) // 3) * 3 + 1, day=1)
            elif wizard.date_filter == 'last_year':
                wizard.date_from = today.replace(year=today.year - 1, month=1, day=1)
                wizard.date_to = today.replace(year=today.year - 1, month=12, day=31)
            elif wizard.date_filter == 'all':
                wizard.date_from = False
                wizard.date_to = False

    def _get_real_product_ids(self):
        """
        ✅ استخراج الـ IDs الحقيقية من product_ids حتى لو كانت NewId
        هذه الدالة تحل مشكلة Odoo 18 مع Many2many في onchange
        """
        if not self.product_ids:
            return []

        real_ids = []
        for product in self.product_ids:
            # التحقق من نوع الـ ID
            if isinstance(product.id, int):
                # ID حقيقي
                real_ids.append(product.id)
            elif isinstance(product.id, NewId):
                # NewId - نحاول الحصول على الـ origin
                if hasattr(product.id, 'origin') and product.id.origin:
                    real_ids.append(product.id.origin)
                elif hasattr(product, '_origin') and product._origin:
                    real_ids.append(product._origin.id)
            else:
                # محاولة أخيرة - تحويل لـ int
                try:
                    real_ids.append(int(product.id))
                except (ValueError, TypeError):
                    _logger.warning(f"Could not extract ID from product: {product}")

        _logger.info(f"✅ Extracted real IDs: {real_ids}")
        return real_ids

    @api.onchange('product_ids', 'category_ids', 'location_ids', 'search_text',
                  'report_type', 'remark_type_ids', 'date_filter', 'date_from', 'date_to')
    def _onchange_filters(self):
        """✅ تحديث التقرير عند تغيير أي فلتر"""
        _logger.info("=" * 50)
        _logger.info("🔄 ONCHANGE TRIGGERED")
        _logger.info(f"   product_ids: {self.product_ids}")
        _logger.info(f"   product_ids type: {type(self.product_ids)}")

        # ✅ استخراج الـ IDs الحقيقية
        real_ids = self._get_real_product_ids()
        _logger.info(f"   Real product IDs: {real_ids}")
        _logger.info(f"   search_text: {self.search_text}")
        _logger.info("=" * 50)

        try:
            data = self.get_report_data()

            if self.report_type == 'stock_value':
                self.report_html = self._generate_stock_value_html(data)
            else:
                self.report_html = self._generate_html_report(data)

            self.last_update = fields.Datetime.now()
        except Exception as e:
            _logger.error(f"Error in onchange: {str(e)}")
            import traceback
            _logger.error(traceback.format_exc())
            self.report_html = f'<div style="color: red;">Error: {str(e)}</div>'

    def _get_filtered_products(self):
        """✅ Get products based on filters - FIXED for Odoo 18 NewId issue"""
        _logger.info("--- _get_filtered_products called ---")

        # ✅ استخدام الدالة الجديدة لاستخراج IDs الحقيقية
        real_product_ids = self._get_real_product_ids()

        if real_product_ids:
            _logger.info(f"✅ Using specific products with IDs: {real_product_ids}")
            products = self.env['product.product'].browse(real_product_ids)
            if products.exists():
                _logger.info(f"   Found {len(products)} products: {', '.join(products.mapped('name'))}")
                return products
            else:
                _logger.warning("⚠️ Products not found in database!")

        domain = [('active', '=', True)]

        if self.category_ids:
            category_ids = self._get_real_ids_from_recordset(self.category_ids)
            if category_ids:
                _logger.info(f"Filtering by category IDs: {category_ids}")
                domain.append(('categ_id', 'child_of', category_ids))

        if self.remark_type_ids:
            try:
                remark_ids = self._get_real_ids_from_recordset(self.remark_type_ids)
                if remark_ids:
                    _logger.info(f"Filtering by remark type IDs: {remark_ids}")
                    products_with_remark = self.env['product.product'].search([
                        ('product_tmpl_id.remark_type_id', 'in', remark_ids)
                    ])
                    if products_with_remark:
                        domain.append(('id', 'in', products_with_remark.ids))
                    else:
                        _logger.info("No products found with selected remark types")
                        return self.env['product.product']
            except Exception as e:
                _logger.error(f"Error filtering by remark type: {str(e)}")

        if self.search_text:
            _logger.info(f"Applying search text: {self.search_text}")
            # ✅ إضافة البحث بـ item_short_code
            search_domain = ['|', '|', '|', '|',
                             ('name', 'ilike', self.search_text),
                             ('default_code', 'ilike', self.search_text),
                             ('barcode', '=', self.search_text),
                             ('default_code', '=', self.search_text),
                             ('product_tmpl_id.item_short_code', 'ilike', self.search_text)]
            final_domain = domain + search_domain
            products = self.env['product.product'].search(final_domain, limit=100)
            _logger.info(f"Found {len(products)} products with search text")
            return products

        if not real_product_ids and not self.category_ids and not self.search_text and not self.remark_type_ids:
            _logger.info("No filters applied, returning first 50 products")
            products = self.env['product.product'].search(domain, limit=50)
            return products

        products = self.env['product.product'].search(domain, limit=100)
        _logger.info(f"Found {len(products)} products with domain filters")
        return products

    def _get_real_ids_from_recordset(self, recordset):
        """✅ استخراج IDs حقيقية من أي recordset"""
        if not recordset:
            return []

        real_ids = []
        for record in recordset:
            if isinstance(record.id, int):
                real_ids.append(record.id)
            elif isinstance(record.id, NewId):
                if hasattr(record.id, 'origin') and record.id.origin:
                    real_ids.append(record.id.origin)
                elif hasattr(record, '_origin') and record._origin:
                    real_ids.append(record._origin.id)
            else:
                try:
                    real_ids.append(int(record.id))
                except (ValueError, TypeError):
                    pass
        return real_ids

    def get_report_data(self):
        self.ensure_one()
        if self.report_type == 'stock_value':
            return self._get_stock_value_data()
        else:
            return self._get_stock_card_data()

    def _get_stock_card_data(self):
        _logger.info("=" * 80)
        _logger.info("Starting Stock Card Report Generation")
        _logger.info(f"Date Range: {self.date_from} to {self.date_to}")

        # ✅ تحقق إذا كان هناك أي فلتر محدد
        real_product_ids = self._get_real_product_ids()
        category_ids = self._get_real_ids_from_recordset(self.category_ids)
        remark_ids = self._get_real_ids_from_recordset(self.remark_type_ids)

        has_filter = bool(real_product_ids or category_ids or remark_ids or self.search_text)

        if not has_filter:
            _logger.info("No filter selected - Stock Card requires product selection")
            return {
                'summary': {},
                'products': [],
                'no_filter': True  # ✅ علامة لعرض رسالة مختلفة
            }

        products = self._get_filtered_products()
        _logger.info(f"Filtered Products Count: {len(products)}")

        if not products:
            _logger.warning("No products found matching filters!")
            return {'summary': {}, 'products': []}

        # Get locations
        location_ids = self._get_real_ids_from_recordset(self.location_ids)
        if location_ids:
            locations = self.env['stock.location'].browse(location_ids)
        else:
            locations = self.env['stock.location'].search([('usage', '=', 'internal')])

        _logger.info(f"Locations Count: {len(locations)}")

        total_movements = 0
        total_receipts = 0
        total_issues = 0
        products_data = []

        for product in products:
            _logger.info(f"Processing product: {product.name} (ID: {product.id})")
            product_data = self._get_product_stock_card(product, locations)

            if product_data['movements'] or product_data['opening_balance'] != 0 or product_data[
                'closing_balance'] != 0:
                products_data.append(product_data)
                total_movements += len(product_data['movements'])
                for move in product_data['movements']:
                    total_receipts += move['receipt_qty']
                    total_issues += move['issue_qty']

        summary = {
            'total_products': len(products_data),
            'total_movements': total_movements,
            'total_receipts': total_receipts,
            'total_issues': total_issues,
        }

        _logger.info(f"Report Summary: {summary}")
        return {'summary': summary, 'products': products_data}

    def _get_product_stock_card(self, product, locations):
        opening_balance = 0
        if self.date_from:
            opening_balance = self._calculate_opening_balance(product, locations, self.date_from)

        domain = [
            ('product_id', '=', product.id),
            ('state', '=', 'done'),
        ]

        if self.date_from:
            domain.append(('date', '>=', fields.Datetime.to_datetime(self.date_from)))
        if self.date_to:
            end_datetime = fields.Datetime.to_datetime(self.date_to).replace(hour=23, minute=59, second=59)
            domain.append(('date', '<=', end_datetime))

        if locations:
            location_ids = locations.ids
            domain.append('|')
            domain.append(('location_id', 'in', location_ids))
            domain.append(('location_dest_id', 'in', location_ids))

        moves = self.env['stock.move'].search(domain, order='date asc, id asc')

        movements = []
        running_balance = opening_balance

        for move in moves:
            receipt_qty = 0
            issue_qty = 0

            from_internal = move.location_id.usage == 'internal'
            to_internal = move.location_dest_id.usage == 'internal'

            if locations:
                from_in_filter = move.location_id.id in locations.ids
                to_in_filter = move.location_dest_id.id in locations.ids

                if to_in_filter and not from_in_filter:
                    receipt_qty = move.product_uom_qty
                elif from_in_filter and not to_in_filter:
                    issue_qty = move.product_uom_qty
                elif from_in_filter and to_in_filter:
                    continue
                else:
                    continue
            else:
                if to_internal and not from_internal:
                    receipt_qty = move.product_uom_qty
                elif from_internal and not to_internal:
                    issue_qty = move.product_uom_qty
                elif from_internal and to_internal:
                    receipt_qty = move.product_uom_qty
                    issue_qty = move.product_uom_qty

            running_balance += receipt_qty - issue_qty

            sale_order_name = ''
            salesman_name = ''

            if move.picking_id:
                if move.picking_id.sale_id:
                    sale_order_name = move.picking_id.sale_id.name
                    if hasattr(move.picking_id.sale_id, 'user_id') and move.picking_id.sale_id.user_id:
                        salesman_name = move.picking_id.sale_id.user_id.name

            movements.append({
                'date': move.date.strftime('%Y-%m-%d %H:%M') if move.date else '',
                'document': move.picking_id.name if move.picking_id else move.name,
                'reference': sale_order_name,
                'type': move.picking_id.picking_type_id.name if move.picking_id and move.picking_id.picking_type_id else 'Transfer',
                'partner': move.picking_id.partner_id.name if move.picking_id and move.picking_id.partner_id else '',
                'salesman': salesman_name,
                'location_from': move.location_id.name,
                'location_to': move.location_dest_id.name,
                'receipt_qty': receipt_qty,
                'issue_qty': issue_qty,
                'balance': running_balance,
            })

        item_short_code = ''
        remark_type = ''
        try:
            # ✅ طريقة 1: جلب مباشر من product_tmpl_id
            tmpl = product.product_tmpl_id

            # جلب item_short_code
            if 'item_short_code' in tmpl._fields:
                item_short_code = tmpl.item_short_code or ''
                _logger.info(f"   Found item_short_code via _fields: '{item_short_code}'")
            elif hasattr(tmpl, 'item_short_code'):
                item_short_code = tmpl.item_short_code or ''
                _logger.info(f"   Found item_short_code via hasattr: '{item_short_code}'")

            # جلب remark_type
            if 'remark_type_id' in tmpl._fields and tmpl.remark_type_id:
                remark_type = tmpl.remark_type_id.name or ''
            elif hasattr(tmpl, 'remark_type_id') and tmpl.remark_type_id:
                remark_type = tmpl.remark_type_id.name or ''

        except Exception as e:
            _logger.error(f"Error getting custom fields: {str(e)}")
            import traceback
            _logger.error(traceback.format_exc())

        _logger.info(f"   Product '{product.name}' - short_code: '{item_short_code}', remark: '{remark_type}'")

        return {
            'product_id': product.id,
            'product_name': product.name,
            'product_code': product.default_code or '',
            'item_short_code': item_short_code,
            'remark_type': remark_type,
            'opening_balance': opening_balance,
            'closing_balance': running_balance,
            'movements': movements,
        }

    def _calculate_opening_balance(self, product, locations, date_from):
        domain = [
            ('product_id', '=', product.id),
            ('state', '=', 'done'),
            ('date', '<', fields.Datetime.to_datetime(date_from)),
        ]

        if locations:
            location_ids = locations.ids
            domain.append('|')
            domain.append(('location_id', 'in', location_ids))
            domain.append(('location_dest_id', 'in', location_ids))

        moves = self.env['stock.move'].search(domain)
        balance = 0

        for move in moves:
            from_internal = move.location_id.usage == 'internal'
            to_internal = move.location_dest_id.usage == 'internal'

            if locations:
                from_in = move.location_id.id in locations.ids
                to_in = move.location_dest_id.id in locations.ids
                if to_in and not from_in:
                    balance += move.product_uom_qty
                elif from_in and not to_in:
                    balance -= move.product_uom_qty
            else:
                if to_internal and not from_internal:
                    balance += move.product_uom_qty
                elif from_internal and not to_internal:
                    balance -= move.product_uom_qty

        return balance

    def _get_stock_value_data(self):
        _logger.info("Starting Stock Value Report")

        products = self._get_filtered_products()
        if not products:
            return {'summary': {}, 'products': []}

        location_ids = self._get_real_ids_from_recordset(self.location_ids)
        if location_ids:
            locations = self.env['stock.location'].browse(location_ids)
        else:
            locations = self.env['stock.location'].search([('usage', '=', 'internal')])

        products_data = []
        total_opening_qty = 0
        total_closing_qty = 0
        total_receipts = 0
        total_issues = 0
        total_opening_value = 0
        total_closing_value = 0

        for product in products:
            opening_qty = self._calculate_opening_balance(product, locations, self.date_from) if self.date_from else 0
            opening_cost = product.standard_price
            opening_value = opening_qty * opening_cost

            receipts_qty = 0
            issues_qty = 0

            if self.date_from and self.date_to:
                domain = [
                    ('product_id', '=', product.id),
                    ('state', '=', 'done'),
                    ('date', '>=', fields.Datetime.to_datetime(self.date_from)),
                    ('date', '<=', fields.Datetime.to_datetime(self.date_to).replace(hour=23, minute=59, second=59)),
                ]
                if locations:
                    domain.append('|')
                    domain.append(('location_id', 'in', locations.ids))
                    domain.append(('location_dest_id', 'in', locations.ids))

                moves = self.env['stock.move'].search(domain)
                for move in moves:
                    if locations:
                        from_in = move.location_id.id in locations.ids
                        to_in = move.location_dest_id.id in locations.ids
                        if to_in and not from_in:
                            receipts_qty += move.product_uom_qty
                        elif from_in and not to_in:
                            issues_qty += move.product_uom_qty
                    else:
                        from_internal = move.location_id.usage == 'internal'
                        to_internal = move.location_dest_id.usage == 'internal'
                        if to_internal and not from_internal:
                            receipts_qty += move.product_uom_qty
                        elif from_internal and not to_internal:
                            issues_qty += move.product_uom_qty

            closing_qty = opening_qty + receipts_qty - issues_qty
            closing_cost = product.standard_price
            closing_value = closing_qty * closing_cost

            cost_change = closing_cost - opening_cost
            cost_change_pct = (cost_change / opening_cost * 100) if opening_cost else 0

            item_short_code = ''
            remark_type = ''
            try:
                tmpl = product.product_tmpl_id
                # جلب item_short_code
                if 'item_short_code' in tmpl._fields:
                    item_short_code = tmpl.item_short_code or ''
                elif hasattr(tmpl, 'item_short_code'):
                    item_short_code = tmpl.item_short_code or ''

                # جلب remark_type
                if 'remark_type_id' in tmpl._fields and tmpl.remark_type_id:
                    remark_type = tmpl.remark_type_id.name or ''
                elif hasattr(tmpl, 'remark_type_id') and tmpl.remark_type_id:
                    remark_type = tmpl.remark_type_id.name or ''
            except:
                pass

            products_data.append({
                'product_id': product.id,
                'product_name': product.name,
                'product_code': product.default_code or '',
                'item_short_code': item_short_code,
                'remark_type': remark_type,
                'category': product.categ_id.name if product.categ_id else '',
                'opening_qty': opening_qty,
                'receipts_qty': receipts_qty,
                'issues_qty': issues_qty,
                'closing_qty': closing_qty,
                'change_qty': closing_qty - opening_qty,
                'opening_cost': opening_cost,
                'closing_cost': closing_cost,
                'cost_change': cost_change,
                'cost_change_pct': cost_change_pct,
                'opening_value': opening_value,
                'closing_value': closing_value,
            })

            total_opening_qty += opening_qty
            total_closing_qty += closing_qty
            total_receipts += receipts_qty
            total_issues += issues_qty
            total_opening_value += opening_value
            total_closing_value += closing_value

        return {
            'summary': {
                'total_products': len(products_data),
                'opening_qty': total_opening_qty,
                'closing_qty': total_closing_qty,
                'receipts_qty': total_receipts,
                'issues_qty': total_issues,
                'change_qty': total_closing_qty - total_opening_qty,
                'opening_value': total_opening_value,
                'closing_value': total_closing_value,
                'change_value': total_closing_value - total_opening_value,
                'date_from': self.date_from.strftime('%d/%m/%Y') if self.date_from else 'Beginning',
                'date_to': self.date_to.strftime('%d/%m/%Y') if self.date_to else fields.Date.today().strftime(
                    '%d/%m/%Y'),
            },
            'products': products_data,
        }

    def _generate_html_report(self, data):
        """Generate HTML for Stock Card Report"""
        if not data:
            return '<div style="text-align: center; padding: 20px;">No data</div>'

        # ✅ رسالة خاصة عند عدم اختيار أي فلتر
        if data.get('no_filter'):
            return '''
            <div style="text-align: center; padding: 60px 40px; color: #666;">
                <div style="font-size: 60px; margin-bottom: 20px;">🔍</div>
                <h2 style="color: #667eea; margin-bottom: 15px;">Please Select a Product</h2>
                <p style="font-size: 16px; color: #888; max-width: 500px; margin: 0 auto;">
                    To view the Stock Card report, please select at least one product, 
                    category, remark type, or use the search field.
                </p>
                <div style="margin-top: 30px; padding: 20px; background: #e3f2fd; border-radius: 10px; display: inline-block;">
                    <p style="margin: 0; color: #1976d2;">
                        <strong>💡 Tip:</strong> Use the filters above to select products
                    </p>
                </div>
            </div>
            '''

        if not data.get('products'):
            return '''
            <div style="text-align: center; padding: 40px; color: #666;">
                <h3>No Stock Movements Found</h3>
                <p>No movements found for the selected filters.</p>
            </div>
            '''

        summary = data.get('summary', {})
        html = f'''
        <div style="margin-bottom: 20px;">
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_products', 0)}</div>
                    <div style="font-size: 14px;">Total Products</div>
                </div>
                <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_movements', 0)}</div>
                    <div style="font-size: 14px;">Total Movements</div>
                </div>
                <div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_receipts', 0):,.2f}</div>
                    <div style="font-size: 14px;">Total Receipts</div>
                </div>
                <div style="background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_issues', 0):,.2f}</div>
                    <div style="font-size: 14px;">Total Issues</div>
                </div>
            </div>
        </div>
        '''

        for product_info in data.get('products', []):
            # ✅ إضافة item_short_code في العرض
            _logger.info(
                f"HTML: product={product_info['product_name']}, short_code='{product_info.get('item_short_code')}'")

            short_code_display = ''
            if product_info.get('item_short_code'):
                short_code_display = f" | <strong style='color: #ffd700;'>Short Code: {product_info['item_short_code']}</strong>"

            html += f'''
            <div style="margin-top: 30px; padding: 15px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                        color: white; border-radius: 10px 10px 0 0;">
                <h3 style="margin: 0;">📦 {product_info['product_name']}</h3>
                <div>Code: {product_info['product_code'] or 'N/A'}{short_code_display} | Opening: {product_info['opening_balance']:,.2f} | Closing: {product_info['closing_balance']:,.2f}</div>
            </div>
            '''

            if product_info['movements']:
                html += '''
                <table class="table table-striped" style="width: 100%; font-size: 13px;">
                    <thead>
                        <tr style="background: #2c3e50; color: white;">
                            <th>Date</th><th>Document</th><th>Type</th><th>Partner</th>
                            <th>From</th><th>To</th><th style="text-align:right;">Receipt</th>
                            <th style="text-align:right;">Issue</th><th style="text-align:right;">Balance</th>
                        </tr>
                    </thead>
                    <tbody>
                '''
                for move in product_info['movements']:
                    receipt_display = f"{move['receipt_qty']:,.2f}" if move['receipt_qty'] else ''
                    issue_display = f"{move['issue_qty']:,.2f}" if move['issue_qty'] else ''

                    html += f'''
                    <tr>
                        <td>{move['date']}</td>
                        <td>{move['document']}</td>
                        <td>{move['type']}</td>
                        <td>{move['partner']}</td>
                        <td>{move['location_from']}</td>
                        <td>{move['location_to']}</td>
                        <td style="text-align:right; color: green;">{receipt_display}</td>
                        <td style="text-align:right; color: red;">{issue_display}</td>
                        <td style="text-align:right; font-weight: bold;">{move['balance']:,.2f}</td>
                    </tr>
                    '''
                html += '</tbody></table>'
            else:
                html += '<div style="padding: 20px; text-align: center;">No movements in this period</div>'

        return html

    def _generate_stock_value_html(self, data):
        """Generate HTML for Stock Value Report"""
        if not data or not data.get('products'):
            return '<div style="text-align: center; padding: 40px;">No products found</div>'

        summary = data.get('summary', {})
        html = f'''
        <div style="margin-bottom: 20px;">
            <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 15px; border-radius: 10px; text-align: center; margin-bottom: 15px;">
                <h3 style="margin: 0;">📅 Period: {summary.get('date_from', 'N/A')} → {summary.get('date_to', 'N/A')}</h3>
            </div>
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;">
                <div style="background: #667eea; color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 24px; font-weight: bold;">{summary.get('total_products', 0)}</div>
                    <div>Products</div>
                </div>
                <div style="background: #11998e; color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 24px; font-weight: bold;">{summary.get('opening_qty', 0):,.2f}</div>
                    <div>Opening Qty</div>
                </div>
                <div style="background: #4facfe; color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 24px; font-weight: bold;">{summary.get('closing_qty', 0):,.2f}</div>
                    <div>Closing Qty</div>
                </div>
                <div style="background: #fa709a; color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 24px; font-weight: bold;">${summary.get('closing_value', 0):,.2f}</div>
                    <div>Closing Value</div>
                </div>
            </div>
        </div>
        '''

        html += '''
        <table class="table table-striped" style="width: 100%; font-size: 12px;">
            <thead>
                <tr style="background: #2c3e50; color: white;">
                    <th>#</th><th>SKU</th><th>Short Code</th><th>Product</th><th>Category</th>
                    <th style="text-align:right;">Open Qty</th>
                    <th style="text-align:right;">Receipts</th>
                    <th style="text-align:right;">Issues</th>
                    <th style="text-align:right;">Close Qty</th>
                    <th style="text-align:right;">Open Value</th>
                    <th style="text-align:right;">Close Value</th>
                </tr>
            </thead>
            <tbody>
        '''

        for i, p in enumerate(data.get('products', []), 1):
            html += f'''
            <tr>
                <td>{i}</td>
                <td>{p['product_code'] or 'N/A'}</td>
                <td style="color: #e67e22; font-weight: bold;">{p.get('item_short_code') or '-'}</td>
                <td>{p['product_name']}</td>
                <td>{p['category']}</td>
                <td style="text-align:right;">{p['opening_qty']:,.2f}</td>
                <td style="text-align:right; color: green;">{p['receipts_qty']:,.2f}</td>
                <td style="text-align:right; color: red;">{p['issues_qty']:,.2f}</td>
                <td style="text-align:right; font-weight: bold;">{p['closing_qty']:,.2f}</td>
                <td style="text-align:right;">${p['opening_value']:,.2f}</td>
                <td style="text-align:right; font-weight: bold;">${p['closing_value']:,.2f}</td>
            </tr>
            '''

        html += '</tbody></table>'
        return html

    def action_export_excel(self):
        """Export to Excel"""
        import io
        import base64

        try:
            import xlsxwriter
        except ImportError:
            raise Exception("xlsxwriter library is required for Excel export")

        output = io.BytesIO()
        workbook = xlsxwriter.Workbook(output)

        data = self.get_report_data()

        if self.report_type == 'stock_value':
            self._export_stock_value_excel(workbook, data)
        else:
            self._export_stock_card_excel(workbook, data)

        workbook.close()
        output.seek(0)

        attachment = self.env['ir.attachment'].create({
            'name': f'{self.report_type}_report.xlsx',
            'type': 'binary',
            'datas': base64.b64encode(output.read()),
            'mimetype': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        })

        return {
            'type': 'ir.actions.act_url',
            'url': f'/web/content/{attachment.id}?download=true',
            'target': 'new',
        }

    def _export_stock_value_excel(self, workbook, data):
        worksheet = workbook.add_worksheet('Stock Value')
        header_format = workbook.add_format({'bold': True, 'bg_color': '#4472C4', 'font_color': 'white', 'border': 1})
        money_format = workbook.add_format({'num_format': '#,##0.00', 'border': 1})

        headers = ['#', 'SKU', 'Product', 'Category', 'Opening Qty', 'Receipts', 'Issues',
                   'Closing Qty', 'Opening Value', 'Closing Value']
        for col, header in enumerate(headers):
            worksheet.write(0, col, header, header_format)

        for i, p in enumerate(data.get('products', []), 1):
            worksheet.write(i, 0, i)
            worksheet.write(i, 1, p['product_code'] or '')
            worksheet.write(i, 2, p['product_name'])
            worksheet.write(i, 3, p['category'])
            worksheet.write(i, 4, p['opening_qty'], money_format)
            worksheet.write(i, 5, p['receipts_qty'], money_format)
            worksheet.write(i, 6, p['issues_qty'], money_format)
            worksheet.write(i, 7, p['closing_qty'], money_format)
            worksheet.write(i, 8, p['opening_value'], money_format)
            worksheet.write(i, 9, p['closing_value'], money_format)

    def _export_stock_card_excel(self, workbook, data):
        for product_info in data.get('products', []):
            sheet_name = (product_info['product_code'] or product_info['product_name'])[:31]
            sheet_name = sheet_name.replace('/', '-').replace('\\', '-')
            worksheet = workbook.add_worksheet(sheet_name)

            header_format = workbook.add_format(
                {'bold': True, 'bg_color': '#4472C4', 'font_color': 'white', 'border': 1})
            money_format = workbook.add_format({'num_format': '#,##0.00', 'border': 1})

            worksheet.write(0, 0, f"Product: {product_info['product_name']}")
            worksheet.write(1, 0, f"Opening: {product_info['opening_balance']:,.2f}")
            worksheet.write(1, 4, f"Closing: {product_info['closing_balance']:,.2f}")

            headers = ['Date', 'Document', 'Type', 'Partner', 'From', 'To', 'Receipt', 'Issue', 'Balance']
            for col, header in enumerate(headers):
                worksheet.write(3, col, header, header_format)

            for i, move in enumerate(product_info['movements'], 4):
                worksheet.write(i, 0, move['date'])
                worksheet.write(i, 1, move['document'])
                worksheet.write(i, 2, move['type'])
                worksheet.write(i, 3, move['partner'])
                worksheet.write(i, 4, move['location_from'])
                worksheet.write(i, 5, move['location_to'])
                worksheet.write(i, 6, move['receipt_qty'], money_format)
                worksheet.write(i, 7, move['issue_qty'], money_format)
                worksheet.write(i, 8, move['balance'], money_format)

    @api.model
    def fields_get(self, allfields=None, attributes=None):
        res = super().fields_get(allfields, attributes)
        try:
            self.env['product.remark.type'].check_access_rights('read')
        except:
            if 'remark_type_ids' in res:
                del res['remark_type_ids']
        return res