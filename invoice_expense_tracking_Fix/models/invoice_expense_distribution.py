# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


class InvoiceExpenseDistribution(models.Model):
    _name = 'invoice.expense.distribution'
    _description = 'Invoice Expense Distribution'
    _order = 'sequence, id'

    sequence = fields.Integer(string='Sequence', default=10)

    expense_id = fields.Many2one(
        'invoice.expense',
        string='Expense',
        required=True,
        ondelete='cascade'
    )

    invoice_id = fields.Many2one(
        'account.move',
        string='Invoice',
        required=True,
        domain=[('move_type', 'in', ['out_invoice', 'out_refund']), ('state', '=', 'posted')],
        ondelete='restrict'
    )

    partner_id = fields.Many2one(
        'res.partner',
        string='Customer',
        related='invoice_id.partner_id',
        store=True,
        readonly=True
    )

    invoice_type = fields.Selection(
        string='Type',
        related='invoice_id.move_type',
        store=True,
        readonly=True
    )

    invoice_amount = fields.Monetary(
        string='Invoice Total',
        related='invoice_id.amount_total',
        readonly=True,
        currency_field='currency_id',
        help='Total amount of the selected invoice including taxes'
    )

    already_distributed = fields.Monetary(
        string='Already Distributed',
        compute='_compute_invoice_distribution_info',
        currency_field='currency_id',
        help='Total expenses already distributed to this invoice (from posted expenses)'
    )

    remaining_on_invoice = fields.Monetary(
        string='Remaining',
        compute='_compute_invoice_distribution_info',
        currency_field='currency_id',
        help='Remaining amount that can be distributed to this invoice'
    )

    amount = fields.Monetary(
        string='Amount',
        required=True,
        currency_field='currency_id',
        help='For invoices: positive amount. For credit notes: positive amount (will be handled as debit in journal)'
    )

    currency_id = fields.Many2one(
        'res.currency',
        string='Currency',
        related='expense_id.currency_id',
        store=True,
        readonly=True
    )

    company_id = fields.Many2one(
        'res.company',
        string='Company',
        related='expense_id.company_id',
        store=True,
        readonly=True
    )

    notes = fields.Char(string='Notes')

    @api.depends('invoice_id')
    def _compute_invoice_distribution_info(self):
        """Calculate already distributed amount and remaining for this invoice"""
        for record in self:
            if record.invoice_id:
                # Get all posted expense distributions for this invoice
                # excluding current record
                domain = [
                    ('invoice_id', '=', record.invoice_id.id),
                    ('expense_id.state', '=', 'posted'),
                    ('id', '!=', record.id or 0)
                ]
                distributions = self.search(domain)
                record.already_distributed = sum(distributions.mapped('amount'))
                record.remaining_on_invoice = abs(record.invoice_amount) - record.already_distributed
            else:
                record.already_distributed = 0.0
                record.remaining_on_invoice = 0.0

    @api.constrains('amount')
    def _check_amount(self):
        """Validate amount is positive"""
        for record in self:
            if record.amount <= 0:
                raise ValidationError(_('Distribution amount must be greater than zero.'))

    @api.onchange('invoice_id')
    def _onchange_invoice_id(self):
        """Show invoice info and suggest remaining amount when selecting invoice"""
        if self.invoice_id and self.expense_id:
            invoice_type_label = dict(self._fields['invoice_type'].related_field.selection).get(
                self.invoice_id.move_type, self.invoice_id.move_type
            )

            # Calculate what's already distributed to this invoice
            domain = [
                ('invoice_id', '=', self.invoice_id.id),
                ('expense_id.state', '=', 'posted'),
                ('id', '!=', self.id or 0)
            ]
            distributions = self.search(domain)
            already_distributed = sum(distributions.mapped('amount'))
            invoice_total = abs(self.invoice_id.amount_untaxed)
            remaining_on_invoice = invoice_total - already_distributed

            # Calculate how much left to distribute in current expense
            total_distributed_in_expense = sum(
                dist.amount if dist.invoice_id.move_type == 'out_invoice' else dist.amount
                for dist in self.expense_id.distribution_ids
            )
            remaining_in_expense = self.expense_id.amount - total_distributed_in_expense

            # Suggest the minimum of both
            if remaining_in_expense > 0:
                suggested = min(remaining_on_invoice, remaining_in_expense)
                if suggested > 0:
                    self.amount = suggested

            # Show informative message
            return {
                'warning': {
                    'title': _('Invoice Information'),
                    'message': _(
                        '📋 %s: %s\n'
                        '━━━━━━━━━━━━━━━━━━━━━━\n'
                        '📌 Type: %s\n'
                        '💰 Amount: %s %s\n'
                        '📊 Already Distributed: %s %s\n'
                        '✅ Remaining: %s %s\n'
                        '━━━━━━━━━━━━━━━━━━━━━━\n'
                        '💡 Expense Budget: %s %s\n'
                        '🎯 To Distribute: %s %s\n'
                        '━━━━━━━━━━━━━━━━━━━━━━\n'
                        'ℹ️ For credit notes: Enter positive amount (will be handled as debit automatically)'
                    ) % (
                                   invoice_type_label,
                                   self.invoice_id.name,
                                   invoice_type_label,
                                   self.invoice_id.currency_id.symbol,
                                   '{:,.2f}'.format(invoice_total),
                                   self.invoice_id.currency_id.symbol,
                                   '{:,.2f}'.format(already_distributed),
                                   self.invoice_id.currency_id.symbol,
                                   '{:,.2f}'.format(remaining_on_invoice),
                                   self.expense_id.currency_id.symbol,
                                   '{:,.2f}'.format(self.expense_id.amount),
                                   self.expense_id.currency_id.symbol,
                                   '{:,.2f}'.format(remaining_in_expense)
                               )
                }
            }