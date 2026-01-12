# -*- coding: utf-8 -*-
{
    'name': 'Invoice Expense Tracking V2',
    'version': '18.0.1.0.0',
    'category': 'Accounting/Accounting',
    'summary': 'Track expenses and profitability for invoices',
    'description': """
        Invoice Expense Tracking
        ========================
        * Distribute expenses across multiple invoices
        * Flexible journal entries with multi-account support
        * Calculate net profit per invoice
        * Profitability dashboard and reports
        * Support for multiple expense types (commission, shipping, storage, etc.)
        * Amazon, Noon platform integration
        
        Key Features:
        -------------
        - Expense Distribution: Allocate one expense to multiple invoices
        - Journal Entry Lines: Create flexible multi-line journal entries
        - Profitability Dashboard: Visual analysis of invoice profitability
        - Reports: Comprehensive profitability reports and analysis
        - Platform Support: Track expenses by platform (Amazon, Noon, etc.)
    """,
    'author': 'ERP Accounting and Auditing L.L.C',
    'website': 'https://www.erpaccounting.ae',
    'depends': ['account', 'mail', 'web'],
    'data': [
        'security/ir.model.access.csv',
        'views/invoice_expense_views.xml',
        'views/account_move_views.xml',
        'views/dashboard_views.xml',
        #'reports/invoice_profitability_report.xml',
        #'reports/report_templates.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'invoice_expense_tracking/static/src/js/dashboard.js',
            'invoice_expense_tracking/static/src/xml/dashboard.xml',
            'invoice_expense_tracking/static/src/css/dashboard.css',
        ],
    },
    'images': ['static/description/icon.png'],
    'installable': True,
    'application': True,  # Make it appear as standalone application
    'auto_install': False,
    'license': 'LGPL-3',
}
