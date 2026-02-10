# -*- coding: utf-8 -*-
{
    'name': 'Daily Cash/Bank Register',
    'version': '18.0.1.0.0',
    'category': 'Accounting',
    'summary': 'Daily Cash and Bank Register with Dashboard',
    'description': """
        Daily Cash/Bank Register Module
        ================================
        - Create daily registers for cash and bank journals
        - Automatic journal entry creation
        - Tax support on lines
        - Interactive Dashboard with Charts
        - Comprehensive Reports (HTML, Excel, PDF)
    """,
    'author': 'Your Company',
    'website': 'https://www.yourcompany.com',
    'depends': ['account', 'mail', 'web'],
    'data': [
        # Security
        'security/ir.model.access.csv',

        # Views
        'views/daily_register_views.xml',

        'views/daily_register_dashboard_action.xml',

        # Menu
        'views/daily_register_menu.xml',
    ],
    'assets': {
        'web.assets_backend': [
            # Dashboard CSS
            'daily_cash_register/static/src/css/daily_register_dashboard.css',

            # Dashboard JS
            'daily_cash_register/static/src/js/daily_register_dashboard.js',

            # Dashboard QWeb Template
            'daily_cash_register/static/src/xml/daily_register_dashboard.xml',
        ],
    },
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}