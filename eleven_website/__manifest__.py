# -*- coding: utf-8 -*-
{
    'name': 'Eleven Website',
    'version': '18.0.1.0.0',
    'category': 'Website',
    'summary': 'Eleven Scent Diffusers Website',
    'description': """
        Eleven Website Module
        - Custom homepage design
        - Product categories display
        - Navigation bar
    """,
    'author': 'Your Company',
    'website': 'https://www.yourcompany.com',
    'depends': ['website', 'website_sale'],
    'data': [
        'security/ir.model.access.csv',
        'views/templates.xml',
        'views/homepage.xml',
        'views/product_views.xml',
        'views/product_review_views.xml',
        'views/contact_page.xml',
        'views/shop_page.xml',
        'views/product_detail.xml',
        'views/cart_page.xml',
    ],
    'assets': {
        'web.assets_frontend': [
            'eleven_website/static/src/css/style.css',
            'eleven_website/static/src/js/shop.js',
            'eleven_website/static/src/js/product_detail.js',

        ],
    },
    'installable': True,
    'application': True,
    'license': 'LGPL-3',
}
