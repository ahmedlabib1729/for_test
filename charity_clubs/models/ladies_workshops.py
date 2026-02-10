# -*- coding: utf-8 -*-

from odoo import models, fields, api
from odoo.exceptions import ValidationError


class LadiesWorkshop(models.Model):
    _name = 'charity.ladies.workshop'
    _description = 'ورش السيدات'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'name'
    _order = 'department_id, sequence, name'

    # الحقول الأساسية
    name = fields.Char(
        string='اسم الورشة',
        required=True,
        tracking=True,
        help='أدخل اسم الورشة'
    )

    department_id = fields.Many2one(
        'charity.departments',
        string='القسم',
        required=True,
        ondelete='cascade',
        domain=[('type', '=', 'ladies')],
        tracking=True,
        help='القسم التابع له الورشة'
    )

    # الموعد
    schedule = fields.Text(
        string='موعد الورشة',
        required=True,
        help='موعد الورشة'
    )

    # ⭐ جديد: هل الورشة مجانية
    is_free = fields.Boolean(
        string='ورشة مجانية',
        default=False,
        tracking=True,
        help='حدد إذا كانت الورشة مجانية أم بسعر'
    )

    # السعر - أصبح اختياري
    price = fields.Float(
        string='سعر الورشة',
        digits=(10, 2),
        tracking=True,
        help='سعر الورشة (إجباري للورش المدفوعة فقط)'
    )

    # معلومات إضافية
    max_capacity = fields.Integer(
        string='عدد المقاعد',
        default=20,
        required=True,
        help='العدد الأقصى للمشتركات'
    )

    sequence = fields.Integer(
        string='الترتيب',
        default=10
    )

    active = fields.Boolean(
        string='نشط',
        default=True
    )

    is_active = fields.Boolean(
        string='مفعلة',
        default=True,
        tracking=True,
        help='هل الورشة مفتوحة للتسجيل'
    )

    company_id = fields.Many2one(
        'res.company',
        string='الشركة',
        related='department_id.company_id',
        store=True,
        readonly=True
    )

    # الإحصائيات
    enrollment_ids = fields.One2many(
        'charity.booking.registrations',
        'workshop_id',
        string='التسجيلات',
        domain=[('state', '!=', 'cancelled')]
    )

    enrollments_count = fields.Integer(
        string='عدد المشتركات',
        compute='_compute_enrollments_count'
    )

    available_seats = fields.Integer(
        string='المقاعد المتاحة',
        compute='_compute_available_seats'
    )

    # ⭐ جديد: هل يمكن تغيير نوع التسعير
    can_change_pricing = fields.Boolean(
        string='يمكن تغيير السعر',
        compute='_compute_can_change_pricing',
        help='يمكن تغيير نوع التسعير فقط إذا لم يكن هناك حجوزات'
    )

    @api.depends('enrollment_ids')
    def _compute_can_change_pricing(self):
        """تحديد إمكانية تغيير نوع التسعير"""
        for record in self:
            # يمكن التغيير فقط إذا لم يكن هناك حجوزات نشطة
            active_bookings = record.enrollment_ids.filtered(
                lambda b: b.state not in ['cancelled', 'rejected']
            )
            record.can_change_pricing = len(active_bookings) == 0

    @api.depends('enrollment_ids')
    def _compute_enrollments_count(self):
        """حساب عدد المشتركات"""
        for record in self:
            record.enrollments_count = len(record.enrollment_ids.filtered(
                lambda r: r.state in ['confirmed', 'approved']
            ))

    @api.depends('enrollments_count', 'max_capacity')
    def _compute_available_seats(self):
        """حساب المقاعد المتاحة"""
        for record in self:
            record.available_seats = record.max_capacity - record.enrollments_count

    @api.constrains('max_capacity')
    def _check_capacity(self):
        """التحقق من السعة"""
        for record in self:
            if record.max_capacity <= 0:
                raise ValidationError('عدد المقاعد يجب أن يكون أكبر من صفر!')

    # ⭐ تعديل: التحقق من السعر
    @api.constrains('price', 'is_free')
    def _check_price(self):
        """التحقق من السعر حسب نوع الورشة"""
        for record in self:
            if not record.is_free:  # إذا كانت الورشة بسعر
                if not record.price or record.price <= 0:
                    raise ValidationError(
                        'يجب تحديد سعر أكبر من صفر للورش المدفوعة!\n'
                        'أو حدد الورشة كـ "مجانية" إذا كانت بدون رسوم.'
                    )

    # ⭐ جديد: منع تغيير نوع التسعير بعد الحجوزات
    @api.constrains('is_free')
    def _check_cannot_change_free_status(self):
        """منع تغيير حالة المجانية إذا كان هناك حجوزات نشطة"""
        for record in self:
            if not record._origin:  # سجل جديد
                continue

            # الحصول على القيمة القديمة
            old_is_free = record._origin.is_free

            # التحقق من وجود حجوزات نشطة
            active_bookings = record.enrollment_ids.filtered(
                lambda b: b.state not in ['cancelled', 'rejected']
            )

            if active_bookings and old_is_free != record.is_free:
                status_change = 'من مجانية إلى مدفوعة' if old_is_free else 'من مدفوعة إلى مجانية'
                raise ValidationError(
                    f'⚠️ لا يمكن تغيير نوع الورشة {status_change}!\n\n'
                    f'السبب: يوجد {len(active_bookings)} حجز نشط على هذه الورشة.\n'
                    f'يجب إلغاء جميع الحجوزات أولاً قبل تغيير نوع التسعير.'
                )

    # ⭐ جديد: onchange للسعر
    @api.onchange('is_free')
    def _onchange_is_free(self):
        """مسح السعر تلقائياً عند اختيار مجاني"""
        if self.is_free:
            self.price = 0.0

    def name_get(self):
        """تخصيص طريقة عرض اسم الورشة"""
        result = []
        for record in self:
            name = record.name
            if record.department_id:
                name = f"{record.department_id.name} / {name}"
            # ⭐ إضافة علامة "مجاني" للورش المجانية
            if record.is_free:
                name = f"{name} (مجاني)"
            result.append((record.id, name))
        return result

    def action_view_enrollments(self):
        """عرض المشتركات في الورشة"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': f'مشتركات {self.name}',
            'view_mode': 'list,form',
            'res_model': 'charity.booking.registrations',
            'domain': [('workshop_id', '=', self.id)],
            'context': {
                'default_workshop_id': self.id,
                'default_department_id': self.department_id.id,
                'default_booking_mode': 'workshop'
            }
        }