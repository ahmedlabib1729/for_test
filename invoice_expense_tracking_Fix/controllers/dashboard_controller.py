# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request
import json
import logging

_logger = logging.getLogger(__name__)


class InvoiceProfitabilityController(http.Controller):

    @http.route('/invoice_expense/dashboard_data', type='json', auth='user')
    def get_dashboard_data(self, **kwargs):
        """Get dashboard data via JSON-RPC"""
        try:
            # Extract filters
            date_from = kwargs.get('date_from', False)
            date_to = kwargs.get('date_to', False)
            partner_ids = kwargs.get('partner_ids', False)
            platform = kwargs.get('platform', False)
            min_profit = kwargs.get('min_profit', False)
            max_profit = kwargs.get('max_profit', False)
            
            # Get data from report model
            report_model = request.env['report.invoice.profitability.dashboard']
            data = report_model.get_dashboard_data(
                date_from=date_from,
                date_to=date_to,
                partner_ids=partner_ids,
                platform=platform,
                min_profit=min_profit,
                max_profit=max_profit,
            )
            
            return data
        except Exception as e:
            _logger.error("Error in dashboard_data: %s", str(e), exc_info=True)
            return {
                'error': str(e),
                'invoices': [],
                'summary': {
                    'total_invoices': 0,
                    'total_sales': 0.0,
                    'total_expenses': 0.0,
                    'total_profit': 0.0,
                }
            }

    @http.route('/invoice_expense/filters', type='json', auth='user')
    def get_filters(self):
        """Get filter options"""
        try:
            report_model = request.env['report.invoice.profitability.dashboard']
            
            # Get partners with invoices
            partners = request.env['res.partner'].search([
                ('customer_rank', '>', 0)
            ], order='name')
            
            partner_list = [{
                'id': p.id,
                'name': p.name,
                'ref': p.ref or '',
            } for p in partners]
            
            # Platform options
            platforms = [
                {'id': 'amazon', 'name': 'Amazon'},
                {'id': 'noon', 'name': 'Noon'},
                {'id': 'other', 'name': 'Other'},
            ]
            
            return {
                'partners': partner_list,
                'platforms': platforms,
            }
        except Exception as e:
            _logger.error("Error in get_filters: %s", str(e), exc_info=True)
            return {'partners': [], 'platforms': []}
