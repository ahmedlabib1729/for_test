# -*- coding: utf-8 -*-

from odoo import models, fields, api
from odoo.exceptions import ValidationError
from datetime import date
from dateutil.relativedelta import relativedelta
import re


class StudentProfile(models.Model):
    _name = 'charity.student.profile'
    _description = 'ملف الطالب'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'full_name'
    _order = 'full_name'

    # معلومات الطالب الأساسية
    full_name = fields.Char(
        string='الاسم الثلاثي كما في الهوية',
        required=True,
        tracking=True,
        help='أدخل الاسم الثلاثي كما هو مكتوب في الهوية'
    )

    birth_date = fields.Date(
        string='تاريخ الميلاد',
        required=True,
        tracking=True,
        help='تاريخ ميلاد الطالب'
    )

    gender = fields.Selection([
        ('male', 'ذكر'),
        ('female', 'أنثى')
    ], string='الجنس',
        required=True,
        tracking=True
    )

    nationality = fields.Many2one(
        'res.country',
        string='الجنسية',
        required=True,
        help='اختر جنسية الطالب'
    )

    # معلومات الهوية
    id_type = fields.Selection([
        ('emirates_id', 'الهوية الإماراتية'),
        ('passport', 'جواز السفر')
    ], string='نوع الهوية',
        required=True,
        default='emirates_id',
        tracking=True,
        help='اختر نوع الهوية'
    )

    id_number = fields.Char(
        string='رقم الهوية/الجواز',
        required=True,
        tracking=True,
        help='أدخل رقم الهوية الإماراتية أو رقم جواز السفر'
    )

    # صور الهوية
    id_front_file = fields.Binary(
        string='صورة الهوية - الوجه الأول',
        required=True,
        attachment=True,
        help='أرفق صورة الوجه الأول من الهوية'
    )

    id_front_filename = fields.Char(
        string='اسم ملف الوجه الأول'
    )

    id_back_file = fields.Binary(
        string='صورة الهوية - الوجه الثاني',
        required=True,
        attachment=True,
        help='أرفق صورة الوجه الثاني من الهوية'
    )

    id_back_filename = fields.Char(
        string='اسم ملف الوجه الثاني'
    )

    # معلومات الوالدين
    family_profile_id = fields.Many2one(
        'charity.family.profile',
        string='ملف العائلة',
        required=True,
        tracking=True,
        help='ملف العائلة المرتبط بالطالب'
    )
    family_email = fields.Char(
        string='البريد الإلكتروني للعائلة',
        related='family_profile_id.email',
        readonly=True,
        store=True,  # لحفظه في قاعدة البيانات للبحث السريع
        help='البريد الإلكتروني من ملف العائلة'
    )

    # معلومات إضافية
    age = fields.Integer(
        string='العمر',
        compute='_compute_age',
        store=True,
        help='العمر المحسوب من تاريخ الميلاد'
    )

    active = fields.Boolean(
        string='نشط',
        default=True,
        help='إذا تم إلغاء التحديد، سيتم أرشفة الطالب'
    )

    company_id = fields.Many2one(
        'res.company',
        string='الشركة',
        default=lambda self: self.env.company,
        required=True
    )

    # المتطلبات الصحية
    has_health_requirements = fields.Boolean(
        string='هل يوجد متطلبات صحية أو احتياجات خاصة؟',
        default=False,
        help='في حال وجود أي متطلبات صحية أو احتياجات خاصة أو حساسيات لدى الطالب'
    )

    health_requirements = fields.Text(
        string='تفاصيل المتطلبات الصحية',
        help='يرجى كتابة تفاصيل المتطلبات الصحية أو الاحتياجات الخاصة'
    )

    # الموافقات
    photo_consent = fields.Boolean(
        string='الموافقة على التصوير',
        default=False,
        required=True,
        help='ملاحظة: يتم تصوير الطلاب خلال فعاليات النوادي وتوضع في مواقع التواصل الاجتماعي للجمعية'
    )

    # العلاقات
    registration_ids = fields.One2many(
        'charity.club.registrations',
        'student_profile_id',
        string='التسجيلات',
        help='جميع التسجيلات الخاصة بالطالب'
    )

    registrations_count = fields.Integer(
        string='عدد التسجيلات',
        compute='_compute_registrations_count',
        help='عدد التسجيلات الحالية للطالب'
    )

    student_code = fields.Char(
        string='رقم الطالب',
        required=True,
        readonly=True,
        copy=False,
        default='جديد',
        index=True,
        help='رقم تعريف فريد للطالب'
    )

    @api.model
    def fix_duplicate_students(self):
        """دالة لمعالجة الطلاب المكررين"""
        try:
            # البحث عن أرقام الهوية المكررة
            self.env.cr.execute("""
                    SELECT id_number, array_agg(id) as ids
                    FROM charity_student_profile
                    WHERE id_number IS NOT NULL
                    GROUP BY id_number
                    HAVING COUNT(*) > 1
                """)

            duplicates = self.env.cr.fetchall()

            for id_number, student_ids in duplicates:
                students = self.browse(student_ids)

                # الاحتفاظ بأقدم سجل
                main_student = students.sorted('create_date')[0]
                duplicate_students = students - main_student

                # نقل جميع التسجيلات للسجل الرئيسي
                registrations = self.env['charity.club.registrations'].search([
                    ('student_profile_id', 'in', duplicate_students.ids)
                ])

                if registrations:
                    registrations.write({'student_profile_id': main_student.id})

                # حذف السجلات المكررة
                duplicate_students.unlink()

            return True
        except Exception as e:
            raise ValidationError(f"خطأ في معالجة المكررات: {str(e)}")

    @api.model
    def generate_codes_for_existing(self):
        """توليد أرقام للطلاب الموجودين بدون رقم"""
        try:
            students_without_code = self.search([
                '|',
                ('student_code', '=', False),
                ('student_code', '=', 'جديد')
            ], order='create_date, id')

            for index, student in enumerate(students_without_code, 1):
                year = fields.Date.today().year
                # التحقق من عدم وجود الرقم مسبقاً
                new_code = f'STD-{year}-{str(index).zfill(5)}'

                # التأكد من عدم التكرار
                while self.search_count([('student_code', '=', new_code)]) > 0:
                    index += 1
                    new_code = f'STD-{year}-{str(index).zfill(5)}'

                student.student_code = new_code

            return True
        except Exception as e:
            raise ValidationError(f"خطأ في توليد الأرقام: {str(e)}")

    @api.model_create_multi
    def create(self, vals_list):
        """Override create to generate student code"""
        for vals in vals_list:
            if vals.get('student_code', 'جديد') == 'جديد':
                # توليد رقم جديد
                vals['student_code'] = self._generate_unique_code()
        return super(StudentProfile, self).create(vals_list)

    def _generate_unique_code(self):
        """توليد رقم فريد للطالب"""
        # البحث عن آخر رقم
        last_student = self.search(
            [('student_code', '!=', 'جديد'), ('student_code', '!=', False)],
            order='id desc',
            limit=1
        )

        if last_student and last_student.student_code:
            # استخراج الرقم من الكود الأخير
            try:
                parts = last_student.student_code.split('-')
                if len(parts) == 3:
                    last_number = int(parts[2])
                    new_number = last_number + 1
                else:
                    new_number = 1
            except:
                new_number = 1
        else:
            new_number = 1

        # صيغة الرقم: STD-YEAR-00001
        year = fields.Date.today().year
        new_code = f'STD-{year}-{str(new_number).zfill(5)}'

        # التأكد من عدم التكرار
        while self.search_count([('student_code', '=', new_code)]) > 0:
            new_number += 1
            new_code = f'STD-{year}-{str(new_number).zfill(5)}'

        return new_code

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

    @api.depends('registration_ids')
    def _compute_registrations_count(self):
        """حساب عدد التسجيلات"""
        for record in self:
            record.registrations_count = len(record.registration_ids.filtered(lambda r: r.state != 'cancelled'))

    @api.onchange('id_type', 'id_number')
    def _onchange_format_id_number(self):
        """تنسيق رقم الهوية تلقائياً"""
        if self.id_type == 'emirates_id' and self.id_number:
            clean_id = self.id_number.replace('-', '').replace(' ', '').strip()
            if len(clean_id) == 15 and clean_id.isdigit():
                self.id_number = f"{clean_id[0:3]}-{clean_id[3:7]}-{clean_id[7:14]}-{clean_id[14]}"
        elif self.id_type == 'passport' and self.id_number:
            self.id_number = self.id_number.upper().strip()

    @api.constrains('id_type', 'id_number')
    def _check_id_number(self):
        """التحقق من صحة رقم الهوية أو الجواز"""
        for record in self:
            if not record.id_number:
                raise ValidationError('يجب إدخال رقم الهوية أو الجواز!')

            if record.id_type == 'emirates_id':
                emirates_id_pattern = re.compile(r'^784-\d{4}-\d{7}-\d$')
                if not emirates_id_pattern.match(record.id_number):
                    clean_id = record.id_number.replace('-', '').strip()
                    if not (len(clean_id) == 15 and clean_id.startswith('784') and clean_id.isdigit()):
                        raise ValidationError(
                            'رقم الهوية الإماراتية غير صحيح!\n'
                            'يجب أن يكون بالصيغة: 784-YYYY-XXXXXXX-X\n'
                            'مثال: 784-1990-1234567-1'
                        )

            elif record.id_type == 'passport':
                passport_pattern = re.compile(r'^[A-Z0-9]{6,9}$')
                if not passport_pattern.match(record.id_number.upper()):
                    raise ValidationError(
                        'رقم جواز السفر غير صحيح!\n'
                        'يجب أن يحتوي على أحرف وأرقام فقط (6-9 خانات)\n'
                        'مثال: AB1234567'
                    )

    @api.constrains('birth_date')
    def _check_birth_date(self):
        """التحقق من صحة تاريخ الميلاد"""
        for record in self:
            if record.birth_date:
                if record.birth_date > date.today():
                    raise ValidationError('تاريخ الميلاد لا يمكن أن يكون في المستقبل!')

    @api.constrains('has_health_requirements', 'health_requirements')
    def _check_health_requirements(self):
        """التحقق من كتابة المتطلبات الصحية إذا تم التحديد"""
        for record in self:
            if record.has_health_requirements and not record.health_requirements:
                raise ValidationError('يجب كتابة تفاصيل المتطلبات الصحية!')

    @api.constrains('id_front_file', 'id_back_file')
    def _check_id_files(self):
        """التحقق من رفع ملفات الهوية"""
        for record in self:
            if not record.id_front_file:
                raise ValidationError('يجب رفع صورة الوجه الأول من الهوية!')
            if not record.id_back_file:
                raise ValidationError('يجب رفع صورة الوجه الثاني من الهوية!')

    _sql_constraints = [
        ('id_number_unique', 'UNIQUE(id_number, company_id)', 'رقم الهوية/الجواز مسجل مسبقاً!'),
    ]

    def name_get(self):
        """تخصيص طريقة عرض اسم الطالب"""
        result = []
        for record in self:
            name = f"{record.full_name} ({record.id_number})"
            result.append((record.id, name))
        return result

    @api.model
    def _name_search(self, name, args=None, operator='ilike', limit=100):
        """البحث في الطلاب بالاسم أو رقم الهوية"""
        args = args or []
        if name:
            args = ['|', '|',
                    ('full_name', operator, name),
                    ('id_number', operator, name),
                    ('family_profile_id.father_mobile', operator, name)] + args
        return self._search(args, limit=limit)


class FamilyProfile(models.Model):
    _name = 'charity.family.profile'
    _description = 'ملف العائلة'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'display_name'
    _order = 'father_name'

    # معلومات الوالدين
    mother_name = fields.Char(
        string='اسم الأم',
        required=True,
        help='أدخل اسم والدة الطالب'
    )

    mother_mobile = fields.Char(
        string='هاتف الأم المتحرك',
        required=True,
        help='أدخل رقم هاتف والدة الطالب'
    )

    father_name = fields.Char(
        string='اسم الأب',
        required=True,
        help='أدخل اسم والد الطالب'
    )

    father_mobile = fields.Char(
        string='هاتف الأب المتحرك',
        required=True,
        help='أدخل رقم هاتف والد الطالب'
    )

    mother_whatsapp = fields.Char(
        string='الواتس اب للأم',
        required=True,
        help='أدخل رقم واتساب والدة الطالب'
    )

    email = fields.Char(
        string='البريد الإلكتروني',
        help='البريد الإلكتروني للتواصل'
    )

    display_name = fields.Char(
        string='اسم العائلة',
        compute='_compute_display_name',
        store=True,
        help='اسم العائلة للعرض'
    )

    active = fields.Boolean(
        string='نشط',
        default=True,
        help='إذا تم إلغاء التحديد، سيتم أرشفة ملف العائلة'
    )

    company_id = fields.Many2one(
        'res.company',
        string='الشركة',
        default=lambda self: self.env.company,
        required=True
    )

    # العلاقات
    student_ids = fields.One2many(
        'charity.student.profile',
        'family_profile_id',
        string='الأبناء',
        help='جميع الأبناء المسجلين لهذه العائلة'
    )

    students_count = fields.Integer(
        string='عدد الأبناء',
        compute='_compute_students_count',
        help='عدد الأبناء المسجلين'
    )

    @api.depends('father_name', 'mother_name')
    def _compute_display_name(self):
        """حساب اسم العائلة للعرض"""
        for record in self:
            record.display_name = f"عائلة {record.father_name}"

    @api.depends('student_ids')
    def _compute_students_count(self):
        """حساب عدد الأبناء"""
        for record in self:
            record.students_count = len(record.student_ids.filtered('active'))

    @api.constrains('mother_mobile', 'father_mobile', 'mother_whatsapp')
    def _check_phone_numbers(self):
        """التحقق من صحة أرقام الهواتف"""
        import re
        phone_pattern = re.compile(r'^[\d\s\-\+]+$')

        for record in self:
            if record.mother_mobile and not phone_pattern.match(record.mother_mobile):
                raise ValidationError('رقم هاتف الأم غير صحيح!')
            if record.father_mobile and not phone_pattern.match(record.father_mobile):
                raise ValidationError('رقم هاتف الأب غير صحيح!')
            if record.mother_whatsapp and not phone_pattern.match(record.mother_whatsapp):
                raise ValidationError('رقم واتساب الأم غير صحيح!')

    @api.constrains('email')
    def _check_email(self):
        """التحقق من صحة البريد الإلكتروني"""
        import re
        email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        for record in self:
            if record.email and not email_pattern.match(record.email):
                raise ValidationError('البريد الإلكتروني غير صحيح!')

    def name_get(self):
        """تخصيص طريقة عرض اسم العائلة"""
        result = []
        for record in self:
            name = f"{record.display_name} - {record.father_mobile}"
            result.append((record.id, name))
        return result

    @api.model
    def _name_search(self, name, args=None, operator='ilike', limit=100):
        """البحث في العائلات"""
        args = args or []
        if name:
            args = ['|', '|', '|',
                    ('father_name', operator, name),
                    ('mother_name', operator, name),
                    ('father_mobile', operator, name),
                    ('mother_mobile', operator, name)] + args
        return self._search(args, limit=limit)