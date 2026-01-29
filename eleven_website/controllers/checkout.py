# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request
from odoo.addons.website_sale.controllers.main import WebsiteSale
from odoo.addons.payment.controllers import portal as payment_portal
import logging

_logger = logging.getLogger(__name__)


class ElevenPaymentPortal(payment_portal.PaymentPortal):
    """Override Payment Portal to redirect to custom confirmation"""

    def _get_extra_payment_form_values(self, **kwargs):
        """Override to change landing route"""
        values = super()._get_extra_payment_form_values(**kwargs)
        # Try to override landing route
        return values

    @http.route(
        '/payment/status',
        type='http',
        auth='public',
        website=True,
        sitemap=False
    )
    def payment_status(self, **kwargs):
        """Override: Redirect to custom confirmation page"""
        _logger.info("=== ELEVEN: Payment status called ===")

        # Get transaction from session
        tx_ids_list = request.session.get('__payment_tx_ids__', [])

        _logger.info(f"Transaction IDs in session: {tx_ids_list}")

        if tx_ids_list:
            tx_id = tx_ids_list[-1] if isinstance(tx_ids_list, list) else tx_ids_list
            tx = request.env['payment.transaction'].sudo().browse(int(tx_id))

            _logger.info(f"Transaction: {tx.reference}, State: {tx.state}")

            if tx.exists() and tx.sale_order_ids:
                order = tx.sale_order_ids[0]
                _logger.info(f"Order: {order.name}, State: {order.state}")

                # Confirm order if payment successful
                if tx.state == 'done' and order.state == 'draft':
                    try:
                        order.sudo().action_confirm()
                        _logger.info(f"Order {order.name} confirmed")
                    except Exception as e:
                        _logger.error(f"Error confirming order: {e}")

                # Clear cart
                request.session['sale_order_id'] = False

                # Redirect to our custom confirmation
                redirect_url = f'/eleven/checkout/confirmation/{order.id}'
                _logger.info(f"Redirecting to: {redirect_url}")
                return request.redirect(redirect_url)

        # Fallback - try to get order from cart
        order = request.website.sale_get_order()
        if order:
            request.session['sale_order_id'] = False
            return request.redirect(f'/eleven/checkout/confirmation/{order.id}')

        _logger.warning("No order found, redirecting to confirmation without order")
        return request.redirect('/eleven/checkout/confirmation')


class ElevenCheckout(WebsiteSale):
    """
    Custom Checkout with Odoo Payment Form
    """

    def _get_checkout_values(self):
        """Get common values for checkout pages"""
        order = request.website.sale_get_order()
        partner = request.env.user.partner_id
        is_logged_in = not request.env.user._is_public()

        saved_addresses = []
        default_address_id = None

        if is_logged_in:
            saved_addresses = request.env['res.partner'].sudo().search([
                '|',
                ('id', '=', partner.id),
                '&',
                ('parent_id', '=', partner.id),
                ('type', 'in', ['delivery', 'contact'])
            ])

            default_address = partner.child_ids.filtered(
                lambda p: p.type == 'delivery'
            )[:1] or partner
            default_address_id = default_address.id

        countries = request.env['res.country'].sudo().search([])
        uae_country = request.env['res.country'].sudo().search([('code', '=', 'AE')], limit=1)
        states = request.env['res.country.state'].sudo().search([
            ('country_id', '=', uae_country.id)
        ]) if uae_country else []

        return {
            'order': order,
            'partner': partner,
            'is_logged_in': is_logged_in,
            'saved_addresses': saved_addresses,
            'default_address_id': default_address_id,
            'countries': countries,
            'states': states,
        }

    # =============================================
    # OVERRIDE ODOO'S CHECKOUT
    # =============================================

    @http.route(['/shop/checkout'], type='http', auth='public', website=True, sitemap=False)
    def checkout(self, **post):
        return request.redirect('/eleven/checkout')

    # =============================================
    # STEP 1: SHIPPING ADDRESS
    # =============================================

    @http.route('/eleven/checkout', type='http', auth='public', website=True)
    def eleven_checkout_page(self, **kwargs):
        order = request.website.sale_get_order()

        if not order or not order.order_line:
            return request.redirect('/cart')

        values = self._get_checkout_values()
        if kwargs.get('error'):
            values['error_message'] = kwargs.get('error')

        return request.render('eleven_website.eleven_checkout_page', values)

    @http.route('/eleven/checkout/save-address', type='http', auth='public', website=True, methods=['POST'], csrf=True)
    def eleven_save_address(self, **post):
        order = request.website.sale_get_order()

        if not order or not order.order_line:
            return request.redirect('/cart')

        partner = request.env.user.partner_id
        is_logged_in = not request.env.user._is_public()

        try:
            address_id = post.get('address_id', 'new')
            shipping_partner = None

            if address_id == 'new' or not is_logged_in:
                # Build full name from first + last
                first_name = post.get('first_name', '').strip()
                last_name = post.get('last_name', '').strip()
                full_name = f"{first_name} {last_name}".strip() if first_name else post.get('name', '')

                if not full_name or not post.get('street') or not post.get('city') or not post.get('country_id'):
                    return request.redirect('/eleven/checkout?error=Please fill all required fields')

                address_vals = {
                    'name': full_name,
                    'street': post.get('street'),
                    'street2': post.get('street2') or False,
                    'city': post.get('city'),
                    'state_id': int(post.get('state_id')) if post.get('state_id') else False,
                    'zip': post.get('zip') or False,
                    'country_id': int(post.get('country_id')) if post.get('country_id') else False,
                    'phone': post.get('phone') or post.get('contact_phone'),
                    'email': post.get('email'),
                }

                if is_logged_in:
                    if post.get('save_address'):
                        address_vals['parent_id'] = partner.id
                        address_vals['type'] = 'delivery'
                        shipping_partner = request.env['res.partner'].sudo().create(address_vals)
                        if post.get('set_default'):
                            partner.child_ids.filtered(
                                lambda p: p.type == 'delivery' and p.id != shipping_partner.id
                            ).write({'type': 'contact'})
                    else:
                        address_vals['parent_id'] = partner.id
                        address_vals['type'] = 'other'
                        shipping_partner = request.env['res.partner'].sudo().create(address_vals)
                else:
                    existing_partner = request.env['res.partner'].sudo().search([
                        ('email', '=', post.get('email'))
                    ], limit=1)
                    if existing_partner:
                        shipping_partner = existing_partner
                        shipping_partner.sudo().write(address_vals)
                    else:
                        shipping_partner = request.env['res.partner'].sudo().create(address_vals)
            else:
                shipping_partner = request.env['res.partner'].sudo().browse(int(address_id))

            if not shipping_partner:
                return request.redirect('/eleven/checkout?error=Could not create address')

            order_vals = {'partner_shipping_id': shipping_partner.id}
            if is_logged_in:
                order_vals['partner_id'] = partner.id
                order_vals['partner_invoice_id'] = partner.id
            else:
                order_vals['partner_id'] = shipping_partner.id
                order_vals['partner_invoice_id'] = shipping_partner.id

            if post.get('email'):
                shipping_partner.sudo().write({'email': post.get('email')})
            if post.get('contact_phone'):
                shipping_partner.sudo().write({'phone': post.get('contact_phone')})
            if post.get('order_notes'):
                order_vals['note'] = post.get('order_notes')

            order.sudo().write(order_vals)

            # Auto-select shipping method - Simple approach for Odoo 18
            try:
                # Get first available delivery carrier
                carrier = request.env['delivery.carrier'].sudo().search([], limit=1)

                if carrier:
                    # Simply set the carrier_id on the order
                    order.sudo().write({'carrier_id': carrier.id})

                    # Use the standard method to add delivery line
                    if hasattr(order, '_set_delivery_carrier'):
                        order.sudo()._set_delivery_carrier(carrier)
                    elif hasattr(order, 'set_delivery_line'):
                        try:
                            price = carrier.fixed_price if carrier.delivery_type == 'fixed' else 0
                            order.sudo().set_delivery_line(carrier, price)
                        except:
                            pass

                    _logger.info(f"Set carrier {carrier.name} on order {order.name}")
                else:
                    _logger.warning("No delivery carrier found in the system")

            except Exception as e:
                _logger.warning(f"Could not set delivery method: {str(e)}")

            return request.redirect('/eleven/checkout/payment')

        except Exception as e:
            _logger.error(f"Checkout error: {str(e)}")
            return request.redirect('/eleven/checkout?error=An error occurred')

    # =============================================
    # STEP 2: PAYMENT PAGE
    # =============================================

    @http.route('/eleven/checkout/payment', type='http', auth='public', website=True)
    def eleven_payment_page(self, **kwargs):
        """Payment page with Odoo's payment form"""
        order = request.website.sale_get_order()

        if not order or not order.order_line:
            return request.redirect('/cart')

        if not order.partner_shipping_id:
            return request.redirect('/eleven/checkout')

        # Store order ID in session for guest users
        request.session['__last_sale_order_id__'] = order.id

        # Ensure carrier is set
        if not order.carrier_id:
            carrier = request.env['delivery.carrier'].sudo().search([], limit=1)
            if carrier:
                order.sudo().write({'carrier_id': carrier.id})
                # Try to add delivery line
                try:
                    if hasattr(order, 'set_delivery_line'):
                        price = carrier.fixed_price if carrier.delivery_type == 'fixed' else 0
                        order.sudo().set_delivery_line(carrier, price)
                except:
                    pass

        # Get payment providers (same as Odoo does)
        providers_sudo = request.env['payment.provider'].sudo()._get_compatible_providers(
            company_id=order.company_id.id,
            partner_id=order.partner_id.id,
            amount=order.amount_total,
            currency_id=order.currency_id.id,
            sale_order_id=order.id,
        )

        # Get payment methods for each provider
        payment_methods_sudo = request.env['payment.method'].sudo()._get_compatible_payment_methods(
            providers_sudo.ids,
            order.partner_id.id,
            currency_id=order.currency_id.id,
            sale_order_id=order.id,
        )

        # Get tokens for logged in users
        tokens_sudo = request.env['payment.token']
        is_logged_in = not request.env.user._is_public()
        if is_logged_in:
            tokens_sudo = request.env['payment.token'].sudo()._get_available_tokens(
                providers_sudo.ids,
                order.partner_id.id,
            )

        # Prepare values for payment form
        # payment.form template requires specific variable names with _sudo suffix
        values = {
            'order': order,
            'is_logged_in': is_logged_in,
            # Payment form values - exact names required by payment.form template
            'providers_sudo': providers_sudo,
            'payment_methods_sudo': payment_methods_sudo,
            'tokens_sudo': tokens_sudo,
            'amount': order.amount_total,
            'currency': order.currency_id,
            'partner_id': order.partner_id.id,
            'access_token': order._portal_ensure_token(),
            'transaction_route': '/shop/payment/transaction/%s' % order.id,
            'landing_route': '/eleven/checkout/confirmation',
            # Additional required
            'res_id': order.id,
            'res_model': 'sale.order',
            'show_tokenize_input_mapping': {provider.id: False for provider in providers_sudo},
        }

        if kwargs.get('error'):
            values['error_message'] = kwargs.get('error')

        return request.render('eleven_website.eleven_payment_page', values)

    # =============================================
    # STEP 3: CONFIRMATION
    # =============================================

    @http.route([
        '/eleven/order/success',
        '/eleven/order/success/<int:order_id>',
        '/eleven/checkout/confirmation',
        '/eleven/checkout/confirmation/<int:order_id>'
    ], type='http', auth='public', website=True)
    def eleven_confirmation_page(self, order_id=None, **kwargs):
        """Order confirmation - works for both logged in and guest users"""
        order = None
        tx_sudo = None
        is_logged_in = not request.env.user._is_public()

        _logger.info(f"=== Confirmation page: order_id={order_id}, is_logged_in={is_logged_in} ===")

        # Method 1: Get order by ID from URL
        if order_id:
            order = request.env['sale.order'].sudo().browse(order_id)
            if order.exists():
                tx_sudo = order.transaction_ids[-1] if order.transaction_ids else None
                _logger.info(f"Found order from URL: {order.name}")

        # Method 2: Get from session transaction
        if not order:
            tx_ids = request.session.get('__payment_tx_ids__', [])
            tx_id = tx_ids[-1] if tx_ids else request.session.get('__payment_tx_id__')

            _logger.info(f"Session tx_ids: {tx_ids}, tx_id: {tx_id}")

            if tx_id:
                tx_sudo = request.env['payment.transaction'].sudo().browse(int(tx_id))
                if tx_sudo.exists() and tx_sudo.sale_order_ids:
                    order = tx_sudo.sale_order_ids[0]
                    _logger.info(f"Found order from transaction: {order.name}")

        # Method 3: Get current cart order from session
        if not order:
            # Try to get from session sale_order_id
            session_order_id = request.session.get('sale_order_id')
            if session_order_id:
                order = request.env['sale.order'].sudo().browse(session_order_id)
                if order.exists():
                    tx_sudo = order.transaction_ids[-1] if order.transaction_ids else None
                    _logger.info(f"Found order from session: {order.name}")

        # Method 4: Get from website sale_get_order
        if not order:
            order = request.website.sale_get_order()
            if order:
                tx_sudo = order.transaction_ids[-1] if order.transaction_ids else None
                _logger.info(f"Found order from sale_get_order: {order.name}")

        # Method 5: For logged in users - get last confirmed order
        if (not order or order.state == 'draft') and is_logged_in:
            partner_id = request.env.user.partner_id.id
            last_order = request.env['sale.order'].sudo().search([
                ('partner_id', '=', partner_id),
                ('state', 'in', ['sale', 'done', 'sent']),
            ], limit=1, order='id desc')
            if last_order:
                order = last_order
                tx_sudo = order.transaction_ids[-1] if order.transaction_ids else None
                _logger.info(f"Found last order for user: {order.name}")

        # Method 6: For guest users - try to find recent order by session data
        if (not order or order.state == 'draft') and not is_logged_in:
            # Check if we have any recent transaction in session
            recent_order_id = request.session.get('__last_sale_order_id__')
            if recent_order_id:
                order = request.env['sale.order'].sudo().browse(recent_order_id)
                if order.exists():
                    tx_sudo = order.transaction_ids[-1] if order.transaction_ids else None
                    _logger.info(f"Found order from __last_sale_order_id__: {order.name}")

        if not order:
            _logger.warning("No order found, redirecting to products")
            return request.redirect('/products')

        # Confirm order if payment successful
        if tx_sudo and tx_sudo.state == 'done' and order.state == 'draft':
            try:
                order.sudo().action_confirm()
                _logger.info(f"Order {order.name} confirmed")
            except Exception as e:
                _logger.warning(f"Could not confirm order: {e}")

        # Store order ID for guest users before clearing cart
        request.session['__last_sale_order_id__'] = order.id

        # Clear cart session
        request.session['sale_order_id'] = False

        values = {
            'order': order,
            'tx': tx_sudo,
            'is_logged_in': is_logged_in,
        }

        _logger.info(f"Rendering confirmation for order: {order.name}")

        return request.render('eleven_website.eleven_order_confirmation', values)

    # =============================================
    # ADDRESS MANAGEMENT
    # =============================================

    @http.route('/eleven/checkout/address/edit/<int:address_id>', type='http', auth='user', website=True)
    def eleven_edit_address(self, address_id, **kwargs):
        partner = request.env.user.partner_id
        address = request.env['res.partner'].sudo().browse(address_id)

        if address.id != partner.id and address.parent_id.id != partner.id:
            return request.redirect('/eleven/checkout')

        countries = request.env['res.country'].sudo().search([])
        uae_country = request.env['res.country'].sudo().search([('code', '=', 'AE')], limit=1)
        states = request.env['res.country.state'].sudo().search([
            ('country_id', '=', uae_country.id)
        ]) if uae_country else []

        values = {
            'address': address,
            'countries': countries,
            'states': states,
            'is_default': address.type == 'delivery' or address.id == partner.id,
            'can_delete': address.parent_id.id == partner.id,
        }

        return request.render('eleven_website.eleven_edit_address_page', values)

    @http.route('/eleven/checkout/address/save', type='http', auth='user', website=True, methods=['POST'], csrf=True)
    def eleven_save_address_edit(self, **post):
        partner = request.env.user.partner_id
        address_id = int(post.get('address_id'))
        address = request.env['res.partner'].sudo().browse(address_id)

        if address.id != partner.id and address.parent_id.id != partner.id:
            return request.redirect('/eleven/checkout')

        address.sudo().write({
            'name': post.get('name'),
            'street': post.get('street'),
            'street2': post.get('street2') or False,
            'city': post.get('city'),
            'state_id': int(post.get('state_id')) if post.get('state_id') else False,
            'zip': post.get('zip') or False,
            'country_id': int(post.get('country_id')) if post.get('country_id') else False,
            'phone': post.get('phone'),
        })

        if post.get('set_default') and address.parent_id:
            partner.child_ids.filtered(
                lambda p: p.type == 'delivery' and p.id != address.id
            ).write({'type': 'contact'})
            address.sudo().write({'type': 'delivery'})

        return request.redirect('/eleven/checkout')

    @http.route('/eleven/checkout/address/delete', type='http', auth='user', website=True, methods=['POST'], csrf=True)
    def eleven_delete_address(self, **post):
        partner = request.env.user.partner_id
        address_id = int(post.get('address_id'))
        address = request.env['res.partner'].sudo().browse(address_id)

        if address.parent_id.id == partner.id:
            address.sudo().unlink()

        return request.redirect('/eleven/checkout')

    @http.route('/eleven/checkout/get-states', type='json', auth='public', website=True)
    def eleven_get_states(self, country_id, **kwargs):
        states = request.env['res.country.state'].sudo().search([
            ('country_id', '=', int(country_id))
        ])
        return [{'id': s.id, 'name': s.name} for s in states]