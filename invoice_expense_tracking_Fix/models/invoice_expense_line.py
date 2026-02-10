# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


class InvoiceExpenseLine(models.Model):
    _name = 'invoice.expense.line'
    _description = 'Invoice Expense Journal Line'
    _order = 'sequence, id'

    sequence = fields.Integer(string='Sequence', default=10)
    
    expense_id = fields.Many2one(
        'invoice.expense',
        string='Expense',
        required=True,
        ondelete='cascade'
    )
    
    name = fields.Char(
        string='Label',
        required=True
    )
    
    account_id = fields.Many2one(
        'account.account',
        string='Account',
        required=True,
        domain=[('deprecated', '=', False)],
        ondelete='restrict'
    )
    
    partner_id = fields.Many2one(
        'res.partner',
        string='Partner',
        ondelete='restrict'
    )
    
    tax_ids = fields.Many2many(
        'account.tax',
        string='Taxes',
        domain=[('type_tax_use', '!=', 'none')]
    )
    
    debit = fields.Monetary(
        string='Debit',
        currency_field='currency_id',
        default=0.0
    )
    
    credit = fields.Monetary(
        string='Credit',
        currency_field='currency_id',
        default=0.0
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
    
    analytic_distribution = fields.Json(
        string='Analytic Distribution'
    )
    
    notes = fields.Char(string='Notes')

    @api.constrains('debit', 'credit')
    def _check_debit_credit(self):
        """Validate debit and credit"""
        for record in self:
            if record.debit < 0 or record.credit < 0:
                raise ValidationError(_('Debit and Credit must be positive or zero.'))
            
            if record.debit > 0 and record.credit > 0:
                raise ValidationError(_('A line cannot have both Debit and Credit.'))
            
            if record.debit == 0 and record.credit == 0:
                raise ValidationError(_('Either Debit or Credit must be greater than zero.'))

    @api.onchange('account_id')
    def _onchange_account_id(self):
        """Auto-fill label from account"""
        if self.account_id and not self.name:
            self.name = self.account_id.display_name

    def _prepare_move_line_vals(self):
        """Prepare account.move.line values"""
        self.ensure_one()
        
        vals = {
            'name': self.name,
            'account_id': self.account_id.id,
            'debit': self.debit,
            'credit': self.credit,
            'currency_id': self.currency_id.id,
        }
        
        if self.partner_id:
            vals['partner_id'] = self.partner_id.id
        
        if self.tax_ids:
            vals['tax_ids'] = [(6, 0, self.tax_ids.ids)]
        
        if self.analytic_distribution:
            vals['analytic_distribution'] = self.analytic_distribution
        
        return vals
