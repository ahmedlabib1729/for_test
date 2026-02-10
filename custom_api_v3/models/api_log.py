from odoo import models, fields, api


class APILog(models.Model):
    _name = 'api.log'
    _description = 'API Request Log'
    _order = 'request_date desc'
    _rec_name = 'endpoint'
    
    endpoint = fields.Char(string='Endpoint', required=True, index=True)
    method = fields.Selection([
        ('GET', 'GET'),
        ('POST', 'POST'),
        ('PUT', 'PUT'),
        ('DELETE', 'DELETE'),
        ('PATCH', 'PATCH'),
    ], string='Method', required=True)
    request_data = fields.Text(string='Request Data')
    response_data = fields.Text(string='Response Data')
    status_code = fields.Integer(string='Status Code', index=True)
    error_message = fields.Text(string='Error Message')
    ip_address = fields.Char(string='IP Address', index=True)
    request_date = fields.Datetime(string='Request Date', default=fields.Datetime.now, index=True)
    
    status_type = fields.Selection([
        ('success', 'Success'),
        ('error', 'Error'),
    ], string='Status Type', compute='_compute_status_type', store=True)
    
    @api.depends('status_code')
    def _compute_status_type(self):
        for record in self:
            if record.status_code and record.status_code < 400:
                record.status_type = 'success'
            else:
                record.status_type = 'error'
    
    @api.autovacuum
    def _gc_api_logs(self):
        """
        Garbage collect old API logs.
        Keeps logs for the last 30 days.
        """
        limit_date = fields.Datetime.subtract(fields.Datetime.now(), days=30)
        self.search([('request_date', '<', limit_date)]).unlink()
