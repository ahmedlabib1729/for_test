# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import UserError, ValidationError


class InvoiceExpense(models.Model):
    _name = 'invoice.expense'
    _description = 'Invoice Related Expense'
    _order = 'date desc, id desc'
    _inherit = ['mail.thread', 'mail.activity.mixin']

    name = fields.Char(
        string='Reference',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: _('New'),
        tracking=True
    )

    date = fields.Date(
        string='Date',
        required=True,
        default=fields.Date.context_today,
        tracking=True
    )

    description = fields.Text(
        string='Description',
        required=True,
        tracking=True
    )

    amount = fields.Monetary(
        string='Total Amount EXP Without Vat',
        required=True,
        currency_field='currency_id',
        tracking=True,
        help='Total expense amount to be distributed'
    )

    currency_id = fields.Many2one(
        'res.currency',
        string='Currency',
        required=True,
        default=lambda self: self.env.company.currency_id
    )

    platform = fields.Selection([
        ('amazon', 'Amazon'),
        ('noon', 'Noon'),
        ('other', 'Other')
    ], string='Platform', tracking=True)



    expense_type = fields.Selection([
        ('commission', 'Commission'),
        ('shipping', 'Shipping'),
        ('storage', 'Storage'),
        ('returns', 'Returns'),
        ('penalties', 'Penalties'),
        ('other', 'Other')
    ], string='Expense Type',default='commission', required=True, tracking=True)

    journal_id = fields.Many2one(
        'account.journal',
        string='Journal',
        required=True,
        domain=[('type', '=', 'bank')],
        default=lambda self: self._get_default_journal(),
        tracking=True
    )

    state = fields.Selection([
        ('draft', 'Draft'),
        ('posted', 'Posted'),
        ('cancelled', 'Cancelled')
    ], string='Status', default='draft', tracking=True, copy=False)

    move_id = fields.Many2one(
        'account.move',
        string='Journal Entry',
        readonly=True,
        copy=False,
        ondelete='restrict'
    )

    statement_reference = fields.Char(
        string='Statement Reference',
        help='Reference number from Amazon/Noon statement'
    )

    company_id = fields.Many2one(
        'res.company',
        string='Company',
        required=True,
        default=lambda self: self.env.company
    )

    notes = fields.Text(string='Notes')

    # Auto-generation fields
    auto_generate_lines = fields.Boolean(
        string='Auto-generate Journal Lines',
        default=True,
        help='Automatically generate journal lines from invoice distributions'
    )

    expense_account_id = fields.Many2one(
        'account.account',
        string='Expense Account',
        domain=[('account_type', '=', 'expense'), ('deprecated', '=', False)],
        help='Account for recording the expense'
    )

    tax_ids = fields.Many2many(
        'account.tax',
        string='Taxes on Expense',
        domain=[('type_tax_use', '=', 'purchase')],
        help='Taxes applicable on this expense'
    )

    bank_account_id = fields.Many2one(
        'account.account',
        string='Bank Account',
        compute='_compute_bank_account',
        store=True,
        help='Bank account from selected journal'
    )

    calculated_bank_amount = fields.Monetary(
        string='Calculated Bank Amount',
        compute='_compute_calculated_amounts',
        currency_field='currency_id',
        help='Amount that should be received in bank after deducting expenses'
    )

    total_with_tax = fields.Monetary(
        string='Expense with Tax',
        compute='_compute_calculated_amounts',
        currency_field='currency_id',
        help='Expense amount including taxes'
    )

    # Distribution Lines
    distribution_ids = fields.One2many(
        'invoice.expense.distribution',
        'expense_id',
        string='Invoice Distribution',
        copy=True
    )

    # Journal Entry Lines
    line_ids = fields.One2many(
        'invoice.expense.line',
        'expense_id',
        string='Journal Items',
        copy=True
    )

    # Computed totals
    total_distributed = fields.Monetary(
        string='Total Distributed',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id'
    )

    total_debit = fields.Monetary(
        string='Total Debit',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id'
    )

    total_credit = fields.Monetary(
        string='Total Credit',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id'
    )

    distribution_difference = fields.Monetary(
        string='Distribution Difference',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id',
        help='Amount - Total Distributed'
    )

    balance_difference = fields.Monetary(
        string='Balance Difference',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id',
        help='Total Debit - Total Credit'
    )

    @api.model
    def _get_default_journal(self):
        """Get default journal - prefer bank journal"""
        journal = self.env['account.journal'].search([
            ('type', '=', 'bank'),
            ('company_id', '=', self.env.company.id)
        ], limit=1)
        return journal

    @api.depends('journal_id', 'journal_id.default_account_id')
    def _compute_bank_account(self):
        """Get bank account from journal"""
        for record in self:
            if record.journal_id and record.journal_id.default_account_id:
                record.bank_account_id = record.journal_id.default_account_id
            else:
                record.bank_account_id = False

    @api.depends('distribution_ids', 'distribution_ids.invoice_amount',
                 'distribution_ids.invoice_id.move_type', 'amount', 'tax_ids')
    def _compute_calculated_amounts(self):
        """Calculate bank amount and expense with tax"""
        for record in self:
            # Calculate total invoices (positive) and credit notes (negative)
            # IMPORTANT: Use invoice_amount (original invoice total), NOT dist.amount!
            total_invoices = sum(
                abs(dist.invoice_amount) for dist in record.distribution_ids
                if dist.invoice_id.move_type == 'out_invoice'
            )
            total_credit_notes = sum(
                abs(dist.invoice_amount) for dist in record.distribution_ids
                if dist.invoice_id.move_type == 'out_refund'
            )

            # Calculate tax amount
            tax_amount = 0.0
            if record.tax_ids and record.amount:
                for tax in record.tax_ids:
                    if tax.amount_type == 'percent':
                        tax_amount += record.amount * (tax.amount / 100.0)
                    elif tax.amount_type == 'fixed':
                        tax_amount += tax.amount

            record.total_with_tax = record.amount + tax_amount

            # Bank = Total Invoices - Total Credit Notes - Expense with Tax
            record.calculated_bank_amount = (
                    total_invoices - total_credit_notes - record.total_with_tax
            )

    @api.depends('amount', 'distribution_ids.amount', 'line_ids.debit', 'line_ids.credit')
    def _compute_totals(self):
        """Compute distribution and balance totals"""
        for record in self:
            # Net distribution (respecting invoice type)
            total_dist = 0.0
            for dist in record.distribution_ids:
                if dist.invoice_id.move_type == 'out_invoice':
                    total_dist += dist.amount
                elif dist.invoice_id.move_type == 'out_refund':
                    # Credit notes are negative in distribution
                    total_dist -= dist.amount

            record.total_distributed = total_dist
            record.total_debit = sum(record.line_ids.mapped('debit'))
            record.total_credit = sum(record.line_ids.mapped('credit'))
            record.distribution_difference = 0.0  # Not used anymore with credit notes
            record.balance_difference = record.total_debit - record.total_credit

    @api.model_create_multi
    def create(self, vals_list):
        """Generate sequence for expense reference"""
        for vals in vals_list:
            if vals.get('name', _('New')) == _('New'):
                vals['name'] = self.env['ir.sequence'].next_by_code('invoice.expense') or _('New')
        return super().create(vals_list)

    @api.constrains('amount')
    def _check_amount(self):
        """Validate amount is positive"""
        for record in self:
            if record.amount <= 0:
                raise ValidationError(_('Amount must be greater than zero.'))

    @api.constrains('line_ids')
    def _check_balance(self):
        """Validate journal lines are balanced"""
        for record in self:
            if record.state == 'posted' and record.line_ids:
                if abs(record.balance_difference) > 0.01:
                    raise ValidationError(_(
                        'Journal entry is not balanced!\n'
                        'Total Debit: %.2f\n'
                        'Total Credit: %.2f\n'
                        'Difference: %.2f'
                    ) % (record.total_debit, record.total_credit, record.balance_difference))
            elif record.state == 'draft' and record.line_ids and record.tax_ids:
                # If there are taxes, allow difference = tax amount
                # Odoo will auto-generate tax lines on post
                expected_tax = sum(
                    record.amount * (tax.amount / 100.0) if tax.amount_type == 'percent'
                    else tax.amount
                    for tax in record.tax_ids
                )
                actual_diff = abs(record.balance_difference)

                # Allow difference if it matches expected tax amount (tolerance 0.01)
                if actual_diff > 0.01 and abs(actual_diff - expected_tax) > 0.01:
                    raise ValidationError(_(
                        'Journal entry is not balanced!\n'
                        'Difference: %.2f AED\n'
                        'Expected tax: %.2f AED\n\n'
                        'Note: If you added taxes, the difference should equal the tax amount.\n'
                        'Odoo will auto-generate tax lines when you post.'
                    ) % (actual_diff, expected_tax))

    @api.constrains('calculated_bank_amount')
    def _check_bank_amount(self):
        """Validate bank amount is not negative"""
        for record in self:
            if record.auto_generate_lines and record.calculated_bank_amount < 0:
                raise ValidationError(_(
                    'Calculated bank amount is negative (%.2f)!\n'
                    'The expense with tax (%.2f) is greater than the net invoices amount.\n'
                    'Please check your distributions or expense amount.'
                ) % (record.calculated_bank_amount, record.total_with_tax))

    def action_generate_lines(self):
        """Generate journal lines automatically from distributions"""
        self.ensure_one()

        if not self.distribution_ids:
            raise UserError(_('Please add invoice distributions first.'))

        if not self.expense_account_id:
            raise UserError(_('Please select an expense account.'))

        if not self.bank_account_id:
            raise UserError(_('Bank account not found in journal. Please check journal configuration.'))

        # Delete existing lines
        self.line_ids.unlink()

        lines_vals = []
        sequence = 10

        # Group distributions by partner - use INVOICE TOTALS for journal entry
        partner_amounts = {}
        for dist in self.distribution_ids:
            partner = dist.partner_id
            invoice = dist.invoice_id
            invoice_type = invoice.move_type
            key = (partner.id, invoice_type)

            if key not in partner_amounts:
                partner_amounts[key] = {
                    'partner': partner,
                    'invoice_type': invoice_type,
                    'amount': 0.0
                }
            # IMPORTANT: Use invoice total, not the distributed expense amount!
            # invoice_amount = original invoice total
            # dist.amount = distributed expense (used for profitability only)
            partner_amounts[key]['amount'] += abs(dist.invoice_amount)

        # Create lines for each partner
        for key, data in partner_amounts.items():
            partner = data['partner']
            invoice_type = data['invoice_type']
            amount = data['amount']

            if amount == 0:
                continue

            # Get receivable account from partner
            receivable_account = partner.property_account_receivable_id

            if invoice_type == 'out_invoice':
                # Credit receivable (قفل الدين)
                lines_vals.append({
                    'sequence': sequence,
                    'name': _('Invoice settlement - %s') % partner.name,
                    'account_id': receivable_account.id,
                    'partner_id': partner.id,
                    'debit': 0.0,
                    'credit': amount,
                })
            else:  # out_refund
                # Debit receivable (العميل مدين لينا)
                lines_vals.append({
                    'sequence': sequence,
                    'name': _('Credit Note - %s') % partner.name,
                    'account_id': receivable_account.id,
                    'partner_id': partner.id,
                    'debit': amount,
                    'credit': 0.0,
                })
            sequence += 10

        # Add expense line with taxes
        # IMPORTANT: Add tax_ids to the expense line, Odoo will auto-generate tax lines
        expense_line_vals = {
            'sequence': sequence,
            'name': self.description or _('Expense'),
            'account_id': self.expense_account_id.id,
            'debit': self.amount,
            'credit': 0.0,
        }

        # Add taxes to expense line - Odoo will generate tax lines automatically
        if self.tax_ids:
            expense_line_vals['tax_ids'] = [(6, 0, self.tax_ids.ids)]

        lines_vals.append(expense_line_vals)
        sequence += 10

        # Add bank line (calculated amount)
        if abs(self.calculated_bank_amount) > 0.01:
            lines_vals.append({
                'sequence': sequence,
                'name': _('Bank Receipt'),
                'account_id': self.bank_account_id.id,
                'debit': self.calculated_bank_amount if self.calculated_bank_amount > 0 else 0.0,
                'credit': abs(self.calculated_bank_amount) if self.calculated_bank_amount < 0 else 0.0,
            })

        # Create the lines
        self.write({'line_ids': [(0, 0, vals) for vals in lines_vals]})

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'message': _('Journal lines generated successfully! Please review and post.'),
                'type': 'success',
                'sticky': False,
                'next': {'type': 'ir.actions.act_window_close'},
            }
        }

    def action_post(self):
        """Post the expense and create journal entry"""
        for record in self:
            if record.state != 'draft':
                raise UserError(_('Only draft expenses can be posted.'))

            # Validate before posting
            if not record.distribution_ids:
                raise UserError(_('Please add at least one invoice distribution.'))

            if not record.line_ids:
                raise UserError(_('Please add at least one journal item.'))

            # Check balance - allow difference if it equals tax amount
            expected_tax = 0.0
            if record.tax_ids:
                expected_tax = sum(
                    record.amount * (tax.amount / 100.0) if tax.amount_type == 'percent'
                    else tax.amount
                    for tax in record.tax_ids
                )

            actual_diff = abs(record.balance_difference)

            # If no taxes, must be balanced
            # If taxes exist, difference should equal tax amount
            if not record.tax_ids and actual_diff > 0.01:
                raise UserError(_(
                    'Journal entry must be balanced.\n'
                    'Difference: %.2f'
                ) % record.balance_difference)
            elif record.tax_ids and abs(actual_diff - expected_tax) > 0.01:
                raise UserError(_(
                    'Journal entry balance incorrect!\n'
                    'Difference: %.2f\n'
                    'Expected tax: %.2f\n\n'
                    'The difference should equal the tax amount.\n'
                    'Odoo will auto-generate tax lines.'
                ) % (actual_diff, expected_tax))

            # Create journal entry
            move_vals = record._prepare_move_vals()
            move = self.env['account.move'].create(move_vals)
            move.action_post()

            # Link the move to expense
            record.write({
                'move_id': move.id,
                'state': 'posted'
            })

            # Update invoice expenses
            for dist in record.distribution_ids:
                if dist.invoice_id:
                    dist.invoice_id._compute_expense_data()

            # Post message
            record.message_post(
                body=_('Expense posted. Journal Entry: %s', move.name)
            )

    def action_cancel(self):
        """Cancel the expense"""
        for record in self:
            if record.state == 'posted' and record.move_id:
                if record.move_id.state == 'posted':
                    raise UserError(_(
                        'Cannot cancel this expense. Please cancel or delete the journal entry first: %s',
                        record.move_id.name
                    ))

            record.state = 'cancelled'
            record.message_post(body=_('Expense cancelled.'))

    def action_draft(self):
        """Reset to draft"""
        for record in self:
            if record.move_id and record.move_id.state == 'posted':
                raise UserError(_(
                    'Cannot reset to draft. Journal entry is still posted: %s',
                    record.move_id.name
                ))

            record.state = 'draft'

    def unlink(self):
        """Prevent deletion of posted expenses"""
        if any(exp.state == 'posted' for exp in self):
            raise UserError(_('You cannot delete posted expenses. Please cancel them first.'))

        # Delete related moves if in draft
        moves_to_delete = self.mapped('move_id').filtered(lambda m: m.state == 'draft')
        if moves_to_delete:
            moves_to_delete.unlink()

        return super().unlink()

    def _prepare_move_vals(self):
        """Prepare journal entry values"""
        self.ensure_one()

        return {
            'move_type': 'entry',
            'date': self.date,
            'journal_id': self.journal_id.id,
            'ref': self.name,
            'narration': self.description,
            'company_id': self.company_id.id,
            'line_ids': [
                (0, 0, line._prepare_move_line_vals()) for line in self.line_ids
            ],
        }

    def action_view_journal_entry(self):
        """Open the related journal entry"""
        self.ensure_one()
        if not self.move_id:
            raise UserError(_('No journal entry found for this expense.'))

        return {
            'name': _('Journal Entry'),
            'type': 'ir.actions.act_window',
            'res_model': 'account.move',
            'view_mode': 'form',
            'res_id': self.move_id.id,
            'target': 'current',
        }