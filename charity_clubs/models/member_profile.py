# -*- coding: utf-8 -*-

from odoo import models, fields, api
from odoo.exceptions import ValidationError
from datetime import date
from dateutil.relativedelta import relativedelta
import re

import logging
_logger = logging.getLogger(__name__)


class MemberProfile(models.Model):
    _name = 'charity.member.profile'
    _description = 'ملف العضوة'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'full_name'
    _order = 'member_number desc'




    # رقم العضوية
    member_number = fields.Char(
        string='رقم العضوية',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: 'جديد',
        tracking=True
    )

    # معلومات العضوة الأساسية
    full_name = fields.Char(
        string='الاسم الثلاثي باللغة العربية',
        required=True,
        tracking=True,
        help='أدخل الاسم الثلاثي'
    )

    birth_date = fields.Date(
        string='تاريخ الميلاد',
        required=True,
        tracking=True,
        help='تاريخ الميلاد'
    )

    age = fields.Integer(
        string='العمر',
        compute='_compute_age',
        store=True,
        help='العمر المحسوب من تاريخ الميلاد'
    )

    # صفة السيدة - الحقل الجديد
    lady_type = fields.Selection([
        ('pioneer', 'رائدة'),
        ('volunteer', 'متطوعة'),
        ('member', 'عضوة')
    ], string='صفة السيدة',
        required=True,
        default='member',
        tracking=True,
        help='اختر صفة السيدة'
    )

    # معلومات التواصل
    mobile = fields.Char(
        string='رقم التواصل',
        required=True,
        tracking=True,
        help='رقم الهاتف للتواصل'
    )

    whatsapp = fields.Char(
        string='رقم الواتساب',
        required=True,
        help='رقم الواتساب للتواصل'
    )

    email = fields.Char(
        string='البريد الإلكتروني',
        help='البريد الإلكتروني للتواصل'
    )

    emirates_id = fields.Char(
        string='رقم الهوية الإماراتية',
        tracking=True,
        help='رقم الهوية بالصيغة: 784-YYYY-XXXXXXX-X'
    )

    # صفة السيدة
    lady_type = fields.Selection([
        ('pioneer', 'رائدة'),
        ('volunteer', 'متطوعة'),
        ('member', 'عضوة')
    ], string='صفة السيدة',
        required=True,
        default='member',
        tracking=True,
        help='اختر صفة السيدة'
    )

    # معلومات إضافية
    nationality = fields.Many2one(
        'res.country',
        string='الجنسية',
        help='جنسية العضوة'
    )

    address = fields.Text(
        string='العنوان',
        help='عنوان السكن'
    )

    # حالة العضوية
    membership_status = fields.Selection([
        ('active', 'نشطة'),
        ('inactive', 'غير نشطة'),
        ('suspended', 'موقوفة')
    ], string='حالة العضوية',
        default='active',
        tracking=True,
        compute='_compute_membership_status',
        store=True
    )

    # تواريخ مهمة
    registration_date = fields.Date(
        string='تاريخ التسجيل',
        default=fields.Date.today,
        readonly=True,
        tracking=True
    )

    last_subscription_date = fields.Date(
        string='تاريخ آخر اشتراك',
        compute='_compute_subscription_info',
        store=True
    )

    current_subscription_end = fields.Date(
        string='تاريخ انتهاء الاشتراك الحالي',
        compute='_compute_subscription_info',
        store=True
    )

    # معلومات النظام
    active = fields.Boolean(
        string='نشط',
        default=True,
        help='إذا تم إلغاء التحديد، سيتم أرشفة العضوة'
    )

    company_id = fields.Many2one(
        'res.company',
        string='الشركة',
        default=lambda self: self.env.company,
        required=True
    )

    # العلاقات
    subscription_ids = fields.One2many(
        'charity.member.subscription',
        'member_id',
        string='الاشتراكات',
        help='جميع الاشتراكات الخاصة بالعضوة'
    )

    subscriptions_count = fields.Integer(
        string='عدد الاشتراكات',
        compute='_compute_subscriptions_count',
        help='عدد الاشتراكات الكلي'
    )

    active_subscription_count = fields.Integer(
        string='الاشتراكات النشطة',
        compute='_compute_subscriptions_count',
        help='عدد الاشتراكات النشطة حالياً'
    )

    id_card_file = fields.Binary(
        string='صورة الهوية',
        attachment=True,
        help='صورة الهوية'
    )

    id_card_filename = fields.Char(
        string='اسم ملف الهوية'
    )

    passport_file = fields.Binary(
        string='صورة الباسبور',
        attachment=True,
        help='صورة جواز السفر'
    )

    passport_filename = fields.Char(
        string='اسم ملف الباسبور'
    )

    residence_file = fields.Binary(
        string='صورة الإقامة',
        attachment=True,
        help='صورة الإقامة'
    )

    residence_filename = fields.Char(
        string='اسم ملف الإقامة'
    )

    workshop_subscription_ids = fields.One2many(
        'charity.member.subscription',
        'member_id',
        string='اشتراكات الورش',
        domain=[('is_workshop', '=', True)],
        help='اشتراكات الورش الخاصة بالعضوة'
    )

    program_subscription_ids = fields.One2many(
        'charity.member.subscription',
        'member_id',
        string='اشتراكات البرامج',
        domain=[('is_workshop', '=', False)],
        help='اشتراكات البرامج الخاصة بالعضوة'
    )

    workshop_subscriptions_count = fields.Integer(
        string='عدد اشتراكات الورش',
        compute='_compute_subscriptions_details',
        help='عدد اشتراكات الورش'
    )

    program_subscriptions_count = fields.Integer(
        string='عدد اشتراكات البرامج',
        compute='_compute_subscriptions_details',
        help='عدد اشتراكات البرامج'
    )

    @api.depends('subscription_ids', 'subscription_ids.is_workshop')
    def _compute_subscriptions_details(self):
        """حساب تفاصيل الاشتراكات"""
        for record in self:
            workshop_subs = record.subscription_ids.filtered(lambda s: s.is_workshop)
            program_subs = record.subscription_ids.filtered(lambda s: not s.is_workshop)

            record.workshop_subscriptions_count = len(workshop_subs)
            record.program_subscriptions_count = len(program_subs)


    @api.model
    def create(self, vals):
        """إنشاء رقم عضوية تلقائي"""
        if vals.get('member_number', 'جديد') == 'جديد':
            vals['member_number'] = self.env['ir.sequence'].next_by_code('charity.member.profile') or 'جديد'
        return super(MemberProfile, self).create(vals)

    @api.depends('birth_date')
    def _compute_age(self):
        """حساب العمر من تاريخ الميلاد"""
        today = date.today()
        for record in self:
            if record.birth_date:
                age = relativedelta(today, record.birth_date)
                record.age = age.years
            else:
                record.age = 0

    @api.depends('subscription_ids', 'subscription_ids.state', 'subscription_ids.end_date')
    def _compute_membership_status(self):
        """حساب حالة العضوية بناءً على الاشتراكات"""
        today = fields.Date.today()
        for record in self:
            active_subs = record.subscription_ids.filtered(
                lambda s: s.state == 'active' and s.end_date >= today
            )
            if active_subs:
                record.membership_status = 'active'
            else:
                record.membership_status = 'inactive'

    @api.depends('subscription_ids', 'subscription_ids.state', 'subscription_ids.start_date',
                 'subscription_ids.end_date')
    def _compute_subscription_info(self):
        """حساب معلومات الاشتراك"""
        for record in self:
            subscriptions = record.subscription_ids.sorted('start_date', reverse=True)
            if subscriptions:
                record.last_subscription_date = subscriptions[0].start_date
                active_sub = subscriptions.filtered(lambda s: s.state == 'active')
                if active_sub:
                    record.current_subscription_end = active_sub[0].end_date
                else:
                    record.current_subscription_end = False
            else:
                record.last_subscription_date = False
                record.current_subscription_end = False

    @api.depends('subscription_ids')
    def _compute_subscriptions_count(self):
        """حساب عدد الاشتراكات"""
        today = fields.Date.today()
        for record in self:
            record.subscriptions_count = len(record.subscription_ids)
            record.active_subscription_count = len(
                record.subscription_ids.filtered(
                    lambda s: s.state == 'active' and s.end_date >= today
                )
            )

    @api.constrains('mobile', 'whatsapp')
    def _check_phone_numbers(self):
        """التحقق من صحة أرقام الهواتف"""
        phone_pattern = re.compile(r'^[\d\s\-\+]+$')
        for record in self:
            if record.mobile and not phone_pattern.match(record.mobile):
                raise ValidationError('رقم التواصل غير صحيح!')
            if record.whatsapp and not phone_pattern.match(record.whatsapp):
                raise ValidationError('رقم الواتساب غير صحيح!')

    @api.constrains('email')
    def _check_email(self):
        """التحقق من صحة البريد الإلكتروني"""
        email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        for record in self:
            if record.email and not email_pattern.match(record.email):
                raise ValidationError('البريد الإلكتروني غير صحيح!')

    @api.constrains('birth_date')
    def _check_birth_date(self):
        """التحقق من صحة تاريخ الميلاد"""
        for record in self:
            if record.birth_date:
                if record.birth_date > date.today():
                    raise ValidationError('تاريخ الميلاد لا يمكن أن يكون في المستقبل!')

    def action_view_subscriptions(self):
        """عرض اشتراكات العضوة"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': f'اشتراكات {self.full_name}',
            'view_mode': 'list,form',
            'res_model': 'charity.member.subscription',
            'domain': [('member_id', '=', self.id)],
            'context': {
                'default_member_id': self.id,
                'default_department_id': self._context.get('department_id')
            }
        }

    def action_create_subscription(self):
        """إنشاء اشتراك جديد"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': 'اشتراك جديد',
            'view_mode': 'form',
            'res_model': 'charity.member.subscription',
            'target': 'new',
            'context': {
                'default_member_id': self.id,
                'default_department_id': self._context.get('department_id')
            }
        }

    def name_get(self):
        """تخصيص طريقة عرض اسم العضوة"""
        result = []
        for record in self:
            name = f"{record.full_name} - {record.member_number}"
            result.append((record.id, name))
        return result

    @api.model
    def _name_search(self, name, args=None, operator='ilike', limit=100):
        """البحث في العضوات بالاسم أو رقم العضوية أو رقم الهاتف"""
        args = args or []
        if name:
            args = ['|', '|', '|',
                    ('full_name', operator, name),
                    ('member_number', operator, name),
                    ('mobile', operator, name),
                    ('whatsapp', operator, name)] + args
        return self._search(args, limit=limit)

    def action_view_program_subscriptions(self):
        """عرض اشتراكات البرامج"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': f'اشتراكات برامج {self.full_name}',
            'view_mode': 'list,form',
            'res_model': 'charity.member.subscription',
            'domain': [
                ('member_id', '=', self.id),
                ('workshop_id', '=', False)  # تغيير هنا
            ],
            'context': {
                'default_member_id': self.id,
            }
        }

    def action_view_workshop_subscriptions(self):
        """عرض اشتراكات الورش"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': f'اشتراكات ورش {self.full_name}',
            'view_mode': 'list,form',
            'res_model': 'charity.member.subscription',
            'domain': [
                ('member_id', '=', self.id),
                ('workshop_id', '!=', False)  # تغيير هنا
            ],
            'context': {
                'default_member_id': self.id,
            }
        }

    def action_print_member_certificate(self):
        """زر طباعة الشهادة"""
        self.ensure_one()
        return self.env.ref('charity_clubs.action_report_member_certificate').report_action(self)

class MemberSubscription(models.Model):
    _name = 'charity.member.subscription'
    _description = 'اشتراكات العضوات'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'subscription_number'
    _order = 'start_date desc'

    # رقم الاشتراك
    subscription_number = fields.Char(
        string='رقم الاشتراك',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: 'جديد',
        tracking=True
    )

    display_title = fields.Char(
        string='عنوان الاشتراك',
        compute='_compute_display_title',
        store=True
    )

    # العضوة
    member_id = fields.Many2one(
        'charity.member.profile',
        string='العضوة',
        required=True,
        ondelete='restrict',
        tracking=True
    )

    member_name = fields.Char(
        related='member_id.full_name',
        string='اسم العضوة',
        store=True
    )

    member_mobile = fields.Char(
        related='member_id.mobile',
        string='رقم الهاتف',
        store=True
    )

    # صفة السيدة - حقل مرتبط
    lady_type = fields.Selection(
        related='member_id.lady_type',
        string='صفة السيدة',
        store=True
    )

    # القسم والمقر
    headquarters_id = fields.Many2one(
        'charity.headquarters',
        string='المقر',
        required=True,
        tracking=True
    )

    department_id = fields.Many2one(
        'charity.departments',
        string='القسم',
        domain="[('headquarters_id', '=', headquarters_id), ('type', '=', 'ladies')]",
        required=True,
        tracking=True
    )

    # معلومات الاشتراك
    subscription_type = fields.Selection([
        ('annual', 'سنوي'),
        ('semi_annual', 'نصف سنوي'),
        ('quarterly', 'ربع سنوي'),
        ('monthly', 'شهري'),

    ], string='نوع الاشتراك',
        default='annual',
        required=True,
        tracking=True
    )

    workshop_subscription_ids = fields.One2many(
        'charity.member.subscription',
        'member_id',
        string='اشتراكات الورش',
        domain=[('workshop_id', '!=', False)],  # تغيير هنا
        help='اشتراكات الورش الخاصة بالعضوة'
    )

    program_subscription_ids = fields.One2many(
        'charity.member.subscription',
        'member_id',
        string='اشتراكات البرامج',
        domain=[('workshop_id', '=', False)],  # تغيير هنا
        help='اشتراكات البرامج الخاصة بالعضوة'
    )

    # التواريخ
    payment_date = fields.Datetime(
        string='تاريخ الدفع',
        default=fields.Datetime.now,
        required=True,
        tracking=True
    )

    start_date = fields.Date(
        string='تاريخ البداية',
        default=fields.Date.today,
        required=True,
        tracking=True
    )

    end_date = fields.Date(
        string='تاريخ النهاية',
        compute='_compute_end_date',
        store=True,
        tracking=True
    )

    days_remaining = fields.Integer(
        string='الأيام المتبقية',
        compute='_compute_days_remaining'
    )

    # المبالغ
    amount = fields.Float(
        string='مبلغ الاشتراك',
        required=True,
        tracking=True
    )

    workshop_id = fields.Many2one(
        'charity.ladies.workshop',
        string='الورشة المختارة',
        help='الورشة المرتبطة بهذا الاشتراك'
    )

    workshop_name = fields.Char(
        related='workshop_id.name',
        string='اسم الورشة',
        store=True,
        readonly=True
    )

    workshop_schedule = fields.Text(
        related='workshop_id.schedule',
        string='موعد الورشة',
        store=True,
        readonly=True
    )

    is_workshop = fields.Boolean(
        string='اشتراك ورشة',
        compute='_compute_is_workshop',
        store=True
    )

    # الحالة
    state = fields.Selection([
        ('draft', 'مسودة'),
        ('confirmed', 'مؤكد'),
        ('active', 'نشط'),
        ('expired', 'منتهي'),
        ('cancelled', 'ملغي')
    ], string='الحالة',
        default='draft',
        tracking=True
    )

    # معلومات إضافية
    notes = fields.Text(
        string='ملاحظات'
    )

    program_ids = fields.Many2many(
        'charity.ladies.program',
        'program_subscription_rel',
        'subscription_id',
        'program_id',
        string='البرامج المختارة',
        domain="[('department_id', '=', department_id), ('is_active', '=', True)]",
        help='البرامج المختارة في هذا الاشتراك'
    )

    programs_count = fields.Integer(
        string='عدد البرامج',
        compute='_compute_programs_count',
        help='عدد البرامج المختارة'
    )

    id_card_file = fields.Binary(
        string='صورة الهوية',
        attachment=True,
        help='صورة الهوية'
    )

    id_card_filename = fields.Char(
        string='اسم ملف الهوية'
    )

    passport_file = fields.Binary(
        string='صورة الباسبور',
        attachment=True,
        help='صورة جواز السفر'
    )

    passport_filename = fields.Char(
        string='اسم ملف الباسبور'
    )

    residence_file = fields.Binary(
        string='صورة الإقامة',
        attachment=True,
        help='صورة الإقامة'
    )

    residence_filename = fields.Char(
        string='اسم ملف الإقامة'
    )

    company_id = fields.Many2one(
        'res.company',
        string='الشركة',
        default=lambda self: self.env.company,
        required=True
    )

    @api.depends('workshop_id', 'program_ids', 'subscription_number')
    def _compute_display_title(self):
        """حساب عنوان الاشتراك الديناميكي"""
        for record in self:
            if record.workshop_id:
                # اشتراك في ورشة
                record.display_title = f"اشتراك في ورشة {record.workshop_id.name}"
            elif record.program_ids:
                # اشتراك في برامج
                record.display_title = "اشتراك في برامج السيدات"
            else:
                # اشتراك عادي في قسم
                record.display_title = f"اشتراك في قسم {record.department_id.name if record.department_id else 'السيدات'}"

    @api.depends('workshop_id')
    def _compute_is_workshop(self):
        for record in self:
            record.is_workshop = bool(record.workshop_id)

    @api.onchange('subscription_type')
    def _onchange_subscription_type(self):
        """مسح الحقول غير المناسبة عند تغيير النوع"""
        if self.subscription_type == 'workshop':
            self.program_ids = False
        else:
            self.workshop_id = False

    @api.model
    def create(self, vals):
        """إنشاء رقم اشتراك تلقائي"""
        if vals.get('subscription_number', 'جديد') == 'جديد':
            vals['subscription_number'] = self.env['ir.sequence'].next_by_code('charity.member.subscription') or 'جديد'
        return super(MemberSubscription, self).create(vals)

    @api.depends('start_date', 'subscription_type')
    def _compute_end_date(self):
        """حساب تاريخ نهاية الاشتراك"""
        for record in self:
            if record.start_date:
                if record.subscription_type == 'annual':
                    record.end_date = record.start_date + relativedelta(years=1)
                elif record.subscription_type == 'semi_annual':
                    record.end_date = record.start_date + relativedelta(months=6)
                elif record.subscription_type == 'quarterly':
                    record.end_date = record.start_date + relativedelta(months=3)
                elif record.subscription_type == 'monthly':
                    record.end_date = record.start_date + relativedelta(months=1)
            else:
                record.end_date = False

    @api.depends('end_date')
    def _compute_days_remaining(self):
        """حساب الأيام المتبقية"""
        today = fields.Date.today()
        for record in self:
            if record.end_date and record.state == 'active':
                delta = record.end_date - today
                record.days_remaining = delta.days if delta.days > 0 else 0
            else:
                record.days_remaining = 0

    @api.onchange('headquarters_id')
    def _onchange_headquarters_id(self):
        """تحديث domain القسم عند تغيير المقر"""
        if self.headquarters_id:
            self.department_id = False
            return {
                'domain': {
                    'department_id': [
                        ('headquarters_id', '=', self.headquarters_id.id),
                        ('type', '=', 'ladies')
                    ]
                }
            }

    @api.depends('program_ids')
    def _compute_programs_count(self):
        """حساب عدد البرامج المختارة"""
        for record in self:
            record.programs_count = len(record.program_ids)

    @api.constrains('program_ids')
    def _check_programs_capacity(self):
        """التحقق من توفر مقاعد في البرامج المختارة"""
        for record in self:
            if record.state == 'active':
                for program in record.program_ids:
                    if program.available_seats <= 0:
                        raise ValidationError(
                            f'البرنامج "{program.name}" ممتلئ ولا يمكن التسجيل فيه!'
                        )

    @api.constrains('department_id', 'program_ids')
    def _check_programs_department(self):
        """التحقق من أن جميع البرامج تنتمي لنفس القسم"""
        for record in self:
            if record.program_ids:
                invalid_programs = record.program_ids.filtered(
                    lambda p: p.department_id != record.department_id
                )
                if invalid_programs:
                    raise ValidationError(
                        'جميع البرامج يجب أن تكون من نفس القسم!'
                    )

    @api.onchange('department_id')
    def _onchange_department_id(self):
        """تحديث السعر من القسم"""
        if self.department_id and self.department_id.booking_price:
            self.amount = self.department_id.booking_price

    @api.constrains('member_id', 'program_ids', 'state')
    def _check_no_duplicate_programs(self):
        """التحقق من عدم التسجيل في نفس البرنامج مرتين - السماح بعدة اشتراكات"""
        for record in self:
            if record.state == 'active' and record.program_ids:
                # البحث عن اشتراكات أخرى نشطة لنفس العضوة
                other_subscriptions = self.search([
                    ('member_id', '=', record.member_id.id),
                    ('state', '=', 'active'),
                    ('id', '!=', record.id)
                ])

                for other in other_subscriptions:
                    # التحقق من البرامج المشتركة
                    common_programs = set(record.program_ids.ids) & set(other.program_ids.ids)
                    if common_programs:
                        program_names = record.program_ids.browse(list(common_programs)).mapped('name')
                        raise ValidationError(
                            f'العضوة {record.member_id.full_name} مسجلة بالفعل في البرامج: {", ".join(program_names)}'
                        )

    def action_confirm(self):
        """تأكيد الاشتراك"""
        self.ensure_one()
        if self.state == 'draft':
            self.state = 'confirmed'

    def action_activate(self):
        """تفعيل الاشتراك"""
        self.ensure_one()

        # ⭐ إذا كان الاشتراك نشط بالفعل، لا نعمل شيء
        if self.state == 'active':
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'تنبيه',
                    'message': 'الاشتراك مفعّل بالفعل',
                    'type': 'info',
                    'sticky': False,
                }
            }

        if self.state == 'confirmed':
            # البحث عن الحجز المرتبط
            booking = self.env['charity.booking.registrations'].search([
                ('subscription_id', '=', self.id)
            ], limit=1)

            # التحقق من الحالات المختلفة
            can_activate = False

            # حالة 1: force_activate من الـ context
            if self._context.get('force_activate'):
                can_activate = True
                _logger.info(f"Subscription {self.id} - forced activation")

            # حالة 2: ورشة مجانية - لا تحتاج دفع
            elif booking and booking.booking_mode == 'workshop' and booking.workshop_id and booking.workshop_id.is_free:
                can_activate = True
                _logger.info(f"Subscription {self.id} - free workshop activation")

            # حالة 3: فاتورة مدفوعة (الحالة العادية)
            elif booking and booking.invoice_payment_state == 'paid':
                can_activate = True
                _logger.info(f"Subscription {self.id} - paid invoice activation")

            # حالة 4: لا توجد فاتورة أصلاً (للورش المجانية القديمة)
            elif booking and not booking.invoice_id and booking.booking_mode == 'workshop':
                can_activate = True
                _logger.info(f"Subscription {self.id} - no invoice (free workshop)")

            # التفعيل أو رفض
            if can_activate:
                self.state = 'active'
                _logger.info(f"Subscription {self.id} activated for member {self.member_id.full_name}")
            else:
                raise ValidationError('لا يمكن تفعيل الاشتراك قبل دفع الفاتورة!')

    def action_cancel(self):
        """إلغاء الاشتراك"""
        self.ensure_one()
        if self.state in ('draft', 'confirmed'):
            self.state = 'cancelled'

    def action_renew(self):
        """تجديد الاشتراك"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': 'تجديد الاشتراك',
            'view_mode': 'form',
            'res_model': 'charity.member.subscription',
            'target': 'new',
            'context': {
                'default_member_id': self.member_id.id,
                'default_headquarters_id': self.headquarters_id.id,
                'default_department_id': self.department_id.id,
                'default_start_date': self.end_date + relativedelta(days=1) if self.end_date else fields.Date.today(),
                'default_subscription_type': self.subscription_type,
                'default_amount': self.amount
            }
        }

    @api.model
    def _check_expired_subscriptions(self):
        """Cron job للتحقق من الاشتراكات المنتهية"""
        today = fields.Date.today()
        expired = self.search([
            ('state', '=', 'active'),
            ('end_date', '<', today)
        ])
        expired.write({'state': 'expired'})

    def name_get(self):
        """تخصيص طريقة عرض اسم الاشتراك"""
        result = []
        for record in self:
            if record.workshop_id:
                # اشتراك ورشة
                if record.workshop_id.is_free:
                    name = f"{record.subscription_number} - ورشة {record.workshop_id.name} (مجاني)"
                else:
                    name = f"{record.subscription_number} - ورشة {record.workshop_id.name}"
            else:
                # اشتراك برامج
                name = f"{record.subscription_number} - {record.member_name}"

            result.append((record.id, name))
        return result