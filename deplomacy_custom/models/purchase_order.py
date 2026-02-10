# models/purchase_order.py
from odoo import models, fields, api, _
from odoo.exceptions import UserError
from collections import defaultdict
import logging

_logger = logging.getLogger(__name__)


class PurchaseOrderLine(models.Model):
    _inherit = 'purchase.order.line'

    x_line_vendor_id = fields.Many2one(
        'res.partner',
        string='Line Vendor',
        domain="[('supplier_rank', '>', 0)]",
        help='Specific vendor for this line. Leave empty to use PO vendor.'
    )

    x_effective_vendor_id = fields.Many2one(
        'res.partner',
        string='Effective Vendor',
        compute='_compute_line_effective_vendor',
        store=True
    )

    x_is_landed_cost = fields.Boolean(
        string='Is LC',
        compute='_compute_is_landed_cost'
    )

    product_image = fields.Binary(
        string='Product Image',
        related='product_id.image_128',
        readonly=True,
        store=False
    )

    qty_on_hand = fields.Float(
        related='product_id.qty_available',
        string='On Hand',
        readonly=True,
        digits='Product Unit of Measure',
        help='Current quantity available in stock for this product'
    )

    @api.depends('product_id.landed_cost_ok', 'product_id.type')
    def _compute_is_landed_cost(self):
        for line in self:
            line.x_is_landed_cost = (
                    line.product_id and
                    line.product_id.landed_cost_ok and
                    line.product_id.type == 'service'
            )

    @api.depends('x_line_vendor_id', 'order_id.partner_id')
    def _compute_line_effective_vendor(self):
        for line in self:
            line.x_effective_vendor_id = line.x_line_vendor_id or line.order_id.partner_id


class PurchaseOrder(models.Model):
    _inherit = 'purchase.order'

    x_line_vendor_id = fields.Many2one(
        'res.partner',
        string='Line Vendor',
        help='Specific vendor for this line. Leave empty to use PO vendor.'
    )

    x_effective_vendor_id = fields.Many2one(
        'res.partner',
        string='Effective Vendor',
        compute='_compute_order_effective_vendor',
        store=True
    )

    @api.depends('partner_id', 'x_line_vendor_id')
    def _compute_order_effective_vendor(self):
        for order in self:
            order.x_effective_vendor_id = order.x_line_vendor_id or order.partner_id

    vendor_balance = fields.Monetary(
        string='Vendor Balance',
        compute='_compute_vendor_balance',
        currency_field='currency_id',
        help='Current balance with this vendor (Positive = We owe them, Negative = They owe us)'
    )

    @api.depends('partner_id', 'partner_id.credit', 'partner_id.debit')
    def _compute_vendor_balance(self):
        for order in self:
            if order.partner_id:
                balance = order.partner_id.credit - order.partner_id.debit
                order.vendor_balance = balance
            else:
                order.vendor_balance = 0.0

    x_auto_validate_picking = fields.Boolean(
        string='Auto Validate Receipt',
        default=True,
        help='Automatically validate the warehouse receipt when this order is confirmed'
    )

    x_multi_vendor_mode = fields.Boolean(
        string='Multi-Vendor Mode',
        default=True,
        help='Enable to create separate invoices for each vendor'
    )

    x_vendor_count = fields.Integer(
        string='Vendor Count',
        compute='_compute_vendor_count',
        store=True
    )

    x_has_landed_cost = fields.Boolean(
        string='Has Landed Cost',
        compute='_compute_has_landed_cost',
        store=True
    )

    x_landed_cost_ids = fields.One2many(
        'stock.landed.cost',
        'x_purchase_order_id',
        string='Landed Costs'
    )

    x_landed_cost_count = fields.Integer(
        string='Landed Cost Count',
        compute='_compute_landed_cost_count'
    )

    @api.depends('order_line.x_effective_vendor_id', 'x_multi_vendor_mode')
    def _compute_vendor_count(self):
        for order in self:
            if order.x_multi_vendor_mode:
                vendors = order.order_line.mapped('x_effective_vendor_id')
                order.x_vendor_count = len(vendors)
            else:
                order.x_vendor_count = 1

    @api.depends('order_line.product_id.landed_cost_ok', 'order_line.product_id.type')
    def _compute_has_landed_cost(self):
        for order in self:
            order.x_has_landed_cost = any(
                line.product_id.landed_cost_ok and line.product_id.type == 'service'
                for line in order.order_line
            )

    @api.depends('x_landed_cost_ids')
    def _compute_landed_cost_count(self):
        for order in self:
            order.x_landed_cost_count = len(order.x_landed_cost_ids)

    def button_confirm(self):
        res = super().button_confirm()

        for order in self:
            if order.x_auto_validate_picking:
                order._auto_validate_pickings()

        return res

    def _auto_validate_pickings(self):
        for picking in self.picking_ids.filtered(lambda p: p.state not in ['done', 'cancel']):
            try:
                if picking.state == 'draft':
                    picking.action_confirm()

                if picking.state in ['waiting', 'confirmed']:
                    picking.action_assign()

                if picking.state == 'assigned':
                    for move in picking.move_ids:
                        move.quantity = move.product_uom_qty

                    picking.x_auto_validated = True
                    picking.button_validate()

                    _logger.info(f"Auto-validated picking: {picking.name}")

            except Exception as e:
                _logger.error(f"Failed to auto-validate {picking.name}: {str(e)}")
                continue

    def action_create_invoice(self):
        if not self.x_multi_vendor_mode:
            return super().action_create_invoice()

        vendor_lines = defaultdict(lambda: self.env['purchase.order.line'])

        for line in self.order_line:
            vendor = line.x_effective_vendor_id
            if vendor:
                vendor_lines[vendor] |= line

        if not vendor_lines:
            raise UserError(_('No vendors found in order lines!'))

        created_invoices = self.env['account.move']

        for vendor, lines in vendor_lines.items():
            invoice_vals = self._prepare_invoice_vals_multi(vendor)
            invoice = self.env['account.move'].create(invoice_vals)

            for po_line in lines:
                invoice_line_vals = self._prepare_invoice_line_vals_multi(po_line, invoice)
                self.env['account.move.line'].with_context(check_move_validity=False).create(invoice_line_vals)

            created_invoices |= invoice
            _logger.info(f"Created invoice for vendor {vendor.name}")

        action = self.env["ir.actions.actions"]._for_xml_id("account.action_move_in_invoice_type")

        if len(created_invoices) == 1:
            action['views'] = [(self.env.ref('account.view_move_form').id, 'form')]
            action['res_id'] = created_invoices.id
        else:
            action['domain'] = [('id', 'in', created_invoices.ids)]
            action['name'] = f'Invoices ({len(created_invoices)} vendors)'

        return action

    def _prepare_invoice_vals_multi(self, vendor):
        self.ensure_one()

        return {
            'move_type': 'in_invoice',
            'partner_id': vendor.id,
            'currency_id': self.currency_id.id,
            'invoice_origin': self.name,
            'invoice_date': fields.Date.today(),
            'company_id': self.company_id.id,
            'payment_reference': f"{self.name} - {vendor.name}",
            'invoice_payment_term_id': self.payment_term_id.id if self.payment_term_id else False,
            'fiscal_position_id': self.fiscal_position_id.id if self.fiscal_position_id else False,
        }

    def _prepare_invoice_line_vals_multi(self, po_line, invoice):
        _logger.warning("=" * 80)
        _logger.warning(f"🎯 _prepare_invoice_line_vals_multi called!")
        _logger.warning(f"Product: {po_line.product_id.name if po_line.product_id else 'NO PRODUCT'}")
        _logger.warning(f"Product ID: {po_line.product_id.id if po_line.product_id else 'N/A'}")
        _logger.warning(
            f"Product Template ID: {po_line.product_id.product_tmpl_id.id if po_line.product_id else 'N/A'}")

        account = False

        if po_line.product_id:
            _logger.warning(f"Product Type (product_id): {po_line.product_id.type}")
            _logger.warning(f"Product Type (template): {po_line.product_id.product_tmpl_id.type}")
            # Check if detailed_type exists (Odoo 18+)
            if hasattr(po_line.product_id, 'detailed_type'):
                _logger.warning(f"Detailed Type: {po_line.product_id.detailed_type}")
            _logger.warning(f"Category: {po_line.product_id.categ_id.name}")
            _logger.warning(f"Valuation: {po_line.product_id.categ_id.property_valuation}")
            _logger.warning(
                f"Stock Input Account: {po_line.product_id.categ_id.property_stock_account_input_categ_id.name if po_line.product_id.categ_id.property_stock_account_input_categ_id else 'NOT SET'}")

            # Check Anglo-Saxon conditions
            # For Odoo 18: Use Automated Valuation + Stock Account existence
            # (Don't rely on 'type' or 'tracking' fields)

            is_automated = po_line.product_id.categ_id.property_valuation == 'real_time'
            has_stock_input = bool(
                po_line.product_id.categ_id.property_stock_account_input_categ_id or
                po_line.product_id.property_stock_account_input
            )

            _logger.warning(f"Automated Valuation: {is_automated}")
            _logger.warning(f"Has Stock Input Account: {has_stock_input}")

            if is_automated and has_stock_input:
                _logger.warning("✅ Conditions met for Anglo-Saxon!")

                account = po_line.product_id.categ_id.property_stock_account_input_categ_id
                _logger.warning(f"Stock Input (Category): {account.name if account else 'NOT SET'}")

                if not account:
                    account = po_line.product_id.property_stock_account_input
                    _logger.warning(f"Stock Input (Product): {account.name if account else 'NOT SET'}")
            else:
                _logger.warning(f"❌ Conditions NOT met: automated={is_automated}, has_stock_input={has_stock_input}")

            if not account:
                fiscal_pos = invoice.fiscal_position_id
                accounts = po_line.product_id.product_tmpl_id.get_product_accounts(fiscal_pos=fiscal_pos)
                account = accounts.get('expense')
                _logger.warning(f"⚠️ Using Expense Account: {account.name if account else 'NOT SET'}")

        if not account:
            account = self.env['account.account'].search([
                ('account_type', '=', 'expense'),
                ('company_id', '=', self.company_id.id)
            ], limit=1)
            _logger.warning(f"❌ Last Resort Expense: {account.name if account else 'NOT SET'}")

        if not account:
            raise UserError(_('Please define an expense account or stock input account'))

        _logger.warning(f"📤 FINAL ACCOUNT: {account.name} (ID: {account.id})")
        _logger.warning("=" * 80)

        return {
            'move_id': invoice.id,
            'product_id': po_line.product_id.id if po_line.product_id else False,
            'name': po_line.name or (po_line.product_id.name if po_line.product_id else ''),
            'quantity': po_line.product_qty,
            'price_unit': po_line.price_unit,
            'product_uom_id': po_line.product_uom.id,
            'account_id': account.id,
            'tax_ids': [(6, 0, po_line.taxes_id.ids)],
            'purchase_line_id': po_line.id,
        }

    def action_view_vendor_summary(self):
        self.ensure_one()

        if not self.x_multi_vendor_mode:
            return

        vendor_totals = {}
        for line in self.order_line:
            vendor = line.x_effective_vendor_id
            if vendor:
                if vendor.id not in vendor_totals:
                    vendor_totals[vendor.id] = {
                        'name': vendor.name,
                        'lines': 0,
                        'total': 0.0
                    }
                vendor_totals[vendor.id]['lines'] += 1
                vendor_totals[vendor.id]['total'] += line.price_subtotal

        message = "Vendor Distribution:\n\n"
        for vendor_data in vendor_totals.values():
            message += f"• {vendor_data['name']}: {vendor_data['lines']} lines, Total: {vendor_data['total']:,.2f}\n"

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Vendor Summary',
                'message': message,
                'type': 'info',
                'sticky': True,
            }
        }

    def action_view_vendor_ledger(self):
        self.ensure_one()

        if not self.partner_id:
            return

        return {
            'type': 'ir.actions.act_window',
            'name': f'Partner Ledger - {self.partner_id.name}',
            'res_model': 'account.move.line',
            'view_mode': 'tree,form',
            'domain': [
                ('partner_id', '=', self.partner_id.id),
                ('move_id.state', '=', 'posted'),
                ('account_id.account_type', 'in', ['liability_payable', 'asset_receivable'])
            ],
            'context': {
                'search_default_partner_id': self.partner_id.id,
                'default_partner_id': self.partner_id.id,
                'group_by': 'date',
            },
            'target': 'current',
        }

    def action_create_landed_cost(self):
        self.ensure_one()

        landed_cost_lines = self.order_line.filtered(
            lambda l: l.product_id.landed_cost_ok and l.product_id.type == 'service'
        )

        if not landed_cost_lines:
            raise UserError(_('No landed cost products found in this order!'))

        vendor_bills = self.invoice_ids.filtered(
            lambda inv: inv.move_type == 'in_invoice' and inv.state == 'posted'
        )

        if not vendor_bills:
            raise UserError(_('Please create and post vendor bill first!'))

        pickings = self.picking_ids.filtered(lambda p: p.state == 'done')

        if not pickings:
            raise UserError(_('No validated receipts found for this order!'))

        landed_cost = self.env['stock.landed.cost'].create({
            'vendor_bill_id': vendor_bills[0].id,
            'x_purchase_order_id': self.id,
            'picking_ids': [(6, 0, pickings.ids)],
            'cost_lines': [(0, 0, self._prepare_landed_cost_line(line)) for line in landed_cost_lines],
        })

        return {
            'type': 'ir.actions.act_window',
            'name': _('Landed Cost'),
            'res_model': 'stock.landed.cost',
            'res_id': landed_cost.id,
            'view_mode': 'form',
            'target': 'current',
        }

    def _prepare_landed_cost_line(self, po_line):
        if 'freight' in po_line.product_id.name.lower():
            split_method = 'by_weight'
        elif 'insurance' in po_line.product_id.name.lower():
            split_method = 'by_current_cost_price'
        else:
            split_method = 'equal'

        return {
            'product_id': po_line.product_id.id,
            'name': po_line.name or po_line.product_id.name,
            'price_unit': po_line.price_unit * po_line.product_qty,
            'split_method': 'by_current_cost_price',
            'account_id': po_line.product_id.property_account_expense_id.id or
                          po_line.product_id.categ_id.property_account_expense_categ_id.id,
        }

    def action_create_and_validate_landed_cost(self):
        self.ensure_one()

        action = self.action_create_landed_cost()
        landed_cost_id = action.get('res_id')

        if landed_cost_id:
            landed_cost = self.env['stock.landed.cost'].browse(landed_cost_id)

            try:
                landed_cost.compute_landed_cost()
                landed_cost.with_context(auto_validate_landed_cost=True).button_validate()

                _logger.info(f"Auto-validated landed cost: {landed_cost.name}")

                return {
                    'type': 'ir.actions.act_window',
                    'name': _('Landed Cost - Validated'),
                    'res_model': 'stock.landed.cost',
                    'res_id': landed_cost.id,
                    'view_mode': 'form',
                    'target': 'current',
                }

            except Exception as e:
                _logger.error(f"Failed to validate landed cost: {str(e)}")
                return action

        return action

    def action_view_landed_costs(self):
        self.ensure_one()

        action = self.env["ir.actions.actions"]._for_xml_id("stock_landed_costs.action_stock_landed_cost")
        action['domain'] = [('x_purchase_order_id', '=', self.id)]

        if len(self.x_landed_cost_ids) == 1:
            action['views'] = [(False, 'form')]
            action['res_id'] = self.x_landed_cost_ids.id

        return action


class StockPicking(models.Model):
    _inherit = 'stock.picking'

    x_auto_validated = fields.Boolean(
        string='Auto Validated',
        readonly=True,
        help='This receipt was automatically validated from purchase order'
    )

    def action_view_auto_status(self):
        return True


class StockLandedCost(models.Model):
    _inherit = 'stock.landed.cost'

    x_purchase_order_id = fields.Many2one(
        'purchase.order',
        string='Source Purchase Order',
        readonly=True,
        help='Purchase order that created this landed cost'
    )

    x_auto_validated = fields.Boolean(
        string='Auto Validated',
        readonly=True
    )

    def button_validate(self):
        if self.env.context.get('auto_validate_landed_cost'):
            self.x_auto_validated = True

        return super().button_validate()