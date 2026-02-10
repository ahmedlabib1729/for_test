# -*- coding: utf-8 -*-
from odoo import models, fields, api
from datetime import datetime


class DailyInvoicesReportWizard(models.TransientModel):
    _name = 'daily.invoices.report.wizard'
    _description = 'Daily Invoices Report Wizard'

    date_from = fields.Date(
        string='From Date',
        required=True,
        default=fields.Date.context_today,
    )
    date_to = fields.Date(
        string='To Date',
        required=True,
        default=fields.Date.context_today,
    )

    def action_print_report(self):
        """Print PDF Report"""
        return self.env.ref('samad_daily_report.action_report_daily_invoices').report_action(self)

    def get_report_data(self):
        """Get report data for the template"""
        dashboard = self.env['daily.invoices.dashboard']
        return dashboard.get_report_data(
            self.date_from.strftime('%Y-%m-%d'),
            self.date_to.strftime('%Y-%m-%d')
        )

    def get_current_datetime(self):
        """Get current datetime for footer"""
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S')
