{
    'name': 'Custom Invoice Report',
    'version': '19.0.1.0.0',
    'category': 'Accounting',
    'summary': 'Custom Tax Invoice Report with Original & Duplicate copies',
    'description': """
        Custom Invoice Report Module
        ============================
        - Custom designed Tax Invoice
        - Prints 2 copies: Original & Duplicate
        - Shows Payment Type (Cash/Credit)
        - Company logo and name from system
    """,
    'author': 'Your Company',
    'website': '',
    'depends': ['account', 'purchase_payment_type'],
    'data': [
        'report/invoice_report_template.xml',
    ],
    'installable': True,
    'application': False,
    'auto_install': False,
    'license': 'LGPL-3',
}
