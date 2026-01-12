# -*- coding: utf-8 -*-

from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


class DailyCashRegisterLine(models.Model):
    _name = 'daily.cash.register.line'
    _description = 'Daily Cash/Bank Register Line'
    _order = 'register_id, sequence, id'

    # ==================== BASIC FIELDS ====================

    register_id = fields.Many2one(
        'daily.cash.register',
        string='Daily Register',
        required=True,
        ondelete='cascade',
        index=True
    )

    sequence = fields.Integer(
        string='Sequence',
        default=10
    )

    description = fields.Char(
        string='Description',
        required=True,
        help='Description of the transaction'
    )

    account_id = fields.Many2one(
        'account.account',
        string='Account',
        required=True,
        domain="[('deprecated', '=', False), ('company_id', '=', company_id)]",
        help='Account from Chart of Accounts'
    )

    partner_id = fields.Many2one(
        'res.partner',
        string='Partner',
        help='Customer or Vendor (optional)'
    )

    debit = fields.Monetary(
        string='Debit',
        default=0.0,
        currency_field='currency_id',
        help='Amount debited to the account'
    )

    credit = fields.Monetary(
        string='Credit',
        default=0.0,
        currency_field='currency_id',
        help='Amount credited to the account'
    )

    # ==================== TAX FIELD ====================

    tax_id = fields.Many2one(
        'account.tax',
        string='Tax',
        domain="[('company_id', '=', company_id), ('type_tax_use', 'in', ['purchase', 'sale', 'none'])]",
        help='Select tax to apply on this line. The tax amount will be calculated and added as a separate line in the journal entry.'
    )

    tax_amount = fields.Monetary(
        string='Tax Amount',
        compute='_compute_tax_amount',
        store=True,
        currency_field='currency_id',
        help='Calculated tax amount based on selected tax'
    )

    amount_with_tax = fields.Monetary(
        string='Total with Tax',
        compute='_compute_tax_amount',
        store=True,
        currency_field='currency_id',
        help='Total amount including tax'
    )

    # ==================== RELATED FIELDS ====================

    company_id = fields.Many2one(
        'res.company',
        string='Company',
        related='register_id.company_id',
        store=True,
        readonly=True
    )

    currency_id = fields.Many2one(
        'res.currency',
        string='Currency',
        related='register_id.currency_id',
        store=True,
        readonly=True
    )

    date = fields.Date(
        string='Date',
        related='register_id.date',
        store=True,
        readonly=True
    )

    state = fields.Selection(
        string='Status',
        related='register_id.state',
        store=True,
        readonly=True
    )

    # ==================== COMPUTED FIELDS ====================

    balance = fields.Monetary(
        string='Balance',
        compute='_compute_balance',
        store=True,
        currency_field='currency_id',
        help='Debit - Credit'
    )

    running_balance = fields.Monetary(
        string='Running Balance',
        compute='_compute_running_balance',
        currency_field='currency_id',
        help='Cumulative balance up to this line'
    )

    # ==================== COMPUTES ====================

    @api.depends('debit', 'credit', 'tax_id')
    def _compute_tax_amount(self):
        """Calculate tax amount based on selected tax"""
        for line in self:
            if line.tax_id:
                # Get the base amount (debit or credit)
                base_amount = line.debit if line.debit > 0 else line.credit

                # Check if tax is price inclusive
                if line.tax_id.price_include:
                    # Amount includes tax, calculate base and tax
                    # Formula: base = amount / (1 + tax_rate)
                    tax_rate = line.tax_id.amount / 100
                    base = base_amount / (1 + tax_rate)
                    line.tax_amount = base_amount - base
                    line.amount_with_tax = base_amount
                else:
                    # Amount excludes tax, calculate tax
                    line.tax_amount = base_amount * (line.tax_id.amount / 100)
                    line.amount_with_tax = base_amount + line.tax_amount
            else:
                line.tax_amount = 0.0
                line.amount_with_tax = line.debit if line.debit > 0 else line.credit

    @api.depends('debit', 'credit')
    def _compute_balance(self):
        """Calculate line balance"""
        for line in self:
            line.balance = line.debit - line.credit

    @api.depends('register_id.line_ids', 'register_id.line_ids.debit', 'register_id.line_ids.credit', 'sequence')
    def _compute_running_balance(self):
        """Calculate running balance"""
        for line in self:
            if line.register_id and line.register_id.line_ids:
                # Sort lines by sequence and id
                sorted_lines = line.register_id.line_ids.sorted(
                    lambda l: (l.sequence, l.id if isinstance(l.id, int) else 0))

                # Calculate running balance up to current line
                running_balance = 0.0
                for sorted_line in sorted_lines:
                    running_balance += sorted_line.debit - sorted_line.credit
                    if sorted_line.id == line.id or (
                            not isinstance(line.id, int) and sorted_line.sequence >= line.sequence):
                        break

                line.running_balance = running_balance
            else:
                line.running_balance = 0.0

    # ==================== CONSTRAINTS ====================

    @api.constrains('debit', 'credit')
    def _check_debit_credit(self):
        """Ensure debit and credit are not both filled or both zero"""
        for line in self:
            # Check if both are filled
            if line.debit > 0 and line.credit > 0:
                raise ValidationError(_(
                    'Line "%s": You cannot have both Debit and Credit values.\n'
                    'Please enter only one of them.'
                ) % line.description)

            # Check if both are zero
            if line.debit == 0 and line.credit == 0:
                raise ValidationError(_(
                    'Line "%s": You must enter either a Debit or Credit amount.\n'
                    'Both cannot be zero.'
                ) % line.description)

            # Check if negative
            if line.debit < 0 or line.credit < 0:
                raise ValidationError(_(
                    'Line "%s": Debit and Credit amounts cannot be negative.'
                ) % line.description)

    @api.constrains('account_id')
    def _check_account_type(self):
        """Ensure account is not the journal account"""
        for line in self:
            if line.register_id.journal_account_id and \
                    line.account_id == line.register_id.journal_account_id:
                raise ValidationError(_(
                    'You cannot use the journal account "%s" in transaction lines.\n'
                    'The journal account will be used automatically for balancing.'
                ) % line.account_id.display_name)

    # ==================== ONCHANGE ====================

    @api.onchange('debit')
    def _onchange_debit(self):
        """Clear credit when debit is entered"""
        if self.debit > 0:
            self.credit = 0.0

    @api.onchange('credit')
    def _onchange_credit(self):
        """Clear debit when credit is entered"""
        if self.credit > 0:
            self.debit = 0.0

    @api.onchange('account_id')
    def _onchange_account_id(self):
        """Auto-fill description from account name"""
        if self.account_id and not self.description:
            self.description = self.account_id.name

    # ==================== NAME ====================

    def name_get(self):
        """Display name"""
        result = []
        for line in self:
            name = '%s - %s' % (line.description or 'Line', line.account_id.code or '')
            result.append((line.id, name))
        return result