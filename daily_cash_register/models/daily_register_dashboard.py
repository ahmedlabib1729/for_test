# -*- coding: utf-8 -*-
from odoo import api, fields, models
from datetime import date, timedelta
from dateutil.relativedelta import relativedelta


class DailyRegisterDashboard(models.Model):
    _name = "daily.register.dashboard"
    _description = "Daily Register Dashboard"

    name = fields.Char(string="Name", default="Dashboard")

    @api.model
    def get_dashboard_data(self, journal_id=False, period='all'):
        """Get main dashboard KPIs"""
        Register = self.env['daily.cash.register']

        today = date.today()
        domain = [('state', '=', 'posted')]

        # Journal filter
        if journal_id:
            domain.append(('journal_id', '=', journal_id))

        # Period filter
        if period == 'today':
            domain.append(('date', '=', today))
        elif period == 'week':
            week_start = today - timedelta(days=today.weekday())
            domain.append(('date', '>=', week_start))
        elif period == 'month':
            month_start = today.replace(day=1)
            domain.append(('date', '>=', month_start))
        elif period == 'year':
            year_start = today.replace(month=1, day=1)
            domain.append(('date', '>=', year_start))

        # Get posted registers
        posted_registers = Register.search(domain)

        # Get draft registers (without period filter for alerts)
        draft_domain = [('state', '=', 'draft')]
        if journal_id:
            draft_domain.append(('journal_id', '=', journal_id))
        draft_registers = Register.search(draft_domain)

        # Calculate totals
        total_debit = sum(posted_registers.mapped('total_debit'))
        total_credit = sum(posted_registers.mapped('total_credit'))

        # Check if total_tax field exists
        total_tax = 0
        if 'total_tax' in Register._fields:
            total_tax = sum(posted_registers.mapped('total_tax'))

        net_balance = total_debit - total_credit

        # Count lines
        total_lines = sum(len(r.line_ids) for r in posted_registers)

        return {
            'total_registers': len(posted_registers),
            'draft_registers': len(draft_registers),
            'total_debit': total_debit,
            'total_credit': total_credit,
            'total_tax': total_tax,
            'net_balance': net_balance,
            'total_lines': total_lines,
        }

    @api.model
    def get_journals(self):
        """Get available bank/cash journals"""
        journals = self.env['account.journal'].search([
            ('type', 'in', ['bank', 'cash'])
        ])
        return [{
            'id': j.id,
            'name': j.name,
            'code': j.code,
            'type': j.type,
        } for j in journals]

    @api.model
    def get_registers_by_journal_chart(self, period='all'):
        """Get registers count by journal for chart"""
        Register = self.env['daily.cash.register']
        Journal = self.env['account.journal']

        today = date.today()
        domain = [('state', '=', 'posted')]

        # Period filter
        if period == 'today':
            domain.append(('date', '=', today))
        elif period == 'week':
            week_start = today - timedelta(days=today.weekday())
            domain.append(('date', '>=', week_start))
        elif period == 'month':
            month_start = today.replace(day=1)
            domain.append(('date', '>=', month_start))
        elif period == 'year':
            year_start = today.replace(month=1, day=1)
            domain.append(('date', '>=', year_start))

        journals = Journal.search([('type', 'in', ['bank', 'cash'])])

        labels = []
        data = []
        colors = []

        color_map = {
            'bank': '#3498db',
            'cash': '#2ecc71',
        }

        for journal in journals:
            j_domain = domain + [('journal_id', '=', journal.id)]
            count = Register.search_count(j_domain)
            if count > 0:
                labels.append(journal.name)
                data.append(count)
                colors.append(color_map.get(journal.type, '#95a5a6'))

        return {
            'labels': labels,
            'data': data,
            'colors': colors,
        }

    @api.model
    def get_monthly_chart_data(self, journal_id=False):
        """Get monthly debit/credit data for bar chart"""
        Register = self.env['daily.cash.register']
        today = date.today()

        result = []
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

        # Last 6 months
        for i in range(5, -1, -1):
            month_date = today - relativedelta(months=i)
            month_start = date(month_date.year, month_date.month, 1)
            month_end = month_start + relativedelta(months=1) - timedelta(days=1)

            domain = [
                ('state', '=', 'posted'),
                ('date', '>=', month_start),
                ('date', '<=', month_end)
            ]

            if journal_id:
                domain.append(('journal_id', '=', journal_id))

            registers = Register.search(domain)

            total_debit = sum(registers.mapped('total_debit'))
            total_credit = sum(registers.mapped('total_credit'))

            result.append({
                'month': months[month_date.month - 1],
                'debit': total_debit,
                'credit': total_credit,
            })

        return result

    @api.model
    def get_recent_registers(self, journal_id=False, limit=5):
        """Get recent posted registers"""
        Register = self.env['daily.cash.register']

        domain = [('state', '=', 'posted')]
        if journal_id:
            domain.append(('journal_id', '=', journal_id))

        registers = Register.search(domain, order='date desc, id desc', limit=limit)

        result = []
        for reg in registers:
            result.append({
                'id': reg.id,
                'name': reg.name,
                'date': reg.date.strftime('%d/%m/%Y') if reg.date else '',
                'journal': reg.journal_id.name,
                'journal_type': reg.journal_id.type,
                'debit': reg.total_debit,
                'credit': reg.total_credit,
                'balance': reg.balance,
                'lines_count': len(reg.line_ids),
            })

        return result

    @api.model
    def get_draft_registers(self, journal_id=False, limit=5):
        """Get draft registers that need attention"""
        Register = self.env['daily.cash.register']

        domain = [('state', '=', 'draft')]
        if journal_id:
            domain.append(('journal_id', '=', journal_id))

        registers = Register.search(domain, order='date desc, id desc', limit=limit)

        result = []
        for reg in registers:
            result.append({
                'id': reg.id,
                'name': reg.name,
                'date': reg.date.strftime('%d/%m/%Y') if reg.date else '',
                'journal': reg.journal_id.name,
                'journal_type': reg.journal_id.type,
                'debit': reg.total_debit,
                'credit': reg.total_credit,
                'balance': reg.balance,
                'lines_count': len(reg.line_ids),
            })

        return result

    @api.model
    def get_daily_trend_chart(self, journal_id=False, days=14):
        """Get daily debit/credit trend for line chart"""
        Register = self.env['daily.cash.register']
        today = date.today()

        result = []

        for i in range(days - 1, -1, -1):
            day = today - timedelta(days=i)

            domain = [
                ('state', '=', 'posted'),
                ('date', '=', day)
            ]

            if journal_id:
                domain.append(('journal_id', '=', journal_id))

            registers = Register.search(domain)

            total_debit = sum(registers.mapped('total_debit'))
            total_credit = sum(registers.mapped('total_credit'))

            result.append({
                'date': day.strftime('%d/%m'),
                'debit': total_debit,
                'credit': total_credit,
            })

        return result

    @api.model
    def get_report_data(self, journal_ids=False, date_from=False, date_to=False):
        """Get hierarchical report data: Journal > Register > Lines"""
        Register = self.env['daily.cash.register']

        # Build domain
        domain = [('state', '=', 'posted')]

        if journal_ids:
            domain.append(('journal_id', 'in', journal_ids))
        if date_from:
            domain.append(('date', '>=', date_from))
        if date_to:
            domain.append(('date', '<=', date_to))

        # Get registers
        registers = Register.search(domain, order='journal_id, date, id')

        if not registers:
            return {'journals': [], 'totals': {}}

        # Group by journal
        journals_data = {}
        grand_totals = {
            'debit': 0,
            'credit': 0,
            'tax': 0,
            'balance': 0,
        }

        for register in registers:
            journal_id = register.journal_id.id

            if journal_id not in journals_data:
                journals_data[journal_id] = {
                    'id': journal_id,
                    'name': register.journal_id.name,
                    'code': register.journal_id.code,
                    'type': register.journal_id.type,
                    'registers': [],
                    'totals': {
                        'debit': 0,
                        'credit': 0,
                        'tax': 0,
                        'balance': 0,
                    }
                }

            # Get tax amount
            reg_tax = 0
            if 'total_tax' in Register._fields:
                reg_tax = register.total_tax or 0

            # Get register data
            register_data = {
                'id': register.id,
                'name': register.name,
                'date': register.date.strftime('%d/%m/%Y') if register.date else '',
                'debit': register.total_debit,
                'credit': register.total_credit,
                'tax': reg_tax,
                'balance': register.balance,
                'lines': [],
            }

            # Get line details
            for line in register.line_ids:
                line_tax = 0
                line_tax_name = ''
                if 'tax_amount' in line._fields:
                    line_tax = line.tax_amount or 0
                if 'tax_id' in line._fields and line.tax_id:
                    line_tax_name = line.tax_id.name

                register_data['lines'].append({
                    'id': line.id,
                    'description': line.description,
                    'account_code': line.account_id.code,
                    'account_name': line.account_id.name,
                    'debit': line.debit,
                    'credit': line.credit,
                    'tax_name': line_tax_name,
                    'tax_amount': line_tax,
                    'balance': line.debit - line.credit,
                })

            journals_data[journal_id]['registers'].append(register_data)

            # Update journal totals
            journals_data[journal_id]['totals']['debit'] += register.total_debit
            journals_data[journal_id]['totals']['credit'] += register.total_credit
            journals_data[journal_id]['totals']['tax'] += reg_tax
            journals_data[journal_id]['totals']['balance'] += register.balance

            # Update grand totals
            grand_totals['debit'] += register.total_debit
            grand_totals['credit'] += register.total_credit
            grand_totals['tax'] += reg_tax
            grand_totals['balance'] += register.balance

        return {
            'journals': list(journals_data.values()),
            'totals': grand_totals,
        }