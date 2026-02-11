# -*- coding: utf-8 -*-
# hr_mobile_app/controllers/mobile_config_api.py
# API للتحقق من كود الشركة وإعداد التطبيق

from odoo import http, fields, _
from odoo.http import request
import json
import logging
from datetime import datetime

_logger = logging.getLogger(__name__)


class MobileConfigAPI(http.Controller):
    """واجهة برمجة تطبيقات لإعداد التطبيق المحمول"""

    # ═══════════════════════════════════════════════════════════════
    # API التحقق من Token/Code
    # ═══════════════════════════════════════════════════════════════

    @http.route('/api/mobile/verify_company', type='http', auth='none',
                methods=['POST', 'OPTIONS'], csrf=False, cors='*')
    def verify_company_token(self, **kw):
        """
        التحقق من كود/توكن الشركة

        Request Body:
        {
            "jsonrpc": "2.0",
            "params": {
                "token": "COMPANY_TOKEN_OR_CODE"
            }
        }

        Response (Success):
        {
            "jsonrpc": "2.0",
            "result": {
                "success": true,
                "company_name": "اسم الشركة",
                "database": "database_name",
                "logo": "base64_encoded_logo",
                "is_active": true,
                "token_expiry": "2025-12-31T23:59:59"
            }
        }

        Response (Failure):
        {
            "jsonrpc": "2.0",
            "result": {
                "success": false,
                "error": "Invalid token"
            }
        }
        """
        # معالجة CORS preflight
        if request.httprequest.method == 'OPTIONS':
            return self._cors_response()

        _logger.info("====== Verify Company Token Request ======")

        try:
            # استخراج البيانات
            data = self._parse_request_data()
            if not data:
                return self._error_response("No data received")

            params = data.get('params', {})
            token = params.get('token', '').strip()

            if not token:
                return self._error_response("Token is required")

            _logger.info("Company token verification attempt received")

            # البحث عن Token في الإعدادات
            config_params = request.env['ir.config_parameter'].sudo()

            stored_token = config_params.get_param('hr_mobile_app.company_token', '')
            stored_code = config_params.get_param('hr_mobile_app.company_code', '')

            # التحقق من Token أو Code
            is_valid = False
            if token == stored_token:
                is_valid = True
                _logger.info("Token matched (full token)")
            elif token.upper() == stored_code:
                is_valid = True
                _logger.info("Token matched (short code)")

            if not is_valid:
                _logger.warning("Invalid token verification attempt")
                return self._error_response("Invalid token or code")

            # التحقق من صلاحية Token
            token_expiry = config_params.get_param('hr_mobile_app.token_expiry_date', '')
            if token_expiry:
                try:
                    expiry_date = fields.Datetime.from_string(token_expiry)
                    if expiry_date and datetime.now() > expiry_date:
                        _logger.warning("Token expired")
                        return self._error_response("Token has expired")
                except:
                    pass

            # التحقق من تفعيل التطبيق
            is_enabled = config_params.get_param('hr_mobile_app.allow_mobile_app_access', 'False')
            if is_enabled.lower() != 'true':
                _logger.warning("Mobile app access is disabled")
                return self._error_response("Mobile app access is disabled")

            # جلب بيانات الشركة
            company = request.env.company.sudo()
            database = config_params.get_param('hr_mobile_app.api_database', request.db)

            # الحصول على شعار الشركة
            logo_base64 = None
            if company.logo:
                logo_base64 = company.logo.decode('utf-8') if isinstance(company.logo, bytes) else company.logo

            # إرجاع البيانات
            result = {
                'success': True,
                'company_name': company.name,
                'database': database,
                'logo': logo_base64,
                'is_active': True,
                'token_expiry': token_expiry if token_expiry else None,
                'server_url': config_params.get_param('hr_mobile_app.api_base_url', ''),
            }

            _logger.info("Company verification successful: %s", company.name)

            return self._success_response(result)

        except Exception as e:
            _logger.error("Error verifying company token: %s", str(e))
            return self._error_response("حدث خطأ في الخادم")

    @http.route('/api/mobile/verify_code', type='http', auth='none',
                methods=['POST', 'OPTIONS'], csrf=False, cors='*')
    def verify_company_code(self, **kw):
        """
        التحقق من الكود القصير للشركة (8 أحرف)
        نفس verify_company_token لكن باسم مختلف للوضوح
        """
        return self.verify_company_token(**kw)

    @http.route('/api/mobile/config_info', type='http', auth='none',
                methods=['GET'], csrf=False, cors='*')
    def get_config_info(self, **kw):
        """
        الحصول على معلومات السيرفر العامة (بدون token)
        للتحقق من أن السيرفر يعمل
        """
        _logger.info("====== Config Info Request ======")

        try:
            config_params = request.env['ir.config_parameter'].sudo()
            company = request.env.company.sudo()

            is_enabled = config_params.get_param('hr_mobile_app.allow_mobile_app_access', 'False')
            database = config_params.get_param('hr_mobile_app.api_database', '') or request.db

            result = {
                'server_online': True,
                'api_version': '2.0',
                'requires_token': True,
                'mobile_app_enabled': is_enabled.lower() == 'true',
                'database': database,
                'company_name': company.name if company else '',
            }

            return self._success_response(result)

        except Exception as e:
            _logger.error("Error getting config info: %s", str(e))
            return self._error_response("حدث خطأ في الخادم")

    # ═══════════════════════════════════════════════════════════════
    # Helper Methods
    # ═══════════════════════════════════════════════════════════════

    def _parse_request_data(self):
        """تحليل بيانات الطلب"""
        try:
            if request.httprequest.data:
                return json.loads(request.httprequest.data.decode('utf-8'))
            return {}
        except Exception as e:
            _logger.error("Error parsing request data: %s", str(e))
            return {}

    def _success_response(self, result):
        """إرجاع استجابة ناجحة"""
        response_data = {
            'jsonrpc': '2.0',
            'result': result
        }
        return self._json_response(response_data)

    def _error_response(self, message, code=None):
        """إرجاع استجابة خطأ"""
        result = {
            'success': False,
            'error': message,
        }
        if code:
            result['error_code'] = code

        response_data = {
            'jsonrpc': '2.0',
            'result': result
        }
        return self._json_response(response_data)

    def _get_allowed_origin(self):
        """Get configured CORS origin - default to * for mobile app compatibility"""
        try:
            return request.env['ir.config_parameter'].sudo().get_param(
                'hr_mobile_app.allowed_cors_origin', '*')
        except Exception:
            return '*'

    def _json_response(self, data):
        """إرجاع استجابة JSON مع CORS headers"""
        allowed_origin = self._get_allowed_origin()
        response = request.make_response(
            json.dumps(data),
            headers=[
                ('Content-Type', 'application/json'),
                ('Access-Control-Allow-Origin', allowed_origin),
                ('Access-Control-Allow-Methods', 'GET, POST, OPTIONS'),
                ('Access-Control-Allow-Headers', 'Content-Type'),
            ]
        )
        return response

    def _cors_response(self):
        """استجابة لـ CORS preflight"""
        allowed_origin = self._get_allowed_origin()
        response = request.make_response(
            '',
            headers=[
                ('Access-Control-Allow-Origin', allowed_origin),
                ('Access-Control-Allow-Methods', 'POST, OPTIONS'),
                ('Access-Control-Allow-Headers', 'Content-Type'),
                ('Access-Control-Max-Age', '86400'),
            ]
        )
        return response