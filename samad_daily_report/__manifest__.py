# -*- coding: utf-8 -*-
{
    'name': 'Daily Invoices Report',
    'version': '18.0.1.0.0',
    'category': 'Accounting/Accounting',
    'summary': 'Daily report for purchases and sales invoices with payment breakdown',
    'description': """
Daily Invoices Report
=====================
This module provides a comprehensive daily report for:

**Purchases:**
- Paid purchase invoices with totals and tax
- Unpaid purchase invoices with totals and tax
- Grand total for all purchases

**Sales:**
- Cash sales with totals and tax
- Bank sales with totals and tax
- Commission sales with totals and tax
- Commission tax sales with totals and tax
- Grand total for all sales

Features:
---------
* Dynamic date range (default: today)
* Filter by invoice_date
* Separate tables for each category
* Configure payment accounts for categorization
* Multiple payment methods per invoice
* Export to Excel (XLSX with colors)
* Export to PDF (Professional report)
* Professional UI design with OWL Dashboard
* Direct links to invoices and partners
* Real-time calculation of totals and taxes
* Net Cash & Bank calculations
    """,
    'author': 'Your Company',
    'website': 'https://www.yourcompany.com',
    'license': 'LGPL-3',
    'depends': [
        'account',
        'base',
        'web',
    ],
    'data': [
        'security/ir.model.access.csv',
        'wizard/report_wizard_views.xml',
        'report/daily_invoices_report.xml',
        'views/daily_invoices_views.xml',
        'views/config_settings_views.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'samad_daily_report/static/src/js/daily_invoices_dashboard.js',
            'samad_daily_report/static/src/xml/daily_invoices_dashboard.xml',
            'samad_daily_report/static/src/css/daily_invoices_dashboard.css',
        ],
    },
    'images': ['static/description/icon.png'],
    'installable': True,
    'application': True,
    'auto_install': False,
}
