# __manifest__.py
{
    'name': 'Partner Ledger by Product',
    'version': '18.0.1.0.0',
    'category': 'Accounting/Accounting',
    'summary': 'Detailed Partner Ledger with Product Line Items',
    'description': """
        Partner Ledger by Product Report
        =================================
        Features:
        - Detailed ledger for customers and suppliers
        - Shows product line items for each invoice
        - Opening and closing balances
        - Includes payments and invoices
        - Export to Excel
        - Date range filtering
        - Partner filtering
    """,
    'author': 'Your Company',
    'depends': ['base', 'account', 'product', 'sale'],
    'external_dependencies': {
        'python': ['xlsxwriter'],
    },
    'data': [
        'security/ir.model.access.csv',
        'views/partner_ledger_views.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'partner_ledger_by_product/static/src/css/partner_ledger.css',
        ],
    },
    'installable': True,
    'application': False,
    'auto_install': False,
    'license': 'LGPL-3',
}