{
    'name': 'Product Auto Reference & Remarks',
    'version': '18.0.1.0.0',
    'category': 'Sales/Sales',
    'summary': 'Auto generate product reference with sequence and add remarks field',
    'description': """
        This module adds:
        - Automatic sequential reference generation for products
        - Remark field for additional product notes
    """,
    'author': 'Your Company',
    'depends': ['product' , 'purchase', 'stock', 'stock_landed_costs', 'account' , 'sale', 'sale_management'],
    'data': [
'security/ir.model.access.csv',

        'data/product_sequence.xml',
        'views/product_views.xml',
        'views/partner_views.xml',
        'views/purchase_views.xml',
        'views/sale_order_views.xml',
        'views/invoice_views.xml',
        'views/product_short_code_views.xml',
        'views/sale_order_cancel_views.xml',
    ],
    'installable': True,
    'application': False,
    'auto_install': False,
    'license': 'LGPL-3',
}