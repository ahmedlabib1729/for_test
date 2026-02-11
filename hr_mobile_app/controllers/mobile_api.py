# -*- coding: utf-8 -*-
from odoo import http, fields
from odoo.http import request
import json
import logging

_logger = logging.getLogger(__name__)


class MobileApi(http.Controller):
    """واجهات API للتطبيق المحمول"""

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات عامة (HTTP endpoints - no session required)
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/version', type='http', auth='none',
                methods=['GET'], csrf=False, cors='*')
    def get_api_version(self, **kw):
        """API version check - basic connectivity test"""
        return request.make_response(
            json.dumps({
                'jsonrpc': '2.0',
                'result': {
                    'version': '2.0',
                    'name': 'Odoo Mobile API',
                    'status': 'online',
                }
            }),
            headers=[('Content-Type', 'application/json')]
        )

    @http.route('/api/mobile/simple_login', type='http', auth='none',
                methods=['POST', 'OPTIONS'], csrf=False, cors='*')
    def simple_login(self, **kw):
        """Simple login for mobile app - no Odoo session required"""
        if request.httprequest.method == 'OPTIONS':
            return request.make_response('', headers=[
                ('Access-Control-Allow-Origin', '*'),
                ('Access-Control-Allow-Methods', 'POST, OPTIONS'),
                ('Access-Control-Allow-Headers', 'Content-Type'),
            ])

        try:
            _logger.info("====== Simple Login Request ======")

            if not request.httprequest.data:
                return self._make_json_response(
                    {'success': False, 'error': 'No data received'})

            data = json.loads(request.httprequest.data.decode('utf-8'))
            params = data.get('params', data)
            username = params.get('username', '')
            password = params.get('password', params.get('pin', ''))

            if not username or not password:
                return self._make_json_response(
                    {'success': False, 'error': 'Username and password required'})

            _logger.info("Login attempt for: %s", username)

            employee = request.env['hr.employee'].sudo().search([
                ('mobile_username', '=', username),
                ('allow_mobile_access', '=', True),
            ], limit=1)

            if not employee:
                _logger.warning("Login failed - user not found: %s", username)
                return self._make_json_response(
                    {'success': False, 'error': 'بيانات الدخول غير صحيحة'})

            # Verify PIN - supports both hashed and plaintext
            pin_valid = False
            if hasattr(employee, 'verify_pin') and employee.mobile_pin_hash and employee.mobile_salt:
                pin_valid = employee.verify_pin(password)
            elif employee.mobile_pin:
                pin_valid = (employee.mobile_pin == password)

            if not pin_valid:
                _logger.warning("Login failed - wrong PIN for: %s", username)
                return self._make_json_response(
                    {'success': False, 'error': 'بيانات الدخول غير صحيحة'})

            _logger.info("Login successful for employee ID: %s", employee.id)

            return self._make_json_response({
                'success': True,
                'employee': {
                    'id': employee.id,
                    'name': employee.name,
                    'job_title': employee.job_title or '',
                    'department': employee.department_id.name if employee.department_id else '',
                    'work_email': employee.work_email or '',
                    'work_phone': employee.work_phone or '',
                    'mobile_phone': employee.mobile_phone or '',
                }
            })

        except Exception as e:
            _logger.error("simple_login error: %s", str(e))
            return self._make_json_response(
                {'success': False, 'error': 'حدث خطأ في الخادم'})

    def _make_json_response(self, data):
        """Return JSON response with CORS headers"""
        return request.make_response(
            json.dumps(data),
            headers=[
                ('Content-Type', 'application/json'),
                ('Access-Control-Allow-Origin', '*'),
                ('Access-Control-Allow-Methods', 'POST, GET, OPTIONS'),
                ('Access-Control-Allow-Headers', 'Content-Type'),
            ]
        )

    @http.route('/api/mobile/test', type='json', auth='public', csrf=False)
    def test_api(self):
        """اختبار أن API يعمل"""
        return ({
            'status': 'success',
            'message': 'API تعمل بشكل صحيح',
            'version': '2.0',
            'timestamp': fields.Datetime.now(),
        })

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات الحضور والانصراف الأساسية
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/attendance/check_location', type='json', auth='user', csrf=False)
    def check_attendance_location(self, employee_id=None, latitude=None, longitude=None):
        """التحقق من الموقع قبل السماح بتسجيل الحضور/الانصراف"""
        try:
            _logger.info("====== التحقق من موقع الحضور ======")
            _logger.info("employee_id: %s, lat: %s, lng: %s", employee_id, latitude, longitude)

            if not all([employee_id, latitude, longitude]):
                return {
                    'success': False,
                    'error': 'جميع البيانات مطلوبة (معرف الموظف، خط العرض، خط الطول)'
                }

            result = request.env['hr.attendance'].sudo().check_location_before_attendance(
                int(employee_id),
                float(latitude),
                float(longitude)
            )

            return result

        except Exception as e:
            _logger.error("خطأ في التحقق من الموقع: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/check_in', type='json', auth='user', csrf=False)
    def mobile_attendance_check_in(self, employee_id=None, latitude=None, longitude=None):
        """تسجيل حضور مع الموقع الجغرافي (بدون صورة)"""
        try:
            _logger.info("====== تسجيل حضور مع الموقع ======")
            _logger.info("employee_id: %s, lat: %s, lng: %s", employee_id, latitude, longitude)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            emp_id = int(employee_id)
            lat = float(latitude) if latitude else None
            lng = float(longitude) if longitude else None

            result = request.env['hr.attendance'].sudo().mobile_check_in(
                emp_id, lat, lng
            )

            return result

        except ValueError as e:
            _logger.error("خطأ في تحويل البيانات: %s", str(e))
            return {
                'success': False,
                'error': 'البيانات المرسلة غير صالحة'
            }
        except Exception as e:
            _logger.error("خطأ في تسجيل الحضور: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/check_out', type='json', auth='user', csrf=False)
    def mobile_attendance_check_out(self, employee_id=None, latitude=None, longitude=None):
        """تسجيل انصراف مع الموقع الجغرافي (بدون صورة)"""
        try:
            _logger.info("====== تسجيل انصراف مع الموقع ======")
            _logger.info("employee_id: %s, lat: %s, lng: %s", employee_id, latitude, longitude)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            emp_id = int(employee_id)
            lat = float(latitude) if latitude else None
            lng = float(longitude) if longitude else None

            result = request.env['hr.attendance'].sudo().mobile_check_out(
                emp_id, lat, lng
            )

            return result

        except ValueError as e:
            _logger.error("خطأ في تحويل البيانات: %s", str(e))
            return {
                'success': False,
                'error': 'البيانات المرسلة غير صالحة'
            }
        except Exception as e:
            _logger.error("خطأ في تسجيل الانصراف: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات الحضور والانصراف مع الصور
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/attendance/check_in_photo', type='json', auth='user', csrf=False)
    def mobile_check_in_with_photo(self, employee_id=None, latitude=None, longitude=None,
                                   photo_base64=None, action_performed=None):
        """تسجيل حضور مع صورة التحقق من الوجه"""
        try:
            _logger.info("=" * 60)
            _logger.info("📸 API: تسجيل حضور مع صورة")
            _logger.info("employee_id: %s", employee_id)
            _logger.info("latitude: %s, longitude: %s", latitude, longitude)
            _logger.info("action_performed: %s", action_performed)
            _logger.info("photo_size: %s bytes", len(photo_base64) if photo_base64 else 0)
            _logger.info("=" * 60)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            if not photo_base64:
                return {'success': False, 'error': 'الصورة مطلوبة للتحقق'}

            result = request.env['hr.attendance'].sudo().mobile_check_in_with_photo(
                employee_id=int(employee_id),
                latitude=float(latitude) if latitude else None,
                longitude=float(longitude) if longitude else None,
                photo_base64=photo_base64,
                action_performed=action_performed,
            )

            return result

        except ValueError as e:
            _logger.error("خطأ في تحويل البيانات: %s", str(e))
            return {
                'success': False,
                'error': 'البيانات المرسلة غير صالحة'
            }
        except Exception as e:
            _logger.error("خطأ في تسجيل الحضور مع الصورة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/check_out_photo', type='json', auth='user', csrf=False)
    def mobile_check_out_with_photo(self, employee_id=None, latitude=None, longitude=None,
                                    photo_base64=None, action_performed=None):
        """تسجيل انصراف مع صورة التحقق من الوجه"""
        try:
            _logger.info("=" * 60)
            _logger.info("📸 API: تسجيل انصراف مع صورة")
            _logger.info("employee_id: %s", employee_id)
            _logger.info("latitude: %s, longitude: %s", latitude, longitude)
            _logger.info("action_performed: %s", action_performed)
            _logger.info("photo_size: %s bytes", len(photo_base64) if photo_base64 else 0)
            _logger.info("=" * 60)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            if not photo_base64:
                return {'success': False, 'error': 'الصورة مطلوبة للتحقق'}

            result = request.env['hr.attendance'].sudo().mobile_check_out_with_photo(
                employee_id=int(employee_id),
                latitude=float(latitude) if latitude else None,
                longitude=float(longitude) if longitude else None,
                photo_base64=photo_base64,
                action_performed=action_performed,
            )

            return result

        except ValueError as e:
            _logger.error("خطأ في تحويل البيانات: %s", str(e))
            return {
                'success': False,
                'error': 'البيانات المرسلة غير صالحة'
            }
        except Exception as e:
            _logger.error("خطأ في تسجيل الانصراف مع الصورة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/get_photos', type='json', auth='user', csrf=False)
    def get_attendance_photos(self, attendance_id=None):
        """الحصول على صور سجل الحضور"""
        try:
            if not attendance_id:
                return {'success': False, 'error': 'معرف سجل الحضور مطلوب'}

            attendance = request.env['hr.attendance'].sudo().browse(int(attendance_id))

            if not attendance.exists():
                return {'success': False, 'error': 'سجل الحضور غير موجود'}

            return {
                'success': True,
                'data': attendance.get_attendance_photos(),
            }

        except Exception as e:
            _logger.error("خطأ في جلب صور الحضور: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات حالة الحضور والسجلات
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/attendance/status', type='json', auth='user', csrf=False)
    def get_attendance_status(self, employee_id=None):
        """الحصول على حالة الحضور الحالية للموظف"""
        try:
            _logger.info("====== طلب حالة الحضور ======")

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            status = request.env['hr.attendance'].sudo().get_employee_attendance_status(
                int(employee_id)
            )

            return {
                'success': True,
                'attendance_status': status
            }

        except Exception as e:
            _logger.error("خطأ في جلب حالة الحضور: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/history', type='json', auth='user', csrf=False)
    def get_attendance_history(self, employee_id=None, limit=10):
        """الحصول على سجل الحضور السابق"""
        try:
            _logger.info("====== طلب سجل الحضور ======")

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            history = request.env['hr.attendance'].sudo().get_employee_attendance_history(
                int(employee_id),
                int(limit)
            )

            return {
                'success': True,
                'attendance_history': history
            }

        except Exception as e:
            _logger.error("خطأ في جلب سجل الحضور: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/attendance/summary', type='json', auth='user', csrf=False)
    def get_attendance_summary(self, employee_id=None):
        """الحصول على ملخص الحضور اليومي"""
        try:
            _logger.info("====== طلب ملخص الحضور ======")

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            summary = request.env['hr.attendance'].sudo().get_employee_attendance_summary(
                int(employee_id)
            )

            return {
                'success': True,
                'summary': summary
            }

        except Exception as e:
            _logger.error("خطأ في جلب ملخص الحضور: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات الإجازات - رصيد الإجازات (معدل)
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/leave/balance', type='json', auth='user', csrf=False)
    def get_employee_leave_balance(self, employee_id=None):
        """
        الحصول على رصيد الإجازات للموظف
        ✅ يظهر فقط الإجازات المخصصة للموظف من Odoo
        """
        try:
            _logger.info("====== طلب رصيد الإجازات للموظف %s ======", employee_id)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            employee = request.env['hr.employee'].sudo().browse(int(employee_id))
            if not employee.exists():
                return {'success': False, 'error': 'الموظف غير موجود'}

            # ═══════════════════════════════════════════════════════════════
            # ✅ جلب التخصيصات المعتمدة للموظف فقط (وليس كل أنواع الإجازات)
            # ═══════════════════════════════════════════════════════════════
            allocations = request.env['hr.leave.allocation'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('state', '=', 'validate'),  # التخصيصات المعتمدة فقط
            ])

            # إذا لم يكن للموظف أي تخصيصات
            if not allocations:
                _logger.info("لا توجد تخصيصات إجازات للموظف %s", employee_id)
                return {
                    'success': True,
                    'balance_data': {
                        'employee_id': int(employee_id),
                        'employee_name': employee.name,
                        'total_allocated': 0,
                        'total_used': 0,
                        'total_remaining': 0,
                        'usage_percentage': 0,
                        'pending_requests': 0,
                        'leave_types': {},
                        'message': 'لا توجد تخصيصات إجازات لهذا الموظف',
                    }
                }

            balance_data = {}
            total_allocated = 0
            total_used = 0
            total_remaining = 0

            current_year = fields.Date.today().year

            # تجميع التخصيصات حسب نوع الإجازة
            allocation_by_type = {}
            for allocation in allocations:
                leave_type_id = allocation.holiday_status_id.id
                if leave_type_id not in allocation_by_type:
                    allocation_by_type[leave_type_id] = {
                        'allocation': allocation,
                        'total_days': 0,
                    }
                allocation_by_type[leave_type_id]['total_days'] += allocation.number_of_days

            # معالجة كل نوع إجازة مخصص للموظف
            for leave_type_id, alloc_data in allocation_by_type.items():
                allocation = alloc_data['allocation']
                leave_type = allocation.holiday_status_id
                allocated_days = alloc_data['total_days']

                # جلب الإجازات المعتمدة للسنة الحالية
                approved_leaves = request.env['hr.leave'].sudo().search([
                    ('employee_id', '=', int(employee_id)),
                    ('holiday_status_id', '=', leave_type_id),
                    ('state', '=', 'validate'),
                    ('date_from', '>=', f'{current_year}-01-01'),
                    ('date_to', '<=', f'{current_year}-12-31')
                ])

                used_days = sum(approved_leaves.mapped('number_of_days'))
                remaining_days = max(0, allocated_days - used_days)

                # الحصول على لون نوع الإجازة
                color = '#2196F3'  # اللون الافتراضي
                if hasattr(leave_type, 'color_name') and leave_type.color_name:
                    color = leave_type.color_name
                elif hasattr(leave_type, 'color') and leave_type.color:
                    color_map = {
                        0: '#FFFFFF', 1: '#F44336', 2: '#E91E63', 3: '#9C27B0',
                        4: '#673AB7', 5: '#3F51B5', 6: '#2196F3', 7: '#03A9F4',
                        8: '#00BCD4', 9: '#009688', 10: '#4CAF50', 11: '#8BC34A',
                    }
                    color = color_map.get(leave_type.color, '#2196F3')

                balance_data[leave_type.name] = {
                    'type_id': leave_type_id,
                    'type_name': leave_type.name,
                    'allocated': allocated_days,
                    'used': used_days,
                    'remaining': remaining_days,
                    'color': color,
                    'requires_allocation': leave_type.requires_allocation == 'yes',
                }

                total_allocated += allocated_days
                total_used += used_days
                total_remaining += remaining_days

            # حساب النسبة المئوية للاستخدام
            usage_percentage = (total_used / total_allocated * 100) if total_allocated > 0 else 0

            # عدد الطلبات المعلقة
            pending_requests = request.env['hr.leave'].sudo().search_count([
                ('employee_id', '=', int(employee_id)),
                ('state', 'in', ['draft', 'confirm'])
            ])

            _logger.info("تم جلب رصيد الإجازات بنجاح: %s أنواع", len(balance_data))

            return {
                'success': True,
                'balance_data': {
                    'employee_id': int(employee_id),
                    'employee_name': employee.name,
                    'total_allocated': total_allocated,
                    'total_used': total_used,
                    'total_remaining': total_remaining,
                    'usage_percentage': round(usage_percentage, 2),
                    'pending_requests': pending_requests,
                    'leave_types': balance_data,
                    'current_year': current_year,
                    'last_updated': fields.Datetime.now().isoformat(),
                }
            }

        except Exception as e:
            _logger.error("خطأ في جلب رصيد الإجازات: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/leave/types', type='json', auth='user', csrf=False)
    def get_leave_types(self, employee_id=None):
        """
        الحصول على أنواع الإجازات المتاحة للموظف
        ✅ يظهر فقط الأنواع التي لها تخصيص للموظف
        """
        try:
            _logger.info("====== طلب أنواع الإجازات للموظف %s ======", employee_id)

            types_data = []

            if employee_id:
                # ═══════════════════════════════════════════════════════════════
                # ✅ جلب فقط أنواع الإجازات المخصصة للموظف
                # ═══════════════════════════════════════════════════════════════
                allocations = request.env['hr.leave.allocation'].sudo().search([
                    ('employee_id', '=', int(employee_id)),
                    ('state', '=', 'validate'),
                ])

                # جمع أنواع الإجازات الفريدة من التخصيصات
                leave_type_ids = list(set(allocations.mapped('holiday_status_id.id')))

                if leave_type_ids:
                    leave_types = request.env['hr.leave.type'].sudo().browse(leave_type_ids)
                else:
                    # إذا لم يكن للموظف تخصيصات، لا نظهر أي نوع
                    return {
                        'success': True,
                        'leave_types': [],
                        'message': 'لا توجد تخصيصات إجازات لهذا الموظف'
                    }
            else:
                # إذا لم يتم تحديد موظف، جلب كل الأنواع النشطة
                leave_types = request.env['hr.leave.type'].sudo().search([
                    ('active', '=', True),
                ])

            for leave_type in leave_types:
                # الحصول على اللون
                color = '#2196F3'
                if hasattr(leave_type, 'color_name') and leave_type.color_name:
                    color = leave_type.color_name
                elif hasattr(leave_type, 'color') and leave_type.color:
                    color_map = {
                        0: '#FFFFFF', 1: '#F44336', 2: '#E91E63', 3: '#9C27B0',
                        4: '#673AB7', 5: '#3F51B5', 6: '#2196F3', 7: '#03A9F4',
                        8: '#00BCD4', 9: '#009688', 10: '#4CAF50', 11: '#8BC34A',
                    }
                    color = color_map.get(leave_type.color, '#2196F3')

                types_data.append({
                    'id': leave_type.id,
                    'name': leave_type.name,
                    'color': color,
                    'requires_approval': leave_type.leave_validation_type != 'no_validation',
                    'requires_allocation': leave_type.requires_allocation == 'yes',
                })

            return {
                'success': True,
                'leave_types': types_data
            }

        except Exception as e:
            _logger.error("خطأ في جلب أنواع الإجازات: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات طلبات الإجازة
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/leave/requests', type='json', auth='user', csrf=False)
    def get_leave_requests(self, employee_id=None, limit=50):
        """الحصول على طلبات الإجازة للموظف"""
        try:
            _logger.info("====== طلب جلب طلبات الإجازة للموظف %s ======", employee_id)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            domain = [('employee_id', '=', int(employee_id))]

            leave_requests = request.env['hr.leave'].sudo().search(
                domain,
                order='create_date desc',
                limit=int(limit)
            )

            requests_data = []
            for leave_request in leave_requests:
                state_mapping = {
                    'draft': {'text': 'مسودة', 'icon': '📝', 'color': '#9E9E9E'},
                    'confirm': {'text': 'قيد المراجعة', 'icon': '⏳', 'color': '#FFA500'},
                    'validate1': {'text': 'مراجعة أولى', 'icon': '👁️', 'color': '#2196F3'},
                    'validate': {'text': 'مقبولة', 'icon': '✅', 'color': '#4CAF50'},
                    'refuse': {'text': 'مرفوضة', 'icon': '❌', 'color': '#F44336'},
                    'cancel': {'text': 'ملغاة', 'icon': '🚫', 'color': '#9E9E9E'},
                }

                state_info = state_mapping.get(leave_request.state, state_mapping['draft'])

                approver_name = None
                approval_date = None
                if hasattr(leave_request, 'first_approver_id') and leave_request.first_approver_id:
                    approver_name = leave_request.first_approver_id.name
                if hasattr(leave_request, 'date_approve') and leave_request.date_approve:
                    approval_date = leave_request.date_approve.isoformat()

                requests_data.append({
                    'id': leave_request.id,
                    'employee_id': leave_request.employee_id.id,
                    'employee_name': leave_request.employee_id.name,
                    'leave_type_id': leave_request.holiday_status_id.id,
                    'leave_type_name': leave_request.holiday_status_id.name,
                    'date_from': leave_request.date_from.isoformat() if leave_request.date_from else None,
                    'date_to': leave_request.date_to.isoformat() if leave_request.date_to else None,
                    'number_of_days': leave_request.number_of_days,
                    'reason': leave_request.name or '',
                    'state': leave_request.state,
                    'state_text': state_info['text'],
                    'state_icon': state_info['icon'],
                    'state_color': state_info['color'],
                    'created_date': leave_request.create_date.isoformat() if leave_request.create_date else None,
                    'approver_name': approver_name,
                    'approval_date': approval_date,
                    'manager_comment': getattr(leave_request, 'notes', '') or '',
                })

            return {
                'success': True,
                'leave_requests': requests_data,
                'total_count': len(requests_data)
            }

        except Exception as e:
            _logger.error("خطأ في جلب طلبات الإجازة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/leave/create', type='json', auth='user', csrf=False)
    def create_leave_request(self, employee_id=None, leave_type_id=None,
                             date_from=None, date_to=None, reason=None):
        """إنشاء طلب إجازة جديد"""
        try:
            _logger.info("====== إنشاء طلب إجازة جديد ======")
            _logger.info("employee_id: %s, leave_type_id: %s", employee_id, leave_type_id)
            _logger.info("date_from: %s, date_to: %s", date_from, date_to)

            if not all([employee_id, leave_type_id, date_from, date_to]):
                return {
                    'success': False,
                    'error': 'جميع البيانات مطلوبة (معرف الموظف، نوع الإجازة، تاريخ البداية، تاريخ النهاية)'
                }

            # التحقق من أن الموظف لديه تخصيص لهذا النوع
            allocation = request.env['hr.leave.allocation'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('holiday_status_id', '=', int(leave_type_id)),
                ('state', '=', 'validate'),
            ], limit=1)

            if not allocation:
                return {
                    'success': False,
                    'error': 'لا يوجد رصيد مخصص لهذا النوع من الإجازات'
                }

            # تحويل التواريخ
            from datetime import datetime
            date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
            date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))

            leave_vals = {
                'employee_id': int(employee_id),
                'holiday_status_id': int(leave_type_id),
                'request_date_from': date_from_dt.date() if hasattr(date_from_dt, 'date') else date_from_dt,
                'request_date_to': date_to_dt.date() if hasattr(date_to_dt, 'date') else date_to_dt,
                'name': reason or '',
            }

            # إضافة حقول التطبيق إذا كانت موجودة
            if 'mobile_created' in request.env['hr.leave']._fields:
                leave_vals['mobile_created'] = True
            if 'mobile_request_date' in request.env['hr.leave']._fields:
                leave_vals['mobile_request_date'] = fields.Datetime.now()

            leave_request = request.env['hr.leave'].sudo().create(leave_vals)

            return {
                'success': True,
                'leave_id': leave_request.id,
                'message': 'تم إنشاء طلب الإجازة بنجاح'
            }

        except Exception as e:
            _logger.error("خطأ في إنشاء طلب الإجازة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/leave/cancel', type='json', auth='user', csrf=False)
    def cancel_leave_request(self, leave_id=None):
        """إلغاء طلب إجازة"""
        try:
            _logger.info("====== إلغاء طلب إجازة ======")
            _logger.info("leave_id: %s", leave_id)

            if not leave_id:
                return {'success': False, 'error': 'معرف طلب الإجازة مطلوب'}

            leave_request = request.env['hr.leave'].sudo().browse(int(leave_id))

            if not leave_request.exists():
                return {'success': False, 'error': 'طلب الإجازة غير موجود'}

            if leave_request.state not in ['draft', 'confirm']:
                return {
                    'success': False,
                    'error': 'لا يمكن إلغاء طلب الإجازة في هذه الحالة'
                }

            leave_request.action_cancel()

            return {
                'success': True,
                'message': 'تم إلغاء طلب الإجازة بنجاح'
            }

        except Exception as e:
            _logger.error("خطأ في إلغاء طلب الإجازة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/leave/check_availability', type='json', auth='user', csrf=False)
    def check_leave_availability(self, employee_id=None, holiday_status_id=None,
                                 date_from=None, date_to=None):
        """فحص توفر الإجازة قبل الإنشاء"""
        try:
            _logger.info("====== فحص توفر الإجازة ======")

            if not all([employee_id, holiday_status_id, date_from, date_to]):
                return {'available': False, 'message': 'جميع البيانات مطلوبة'}

            # التحقق من وجود تخصيص للموظف
            allocation = request.env['hr.leave.allocation'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('holiday_status_id', '=', int(holiday_status_id)),
                ('state', '=', 'validate'),
            ], limit=1)

            if not allocation:
                return {
                    'available': False,
                    'message': 'لا يوجد رصيد مخصص لهذا النوع من الإجازات'
                }

            # تحويل التواريخ
            from datetime import datetime
            try:
                date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
            except ValueError:
                return {'available': False, 'message': 'تنسيق التاريخ غير صحيح'}

            # حساب عدد الأيام
            number_of_days = (date_to_dt - date_from_dt).days + 1

            # التحقق من التداخل
            overlapping_requests = request.env['hr.leave'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('state', 'in', ['confirm', 'validate1', 'validate']),
                '|',
                '&', ('date_from', '<=', date_from_dt), ('date_to', '>=', date_from_dt),
                '&', ('date_from', '<=', date_to_dt), ('date_to', '>=', date_to_dt),
            ])

            if overlapping_requests:
                return {
                    'available': False,
                    'message': 'يتداخل مع طلب إجازة آخر موجود'
                }

            # حساب الرصيد المتبقي
            current_year = fields.Date.today().year
            approved_leaves = request.env['hr.leave'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('holiday_status_id', '=', int(holiday_status_id)),
                ('state', '=', 'validate'),
                ('date_from', '>=', f'{current_year}-01-01'),
                ('date_to', '<=', f'{current_year}-12-31')
            ])

            used_days = sum(approved_leaves.mapped('number_of_days'))
            remaining_days = allocation.number_of_days - used_days

            if remaining_days < number_of_days:
                return {
                    'available': False,
                    'message': f'الرصيد المتاح ({remaining_days} يوم) أقل من المطلوب ({number_of_days} يوم)'
                }

            return {
                'available': True,
                'message': 'الإجازة متاحة',
                'requested_days': number_of_days,
                'remaining_after': remaining_days - number_of_days
            }

        except Exception as e:
            _logger.error("خطأ في فحص توفر الإجازة: %s", str(e))
            return {
                'available': False,
                'message': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات الإعلانات (مصححة)
    # ═══════════════════════════════════════════════════════════════════════════

    def _get_employee_announcements_domain(self, employee_id):
        """
        بناء domain صحيح للإعلانات بناءً على نوع الإعلان
        """
        employee = request.env['hr.employee'].sudo().browse(employee_id)
        if not employee.exists():
            return [('id', '=', 0)]  # لا نتائج

        department_id = employee.department_id.id if employee.department_id else 0
        job_id = employee.job_id.id if employee.job_id else 0

        # Domain يجلب الإعلانات المنشورة للموظف حسب نوعها
        domain = [
            ('state', '=', 'published'),
            '|', '|', '|', '|',
            # 1. الإعلانات العامة - للجميع
            ('announcement_type', '=', 'general'),
            # 2. الإعلانات العاجلة - للجميع
            ('announcement_type', '=', 'urgent'),
            # 3. إعلانات القسم - إذا كان الموظف في القسم المستهدف
            '&',
            ('announcement_type', '=', 'department'),
            ('department_ids', 'in', [department_id] if department_id else []),
            # 4. إعلانات الوظيفة - إذا كانت وظيفة الموظف مستهدفة
            '&',
            ('announcement_type', '=', 'job'),
            ('job_ids', 'in', [job_id] if job_id else []),
            # 5. إعلانات شخصية - إذا كان الموظف مستهدف مباشرة
            '&',
            ('announcement_type', '=', 'personal'),
            ('employee_ids', 'in', [employee_id]),
        ]

        return domain

    def _get_announcement_target_count(self, announcement):
        """حساب عدد الموظفين المستهدفين"""
        try:
            if announcement.announcement_type == 'personal':
                return len(announcement.employee_ids) if announcement.employee_ids else 0
            elif announcement.announcement_type == 'department':
                if announcement.department_ids:
                    employees = request.env['hr.employee'].sudo().search([
                        ('department_id', 'in', announcement.department_ids.ids)
                    ])
                    return len(employees)
                return 0
            elif announcement.announcement_type == 'job':
                if announcement.job_ids:
                    employees = request.env['hr.employee'].sudo().search([
                        ('job_id', 'in', announcement.job_ids.ids)
                    ])
                    return len(employees)
                return 0
            else:  # general or urgent
                return request.env['hr.employee'].sudo().search_count([])
        except:
            return 1

    @http.route('/api/mobile/announcements/list', type='json', auth='user', methods=['POST'], csrf=False)
    def get_announcements(self, **kwargs):
        """جلب قائمة الإعلانات للموظف"""
        try:
            employee_id = kwargs.get('employee_id')
            limit = kwargs.get('limit', 20)
            offset = kwargs.get('offset', 0)

            _logger.info(f"📢 جلب الإعلانات للموظف: {employee_id}")

            if not employee_id:
                return {'success': False, 'error': 'Employee ID is required'}

            employee = request.env['hr.employee'].sudo().browse(int(employee_id))
            if not employee.exists():
                return {'success': False, 'error': 'Employee not found'}

            # بناء domain صحيح
            domain = self._get_employee_announcements_domain(int(employee_id))

            _logger.info(f"📢 Domain: {domain}")

            announcements = request.env['hr.announcement'].sudo().search(
                domain,
                limit=int(limit),
                offset=int(offset),
                order='is_pinned desc, priority desc, create_date desc'
            )

            _logger.info(f"📢 عدد الإعلانات: {len(announcements)}")

            result = []
            for announcement in announcements:
                # التحقق من قراءة الموظف للإعلان
                read_record = request.env['hr.announcement.read'].sudo().search([
                    ('announcement_id', '=', announcement.id),
                    ('employee_id', '=', int(employee_id))
                ], limit=1)

                # حساب العدد المستهدف
                target_count = self._get_announcement_target_count(announcement)

                result.append({
                    'id': announcement.id,
                    'title': announcement.name or '',
                    'summary': announcement.summary or '',
                    'content': announcement.content or '',
                    'type': announcement.announcement_type or 'general',
                    'priority': announcement.priority or 'normal',
                    'is_pinned': announcement.is_pinned or False,
                    'is_read': bool(read_record),
                    'created_date': announcement.create_date.isoformat() if announcement.create_date else None,
                    'author': announcement.create_uid.name if announcement.create_uid else 'Unknown',
                    'attachments': len(announcement.attachment_ids) if announcement.attachment_ids else 0,
                    'read_count': announcement.read_count or 0,
                    'target_count': target_count,
                })

            return {'success': True, 'announcements': result}

        except Exception as e:
            _logger.error(f"❌ خطأ في جلب الإعلانات: {str(e)}")
            return {'success': False, 'error': str(e)}

    @http.route('/api/mobile/announcements/detail', type='json', auth='user', methods=['POST'], csrf=False)
    def get_announcement_detail(self, announcement_id=None, employee_id=None, **kwargs):
        """جلب تفاصيل إعلان معين"""
        try:
            if not announcement_id or not employee_id:
                return {'success': False, 'error': 'announcement_id and employee_id are required'}

            announcement = request.env['hr.announcement'].sudo().browse(int(announcement_id))

            if not announcement.exists():
                return {'success': False, 'error': 'Announcement not found'}

            if announcement.state != 'published':
                return {'success': False, 'error': 'Announcement not published'}

            read_record = request.env['hr.announcement.read'].sudo().search([
                ('announcement_id', '=', int(announcement_id)),
                ('employee_id', '=', int(employee_id))
            ], limit=1)

            target_count = self._get_announcement_target_count(announcement)
            read_percentage = (announcement.read_count / target_count * 100) if target_count > 0 else 0

            return {
                'success': True,
                'announcement': {
                    'id': announcement.id,
                    'title': announcement.name or '',
                    'summary': announcement.summary or '',
                    'content': announcement.content or '',
                    'type': announcement.announcement_type or 'general',
                    'priority': announcement.priority or 'normal',
                    'is_pinned': announcement.is_pinned or False,
                    'is_read': bool(read_record),
                    'created_date': announcement.create_date.isoformat() if announcement.create_date else None,
                    'author': announcement.create_uid.name if announcement.create_uid else 'Unknown',
                    'attachments': [{
                        'id': att.id,
                        'name': att.name,
                        'url': f'/web/content/{att.id}?download=true',
                        'size': att.file_size,
                        'type': att.mimetype,
                    } for att in announcement.attachment_ids] if announcement.attachment_ids else [],
                    'read_count': announcement.read_count or 0,
                    'target_count': target_count,
                    'read_percentage': read_percentage,
                }
            }

        except Exception as e:
            _logger.error(f"❌ خطأ في جلب تفاصيل الإعلان: {str(e)}")
            return {'success': False, 'error': str(e)}

    @http.route('/api/mobile/announcements/mark_read', type='json', auth='user', methods=['POST'], csrf=False)
    def mark_announcement_read(self, announcement_id=None, employee_id=None, **kwargs):
        """تعليم الإعلان كمقروء"""
        try:
            if not announcement_id or not employee_id:
                return {'success': False, 'error': 'announcement_id and employee_id are required'}

            announcement = request.env['hr.announcement'].sudo().browse(int(announcement_id))
            if not announcement.exists():
                return {'success': False, 'error': 'Announcement not found'}

            existing = request.env['hr.announcement.read'].sudo().search([
                ('announcement_id', '=', int(announcement_id)),
                ('employee_id', '=', int(employee_id))
            ])

            if not existing:
                request.env['hr.announcement.read'].sudo().create({
                    'announcement_id': int(announcement_id),
                    'employee_id': int(employee_id),
                    'read_date': fields.Datetime.now(),
                })
                _logger.info(f"✅ الموظف {employee_id} قرأ الإعلان {announcement_id}")

            return {'success': True}

        except Exception as e:
            _logger.error(f"❌ خطأ في تعليم الإعلان كمقروء: {str(e)}")
            return {'success': False, 'error': str(e)}

    @http.route('/api/mobile/announcements/categories', type='json', auth='user', methods=['POST'], csrf=False)
    def get_announcement_categories(self, **kwargs):
        """جلب تصنيفات الإعلانات"""
        return [
            {'id': 'all', 'name': 'All', 'icon': '📢', 'color': '#2196F3'},
            {'id': 'general', 'name': 'General', 'icon': '📣', 'color': '#4CAF50'},
            {'id': 'department', 'name': 'Department', 'icon': '🏢', 'color': '#FF9800'},
            {'id': 'urgent', 'name': 'Urgent', 'icon': '🚨', 'color': '#F44336'},
            {'id': 'personal', 'name': 'Personal', 'icon': '👤', 'color': '#9C27B0'},
            {'id': 'job', 'name': 'Job', 'icon': '💼', 'color': '#2196F3'},
        ]

    @http.route('/api/mobile/announcements/search', type='json', auth='user', methods=['POST'], csrf=False)
    def search_announcements(self, employee_id=None, search_term='', category='all', limit=20, **kwargs):
        """البحث في الإعلانات"""
        try:
            _logger.info(f"🔍 البحث في الإعلانات: {search_term}, الفئة: {category}")

            if not employee_id:
                return {'success': False, 'error': 'Employee ID is required'}

            # بناء domain أساسي
            domain = self._get_employee_announcements_domain(int(employee_id))

            # إضافة شرط البحث
            if search_term:
                domain = ['&'] + domain + [
                    '|',
                    ('name', 'ilike', search_term),
                    ('summary', 'ilike', search_term)
                ]

            # إضافة فلتر الفئة
            if category and category != 'all':
                domain = ['&'] + domain + [('announcement_type', '=', category)]

            announcements = request.env['hr.announcement'].sudo().search(
                domain,
                limit=int(limit),
                order='is_pinned desc, priority desc, create_date desc'
            )

            result = []
            for announcement in announcements:
                read_record = request.env['hr.announcement.read'].sudo().search([
                    ('announcement_id', '=', announcement.id),
                    ('employee_id', '=', int(employee_id))
                ], limit=1)

                target_count = self._get_announcement_target_count(announcement)

                result.append({
                    'id': announcement.id,
                    'title': announcement.name or '',
                    'summary': announcement.summary or '',
                    'content': announcement.content or '',
                    'type': announcement.announcement_type or 'general',
                    'priority': announcement.priority or 'normal',
                    'is_pinned': announcement.is_pinned or False,
                    'is_read': bool(read_record),
                    'created_date': announcement.create_date.isoformat() if announcement.create_date else None,
                    'author': announcement.create_uid.name if announcement.create_uid else 'Unknown',
                    'attachments': len(announcement.attachment_ids) if announcement.attachment_ids else 0,
                    'read_count': announcement.read_count or 0,
                    'target_count': target_count,
                })

            return {'success': True, 'results': result}

        except Exception as e:
            _logger.error(f"❌ خطأ في البحث: {str(e)}")
            return {'success': False, 'error': str(e)}

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات الموظفين
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/employee/info', type='json', auth='user', csrf=False)
    def get_employee_info(self, employee_id=None):
        """الحصول على معلومات الموظف"""
        try:
            _logger.info("====== طلب معلومات الموظف ======")

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            employee = request.env['hr.employee'].sudo().browse(int(employee_id))

            if not employee.exists():
                return {'success': False, 'error': 'الموظف غير موجود'}

            return {
                'success': True,
                'employee': {
                    'id': employee.id,
                    'name': employee.name,
                    'job_title': employee.job_id.name if employee.job_id else '',
                    'department': employee.department_id.name if employee.department_id else '',
                    'email': employee.work_email or '',
                    'phone': employee.work_phone or '',
                    'mobile': employee.mobile_phone or '',
                    'manager_name': employee.parent_id.name if employee.parent_id else '',
                    'image': employee.image_128.decode('utf-8') if employee.image_128 else None,
                }
            }

        except Exception as e:
            _logger.error("خطأ في جلب معلومات الموظف: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/employee/login', type='json', auth='public', csrf=False)
    def employee_login(self, username=None, pin=None):
        """تسجيل دخول الموظف بالـ username و PIN"""
        try:
            if not username or not pin:
                return {'success': False, 'error': 'اسم المستخدم ورمز PIN مطلوبان'}

            # البحث عن الموظف بالاسم فقط
            employee = request.env['hr.employee'].sudo().search([
                ('mobile_username', '=', username),
                ('allow_mobile_access', '=', True),
            ], limit=1)

            if not employee:
                return {
                    'success': False,
                    'error': 'اسم المستخدم أو رمز PIN غير صحيح'
                }

            # التحقق من PIN - يدعم كلاً من التشفير والنص العادي
            pin_valid = False
            if hasattr(employee, 'verify_pin') and employee.mobile_pin_hash:
                pin_valid = employee.verify_pin(pin)
            elif employee.mobile_pin:
                pin_valid = (employee.mobile_pin == pin)

            if not pin_valid:
                return {
                    'success': False,
                    'error': 'اسم المستخدم أو رمز PIN غير صحيح'
                }

            # تحديث آخر تسجيل دخول
            employee.sudo().write({
                'mobile_last_login': fields.Datetime.now(),
                'mobile_login_count': (employee.mobile_login_count or 0) + 1,
            })

            return {
                'success': True,
                'employee': {
                    'id': employee.id,
                    'name': employee.name,
                    'job_title': employee.job_id.name if employee.job_id else '',
                    'department': employee.department_id.name if employee.department_id else '',
                    'image': employee.image_128.decode('utf-8') if employee.image_128 else None,
                }
            }

        except Exception as e:
            _logger.error("خطأ في تسجيل الدخول: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    # ═══════════════════════════════════════════════════════════════════════════
    # واجهات كشوف المرتبات (Payslips)
    # ═══════════════════════════════════════════════════════════════════════════

    @http.route('/api/mobile/payslips/list', type='json', auth='user', methods=['POST'], csrf=False)
    def get_payslips(self, employee_id=None, limit=12, offset=0, year=None, **kwargs):
        """الحصول على قائمة كشوف مرتبات الموظف"""
        try:
            _logger.info("====== طلب كشوف المرتبات للموظف %s ======", employee_id)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            # التحقق من وجود الموظف
            employee = request.env['hr.employee'].sudo().browse(int(employee_id))
            if not employee.exists():
                return {'success': False, 'error': 'الموظف غير موجود'}

            # بناء domain
            domain = [('employee_id', '=', int(employee_id))]

            # فلترة حسب السنة إذا تم تحديدها
            if year:
                domain.extend([
                    ('date_from', '>=', f'{year}-01-01'),
                    ('date_from', '<=', f'{year}-12-31'),
                ])

            # جلب كشوف المرتبات
            payslips = request.env['hr.payslip'].sudo().search(
                domain,
                order='date_from desc',
                limit=int(limit),
                offset=int(offset)
            )

            _logger.info("📋 عدد كشوف المرتبات: %s", len(payslips))

            payslips_data = []
            for payslip in payslips:
                try:
                    # حساب البدلات والخصومات
                    allowance_total = 0
                    deduction_total = 0

                    for line in payslip.line_ids:
                        if line.salary_rule_id and line.salary_rule_id.category_id:
                            if line.salary_rule_id.category_id.code == 'ALW':
                                allowance_total += line.total
                            elif line.salary_rule_id.category_id.code == 'DED':
                                deduction_total += abs(line.total)

                    # تحديد حالة الكشف
                    state_mapping = {
                        'draft': {'text': 'Draft', 'icon': '📝', 'color': '#9E9E9E'},
                        'verify': {'text': 'Waiting', 'icon': '⏳', 'color': '#FF9800'},
                        'done': {'text': 'Paid', 'icon': '✅', 'color': '#4CAF50'},
                        'cancel': {'text': 'Cancelled', 'icon': '❌', 'color': '#F44336'},
                    }

                    state_info = state_mapping.get(payslip.state, state_mapping['draft'])

                    # معلومات العملة
                    currency_name = 'EGP'
                    if payslip.company_id and payslip.company_id.currency_id:
                        currency_name = payslip.company_id.currency_id.name

                    # الحصول على الراتب الأساسي والإجمالي والصافي
                    basic_wage = 0
                    gross_wage = 0
                    net_wage = 0

                    for line in payslip.line_ids:
                        if line.salary_rule_id and line.salary_rule_id.category_id:
                            code = line.salary_rule_id.category_id.code
                            if code == 'BASIC':
                                basic_wage = line.total
                            elif code == 'GROSS':
                                gross_wage = line.total
                            elif code == 'NET':
                                net_wage = line.total

                    # إذا لم نجد القيم من البنود، استخدم الحقول المباشرة
                    if hasattr(payslip, 'basic_wage') and payslip.basic_wage:
                        basic_wage = payslip.basic_wage
                    if hasattr(payslip, 'gross_wage') and payslip.gross_wage:
                        gross_wage = payslip.gross_wage
                    if hasattr(payslip, 'net_wage') and payslip.net_wage:
                        net_wage = payslip.net_wage

                    payslips_data.append({
                        'id': payslip.id,
                        'number': payslip.number or payslip.name or f'SLIP/{payslip.id}',
                        'name': payslip.name or '',
                        'date_from': payslip.date_from.isoformat() if payslip.date_from else None,
                        'date_to': payslip.date_to.isoformat() if payslip.date_to else None,
                        'state': payslip.state,
                        'state_text': state_info['text'],
                        'state_icon': state_info['icon'],
                        'state_color': state_info['color'],
                        'basic_salary': basic_wage,
                        'gross_salary': gross_wage,
                        'net_salary': net_wage,
                        'total_allowances': allowance_total,
                        'total_deductions': deduction_total,
                        'payment_date': payslip.date_from.strftime('%Y-%m-%d') if payslip.date_from else None,
                        'currency': currency_name,
                    })
                except Exception as e:
                    _logger.error("خطأ في معالجة كشف مرتب: %s", str(e))
                    continue

            # حساب الإجمالي
            total_payslips = request.env['hr.payslip'].sudo().search_count([
                ('employee_id', '=', int(employee_id))
            ])

            return {
                'success': True,
                'payslips': payslips_data,
                'total_count': total_payslips,
                'current_count': len(payslips_data),
            }

        except Exception as e:
            _logger.error("خطأ في جلب كشوف المرتبات: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/payslips/detail', type='json', auth='user', methods=['POST'], csrf=False)
    def get_payslip_details(self, payslip_id=None, **kwargs):
        """الحصول على تفاصيل كشف مرتب محدد"""
        try:
            _logger.info("====== طلب تفاصيل كشف المرتب %s ======", payslip_id)

            if not payslip_id:
                return {'success': False, 'error': 'معرف كشف المرتب مطلوب'}

            payslip = request.env['hr.payslip'].sudo().browse(int(payslip_id))

            if not payslip.exists():
                return {'success': False, 'error': 'كشف المرتب غير موجود'}

            # تصنيف بنود الراتب
            allowances = {}
            deductions = {}
            basic_salary = 0
            gross_salary = 0
            net_salary = 0

            # معالجة البنود
            for line in payslip.line_ids:
                if not line.salary_rule_id or not line.salary_rule_id.category_id:
                    continue

                amount = line.total
                code = line.salary_rule_id.category_id.code
                rule_code = (line.salary_rule_id.code or '').lower()
                line_name = (line.name or '').lower()

                if code == 'BASIC':
                    basic_salary = amount
                elif code == 'GROSS':
                    gross_salary = amount
                elif code == 'NET':
                    net_salary = amount
                elif code == 'ALW':
                    # البدلات
                    if 'house' in rule_code or 'housing' in rule_code or 'سكن' in line_name:
                        allowances['housing_allowance'] = amount
                    elif 'transport' in rule_code or 'نقل' in line_name:
                        allowances['transportation_allowance'] = amount
                    elif 'food' in rule_code or 'طعام' in line_name or 'meal' in rule_code:
                        allowances['food_allowance'] = amount
                    elif 'phone' in rule_code or 'هاتف' in line_name or 'mobile' in rule_code:
                        allowances['phone_allowance'] = amount
                    else:
                        allowances['other_allowances'] = allowances.get('other_allowances', 0) + amount
                elif code == 'DED':
                    # الخصومات
                    amount = abs(amount)
                    if 'insurance' in rule_code or 'تأمين' in line_name or 'social' in rule_code:
                        deductions['social_insurance'] = amount
                    elif 'tax' in rule_code or 'ضريب' in line_name:
                        deductions['taxes'] = amount
                    elif 'loan' in rule_code or 'سلف' in line_name or 'قرض' in line_name:
                        deductions['loans'] = amount
                    elif 'absence' in rule_code or 'غياب' in line_name:
                        deductions['absence'] = amount
                    else:
                        deductions['other_deductions'] = deductions.get('other_deductions', 0) + amount

            # استخدام الحقول المباشرة إذا لم نجد القيم
            if hasattr(payslip, 'basic_wage') and payslip.basic_wage and not basic_salary:
                basic_salary = payslip.basic_wage
            if hasattr(payslip, 'gross_wage') and payslip.gross_wage and not gross_salary:
                gross_salary = payslip.gross_wage
            if hasattr(payslip, 'net_wage') and payslip.net_wage and not net_salary:
                net_salary = payslip.net_wage

            # حساب الإجماليات
            total_allowances = sum(allowances.values())
            total_deductions = sum(deductions.values())

            # معلومات أيام العمل
            working_days = 30
            actual_working_days = 30

            for worked_days in payslip.worked_days_line_ids:
                if worked_days.code == 'WORK100':
                    if hasattr(worked_days, 'number_of_days'):
                        working_days = int(worked_days.number_of_days or 30)
                        actual_working_days = working_days

            # معلومات البنك
            bank_account = None
            bank_name = None
            if payslip.employee_id.bank_account_id:
                bank_account = payslip.employee_id.bank_account_id.acc_number
                if payslip.employee_id.bank_account_id.bank_id:
                    bank_name = payslip.employee_id.bank_account_id.bank_id.name

            # معلومات الشركة والعملة
            company_name = payslip.company_id.name if payslip.company_id else None
            currency_name = 'EGP'
            if payslip.company_id and payslip.company_id.currency_id:
                currency_name = payslip.company_id.currency_id.name

            # حالة الكشف
            state_mapping = {
                'draft': {'text': 'Draft', 'icon': '📝', 'color': '#9E9E9E'},
                'verify': {'text': 'Waiting', 'icon': '⏳', 'color': '#FF9800'},
                'done': {'text': 'Paid', 'icon': '✅', 'color': '#4CAF50'},
                'cancel': {'text': 'Cancelled', 'icon': '❌', 'color': '#F44336'},
            }

            state_info = state_mapping.get(payslip.state, state_mapping['draft'])

            return {
                'success': True,
                'payslip': {
                    'id': payslip.id,
                    'employee_id': payslip.employee_id.id,
                    'employee_name': payslip.employee_id.name,
                    'number': payslip.number or payslip.name or f'SLIP/{payslip.id}',
                    'date_from': payslip.date_from.isoformat() if payslip.date_from else None,
                    'date_to': payslip.date_to.isoformat() if payslip.date_to else None,
                    'state': payslip.state,
                    'state_text': state_info['text'],
                    'state_icon': state_info['icon'],
                    'state_color': state_info['color'],
                    'payment_date': payslip.date_from.strftime('%Y-%m-%d') if payslip.date_from else None,
                    'basic_salary': basic_salary,
                    'gross_salary': gross_salary,
                    'net_salary': net_salary,
                    'housing_allowance': allowances.get('housing_allowance', 0),
                    'transportation_allowance': allowances.get('transportation_allowance', 0),
                    'food_allowance': allowances.get('food_allowance', 0),
                    'phone_allowance': allowances.get('phone_allowance', 0),
                    'other_allowances': allowances.get('other_allowances', 0),
                    'total_allowances': total_allowances,
                    'social_insurance': deductions.get('social_insurance', 0),
                    'taxes': deductions.get('taxes', 0),
                    'loans': deductions.get('loans', 0),
                    'absence': deductions.get('absence', 0),
                    'other_deductions': deductions.get('other_deductions', 0),
                    'total_deductions': total_deductions,
                    'notes': payslip.note if hasattr(payslip, 'note') else None,
                    'bank_name': bank_name,
                    'bank_account': bank_account,
                    'currency': currency_name,
                    'working_days': working_days,
                    'actual_working_days': actual_working_days,
                    'company_name': company_name,
                }
            }

        except Exception as e:
            _logger.error("خطأ في جلب تفاصيل كشف المرتب: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/payslips/summary', type='json', auth='user', methods=['POST'], csrf=False)
    def get_payslips_summary(self, employee_id=None, **kwargs):
        """الحصول على ملخص كشوف المرتبات"""
        try:
            _logger.info("====== طلب ملخص كشوف المرتبات للموظف %s ======", employee_id)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            # جلب كشوف المرتبات المدفوعة
            paid_payslips = request.env['hr.payslip'].sudo().search([
                ('employee_id', '=', int(employee_id)),
                ('state', '=', 'done')
            ], order='date_from desc')

            # حساب الإحصائيات
            total_net = 0
            for p in paid_payslips:
                if hasattr(p, 'net_wage') and p.net_wage:
                    total_net += p.net_wage
                else:
                    # حساب من البنود
                    for line in p.line_ids:
                        if line.salary_rule_id and line.salary_rule_id.category_id:
                            if line.salary_rule_id.category_id.code == 'NET':
                                total_net += line.total

            count = len(paid_payslips)
            average_net = total_net / count if count > 0 else 0

            # آخر دفعة
            last_payment = None
            if paid_payslips:
                last_payment = paid_payslips[0].date_from.isoformat() if paid_payslips[0].date_from else None

            # إجمالي كل الكشوف
            all_payslips = request.env['hr.payslip'].sudo().search([
                ('employee_id', '=', int(employee_id))
            ])

            return {
                'success': True,
                'summary': {
                    'total_net': total_net,
                    'average_net': average_net,
                    'last_payment': last_payment,
                    'total_count': len(all_payslips),
                    'paid_count': count,
                }
            }

        except Exception as e:
            _logger.error("خطأ في جلب ملخص كشوف المرتبات: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @http.route('/api/mobile/payslips/download', type='json', auth='user', methods=['POST'], csrf=False)
    def download_payslip_pdf(self, payslip_id=None, **kwargs):
        """تحميل كشف المرتب كملف PDF (Base64)"""
        try:
            _logger.info("====== طلب تحميل PDF لكشف المرتب %s ======", payslip_id)

            if not payslip_id:
                return {'success': False, 'error': 'معرف كشف المرتب مطلوب'}

            payslip = request.env['hr.payslip'].sudo().browse(int(payslip_id))

            if not payslip.exists():
                return {'success': False, 'error': 'كشف المرتب غير موجود'}

            # توليد PDF
            try:
                pdf_content, _ = request.env['ir.actions.report'].sudo()._render_qweb_pdf(
                    'hr_payroll.action_report_payslip', [payslip.id]
                )

                import base64
                pdf_base64 = base64.b64encode(pdf_content).decode('utf-8')

                return {
                    'success': True,
                    'pdf_data': pdf_base64,
                    'filename': f'payslip_{payslip.number or payslip.id}.pdf'
                }
            except Exception as pdf_error:
                _logger.error("خطأ في توليد PDF: %s", str(pdf_error))
                return {
                    'success': False,
                    'error': f'فشل في توليد ملف PDF: {str(pdf_error)}'
                }

        except Exception as e:
            _logger.error("خطأ في تحميل كشف المرتب: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }