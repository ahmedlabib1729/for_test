# -*- coding: utf-8 -*-
# hr_mobile_app/models/hr_mobile_app_settings.py
# إعدادات التطبيق المحمول مع توليد Token و QR Code

from odoo import fields, models, api, _
from odoo.exceptions import ValidationError
import secrets
import string
import base64
import json
import logging

_logger = logging.getLogger(__name__)


class HrMobileAppSettings(models.TransientModel):
    _name = 'hr.mobile.app.settings'
    _description = 'Employee Mobile App Settings'

    name = fields.Char(default='Mobile App Settings')

    # ═══════════════════════════════════════════════════════════════
    # الإعدادات العامة
    # ═══════════════════════════════════════════════════════════════
    allow_mobile_app_access = fields.Boolean(
        string="Enable App Access",
        default=lambda self: self._default_allow_mobile_app_access(),
        help="Enable employees to use the mobile app"
    )

    mobile_service_username = fields.Char(
        string="Service Username",
        default=lambda self: self._default_service_username(),
        help="Shared username for server connection"
    )

    mobile_service_password = fields.Char(
        string="Service Password",
        default=lambda self: self._default_service_password(),
        help="Shared user password (should be changed regularly)"
    )

    # ═══════════════════════════════════════════════════════════════
    # معلومات الاتصال
    # ═══════════════════════════════════════════════════════════════
    api_base_url = fields.Char(
        string="API Server URL",
        default=lambda self: self._default_api_base_url(),
        help="Base URL for Odoo server (example: https://your-odoo-server.com)"
    )

    api_database = fields.Char(
        string="Database Name",
        default=lambda self: self._default_api_database(),
        help="Odoo database name to connect to"
    )

    # ═══════════════════════════════════════════════════════════════
    # Token وQR Code
    # ═══════════════════════════════════════════════════════════════
    company_token = fields.Char(
        string="Company Token",
        default=lambda self: self._default_company_token(),
        help="Unique token for mobile app connection",
    )

    company_code = fields.Char(
        string="Short Code (8 chars)",
        default=lambda self: self._default_company_code(),
        help="Short code for easy entry (8 characters)",
    )

    token_created_date = fields.Char(
        string="Token Created",
        default=lambda self: self._default_token_created_date(),
    )

    token_expiry_date = fields.Datetime(
        string="Token Expiry",
        help="Leave empty for no expiration",
    )

    qr_code_image = fields.Binary(
        string="QR Code",
        default=lambda self: self._default_qr_code(),
        help="QR Code for mobile app configuration"
    )

    connection_string = fields.Char(
        string="Connection String",
        default=lambda self: self._default_connection_string(),
        help="Full connection string for manual entry"
    )

    # ═══════════════════════════════════════════════════════════════
    # Default Methods
    # ═══════════════════════════════════════════════════════════════
    def _default_allow_mobile_app_access(self):
        return self.env['ir.config_parameter'].sudo().get_param(
            'hr_mobile_app.allow_mobile_app_access', 'False').lower() == 'true'

    def _default_service_username(self):
        return self.env['ir.config_parameter'].sudo().get_param(
            'hr_mobile_app.service_username', 'mobile_app_service')

    def _default_service_password(self):
        return self.env['ir.config_parameter'].sudo().get_param(
            'hr_mobile_app.service_password', '')

    def _default_api_base_url(self):
        param_url = self.env['ir.config_parameter'].sudo().get_param('hr_mobile_app.api_base_url', '')
        if param_url:
            return param_url.rstrip('/')
        base_url = self.env['ir.config_parameter'].sudo().get_param('web.base.url', '')
        return base_url.rstrip('/') if base_url else ''

    def _default_api_database(self):
        param_db = self.env['ir.config_parameter'].sudo().get_param('hr_mobile_app.api_database', '')
        return param_db or self.env.cr.dbname

    def _default_company_token(self):
        return self.env['ir.config_parameter'].sudo().get_param('hr_mobile_app.company_token', '')

    def _default_company_code(self):
        return self.env['ir.config_parameter'].sudo().get_param('hr_mobile_app.company_code', '')

    def _default_token_created_date(self):
        return self.env['ir.config_parameter'].sudo().get_param('hr_mobile_app.token_created_date', '')

    def _default_connection_string(self):
        params = self.env['ir.config_parameter'].sudo()
        token = params.get_param('hr_mobile_app.company_token', '')
        url = params.get_param('hr_mobile_app.api_base_url', '') or params.get_param('web.base.url', '')
        db = params.get_param('hr_mobile_app.api_database', '') or self.env.cr.dbname

        if token and url:
            return f"{url}|{token}|{db}"
        return ''

    def _default_qr_code(self):
        params = self.env['ir.config_parameter'].sudo()
        token = params.get_param('hr_mobile_app.company_token', '')
        url = params.get_param('hr_mobile_app.api_base_url', '') or params.get_param('web.base.url', '')
        db = params.get_param('hr_mobile_app.api_database', '') or self.env.cr.dbname

        if token and url:
            qr_data = json.dumps({
                'url': url,
                'db': db,
                'token': token,
                'name': self.env.company.name,
            })
            return self._generate_qr_code_static(qr_data)
        return False

    # ═══════════════════════════════════════════════════════════════
    # Token Actions
    # ═══════════════════════════════════════════════════════════════
    def action_generate_token(self):
        self.ensure_one()

        url = self.api_base_url
        if not url:
            url = self.env['ir.config_parameter'].sudo().get_param('web.base.url', '')

        if not url:
            raise ValidationError(_('Please enter the API Server URL first.'))

        token = self._generate_secure_token(32)
        short_code = self._generate_short_code(8)
        now = fields.Datetime.now()
        now_str = fields.Datetime.to_string(now)

        params = self.env['ir.config_parameter'].sudo()
        params.set_param('hr_mobile_app.company_token', token)
        params.set_param('hr_mobile_app.company_code', short_code)
        params.set_param('hr_mobile_app.token_created_date', now_str)
        params.set_param('hr_mobile_app.api_base_url', url)
        params.set_param('hr_mobile_app.api_database', self.api_database or self.env.cr.dbname)

        _logger.info("Generated new company token: %s... and code: %s", token[:8], short_code)

        return {
            'type': 'ir.actions.act_window',
            'res_model': 'hr.mobile.app.settings',
            'view_mode': 'form',
            'target': 'current',
        }

    def action_regenerate_token(self):
        return self.action_generate_token()

    def action_revoke_token(self):
        params = self.env['ir.config_parameter'].sudo()
        params.set_param('hr_mobile_app.company_token', '')
        params.set_param('hr_mobile_app.company_code', '')
        params.set_param('hr_mobile_app.token_created_date', '')

        return {
            'type': 'ir.actions.act_window',
            'res_model': 'hr.mobile.app.settings',
            'view_mode': 'form',
            'target': 'current',
        }

    def action_copy_connection_string(self):
        connection_str = self._default_connection_string()

        if not connection_str:
            raise ValidationError(_('Please generate a token first.'))

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Connection String'),
                'message': connection_str,
                'type': 'info',
                'sticky': True,
            }
        }

    def action_refresh(self):
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'hr.mobile.app.settings',
            'view_mode': 'form',
            'target': 'current',
        }

    # ═══════════════════════════════════════════════════════════════
    # Helper Methods
    # ═══════════════════════════════════════════════════════════════
    def _generate_secure_token(self, length=32):
        alphabet = string.ascii_letters + string.digits
        return ''.join(secrets.choice(alphabet) for _ in range(length))

    def _generate_short_code(self, length=8):
        alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        return ''.join(secrets.choice(alphabet) for _ in range(length))

    @staticmethod
    def _generate_qr_code_static(data):
        try:
            import qrcode
            from io import BytesIO

            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_M,
                box_size=10,
                border=4,
            )
            qr.add_data(data)
            qr.make(fit=True)

            img = qr.make_image(fill_color="black", back_color="white")

            buffer = BytesIO()
            img.save(buffer, format='PNG')
            qr_image = base64.b64encode(buffer.getvalue())

            return qr_image

        except ImportError:
            _logger.warning("qrcode library not installed")
            return False
        except Exception as e:
            _logger.error("Error generating QR Code: %s", str(e))
            return False

    def execute(self):
        if self.mobile_service_password and len(self.mobile_service_password) < 12:
            raise ValidationError(_('Password must be at least 12 characters long'))

        params = self.env['ir.config_parameter'].sudo()
        params.set_param('hr_mobile_app.allow_mobile_app_access', str(self.allow_mobile_app_access))
        params.set_param('hr_mobile_app.service_username', self.mobile_service_username or 'mobile_app_service')

        if self.mobile_service_password:
            params.set_param('hr_mobile_app.service_password', self.mobile_service_password)

        if self.api_base_url:
            params.set_param('hr_mobile_app.api_base_url', self.api_base_url)

        params.set_param('hr_mobile_app.api_database', self.api_database or self.env.cr.dbname)

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Success'),
                'message': _('Settings saved successfully!'),
                'type': 'success',
                'sticky': False,
            }
        }

    def cancel(self):
        return {'type': 'ir.actions.act_window_close'}