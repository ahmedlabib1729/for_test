import secrets
from odoo import models, fields, api


class APIConfig(models.Model):
    _name = 'api.config'
    _description = 'API Configuration'
    _rec_name = 'name'
    
    name = fields.Char(string='Name', default='API Configuration', required=True)
    api_key = fields.Char(string='API Key', required=True, copy=False)
    is_active = fields.Boolean(string='Active', default=True)
    allowed_ips = fields.Text(
        string='Allowed IPs',
        help='Comma-separated list of allowed IP addresses. Leave empty to allow all.'
    )
    rate_limit = fields.Integer(
        string='Rate Limit (requests/minute)',
        default=60,
        help='Maximum number of requests per minute. 0 for unlimited.'
    )
    notes = fields.Text(string='Notes')
    
    # Timestamps
    create_date = fields.Datetime(string='Created On', readonly=True)
    write_date = fields.Datetime(string='Last Updated', readonly=True)
    
    @api.model
    def generate_api_key(self):
        """Generate a secure random API key"""
        return secrets.token_urlsafe(32)
    
    @api.model
    def create(self, vals):
        """Generate API key if not provided"""
        if not vals.get('api_key'):
            vals['api_key'] = self.generate_api_key()
        return super().create(vals)
    
    def action_regenerate_key(self):
        """Regenerate API key"""
        self.ensure_one()
        self.api_key = self.generate_api_key()
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'API Key Regenerated',
                'message': 'A new API key has been generated. Please update external systems.',
                'type': 'warning',
                'sticky': True,
            }
        }
    
    def copy(self, default=None):
        """Generate new API key when duplicating"""
        default = default or {}
        default['api_key'] = self.generate_api_key()
        default['name'] = f"{self.name} (Copy)"
        return super().copy(default)
