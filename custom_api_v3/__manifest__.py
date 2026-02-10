{
    'name': 'External API Integration',
    'version': '18.0.1.0.0',
    'summary': 'REST API for External Systems Integration',
    'description': """
        This module provides REST API endpoints for:
        - Receiving Orders from external systems
        - Providing Stock/Inventory information
        - Product synchronization
        
        Features:
        - API Key Authentication
        - Request Logging
        - Error Handling
        - Rate Limiting Support
    """,
    'author': 'Your Company',
    'website': 'https://yourcompany.com',
    'category': 'Technical/API',
    'depends': ['base', 'sale', 'stock', 'product'],
    'data': [
        'security/ir.model.access.csv',
        'views/api_log_views.xml',
        'views/api_config_views.xml',
        'data/api_config_data.xml',
    ],
    'installable': True,
    'application': False,
    'auto_install': False,
    'license': 'LGPL-3',
}
