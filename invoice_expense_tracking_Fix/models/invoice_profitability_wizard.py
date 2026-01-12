# -*- coding: utf-8 -*-
from odoo import models, fields, api
from datetime import datetime, timedelta


class InvoiceProfitabilityWizard(models.TransientModel):
    _name = 'invoice.profitability.wizard'
    _description = 'Invoice Profitability Analysis Wizard'

    date_from = fields.Date(
        string='Date From',
        required=True,
        default=lambda self: fields.Date.today().replace(day=1)
    )
    
    date_to = fields.Date(
        string='Date To',
        required=True,
        default=fields.Date.today
    )
    
    partner_ids = fields.Many2many(
        'res.partner',
        string='Customers',
        help='Leave empty for all customers'
    )
    
    platform = fields.Selection([
        ('all', 'All Platforms'),
        ('amazon', 'Amazon'),
        ('noon', 'Noon'),
        ('other', 'Other')
    ], string='Platform', default='all')
    
    state = fields.Selection([
        ('all', 'All States'),
        ('draft', 'Draft'),
        ('posted', 'Posted')
    ], string='Status', default='posted')
    
    company_id = fields.Many2one(
        'res.company',
        string='Company',
        required=True,
        default=lambda self: self.env.company
    )

    def _get_invoices_domain(self):
        """Build domain for invoice selection"""
        domain = [
            ('move_type', '=', 'out_invoice'),
            ('invoice_date', '>=', self.date_from),
            ('invoice_date', '<=', self.date_to),
            ('company_id', '=', self.company_id.id),
        ]
        
        if self.partner_ids:
            domain.append(('partner_id', 'in', self.partner_ids.ids))
        
        if self.state != 'all':
            domain.append(('state', '=', self.state))
        
        return domain

    def action_print_report(self):
        """Generate PDF report"""
        invoices = self.env['account.move'].search(self._get_invoices_domain())
        
        if not invoices:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'message': 'No invoices found for the selected criteria.',
                    'type': 'warning',
                    'sticky': False,
                }
            }
        
        return self.env.ref('invoice_expense_tracking_Fix.action_report_invoice_profitability').report_action(invoices)

    def action_view_analysis(self):
        """Open pivot/graph analysis"""
        domain = self._get_invoices_domain()
        
        return {
            'name': 'Invoice Profitability Analysis',
            'type': 'ir.actions.act_window',
            'res_model': 'account.move',
            'view_mode': 'pivot,graph,list,form',
            'domain': domain,
            'context': {
                'search_default_group_by_partner': 1,
            },
            'views': [
                (self.env.ref('invoice_expense_tracking_Fix.view_invoice_move_profitability_pivot').id, 'pivot'),
                (self.env.ref('invoice_expense_tracking_Fix.view_invoice_move_profitability_graph').id, 'graph'),
            ],
        }
