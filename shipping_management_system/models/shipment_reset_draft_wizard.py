# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import UserError


class ShipmentResetDraftWizard(models.TransientModel):
    """Wizard لتأكيد Reset to Draft مع عرض ما سيتم مسحه"""
    _name = 'shipment.reset.draft.wizard'
    _description = 'Reset Shipment to Draft Wizard'

    shipment_id = fields.Many2one(
        'shipment.order',
        string='Shipment',
        required=True
    )

    order_number = fields.Char(
        related='shipment_id.order_number',
        string='Order Number',
        readonly=True
    )

    current_state = fields.Char(
        string='Current State',
        compute='_compute_items_to_delete',
        readonly=True
    )

    # عدد العناصر التي سيتم مسحها
    invoice_count = fields.Integer(
        string='Customer Invoices',
        compute='_compute_items_to_delete'
    )

    vendor_bill_count = fields.Integer(
        string='Vendor Bills',
        compute='_compute_items_to_delete'
    )

    advance_payment_count = fields.Integer(
        string='Advance Payments',
        compute='_compute_items_to_delete'
    )

    total_invoice_amount = fields.Float(
        string='Total Invoice Amount',
        compute='_compute_items_to_delete'
    )

    total_bill_amount = fields.Float(
        string='Total Bill Amount',
        compute='_compute_items_to_delete'
    )

    total_advance_amount = fields.Float(
        string='Total Advance Amount',
        compute='_compute_items_to_delete'
    )

    # تفاصيل نصية
    invoice_details = fields.Text(
        string='Invoice Details',
        compute='_compute_items_to_delete'
    )

    bill_details = fields.Text(
        string='Bill Details',
        compute='_compute_items_to_delete'
    )

    advance_details = fields.Text(
        string='Advance Payment Details',
        compute='_compute_items_to_delete'
    )

    has_items_to_delete = fields.Boolean(
        string='Has Items to Delete',
        compute='_compute_items_to_delete'
    )

    warning_message = fields.Text(
        string='Warning Message',
        compute='_compute_items_to_delete'
    )

    @api.depends('shipment_id')
    def _compute_items_to_delete(self):
        for record in self:
            shipment = record.shipment_id

            if not shipment:
                record.current_state = ''
                record.invoice_count = 0
                record.vendor_bill_count = 0
                record.advance_payment_count = 0
                record.total_invoice_amount = 0
                record.total_bill_amount = 0
                record.total_advance_amount = 0
                record.invoice_details = ''
                record.bill_details = ''
                record.advance_details = ''
                record.has_items_to_delete = False
                record.warning_message = ''
                continue

            # الحالة الحالية
            state_dict = dict(shipment._fields['state'].selection)
            record.current_state = state_dict.get(shipment.state, shipment.state)

            # البحث عن الفواتير
            customer_invoices = self.env['account.move'].search([
                ('shipment_id', '=', shipment.id),
                ('move_type', '=', 'out_invoice'),
                ('state', '!=', 'cancel')
            ])
            record.invoice_count = len(customer_invoices)
            record.total_invoice_amount = sum(customer_invoices.mapped('amount_total'))

            invoice_lines = []
            for inv in customer_invoices:
                invoice_lines.append(f"• {inv.name} - {inv.amount_total:.2f} EGP ({inv.state})")
            record.invoice_details = '\n'.join(invoice_lines) if invoice_lines else 'No invoices'

            # البحث عن فواتير الموردين
            vendor_bills = self.env['account.move'].search([
                ('shipment_vendor_id', '=', shipment.id),
                ('move_type', '=', 'in_invoice'),
                ('state', '!=', 'cancel')
            ])
            record.vendor_bill_count = len(vendor_bills)
            record.total_bill_amount = sum(vendor_bills.mapped('amount_total'))

            bill_lines = []
            for bill in vendor_bills:
                bill_lines.append(f"• {bill.name} - {bill.amount_total:.2f} EGP ({bill.state})")
            record.bill_details = '\n'.join(bill_lines) if bill_lines else 'No vendor bills'

            # البحث عن الدفعات المقدمة
            advance_payments = self.env['account.payment'].search([
                ('shipment_advance_id', '=', shipment.id),
                ('state', '!=', 'cancelled')
            ])
            record.advance_payment_count = len(advance_payments)
            record.total_advance_amount = sum(advance_payments.mapped('amount'))

            advance_lines = []
            for payment in advance_payments:
                advance_lines.append(f"• {payment.name} - {payment.amount:.2f} EGP ({payment.state})")
            record.advance_details = '\n'.join(advance_lines) if advance_lines else 'No advance payments'

            # هل يوجد عناصر للمسح؟
            record.has_items_to_delete = (
                record.invoice_count > 0 or
                record.vendor_bill_count > 0 or
                record.advance_payment_count > 0
            )

            # رسالة التحذير
            if record.has_items_to_delete:
                total_amount = record.total_invoice_amount + record.total_bill_amount + record.total_advance_amount
                record.warning_message = _(
                    '⚠️ WARNING: The following items will be PERMANENTLY DELETED:\n\n'
                    '• %d Customer Invoice(s) - Total: %.2f EGP\n'
                    '• %d Vendor Bill(s) - Total: %.2f EGP\n'
                    '• %d Advance Payment(s) - Total: %.2f EGP\n\n'
                    '💰 Grand Total: %.2f EGP\n\n'
                    'This action CANNOT be undone!'
                ) % (
                    record.invoice_count, record.total_invoice_amount,
                    record.vendor_bill_count, record.total_bill_amount,
                    record.advance_payment_count, record.total_advance_amount,
                    total_amount
                )
            else:
                record.warning_message = _('ℹ️ No invoices or payments found. The shipment will be reset to Draft.')

    def action_confirm_reset(self):
        """تأكيد إعادة التعيين ومسح كل شيء"""
        self.ensure_one()

        shipment = self.shipment_id

        if not shipment:
            raise UserError(_('Shipment not found!'))

        deleted_items = []

        # 1. مسح فواتير العملاء
        customer_invoices = self.env['account.move'].search([
            ('shipment_id', '=', shipment.id),
            ('move_type', '=', 'out_invoice'),
            ('state', '!=', 'cancel')
        ])

        for invoice in customer_invoices:
            invoice_name = invoice.name
            try:
                # إلغاء الربط أولاً (Unreconcile)
                if invoice.state == 'posted':
                    # البحث عن أي reconciliation
                    for line in invoice.line_ids.filtered(lambda l: l.account_id.reconcile):
                        if line.matched_debit_ids or line.matched_credit_ids:
                            line.remove_move_reconcile()
                    invoice.button_draft()
                invoice.button_cancel()
                invoice.unlink()
                deleted_items.append(f"✓ Invoice: {invoice_name}")
            except Exception as e:
                deleted_items.append(f"✗ Invoice {invoice_name}: {str(e)}")

        # 2. مسح فواتير الموردين
        vendor_bills = self.env['account.move'].search([
            ('shipment_vendor_id', '=', shipment.id),
            ('move_type', '=', 'in_invoice'),
            ('state', '!=', 'cancel')
        ])

        for bill in vendor_bills:
            bill_name = bill.name
            try:
                if bill.state == 'posted':
                    for line in bill.line_ids.filtered(lambda l: l.account_id.reconcile):
                        if line.matched_debit_ids or line.matched_credit_ids:
                            line.remove_move_reconcile()
                    bill.button_draft()
                bill.button_cancel()
                bill.unlink()
                deleted_items.append(f"✓ Vendor Bill: {bill_name}")
            except Exception as e:
                deleted_items.append(f"✗ Bill {bill_name}: {str(e)}")

        # 3. مسح الدفعات المقدمة
        advance_payments = self.env['account.payment'].search([
            ('shipment_advance_id', '=', shipment.id),
            ('state', '!=', 'cancelled')
        ])

        for payment in advance_payments:
            payment_name = payment.name
            try:
                if payment.state == 'posted':
                    # إلغاء الربط
                    if payment.move_id:
                        for line in payment.move_id.line_ids.filtered(lambda l: l.account_id.reconcile):
                            if line.matched_debit_ids or line.matched_credit_ids:
                                line.remove_move_reconcile()
                    payment.action_draft()
                payment.action_cancel()
                payment.unlink()
                deleted_items.append(f"✓ Payment: {payment_name}")
            except Exception as e:
                deleted_items.append(f"✗ Payment {payment_name}: {str(e)}")

        # 4. إعادة تعيين حقول الشحنة
        shipment.write({
            'state': 'draft',
            'tracking_number': False,
            'is_return_processed': False,
            'planned_advance_amount': 0,
            'planned_advance_status': 'none',
            'planned_advance_date': False,
            'advance_skip_reason': False,
            'advance_skip_notes': False,
        })

        # 5. تسجيل الرسالة
        message_body = f"""
        <b>🔄 Shipment Reset to Draft</b><br/><br/>
        <b>Deleted Items:</b><br/>
        {'<br/>'.join(deleted_items) if deleted_items else 'No items deleted'}
        """

        shipment.message_post(
            body=message_body,
            subject='Reset to Draft'
        )

        # إغلاق الـ wizard
        return {'type': 'ir.actions.act_window_close'}