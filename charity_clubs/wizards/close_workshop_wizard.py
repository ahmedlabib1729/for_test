# -*- coding: utf-8 -*-

from odoo import models, fields, api
from odoo.exceptions import UserError


class CloseWorkshopWizard(models.TransientModel):
    _name = 'close.workshop.wizard'
    _description = 'معالج إنهاء الورش'

    workshop_ids = fields.Many2many(
        'charity.ladies.workshop',
        string='الورش المراد إنهاؤها',
        required=True,
        domain=[('is_active', '=', True)],
        help='اختر الورش التي تريد إنهاءها'
    )

    reason = fields.Text(
        string='سبب الإنهاء',
        help='اختياري - سبب إنهاء الورش'
    )

    subscriptions_count = fields.Integer(
        string='عدد الاشتراكات المتأثرة',
        compute='_compute_subscriptions_count',
        help='عدد الاشتراكات التي سيتم إنهاؤها'
    )

    @api.depends('workshop_ids')
    def _compute_subscriptions_count(self):
        for wizard in self:
            count = 0
            if wizard.workshop_ids:
                subscriptions = self.env['charity.member.subscription'].search([
                    ('workshop_id', 'in', wizard.workshop_ids.ids),
                    ('state', '=', 'active')
                ])
                count = len(subscriptions)
            wizard.subscriptions_count = count

    def action_close_workshops(self):
        """إنهاء الورش المحددة وتحويل اشتراكاتها"""
        self.ensure_one()

        if not self.workshop_ids:
            raise UserError('يجب اختيار ورشة واحدة على الأقل!')

        # إنهاء الاشتراكات النشطة
        active_subscriptions = self.env['charity.member.subscription'].search([
            ('workshop_id', 'in', self.workshop_ids.ids),
            ('state', '=', 'active')
        ])

        if active_subscriptions:
            active_subscriptions.write({'state': 'expired'})

            # إضافة ملاحظة في كل اشتراك
            for subscription in active_subscriptions:
                message = f"تم إنهاء الاشتراك بسبب إنهاء الورشة: {subscription.workshop_id.name}"
                if self.reason:
                    message += f"\nالسبب: {self.reason}"
                subscription.message_post(body=message)

        # تعطيل الورش
        self.workshop_ids.write({'is_active': False})

        # إضافة ملاحظة في كل ورشة
        for workshop in self.workshop_ids:
            message = "تم إنهاء الورشة"
            if self.reason:
                message += f"\nالسبب: {self.reason}"
            workshop.message_post(body=message)

        # رسالة نجاح
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'تم إنهاء الورش',
                'message': f'تم إنهاء {len(self.workshop_ids)} ورشة و {len(active_subscriptions)} اشتراك',
                'type': 'success',
                'sticky': False,
            }
        }