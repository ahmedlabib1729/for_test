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
* Filter by create_date
* Separate tables for each category
* Configure payment journals for categorization
* Multiple payment methods per invoice
* Export to Excel with multiple sheets
* Professional UI design with gradients
* Direct links to invoices and partners
* Real-time calculation of totals and taxes

Configuration:
--------------
Go to Accounting → Configuration → Settings → Daily Invoices Report Settings
to configure the journals for each payment category.
    """,
    'author': 'Your Company',
    'website': 'https://www.yourcompany.com',
    'license': 'LGPL-3',
    'depends': [
        'account',
        'base',
    ],
    'data': [
        'security/ir.model.access.csv',
        'views/daily_invoices_views.xml',
        'views/config_settings_views.xml',
    ],
    'images': ['static/description/icon.png'],
    'installable': True,
    'application': True,
    'auto_install': False,
}