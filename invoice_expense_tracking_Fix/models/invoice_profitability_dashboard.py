# -*- coding: utf-8 -*-
from odoo import api, fields, models, _


class InvoiceProfitabilityDashboard(models.AbstractModel):
    _name = 'report.invoice.profitability.dashboard'
    _description = 'Invoice Profitability Dashboard'

    @api.model
    def get_dashboard_data(self, date_from=False, date_to=False, partner_ids=False,
                           platform=False, move_type=False, min_profit=False, max_profit=False, search_term=False):
        """
        Get dashboard data for invoice profitability

        Args:
            date_from: Start date
            date_to: End date
            partner_ids: List of partner IDs
            platform: Platform filter (amazon, noon, other)
            move_type: Invoice type filter (out_invoice, out_refund)
            min_profit: Minimum profit filter
            max_profit: Maximum profit filter
            search_term: Search in invoice number or customer name

        Returns:
            dict with invoices data and summary statistics
        """
        Invoice = self.env['account.move']
        Distribution = self.env['invoice.expense.distribution']

        # Get invoices that have expense distributions
        distributions = Distribution.search([
            ('expense_id.state', '=', 'posted')
        ])
        invoice_ids_with_expenses = distributions.mapped('invoice_id').ids

        if not invoice_ids_with_expenses:
            return {
                'invoices': [],
                'summary': {
                    'total_invoices': 0,
                    'total_sales': 0.0,
                    'total_cost': 0.0,
                    'total_expenses': 0.0,
                    'total_profit': 0.0,
                    'avg_profit_margin': 0.0,
                    'profitable_count': 0,
                    'loss_count': 0,
                    'gross_profit': 0.0,
                    'platform_stats': {},
                }
            }

        # Build domain - only invoices with expenses (including credit notes)
        domain = [
            ('id', 'in', invoice_ids_with_expenses),
            ('move_type', 'in', ['out_invoice', 'out_refund']),  # Include credit notes
            ('state', '=', 'posted'),
        ]

        if date_from:
            domain.append(('invoice_date', '>=', date_from))
        if date_to:
            domain.append(('invoice_date', '<=', date_to))
        if partner_ids and isinstance(partner_ids, (list, tuple)) and len(partner_ids) > 0:
            domain.append(('partner_id', 'in', partner_ids))
        if move_type:
            # Override the move_type if specific type is selected
            domain = [d for d in domain if not (isinstance(d, tuple) and d[0] == 'move_type')]
            domain.append(('move_type', '=', move_type))
        if search_term:
            domain.append('|')
            domain.append(('name', 'ilike', search_term))
            domain.append(('partner_id.name', 'ilike', search_term))

        # Get invoices
        invoices = Invoice.search(domain, order='invoice_date desc, name desc')

        # Prepare data
        invoice_data = []
        summary = {
            'total_invoices': 0,
            'total_sales': 0.0,
            'total_cost': 0.0,
            'total_expenses': 0.0,
            'total_profit': 0.0,
            'avg_profit_margin': 0.0,
            'profitable_count': 0,
            'loss_count': 0,
        }

        profit_margins = []

        for inv in invoices:
            # Get platform from distributions
            invoice_platform = ''
            if inv.expense_distribution_ids:
                platforms = inv.expense_distribution_ids.mapped('expense_id.platform')
                if 'amazon' in platforms:
                    invoice_platform = 'Amazon'
                elif 'noon' in platforms:
                    invoice_platform = 'Noon'
                elif 'other' in platforms:
                    invoice_platform = 'Other'

            # Apply platform filter
            if platform:
                if platform == 'amazon' and invoice_platform != 'Amazon':
                    continue
                elif platform == 'noon' and invoice_platform != 'Noon':
                    continue
                elif platform == 'other' and invoice_platform != 'Other':
                    continue

            # Apply profit filters
            if min_profit is not False and inv.net_profit < min_profit:
                continue
            if max_profit is not False and inv.net_profit > max_profit:
                continue

            # Get expense breakdown
            expense_breakdown = []
            for dist in inv.expense_distribution_ids.filtered(lambda d: d.expense_id.state == 'posted'):
                expense_breakdown.append({
                    'expense_ref': dist.expense_id.name,
                    'expense_type': dict(dist.expense_id._fields['expense_type'].selection).get(
                        dist.expense_id.expense_type, dist.expense_id.expense_type
                    ),
                    'platform': dict(dist.expense_id._fields['platform'].selection).get(
                        dist.expense_id.platform, dist.expense_id.platform or ''
                    ),
                    'amount': dist.amount,
                })

            invoice_info = {
                'id': inv.id,
                'name': inv.name,
                'date': inv.invoice_date.strftime('%d/%m/%Y') if inv.invoice_date else '',
                'move_type': inv.move_type,
                'move_type_label': 'Credit Note' if inv.move_type == 'out_refund' else 'Invoice',
                'partner_name': inv.partner_id.name,
                'partner_ref': inv.partner_id.ref or '',
                'platform': invoice_platform,
                # For credit notes, make sales negative
                'sales': inv.amount_untaxed if inv.move_type == 'out_invoice' else -inv.amount_untaxed,
                'cost': inv.invoice_cost if inv.move_type == 'out_invoice' else -inv.invoice_cost,
                'gross_profit': (inv.amount_untaxed - inv.invoice_cost) if inv.move_type == 'out_invoice' else -(
                            inv.amount_untaxed - inv.invoice_cost),
                'expenses': inv.total_expenses,
                'expense_breakdown': expense_breakdown,
                'expense_count': len(inv.expense_distribution_ids),
                'net_profit': inv.net_profit,
                'profit_margin': inv.profit_margin,
                'is_profitable': inv.net_profit > 0,
                'currency': inv.currency_id.symbol,
            }

            invoice_data.append(invoice_info)

            # Update summary - use invoice_info values (which already have negative for credit notes)
            summary['total_invoices'] += 1
            summary['total_sales'] += invoice_info['sales']  # Already negative for credit notes
            summary['total_cost'] += invoice_info['cost']  # Already negative for credit notes
            summary['total_expenses'] += inv.total_expenses
            summary['total_profit'] += inv.net_profit

            if inv.net_profit > 0:
                summary['profitable_count'] += 1
            elif inv.net_profit < 0:
                summary['loss_count'] += 1

            profit_margins.append(inv.profit_margin)

        # Calculate average profit margin
        if profit_margins:
            summary['avg_profit_margin'] = sum(profit_margins) / len(profit_margins)

        # Calculate gross profit
        summary['gross_profit'] = summary['total_sales'] - summary['total_cost']

        # Top/Bottom performers
        sorted_by_profit = sorted(invoice_data, key=lambda x: x['net_profit'], reverse=True)
        summary['top_performers'] = sorted_by_profit[:5]
        summary['bottom_performers'] = sorted_by_profit[-5:] if len(sorted_by_profit) > 5 else []

        # Group by platform
        platform_stats = {}
        for inv in invoice_data:
            platform = inv['platform'] or 'Unknown'
            if platform not in platform_stats:
                platform_stats[platform] = {
                    'count': 0,
                    'sales': 0.0,
                    'expenses': 0.0,
                    'profit': 0.0,
                }
            platform_stats[platform]['count'] += 1
            platform_stats[platform]['sales'] += inv['sales']
            platform_stats[platform]['expenses'] += inv['expenses']
            platform_stats[platform]['profit'] += inv['net_profit']

        summary['platform_stats'] = platform_stats

        return {
            'invoices': invoice_data,
            'summary': summary,
        }

    @api.model
    def get_expense_types_breakdown(self, date_from=False, date_to=False):
        """Get expense breakdown by type"""
        Expense = self.env['invoice.expense']

        domain = [('state', '=', 'posted')]

        if date_from:
            domain.append(('date', '>=', date_from))
        if date_to:
            domain.append(('date', '<=', date_to))

        expenses = Expense.search(domain)

        breakdown = {}
        for expense in expenses:
            exp_type = dict(expense._fields['expense_type'].selection).get(
                expense.expense_type, expense.expense_type
            )
            if exp_type not in breakdown:
                breakdown[exp_type] = {
                    'count': 0,
                    'total': 0.0,
                }
            breakdown[exp_type]['count'] += 1
            breakdown[exp_type]['total'] += expense.amount

        return breakdown