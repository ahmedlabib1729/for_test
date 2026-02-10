# -*- coding: utf-8 -*-
from odoo import models, fields, api


class AccountMove(models.Model):
    _inherit = 'account.move'

    expense_distribution_ids = fields.One2many(
        'invoice.expense.distribution',
        'invoice_id',
        string='Expense Distributions',
        readonly=True
    )
    
    expense_count = fields.Integer(
        string='Expense Count',
        compute='_compute_expense_data',
        store=True
    )
    
    total_expenses = fields.Monetary(
        string='Total Expenses',
        compute='_compute_expense_data',
        store=True,
        currency_field='currency_id',
        help='Total expenses distributed to this invoice'
    )
    
    invoice_cost = fields.Monetary(
        string='Cost of Goods',
        compute='_compute_invoice_cost',
        store=True,
        currency_field='currency_id',
        help='Total cost of products in invoice lines'
    )
    
    net_profit = fields.Monetary(
        string='Net Profit',
        compute='_compute_profitability',
        store=True,
        currency_field='currency_id',
        help='Sales - Cost - Expenses'
    )
    
    profit_margin = fields.Float(
        string='Profit Margin %',
        compute='_compute_profitability',
        store=True,
        help='(Net Profit / Sales) * 100'
    )

    @api.depends('expense_distribution_ids', 'expense_distribution_ids.amount', 
                 'expense_distribution_ids.expense_id.state')
    def _compute_expense_data(self):
        """Compute expense count and total"""
        for move in self:
            distributions = move.expense_distribution_ids.filtered(
                lambda d: d.expense_id.state == 'posted'
            )
            move.expense_count = len(distributions)
            move.total_expenses = sum(distributions.mapped('amount'))

    @api.depends('invoice_line_ids', 'invoice_line_ids.product_id', 
                 'invoice_line_ids.quantity', 'invoice_line_ids.product_id.standard_price')
    def _compute_invoice_cost(self):
        """Compute total cost of products in invoice"""
        for move in self:
            if move.move_type == 'out_invoice':
                cost = 0.0
                for line in move.invoice_line_ids.filtered(lambda l: l.product_id):
                    product_cost = line.product_id.standard_price
                    cost += product_cost * line.quantity
                move.invoice_cost = cost
            else:
                move.invoice_cost = 0.0

    @api.depends('amount_untaxed', 'invoice_cost', 'total_expenses')
    def _compute_profitability(self):
        """Compute net profit and profit margin"""
        for move in self:
            if move.move_type == 'out_invoice':
                # Net Profit = Sales - Cost - Expenses
                move.net_profit = move.amount_untaxed - move.invoice_cost - move.total_expenses
                
                # Profit Margin % = (Net Profit / Sales) * 100
                if move.amount_untaxed:
                    move.profit_margin = (move.net_profit / move.amount_untaxed) * 100
                else:
                    move.profit_margin = 0.0
            else:
                move.net_profit = 0.0
                move.profit_margin = 0.0

    def action_view_expenses(self):
        """Open expense distributions related to this invoice"""
        self.ensure_one()
        expense_ids = self.expense_distribution_ids.mapped('expense_id').ids
        
        return {
            'name': 'Related Expenses',
            'type': 'ir.actions.act_window',
            'res_model': 'invoice.expense',
            'view_mode': 'list,form',
            'domain': [('id', 'in', expense_ids)],
            'context': {'create': False},
        }

