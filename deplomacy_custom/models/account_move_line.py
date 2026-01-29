# models/account_move.py
from odoo import models, fields, api, _
from odoo.tools import float_compare
import logging

_logger = logging.getLogger(__name__)


class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    product_image = fields.Binary(
        string='Product Image',
        related='product_id.image_128',
        readonly=True,
        store=False
    )

    product_image_medium = fields.Binary(
        string='Product Image',
        related='product_id.image_512',
        readonly=True,
        store=False
    )

    has_product = fields.Boolean(
        compute='_compute_has_product',
        store=False
    )

    @api.depends('product_id')
    def _compute_has_product(self):
        for line in self:
            line.has_product = bool(line.product_id)

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎯 FIX 1: Override _get_computed_account
    # ═══════════════════════════════════════════════════════════════════════════
    def _get_computed_account(self):
        """Fix account for Anglo-Saxon on vendor bills"""
        self.ensure_one()

        # Check if vendor bill with Anglo-Saxon product
        if self.move_id and \
                self.move_id.move_type == 'in_invoice' and \
                self.product_id and \
                self.product_id.type == 'product' and \
                self.product_id.categ_id.property_valuation == 'real_time':

            # Get Stock Input Account
            stock_input = self.product_id.categ_id.property_stock_account_input_categ_id
            if not stock_input:
                stock_input = self.product_id.property_stock_account_input

            if stock_input:
                _logger.info(f"✅ _get_computed_account: {self.product_id.name} -> {stock_input.name}")
                return stock_input

        # Default behavior
        return super()._get_computed_account()

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎯 FIX 2: Override create
    # ═══════════════════════════════════════════════════════════════════════════
    @api.model_create_multi
    def create(self, vals_list):
        """Fix account before creating the line"""

        for vals in vals_list:
            # Skip non-product lines
            if vals.get('display_type') in ('line_section', 'line_note'):
                continue

            product_id = vals.get('product_id')
            move_id = vals.get('move_id')

            if not product_id or not move_id:
                continue

            # Get the move and product
            move = self.env['account.move'].browse(move_id)
            product = self.env['product.product'].browse(product_id)

            # Check if vendor bill with Anglo-Saxon product
            if move.move_type == 'in_invoice' and \
                    product.type == 'product' and \
                    product.categ_id.property_valuation == 'real_time':

                # Get Stock Input Account
                stock_input = product.categ_id.property_stock_account_input_categ_id
                if not stock_input:
                    stock_input = product.property_stock_account_input

                if stock_input:
                    _logger.info(f"✅ create: Fixing {product.name} -> {stock_input.name}")
                    vals['account_id'] = stock_input.id

        # Create the lines
        lines = super().create(vals_list)

        # Double-check after creation
        for line in lines:
            if line.move_id.move_type == 'in_invoice' and \
                    line.product_id and \
                    line.product_id.type == 'product' and \
                    line.product_id.categ_id.property_valuation == 'real_time':

                stock_input = line.product_id.categ_id.property_stock_account_input_categ_id
                if not stock_input:
                    stock_input = line.product_id.property_stock_account_input

                if stock_input and line.account_id != stock_input:
                    _logger.warning(f"⚠️ Fixing account AFTER create: {line.product_id.name}")
                    line.account_id = stock_input

        return lines

    def action_view_product_sales_history(self):
        self.ensure_one()

        if not self.product_id:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'تحذير',
                    'message': 'يرجى اختيار منتج أولاً',
                    'type': 'warning',
                    'sticky': False,
                }
            }

        wizard = self.env['product.sales.history.wizard'].create({
            'product_id': self.product_id.id,
            'current_partner_id': self.move_id.partner_id.id if self.move_id else False,
        })

        return {
            'name': f'📊 تاريخ مبيعات: {self.product_id.display_name}',
            'type': 'ir.actions.act_window',
            'res_model': 'product.sales.history.wizard',
            'view_mode': 'form',
            'res_id': wizard.id,
            'target': 'new',
            'context': {'dialog_size': 'extra-large'},
        }


class AccountMove(models.Model):
    _inherit = 'account.move'

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎯 FIX 3: Override create on account.move
    # ═══════════════════════════════════════════════════════════════════════════
    @api.model_create_multi
    def create(self, vals_list):
        """Fix accounts after creating vendor bills"""

        # Create the moves
        moves = super().create(vals_list)

        # Fix accounts for vendor bills
        for move in moves:
            if move.move_type == 'in_invoice':
                for line in move.invoice_line_ids:
                    if not line.product_id:
                        continue

                    # Anglo-Saxon check
                    if line.product_id.type == 'product' and \
                            line.product_id.categ_id.property_valuation == 'real_time':

                        # Get Stock Input Account
                        stock_input = line.product_id.categ_id.property_stock_account_input_categ_id
                        if not stock_input:
                            stock_input = line.product_id.property_stock_account_input

                        if stock_input and line.account_id != stock_input:
                            _logger.info(f"✅ Move create: Fixing {line.product_id.name} -> {stock_input.name}")
                            line.account_id = stock_input

        return moves

    # ═══════════════════════════════════════════════════════════════════════════
    # Partner Balance Fields
    # ═══════════════════════════════════════════════════════════════════════════
    partner_balance = fields.Monetary(
        string='رصيد الشريك',
        compute='_compute_partner_balance',
        store=False,
        currency_field='currency_id',
        help='رصيد العميل/المورد قبل هذه الفاتورة'
    )

    partner_balance_type = fields.Selection([
        ('debit', 'مدين'),
        ('credit', 'دائن'),
        ('zero', 'صفر')
    ], string='نوع الرصيد', compute='_compute_partner_balance', store=False)

    @api.depends('partner_id', 'state', 'date')
    def _compute_partner_balance(self):
        for record in self:
            if not record.partner_id:
                record.partner_balance = 0
                record.partner_balance_type = 'zero'
                continue

            query = """
                SELECT 
                    COALESCE(SUM(aml.debit), 0) as total_debit,
                    COALESCE(SUM(aml.credit), 0) as total_credit
                FROM account_move_line aml
                JOIN account_move am ON aml.move_id = am.id
                JOIN account_account aa ON aml.account_id = aa.id
                WHERE 
                    aml.partner_id = %s
                    AND aa.account_type IN ('asset_receivable', 'liability_payable')
                    AND am.state = 'posted'
                    AND am.id != %s
                    AND (am.date < %s OR (am.date = %s AND am.id < %s))
            """

            params = [
                record.partner_id.id,
                record.id or 0,
                record.date or fields.Date.today(),
                record.date or fields.Date.today(),
                record.id or 0
            ]

            self.env.cr.execute(query, params)
            result = self.env.cr.dictfetchone()

            total_debit = result['total_debit'] or 0
            total_credit = result['total_credit'] or 0
            balance = total_debit - total_credit

            precision = record.currency_id.decimal_places
            comparison = float_compare(balance, 0, precision_digits=precision)

            if comparison > 0:
                record.partner_balance = abs(balance)
                record.partner_balance_type = 'debit'
            elif comparison < 0:
                record.partner_balance = abs(balance)
                record.partner_balance_type = 'credit'
            else:
                record.partner_balance = 0
                record.partner_balance_type = 'zero'

    balance_after_invoice = fields.Monetary(
        string='الرصيد بعد الفاتورة',
        compute='_compute_balance_after_invoice',
        store=False,
        currency_field='currency_id',
        help='رصيد العميل/المورد بعد احتساب هذه الفاتورة'
    )

    balance_after_type = fields.Selection([
        ('debit', 'مدين'),
        ('credit', 'دائن'),
        ('zero', 'صفر')
    ], string='نوع الرصيد بعد الفاتورة', compute='_compute_balance_after_invoice', store=False)

    @api.depends('partner_balance', 'partner_balance_type', 'amount_total', 'move_type', 'state')
    def _compute_balance_after_invoice(self):
        for record in self:
            if not record.partner_id:
                record.balance_after_invoice = 0
                record.balance_after_type = 'zero'
                continue

            if record.partner_balance_type == 'debit':
                current_balance = record.partner_balance
            elif record.partner_balance_type == 'credit':
                current_balance = -record.partner_balance
            else:
                current_balance = 0

            invoice_impact = 0
            if record.state != 'cancel':
                if record.move_type == 'out_invoice':
                    invoice_impact = record.amount_total
                elif record.move_type == 'out_refund':
                    invoice_impact = -record.amount_total
                elif record.move_type == 'in_invoice':
                    invoice_impact = -record.amount_total
                elif record.move_type == 'in_refund':
                    invoice_impact = record.amount_total

            new_balance = current_balance + invoice_impact

            precision = record.currency_id.decimal_places
            comparison = float_compare(new_balance, 0, precision_digits=precision)

            if comparison > 0:
                record.balance_after_invoice = abs(new_balance)
                record.balance_after_type = 'debit'
            elif comparison < 0:
                record.balance_after_invoice = abs(new_balance)
                record.balance_after_type = 'credit'
            else:
                record.balance_after_invoice = 0
                record.balance_after_type = 'zero'

    partner_total_debit = fields.Monetary(
        string='إجمالي المدين',
        compute='_compute_partner_detailed_balance',
        store=False,
        currency_field='currency_id'
    )

    partner_total_credit = fields.Monetary(
        string='إجمالي الدائن',
        compute='_compute_partner_detailed_balance',
        store=False,
        currency_field='currency_id'
    )

    @api.depends('partner_id', 'state', 'date')
    def _compute_partner_detailed_balance(self):
        for record in self:
            if not record.partner_id:
                record.partner_total_debit = 0
                record.partner_total_credit = 0
                continue

            domain = [
                ('partner_id', '=', record.partner_id.id),
                ('account_id.account_type', 'in', ['asset_receivable', 'liability_payable']),
                ('parent_state', '=', 'posted'),
                ('move_id', '!=', record.id or 0)
            ]

            if record.date:
                domain.append(('date', '<=', record.date))

            move_lines = self.env['account.move.line'].search_read(
                domain,
                ['debit', 'credit'],
                limit=None
            )

            record.partner_total_debit = sum(line['debit'] for line in move_lines)
            record.partner_total_credit = sum(line['credit'] for line in move_lines)