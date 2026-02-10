# -*- coding: utf-8 -*-

from odoo import models, fields, api, _
from odoo.exceptions import UserError, ValidationError


class DailyCashRegister(models.Model):
    _name = 'daily.cash.register'
    _description = 'Daily Cash/Bank Register'
    _order = 'date desc, id desc'
    _inherit = ['mail.thread', 'mail.activity.mixin']

    # ==================== BASIC FIELDS ====================

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
        states={'posted': [('readonly', True)], 'cancel': [('readonly', True)]},
        tracking=True
    )

    journal_id = fields.Many2one(
        'account.journal',
        string='Journal',
        required=True,
        domain="[('type', 'in', ['bank', 'cash']), ('company_id', '=', company_id)]",
        states={'posted': [('readonly', True)], 'cancel': [('readonly', True)]},
        tracking=True
    )

    company_id = fields.Many2one(
        'res.company',
        string='Company',
        required=True,
        default=lambda self: self.env.company,
        readonly=True
    )

    currency_id = fields.Many2one(
        'res.currency',
        string='Currency',
        related='company_id.currency_id',
        store=True,
        readonly=True
    )

    state = fields.Selection([
        ('draft', 'Draft'),
        ('posted', 'Posted'),
        ('cancel', 'Cancelled')
    ], string='Status', default='draft', required=True, tracking=True)

    # ==================== LINES ====================

    line_ids = fields.One2many(
        'daily.cash.register.line',
        'register_id',
        string='Transaction Lines',
        states={'posted': [('readonly', True)], 'cancel': [('readonly', True)]}
    )

    # ==================== COMPUTED FIELDS ====================

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

    balance = fields.Monetary(
        string='Balance (Debit - Credit)',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id',
        help='Positive = Net Debit, Negative = Net Credit'
    )

    total_tax = fields.Monetary(
        string='Total Tax',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id',
        help='Total tax amount from all lines'
    )

    grand_total = fields.Monetary(
        string='Grand Total',
        compute='_compute_totals',
        store=True,
        currency_field='currency_id',
        help='Total amount including tax'
    )

    journal_account_id = fields.Many2one(
        'account.account',
        string='Journal Account',
        related='journal_id.default_account_id',
        store=True,
        readonly=True,
        help='The default account of the selected journal (Bank/Cash account)'
    )

    move_id = fields.Many2one(
        'account.move',
        string='Journal Entry',
        readonly=True,
        copy=False,
        help='The generated journal entry after posting'
    )

    line_count = fields.Integer(
        string='Number of Lines',
        compute='_compute_line_count'
    )

    # ==================== COMPUTES ====================

    @api.depends('line_ids.debit', 'line_ids.credit', 'line_ids.tax_amount')
    def _compute_totals(self):
        for record in self:
            record.total_debit = sum(record.line_ids.mapped('debit'))
            record.total_credit = sum(record.line_ids.mapped('credit'))
            record.balance = record.total_debit - record.total_credit
            record.total_tax = sum(record.line_ids.mapped('tax_amount'))
            record.grand_total = record.total_debit + record.total_credit + record.total_tax

    @api.depends('line_ids')
    def _compute_line_count(self):
        for record in self:
            record.line_count = len(record.line_ids)

    # ==================== CONSTRAINTS ====================

    @api.constrains('date', 'journal_id')
    def _check_unique_date_journal(self):
        """Check that only one register exists per date per journal"""
        for record in self:
            if record.state != 'cancel':
                duplicate = self.search([
                    ('id', '!=', record.id),
                    ('date', '=', record.date),
                    ('journal_id', '=', record.journal_id.id),
                    ('state', '!=', 'cancel')
                ], limit=1)

                if duplicate:
                    raise ValidationError(_(
                        'A daily register already exists for %s on %s.\n'
                        'Only one register per journal per day is allowed.\n'
                        'Existing register: %s'
                    ) % (record.journal_id.name, record.date, duplicate.name))

    @api.constrains('line_ids')
    def _check_lines_exist(self):
        """Ensure at least one line exists before posting"""
        for record in self:
            if record.state == 'posted' and not record.line_ids:
                raise ValidationError(_('You cannot post a register without any transaction lines.'))

    # ==================== ONCHANGE ====================

    @api.onchange('journal_id')
    def _onchange_journal_id(self):
        """Update lines when journal changes"""
        if self.journal_id and self.line_ids:
            # Clear lines if journal changes
            return {
                'warning': {
                    'title': _('Warning'),
                    'message': _('Changing the journal will not affect existing lines. '
                                 'Please verify all accounts are correct.')
                }
            }

    # ==================== CRUD ====================

    @api.model_create_multi
    def create(self, vals_list):
        """Override create to generate sequence number"""
        for vals in vals_list:
            if vals.get('name', _('New')) == _('New'):
                journal_id = vals.get('journal_id')
                date = vals.get('date', fields.Date.context_today(self))

                # Convert date to string if needed
                if isinstance(date, str):
                    date_str = date
                else:
                    date_str = fields.Date.to_string(date)

                if journal_id:
                    journal = self.env['account.journal'].browse(journal_id)
                    vals['name'] = 'DCR/%s/%s' % (journal.code, date_str)
                else:
                    vals['name'] = 'DCR/%s' % date_str

        return super(DailyCashRegister, self).create(vals_list)

    def write(self, vals):
        """Prevent editing posted registers"""
        if 'state' not in vals:
            for record in self:
                if record.state == 'posted':
                    raise UserError(_('You cannot modify a posted register. Please cancel it first.'))

        return super(DailyCashRegister, self).write(vals)

    def unlink(self):
        """Prevent deleting posted registers"""
        for record in self:
            if record.state == 'posted':
                raise UserError(_('You cannot delete a posted register. Please cancel it first.'))

        return super(DailyCashRegister, self).unlink()

    # ==================== ACTIONS ====================

    def action_post(self):
        """
        Post the daily register and create journal entry
        """
        for record in self:
            # Validation
            if not record.line_ids:
                raise UserError(_('Please add at least one transaction line before posting.'))

            if not record.journal_id:
                raise UserError(_('Please select a journal before posting.'))

            if not record.journal_account_id:
                raise UserError(_(
                    'The selected journal "%s" does not have a default account configured.\n'
                    'Please configure the journal account first.'
                ) % record.journal_id.name)

            # Create journal entry
            move_vals = record._prepare_move_vals()
            move = self.env['account.move'].create(move_vals)

            # Post the move
            move.action_post()

            # Update register
            record.write({
                'state': 'posted',
                'move_id': move.id
            })

            # Log message
            record.message_post(
                body=_('Daily register posted. Journal Entry: %s') % move.name
            )

        return True

    def action_cancel(self):
        """Cancel the register and delete the journal entry"""
        for record in self:
            if record.move_id:
                # Cancel and delete the journal entry
                if record.move_id.state == 'posted':
                    record.move_id.button_draft()

                record.move_id.button_cancel()
                move_name = record.move_id.name
                record.move_id.unlink()

                record.message_post(
                    body=_('Daily register cancelled. Journal Entry %s deleted.') % move_name
                )

            record.write({
                'state': 'cancel',
                'move_id': False
            })

        return True

    def action_draft(self):
        """Set register back to draft"""
        for record in self:
            if record.move_id:
                raise UserError(_(
                    'Cannot set to draft while journal entry exists.\n'
                    'Please cancel the register first.'
                ))

            record.write({'state': 'draft'})

        return True

    def action_view_move(self):
        """Open the related journal entry"""
        self.ensure_one()

        if not self.move_id:
            raise UserError(_('No journal entry has been created yet.'))

        return {
            'name': _('Journal Entry'),
            'type': 'ir.actions.act_window',
            'res_model': 'account.move',
            'view_mode': 'form',
            'res_id': self.move_id.id,
            'target': 'current',
        }

    # ==================== PRIVATE METHODS ====================

    def _prepare_move_vals(self):
        """
        Prepare values for creating the journal entry
        Auto-balances with the journal's default account
        Includes tax lines for tax reporting
        """
        self.ensure_one()

        move_lines = []
        total_tax_debit = 0.0
        total_tax_credit = 0.0

        # Add all transaction lines
        for line in self.line_ids:
            # Determine base amount and direction
            is_debit = line.debit > 0
            base_amount = line.debit if is_debit else line.credit

            # If tax is price inclusive, adjust the base amount
            if line.tax_id and line.tax_id.price_include:
                tax_rate = line.tax_id.amount / 100
                base_amount = base_amount / (1 + tax_rate)

            # Main transaction line
            line_vals = {
                'name': line.description or '/',
                'account_id': line.account_id.id,
                'partner_id': line.partner_id.id if line.partner_id else False,
                'debit': base_amount if is_debit else 0,
                'credit': base_amount if not is_debit else 0,
                'date': self.date,
            }

            # Add tax_ids to the base line (required for tax reporting)
            if line.tax_id:
                line_vals['tax_ids'] = [(6, 0, [line.tax_id.id])]

            move_lines.append((0, 0, line_vals))

            # Add tax line if tax is selected
            if line.tax_id and line.tax_amount > 0:
                # Get tax account
                tax_account = False
                if is_debit:
                    # For debit (expense/asset), use purchase tax account (tax credit/refund)
                    tax_account = line.tax_id.invoice_repartition_line_ids.filtered(
                        lambda r: r.repartition_type == 'tax'
                    ).account_id
                else:
                    # For credit (income/liability), use sale tax account (tax payable)
                    tax_account = line.tax_id.refund_repartition_line_ids.filtered(
                        lambda r: r.repartition_type == 'tax'
                    ).account_id

                if not tax_account:
                    # Fallback: try the other repartition
                    tax_account = line.tax_id.invoice_repartition_line_ids.filtered(
                        lambda r: r.repartition_type == 'tax'
                    ).account_id or line.tax_id.refund_repartition_line_ids.filtered(
                        lambda r: r.repartition_type == 'tax'
                    ).account_id

                if tax_account:
                    # Get the repartition line for tax_repartition_line_id
                    if is_debit:
                        repartition_line = line.tax_id.invoice_repartition_line_ids.filtered(
                            lambda r: r.repartition_type == 'tax'
                        )
                    else:
                        repartition_line = line.tax_id.refund_repartition_line_ids.filtered(
                            lambda r: r.repartition_type == 'tax'
                        )

                    tax_line_vals = {
                        'name': _('%s - %s') % (line.tax_id.name, line.description or '/'),
                        'account_id': tax_account.id,
                        'partner_id': line.partner_id.id if line.partner_id else False,
                        'debit': line.tax_amount if is_debit else 0,
                        'credit': line.tax_amount if not is_debit else 0,
                        'date': self.date,
                        # Important fields for Tax Report
                        'tax_line_id': line.tax_id.id,
                        'tax_base_amount': base_amount,
                        'tax_repartition_line_id': repartition_line.id if repartition_line else False,
                    }
                    move_lines.append((0, 0, tax_line_vals))

                    # Track tax amounts for balance calculation
                    if is_debit:
                        total_tax_debit += line.tax_amount
                    else:
                        total_tax_credit += line.tax_amount

        # Calculate balance including tax
        balance = (self.total_debit + total_tax_debit) - (self.total_credit + total_tax_credit)

        # Adjust for price inclusive taxes
        for line in self.line_ids:
            if line.tax_id and line.tax_id.price_include:
                # The original amount already includes tax, so we need to adjust
                if line.debit > 0:
                    balance = balance - line.tax_amount
                else:
                    balance = balance + line.tax_amount

        # Add balancing line for journal account
        if not self.currency_id.is_zero(balance):
            move_lines.append((0, 0, {
                'name': _('Balance - %s') % self.name,
                'account_id': self.journal_account_id.id,
                'debit': abs(balance) if balance < 0 else 0,
                'credit': abs(balance) if balance > 0 else 0,
                'date': self.date,
            }))

        # Create move values
        move_vals = {
            'journal_id': self.journal_id.id,
            'date': self.date,
            'ref': self.name,
            'move_type': 'entry',
            'line_ids': move_lines,
        }

        return move_vals