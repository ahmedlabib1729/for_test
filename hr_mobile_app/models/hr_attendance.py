# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import UserError, ValidationError
from datetime import datetime, timedelta
import logging
import math
import pytz
import re
import base64

_logger = logging.getLogger(__name__)


class HrAttendance(models.Model):
    _inherit = 'hr.attendance'

    # ═══════════════════════════════════════════════════════════════════════════
    # الحقول الأساسية الموجودة
    # ═══════════════════════════════════════════════════════════════════════════

    mobile_created = fields.Boolean(
        string="Created from App",
        default=False,
        help="Indicates if the attendance record was created from the mobile app"
    )

    # حقول الموقع الجغرافي
    check_in_latitude = fields.Float(
        string="Check-in Latitude",
        digits=(10, 6),
        help="Latitude for check-in location"
    )

    check_in_longitude = fields.Float(
        string="Check-in Longitude",
        digits=(10, 6),
        help="Longitude for check-in location"
    )

    check_out_latitude = fields.Float(
        string="Check-out Latitude",
        digits=(10, 6),
        help="Latitude for check-out location"
    )

    check_out_longitude = fields.Float(
        string="Check-out Longitude",
        digits=(10, 6),
        help="Longitude for check-out location"
    )

    location_verified = fields.Boolean(
        string="Location Verified",
        default=False,
        help="Indicates if the location has been verified and is within allowed range"
    )

    check_in_distance = fields.Float(
        string="Check-in Distance (m)",
        help="Distance between employee location and office location at check-in"
    )

    check_out_distance = fields.Float(
        string="Check-out Distance (m)",
        help="Distance between employee location and office location at check-out"
    )

    # ═══════════════════════════════════════════════════════════════════════════
    # 🆕 حقول الصور الجديدة للتحقق من الوجه
    # ═══════════════════════════════════════════════════════════════════════════

    # صورة تسجيل الحضور
    check_in_photo = fields.Binary(
        string="Check-in Photo",
        attachment=True,
        help="Photo captured during check-in for face verification"
    )

    check_in_photo_filename = fields.Char(
        string="Check-in Photo Filename",
        default="checkin.jpg"
    )

    check_in_action = fields.Char(
        string="Check-in Action",
        help="The action performed for verification (smile, blinkLeft, blinkRight, turnLeft, turnRight)"
    )

    # صورة تسجيل الانصراف
    check_out_photo = fields.Binary(
        string="Check-out Photo",
        attachment=True,
        help="Photo captured during check-out for face verification"
    )

    check_out_photo_filename = fields.Char(
        string="Check-out Photo Filename",
        default="checkout.jpg"
    )

    check_out_action = fields.Char(
        string="Check-out Action",
        help="The action performed for verification (smile, blinkLeft, blinkRight, turnLeft, turnRight)"
    )

    # حقول التحقق
    face_verified = fields.Boolean(
        string="Face Verified",
        default=False,
        help="Indicates if face verification was performed"
    )

    verification_method = fields.Selection([
        ('none', 'No Verification'),
        ('face_action', 'Face Action'),
        ('fingerprint', 'Fingerprint'),
        ('pin', 'PIN Code'),
    ], string="Verification Method", default='none')

    # ═══════════════════════════════════════════════════════════════════════════
    # دوال حساب المسافة والتحقق من الموقع
    # ═══════════════════════════════════════════════════════════════════════════

    @api.model
    def _calculate_distance(self, lat1, lon1, lat2, lon2):
        """
        حساب المسافة بين نقطتين جغرافيتين باستخدام Haversine formula
        المسافة المرجعة بالأمتار
        """
        # نصف قطر الأرض بالكيلومتر
        R = 6371.0

        # تحويل من درجات إلى راديان
        lat1_rad = math.radians(lat1)
        lon1_rad = math.radians(lon1)
        lat2_rad = math.radians(lat2)
        lon2_rad = math.radians(lon2)

        # الفرق بين الإحداثيات
        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad

        # حساب Haversine
        a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        # المسافة بالكيلومتر
        distance_km = R * c

        # تحويل إلى أمتار
        distance_m = distance_km * 1000

        return distance_m

    # الحد الأدنى لحجم الصورة (5 كيلوبايت) لمنع الصور الوهمية
    MIN_PHOTO_SIZE = 5 * 1024
    # الحد الأقصى لحجم الصورة (10 ميجابايت)
    MAX_PHOTO_SIZE = 10 * 1024 * 1024

    @api.model
    def _validate_photo_data(self, photo_base64):
        """
        التحقق من صحة بيانات الصورة المرسلة على الخادم
        إرجاع tuple: (is_valid, error_message)
        """
        if not photo_base64:
            return False, 'لم يتم إرسال صورة'

        try:
            # إزالة prefix إذا وجد
            photo_data = photo_base64
            if ',' in str(photo_data):
                photo_data = photo_data.split(',')[1]

            # التحقق من صحة ترميز base64
            decoded = base64.b64decode(photo_data, validate=True)

            # التحقق من الحد الأدنى للحجم (منع الصور الوهمية/الفارغة)
            if len(decoded) < self.MIN_PHOTO_SIZE:
                _logger.warning("صورة صغيرة جداً: %s bytes", len(decoded))
                return False, 'الصورة صغيرة جداً - يرجى التقاط صورة واضحة'

            # التحقق من الحد الأقصى للحجم
            if len(decoded) > self.MAX_PHOTO_SIZE:
                return False, 'حجم الصورة كبير جداً'

            # التحقق من أن البيانات هي صورة فعلية (JPEG أو PNG)
            is_jpeg = decoded[:2] == b'\xff\xd8'
            is_png = decoded[:8] == b'\x89PNG\r\n\x1a\n'

            if not is_jpeg and not is_png:
                _logger.warning("بيانات ليست صورة صالحة (ليست JPEG أو PNG)")
                return False, 'تنسيق الصورة غير صالح'

            return True, None

        except Exception as e:
            _logger.error("خطأ في التحقق من بيانات الصورة: %s", str(e))
            return False, 'بيانات الصورة غير صالحة'

    def _verify_location(self, employee_id, latitude, longitude):
        """
        التحقق من أن الموقع ضمن النطاق المسموح للموظف
        إرجاع tuple: (is_valid, distance, office_location)
        """
        employee = self.env['hr.employee'].browse(employee_id)
        if not employee.exists():
            return False, 0, {}

        # التحقق من السماح بالعمل عن بُعد
        if employee.allow_remote_attendance:
            return True, 0, {
                'latitude': latitude,
                'longitude': longitude,
                'radius': 0,
                'remote_allowed': True
            }

        # التحقق من المواقع المؤقتة
        today = fields.Date.today()
        temp_location = employee.temporary_location_ids.filtered(
            lambda l: l.date_from <= today <= l.date_to
        )

        if temp_location:
            # استخدام أول موقع مؤقت صالح
            temp_loc = temp_location[0]
            distance = self._calculate_distance(
                latitude, longitude,
                temp_loc.latitude, temp_loc.longitude
            )
            is_valid = distance <= temp_loc.allowed_radius

            return is_valid, distance, {
                'latitude': temp_loc.latitude,
                'longitude': temp_loc.longitude,
                'radius': temp_loc.allowed_radius,
                'temporary': True,
                'reason': temp_loc.reason
            }

        # استخدام موقع المكتب المخصص للموظف
        office_location = employee.office_location_id

        # إذا لم يكن للموظف موقع مخصص، استخدم موقع القسم
        if not office_location and employee.department_id:
            office_location = employee.department_id.office_location_id

        # إذا لم يكن هناك موقع محدد، اسمح بالحضور من أي مكان
        if not office_location:
            return True, 0, {
                'latitude': latitude,
                'longitude': longitude,
                'radius': 0,
                'no_location_set': True
            }

        # حساب المسافة
        distance = self._calculate_distance(
            latitude, longitude,
            office_location.latitude, office_location.longitude
        )

        # التحقق من النطاق
        allowed_radius = office_location.allowed_radius
        if hasattr(office_location, 'allow_flexible_radius') and office_location.allow_flexible_radius:
            current_hour = fields.Datetime.now().hour
            if 7 <= current_hour <= 10 or 16 <= current_hour <= 19:
                allowed_radius = office_location.flexible_radius

        is_valid = distance <= allowed_radius

        return is_valid, distance, {
            'latitude': office_location.latitude,
            'longitude': office_location.longitude,
            'radius': allowed_radius,
            'location_name': office_location.name,
            'location_id': office_location.id
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # دوال حالة الحضور
    # ═══════════════════════════════════════════════════════════════════════════

    @api.model
    def get_employee_attendance_status(self, employee_id):
        """الحصول على حالة الحضور الحالية للموظف"""
        if not employee_id or not isinstance(employee_id, int):
            return {'is_checked_in': False, 'check_in': None, 'attendance_id': None}

        employee = self.env['hr.employee'].browse(employee_id)
        if not employee.exists():
            return {'is_checked_in': False, 'check_in': None, 'attendance_id': None}

        # التحقق مما إذا كان الموظف قد سجل حضوره بالفعل ولم يسجل انصرافه
        attendance = self.search([
            ('employee_id', '=', employee_id),
            ('check_out', '=', False)
        ], limit=1)

        if attendance:
            return {
                'is_checked_in': True,
                'check_in': attendance.check_in.isoformat() + 'Z',
                'attendance_id': attendance.id,
            }

        return {
            'is_checked_in': False,
            'check_in': None,
            'attendance_id': None,
        }

    @api.model
    def get_employee_attendance_history(self, employee_id, limit=10):
        """الحصول على سجل الحضور السابق للموظف"""
        if not employee_id:
            return []

        attendances = self.search([
            ('employee_id', '=', employee_id)
        ], order='check_in desc', limit=limit)

        history = []
        for att in attendances:
            duration = ''
            if att.check_in and att.check_out:
                delta = att.check_out - att.check_in
                hours = int(delta.total_seconds() // 3600)
                minutes = int((delta.total_seconds() % 3600) // 60)
                duration = f"{hours}:{minutes:02d}"

            history.append({
                'id': att.id,
                'date': att.check_in.strftime('%Y-%m-%d') if att.check_in else '',
                'check_in': att.check_in.isoformat() + 'Z' if att.check_in else None,
                'check_out': att.check_out.isoformat() + 'Z' if att.check_out else None,
                'duration': duration,
                'location_verified': att.location_verified,
                'face_verified': att.face_verified,
            })

        return history

    @api.model
    def get_employee_attendance_summary(self, employee_id):
        """الحصول على ملخص الحضور اليومي للموظف"""
        if not employee_id or not isinstance(employee_id, int):
            return {'work_hours': '0:00', 'request_count': 0}

        employee = self.env['hr.employee'].browse(employee_id)
        if not employee.exists():
            return {'work_hours': '0:00', 'request_count': 0}

        today = fields.Date.today()
        today_start = fields.Datetime.to_string(datetime.combine(today, datetime.min.time()))

        domain = [
            ('employee_id', '=', employee_id),
            ('check_in', '>=', today_start),
        ]

        completed_attendances = self.search(domain + [('check_out', '!=', False)])
        open_attendance = self.search(domain + [('check_out', '=', False)], limit=1)

        total_worked_hours = 0.0

        for att in completed_attendances:
            if att.check_in and att.check_out:
                delta = att.check_out - att.check_in
                total_worked_hours += delta.total_seconds() / 3600.0

        if open_attendance and open_attendance.check_in:
            delta = fields.Datetime.now() - open_attendance.check_in
            total_worked_hours += delta.total_seconds() / 3600.0

        hours = int(total_worked_hours)
        minutes = int((total_worked_hours - hours) * 60)

        return {
            'work_hours': f"{hours}:{minutes:02d}",
            'request_count': len(completed_attendances) + (1 if open_attendance else 0)
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # دوال الحضور والانصراف الأصلية (بدون صور)
    # ═══════════════════════════════════════════════════════════════════════════

    @api.model
    def mobile_check_in(self, employee_id, latitude=None, longitude=None):
        """تسجيل حضور من التطبيق المحمول مع التحقق من الموقع"""
        if not employee_id:
            return {'success': False, 'error': 'معرف الموظف غير صالح'}

        employee = self.env['hr.employee'].browse(employee_id)
        if not employee.exists():
            return {'success': False, 'error': 'الموظف غير موجود'}

        open_attendance = self.search([
            ('employee_id', '=', employee_id),
            ('check_out', '=', False),
        ], limit=1)

        if open_attendance:
            return {
                'success': False,
                'error': 'يوجد بالفعل سجل حضور مفتوح لهذا الموظف'
            }

        location_verified = False
        distance = 0

        if latitude is not None and longitude is not None:
            is_valid, distance, office_location = self._verify_location(
                employee_id, latitude, longitude
            )

            if not is_valid:
                return {
                    'success': False,
                    'error': f'موقعك الحالي بعيد عن مكان العمل. المسافة: {distance:.0f} متر',
                    'distance': distance,
                    'allowed_radius': office_location.get('radius', 0),
                    'office_location': office_location
                }

            location_verified = True

        try:
            now = fields.Datetime.now()

            attendance_vals = {
                'employee_id': employee_id,
                'check_in': now,
                'mobile_created': True,
            }

            if latitude is not None and longitude is not None:
                attendance_vals.update({
                    'check_in_latitude': latitude,
                    'check_in_longitude': longitude,
                    'location_verified': location_verified,
                    'check_in_distance': distance
                })

            attendance = self.create(attendance_vals)

            _logger.info(f"تم إنشاء سجل حضور جديد بنجاح للموظف {employee.name}")

            return {
                'success': True,
                'attendance_id': attendance.id,
                'location_verified': location_verified,
                'distance': distance
            }
        except Exception as e:
            _logger.error(f"خطأ أثناء إنشاء سجل حضور للموظف {employee.name}: {str(e)}")
            return {
                'success': False,
                'error': str(e),
            }

    @api.model
    def mobile_check_out(self, employee_id, latitude=None, longitude=None):
        """تسجيل انصراف من التطبيق المحمول مع التحقق من الموقع"""
        if not employee_id:
            return {'success': False, 'error': 'معرف الموظف غير صالح'}

        attendance = self.search([
            ('employee_id', '=', employee_id),
            ('check_out', '=', False),
        ], limit=1)

        if not attendance:
            return {
                'success': False,
                'error': 'لا يوجد سجل حضور مفتوح للموظف'
            }

        location_verified = False
        distance = 0

        if latitude is not None and longitude is not None:
            is_valid, distance, office_location = self._verify_location(
                employee_id, latitude, longitude
            )

            if not is_valid:
                return {
                    'success': False,
                    'error': f'موقعك الحالي بعيد عن مكان العمل. المسافة: {distance:.0f} متر',
                    'distance': distance,
                    'allowed_radius': office_location.get('radius', 0),
                    'office_location': office_location
                }

            location_verified = True

        try:
            now = fields.Datetime.now()

            update_vals = {
                'check_out': now,
            }

            if latitude is not None and longitude is not None:
                update_vals.update({
                    'check_out_latitude': latitude,
                    'check_out_longitude': longitude,
                    'check_out_distance': distance
                })

                if attendance.location_verified:
                    update_vals['location_verified'] = location_verified

            attendance.write(update_vals)

            duration = (attendance.check_out - attendance.check_in).total_seconds() / 3600.0
            hours = int(duration)
            minutes = int((duration - hours) * 60)
            duration_str = f"{hours}:{minutes:02d}"

            _logger.info(f"تم تسجيل الانصراف بنجاح للموظف {attendance.employee_id.name}")

            return {
                'success': True,
                'duration': duration_str,
                'location_verified': location_verified,
                'distance': distance
            }
        except Exception as e:
            _logger.error(f"خطأ أثناء تسجيل انصراف الموظف: {str(e)}")
            return {
                'success': False,
                'error': str(e),
            }

    @api.model
    def check_location_before_attendance(self, employee_id, latitude, longitude):
        """التحقق من الموقع قبل السماح بتسجيل الحضور/الانصراف"""
        if not employee_id:
            return {'success': False, 'error': 'معرف الموظف غير صالح'}

        employee = self.env['hr.employee'].browse(employee_id)
        if not employee.exists():
            return {'success': False, 'error': 'الموظف غير موجود'}

        is_valid, distance, office_location = self._verify_location(
            employee_id, latitude, longitude
        )

        return {
            'success': True,
            'location_valid': is_valid,
            'distance': distance,
            'allowed_radius': office_location.get('radius', 0),
            'office_location': office_location,
            'message': 'موقعك ضمن النطاق المسموح' if is_valid else f'موقعك بعيد {distance:.0f} متر عن مكان العمل'
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # 🆕 دوال الحضور والانصراف مع الصور (الجديدة)
    # ═══════════════════════════════════════════════════════════════════════════

    @api.model
    def mobile_check_in_with_photo(self, employee_id, latitude=None, longitude=None,
                                   photo_base64=None, action_performed=None):
        """تسجيل حضور مع صورة التحقق من الوجه"""
        try:
            _logger.info("=" * 60)
            _logger.info("📸 تسجيل حضور مع صورة للموظف: %s", employee_id)
            _logger.info("📍 الإحداثيات: %s, %s", latitude, longitude)
            _logger.info("🎭 الحركة: %s", action_performed)
            _logger.info("=" * 60)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            # التحقق من وجود الموظف
            employee = self.env['hr.employee'].browse(int(employee_id))
            if not employee.exists():
                return {'success': False, 'error': 'الموظف غير موجود'}

            # التحقق من عدم وجود حضور مفتوح
            open_attendance = self.search([
                ('employee_id', '=', int(employee_id)),
                ('check_out', '=', False),
            ], limit=1)

            if open_attendance:
                return {
                    'success': False,
                    'error': 'يوجد بالفعل سجل حضور مفتوح لهذا الموظف'
                }

            # التحقق من صحة الصورة على الخادم
            photo_valid = False
            if photo_base64:
                photo_valid, photo_error = self._validate_photo_data(photo_base64)
                if not photo_valid:
                    return {'success': False, 'error': photo_error}

            # التحقق من الموقع
            location_verified = False
            distance = 0

            if latitude is not None and longitude is not None:
                is_valid, distance, office_location = self._verify_location(
                    int(employee_id), float(latitude), float(longitude)
                )

                if not is_valid:
                    return {
                        'success': False,
                        'error': f'موقعك الحالي بعيد عن مكان العمل. المسافة: {distance:.0f} متر',
                        'distance': distance,
                        'allowed_radius': office_location.get('radius', 0),
                    }

                location_verified = True

            # تحضير بيانات الحضور
            attendance_vals = {
                'employee_id': int(employee_id),
                'check_in': fields.Datetime.now(),
                'mobile_created': True,
                'face_verified': photo_valid,
                'verification_method': 'face_action' if photo_valid else 'none',
            }

            # إضافة إحداثيات الموقع
            if latitude is not None and longitude is not None:
                attendance_vals.update({
                    'check_in_latitude': float(latitude),
                    'check_in_longitude': float(longitude),
                    'location_verified': location_verified,
                    'check_in_distance': distance,
                })

            # إضافة الصورة
            if photo_base64:
                # إزالة prefix إذا وجد (data:image/jpeg;base64,)
                if ',' in str(photo_base64):
                    photo_base64 = photo_base64.split(',')[1]

                attendance_vals.update({
                    'check_in_photo': photo_base64,
                    'check_in_photo_filename': f'checkin_{employee_id}_{fields.Datetime.now().strftime("%Y%m%d_%H%M%S")}.jpg',
                    'check_in_action': action_performed or 'unknown',
                })

            # إنشاء سجل الحضور
            attendance = self.create(attendance_vals)

            _logger.info("✅ تم إنشاء سجل حضور بنجاح: ID=%s", attendance.id)

            return {
                'success': True,
                'attendance_id': attendance.id,
                'message': 'تم تسجيل الحضور بنجاح',
                'check_in': attendance.check_in.isoformat() + 'Z',
                'location_verified': attendance.location_verified,
                'photo_saved': bool(attendance.check_in_photo),
                'face_verified': attendance.face_verified,
            }

        except Exception as e:
            _logger.error("❌ خطأ في تسجيل الحضور مع الصورة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    @api.model
    def mobile_check_out_with_photo(self, employee_id, latitude=None, longitude=None,
                                    photo_base64=None, action_performed=None):
        """تسجيل انصراف مع صورة التحقق من الوجه"""
        try:
            _logger.info("=" * 60)
            _logger.info("📸 تسجيل انصراف مع صورة للموظف: %s", employee_id)
            _logger.info("📍 الإحداثيات: %s, %s", latitude, longitude)
            _logger.info("🎭 الحركة: %s", action_performed)
            _logger.info("=" * 60)

            if not employee_id:
                return {'success': False, 'error': 'معرف الموظف مطلوب'}

            # البحث عن سجل حضور مفتوح
            attendance = self.search([
                ('employee_id', '=', int(employee_id)),
                ('check_out', '=', False),
            ], limit=1, order='check_in desc')

            if not attendance:
                return {
                    'success': False,
                    'error': 'لا يوجد سجل حضور مفتوح لهذا الموظف'
                }

            # التحقق من صحة الصورة على الخادم
            photo_valid = False
            if photo_base64:
                photo_valid, photo_error = self._validate_photo_data(photo_base64)
                if not photo_valid:
                    return {'success': False, 'error': photo_error}

            # التحقق من الموقع
            location_verified = False
            distance = 0

            if latitude is not None and longitude is not None:
                is_valid, distance, office_location = self._verify_location(
                    int(employee_id), float(latitude), float(longitude)
                )

                if not is_valid:
                    return {
                        'success': False,
                        'error': f'موقعك الحالي بعيد عن مكان العمل. المسافة: {distance:.0f} متر',
                        'distance': distance,
                        'allowed_radius': office_location.get('radius', 0),
                    }

                location_verified = True

            # تحضير بيانات التحديث
            update_vals = {
                'check_out': fields.Datetime.now(),
            }

            # إضافة إحداثيات الموقع
            if latitude is not None and longitude is not None:
                update_vals.update({
                    'check_out_latitude': float(latitude),
                    'check_out_longitude': float(longitude),
                    'check_out_distance': distance,
                })

            # إضافة الصورة (تم التحقق منها مسبقاً)
            if photo_valid and photo_base64:
                # إزالة prefix إذا وجد
                clean_photo = photo_base64
                if ',' in str(clean_photo):
                    clean_photo = clean_photo.split(',')[1]

                update_vals.update({
                    'check_out_photo': clean_photo,
                    'check_out_photo_filename': f'checkout_{employee_id}_{fields.Datetime.now().strftime("%Y%m%d_%H%M%S")}.jpg',
                    'check_out_action': action_performed or 'unknown',
                    'face_verified': True,
                })

            # تحديث سجل الحضور
            attendance.write(update_vals)

            # حساب مدة العمل
            check_in = attendance.check_in
            check_out = attendance.check_out
            duration = (check_out - check_in).total_seconds() / 3600.0
            hours = int(duration)
            minutes = int((duration - hours) * 60)
            duration_str = f"{hours}:{minutes:02d}"

            _logger.info("✅ تم تسجيل الانصراف بنجاح: ID=%s, المدة=%s", attendance.id, duration_str)

            return {
                'success': True,
                'attendance_id': attendance.id,
                'duration': duration_str,
                'message': 'تم تسجيل الانصراف بنجاح',
                'check_out': attendance.check_out.isoformat() + 'Z',
                'photo_saved': bool(attendance.check_out_photo),
                'face_verified': attendance.face_verified,
            }

        except Exception as e:
            _logger.error("❌ خطأ في تسجيل الانصراف مع الصورة: %s", str(e))
            return {
                'success': False,
                'error': str(e)
            }

    def get_attendance_photos(self):
        """الحصول على صور الحضور والانصراف"""
        self.ensure_one()
        return {
            'check_in_photo': self.check_in_photo,
            'check_in_action': self.check_in_action,
            'check_out_photo': self.check_out_photo,
            'check_out_action': self.check_out_action,
            'face_verified': self.face_verified,
            'verification_method': self.verification_method,
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # دوال إضافية للتوافقية
    # ═══════════════════════════════════════════════════════════════════════════

    @api.model
    def create_mobile_attendance(self, employee_id):
        """إنشاء سجل حضور جديد من التطبيق المحمول (للتوافقية)"""
        return self.mobile_check_in(employee_id)

    @api.model
    def update_mobile_attendance_checkout(self, attendance_id):
        """تحديث سجل حضور بوقت الانصراف من التطبيق المحمول"""
        if not attendance_id or not isinstance(attendance_id, int):
            return {'success': False, 'error': 'معرف سجل الحضور غير صالح'}

        attendance = self.browse(attendance_id)
        if not attendance.exists():
            return {'success': False, 'error': 'سجل الحضور غير موجود'}

        if attendance.check_out:
            return {
                'success': False,
                'error': 'تم تسجيل وقت الانصراف بالفعل لهذا السجل'
            }

        try:
            attendance.write({
                'check_out': fields.Datetime.now(),
            })

            duration = (attendance.check_out - attendance.check_in).total_seconds() / 3600.0
            hours = int(duration)
            minutes = int((duration - hours) * 60)
            duration_str = f"{hours}:{minutes:02d}"

            return {
                'success': True,
                'duration': duration_str,
            }
        except Exception as e:
            _logger.error(f"خطأ أثناء تحديث سجل الحضور: {str(e)}")
            return {
                'success': False,
                'error': str(e),
            }