# models/daily_invoices_dashboard.py
from odoo import models, fields, api
from datetime import datetime
import logging

_logger = logging.getLogger(__name__)


class DailyInvoicesDashboard(models.AbstractModel):
    _name = 'daily.invoices.dashboard'
    _description = 'Daily Invoices Dashboard'

    @api.model
    def get_report_data(self, date_from, date_to):
        """جلب بيانات فواتير المشتريات والمبيعات"""
        
        # جلب الحسابات من الإعدادات
        ICP = self.env['ir.config_parameter'].sudo()
        cash_account_id = int(ICP.get_param('daily_invoices.sales_cash_account_id', 0))
        bank_account_id = int(ICP.get_param('daily_invoices.sales_bank_account_id', 0))
        commission_account_id = int(ICP.get_param('daily_invoices.sales_commission_account_id', 0))
        commission_tax_account_id = int(ICP.get_param('daily_invoices.sales_commission_tax_account_id', 0))

        # متغيرات لتجميع المدفوعات والاستلامات
        total_cash_in = 0  # استلامات من المبيعات
        total_cash_out = 0  # مدفوعات للمشتريات
        total_bank_in = 0
        total_bank_out = 0
        
        # ======= PURCHASES - فواتير المشتريات =======
        purchase_domain = [
            ('state', '=', 'posted'),
            ('move_type', '=', 'in_invoice'),
            ('invoice_date', '>=', date_from),
            ('invoice_date', '<=', date_to),
        ]

        purchase_invoices = self.env['account.move'].search(purchase_domain, order='invoice_date desc')

        # تقسيم المشتريات حسب حالة الدفع
        paid_purchases = []
        unpaid_purchases = []

        total_paid_amount = 0
        total_paid_tax = 0
        total_unpaid_amount = 0
        total_unpaid_tax = 0

        for invoice in purchase_invoices:
            # جلب قيمة payment_type
            payment_type_label = ''
            if hasattr(invoice, 'payment_type') and invoice.payment_type:
                payment_type_selection = dict(invoice._fields['payment_type'].selection)
                payment_type_label = payment_type_selection.get(invoice.payment_type, '')
            
            # حساب المدفوعات من المشتريات (خصم من الكاش/البنك)
            purchase_distributions = self._get_purchase_distributions(invoice, cash_account_id, bank_account_id)
            cash_paid = purchase_distributions.get('cash', 0)
            bank_paid = purchase_distributions.get('bank', 0)
            
            total_cash_out += cash_paid
            total_bank_out += bank_paid
            
            invoice_data = {
                'id': invoice.id,
                'name': invoice.name,
                'partner': invoice.partner_id.name,
                'partner_id': invoice.partner_id.id,
                'date': invoice.invoice_date.strftime('%d/%m/%Y') if invoice.invoice_date else '',
                'create_date': invoice.create_date.strftime('%d/%m/%Y %H:%M') if invoice.create_date else '',
                'amount_untaxed': invoice.amount_untaxed,
                'amount_tax': invoice.amount_tax,
                'amount_total': invoice.amount_total,
                'payment_state': dict(invoice._fields['payment_state'].selection).get(invoice.payment_state),
                'payment_type': invoice.payment_type if hasattr(invoice, 'payment_type') else '',
                'payment_type_label': payment_type_label,
                'cash_paid': cash_paid,
                'bank_paid': bank_paid,
            }

            if invoice.payment_state == 'paid':
                paid_purchases.append(invoice_data)
                total_paid_amount += invoice.amount_total
                total_paid_tax += invoice.amount_tax
            else:
                unpaid_purchases.append(invoice_data)
                total_unpaid_amount += invoice.amount_total
                total_unpaid_tax += invoice.amount_tax

        # ======= SALES - فواتير المبيعات =======
        sales_domain = [
            ('state', '=', 'posted'),
            ('move_type', '=', 'out_invoice'),
            ('invoice_date', '>=', date_from),
            ('invoice_date', '<=', date_to),
        ]

        sales_invoices = self.env['account.move'].search(sales_domain, order='invoice_date desc')

        # تقسيم المبيعات حسب حالة الدفع
        paid_sales = []
        unpaid_sales = []
        other_payments = []

        total_paid_sales_amount = 0
        total_paid_sales_tax = 0
        total_unpaid_sales_amount = 0
        total_unpaid_sales_tax = 0

        total_commission = 0
        total_commission_tax = 0
        total_commission_tax_account = 0
        total_commission_tax_account_tax = 0
        total_other = 0

        for invoice in sales_invoices:
            # البحث في سطور الدفع
            distributions = self._get_account_distributions(invoice, cash_account_id, bank_account_id,
                                                            commission_account_id, commission_tax_account_id)

            # تجميع المبالغ الأساسية
            cash_amount = sum(d[1] for d in distributions['cash']) if distributions['cash'] else 0
            cash_tax = sum(d[2] for d in distributions['cash']) if distributions['cash'] else 0
            bank_amount = sum(d[1] for d in distributions['bank']) if distributions['bank'] else 0
            bank_tax = sum(d[2] for d in distributions['bank']) if distributions['bank'] else 0
            commission_amount = sum(d[1] for d in distributions['commission']) if distributions['commission'] else 0
            commission_tax_val = sum(d[2] for d in distributions['commission']) if distributions['commission'] else 0
            commission_tax_account_amount = sum(d[1] for d in distributions['commission_tax']) if distributions['commission_tax'] else 0
            commission_tax_account_tax = sum(d[2] for d in distributions['commission_tax']) if distributions['commission_tax'] else 0

            # إضافة Other payments
            for other_item in distributions['other']:
                other_payments.append({
                    'invoice_id': invoice.id,
                    'invoice_name': invoice.name,
                    'invoice_date': invoice.invoice_date.strftime('%d/%m/%Y') if invoice.invoice_date else '',
                    'partner': other_item['partner'],
                    'partner_id': other_item['partner_id'],
                    'account': other_item['account'],
                    'account_id': other_item['account_id'],
                    'amount': other_item['amount'],
                    'date': other_item['date'],
                })
                total_other += other_item['amount']

            # جلب قيمة payment_type
            payment_type_label = ''
            if hasattr(invoice, 'payment_type') and invoice.payment_type:
                payment_type_selection = dict(invoice._fields['payment_type'].selection)
                payment_type_label = payment_type_selection.get(invoice.payment_type, '')

            # إنشاء بيانات الفاتورة
            invoice_data = {
                'id': invoice.id,
                'name': invoice.name,
                'partner': invoice.partner_id.name,
                'partner_id': invoice.partner_id.id,
                'date': invoice.invoice_date.strftime('%d/%m/%Y') if invoice.invoice_date else '',
                'create_date': invoice.create_date.strftime('%d/%m/%Y %H:%M') if invoice.create_date else '',
                'amount_untaxed': invoice.amount_untaxed,
                'amount_tax': invoice.amount_tax,
                'amount_total': invoice.amount_total,
                'cash_amount': cash_amount,
                'cash_tax': cash_tax,
                'bank_amount': bank_amount,
                'bank_tax': bank_tax,
                'commission_amount': commission_amount,
                'commission_tax': commission_tax_val,
                'commission_tax_account_amount': commission_tax_account_amount,
                'commission_tax_account_tax': commission_tax_account_tax,
                'payment_state': dict(invoice._fields['payment_state'].selection).get(invoice.payment_state),
                'payment_type': invoice.payment_type if hasattr(invoice, 'payment_type') else '',
                'payment_type_label': payment_type_label,
            }

            # تقسيم حسب حالة الدفع
            if invoice.payment_state == 'paid':
                paid_sales.append(invoice_data)
                total_paid_sales_amount += invoice.amount_total
                total_paid_sales_tax += invoice.amount_tax
            else:
                unpaid_sales.append(invoice_data)
                total_unpaid_sales_amount += invoice.amount_total
                total_unpaid_sales_tax += invoice.amount_tax

            # تجميع الاستلامات من المبيعات
            total_cash_in += cash_amount
            total_bank_in += bank_amount
            total_commission += commission_amount
            total_commission_tax += commission_tax_val
            total_commission_tax_account += commission_tax_account_amount
            total_commission_tax_account_tax += commission_tax_account_tax

        # حساب صافي الكاش والبنك
        net_cash = total_cash_in - total_cash_out
        net_bank = total_bank_in - total_bank_out

        # ======= OTHER PAYMENTS =======
        all_moves_domain = [
            ('state', '=', 'posted'),
            ('date', '>=', date_from),
            ('date', '<=', date_to),
        ]

        all_moves = self.env['account.move'].search(all_moves_domain)

        for move in all_moves:
            expense_lines = move.line_ids.filtered(
                lambda l: l.partner_id
                          and l.account_id.account_type == 'expense'
                          and l.debit > 0
            )

            for line in expense_lines:
                if line.account_id.id not in [cash_account_id, bank_account_id, commission_account_id,
                                              commission_tax_account_id]:
                    existing = False
                    for op in other_payments:
                        if (op['invoice_id'] == move.id and
                                op['account_id'] == line.account_id.id and
                                op['partner_id'] == line.partner_id.id):
                            existing = True
                            break

                    if not existing:
                        other_payments.append({
                            'invoice_id': move.id,
                            'invoice_name': move.name,
                            'invoice_date': move.date.strftime('%d/%m/%Y') if move.date else '',
                            'partner': line.partner_id.name,
                            'partner_id': line.partner_id.id,
                            'account': f"{line.account_id.code} - {line.account_id.name}",
                            'account_id': line.account_id.id,
                            'amount': line.debit,
                            'date': move.date.strftime('%d/%m/%Y') if move.date else '',
                        })
                        total_other += line.debit

        return {
            'purchases': {
                'paid': paid_purchases,
                'unpaid': unpaid_purchases,
                'total_paid': total_paid_amount,
                'total_paid_tax': total_paid_tax,
                'total_unpaid': total_unpaid_amount,
                'total_unpaid_tax': total_unpaid_tax,
                'grand_total': total_paid_amount + total_unpaid_amount,
                'grand_total_tax': total_paid_tax + total_unpaid_tax,
                'total_cash_out': total_cash_out,
                'total_bank_out': total_bank_out,
            },
            'sales': {
                'paid': paid_sales,
                'unpaid': unpaid_sales,
                'total_paid': total_paid_sales_amount,
                'total_paid_tax': total_paid_sales_tax,
                'total_unpaid': total_unpaid_sales_amount,
                'total_unpaid_tax': total_unpaid_sales_tax,
                'other_payments': other_payments,
                'total_cash_in': total_cash_in,
                'total_bank_in': total_bank_in,
                'total_commission': total_commission,
                'total_commission_tax': total_commission_tax,
                'total_commission_tax_account': total_commission_tax_account,
                'total_commission_tax_account_tax': total_commission_tax_account_tax,
                'total_other': total_other,
                'grand_total': total_paid_sales_amount + total_unpaid_sales_amount,
                'grand_total_tax': total_paid_sales_tax + total_unpaid_sales_tax,
            },
            'payment_summary': {
                'cash_in': total_cash_in,
                'cash_out': total_cash_out,
                'net_cash': net_cash,
                'bank_in': total_bank_in,
                'bank_out': total_bank_out,
                'net_bank': net_bank,
                'total_commission': total_commission,
                'total_commission_tax_account': total_commission_tax_account,
                'total_other': total_other,
            },
            'totals': {
                'total_invoices': len(paid_purchases) + len(unpaid_purchases) + len(paid_sales) + len(unpaid_sales),
                'purchases_total': total_paid_amount + total_unpaid_amount,
                'sales_total': total_paid_sales_amount + total_unpaid_sales_amount,
                'paid_percentage': ((len(paid_purchases) + len(paid_sales)) / (len(paid_purchases) + len(unpaid_purchases) + len(paid_sales) + len(unpaid_sales)) * 100) if (len(paid_purchases) + len(unpaid_purchases) + len(paid_sales) + len(unpaid_sales)) > 0 else 0,
            }
        }

    def _get_account_distributions(self, invoice, cash_account_id, bank_account_id,
                                   commission_account_id, commission_tax_account_id):
        """حساب توزيع المبالغ على الحسابات المختلفة"""
        result = {
            'cash': [],
            'bank': [],
            'commission': [],
            'commission_tax': [],
            'other': []
        }

        # البحث عن سطور الـ Receivable/Payable في الفاتورة
        invoice_arap_lines = invoice.line_ids.filtered(
            lambda l: l.account_id.account_type in ('asset_receivable', 'liability_payable')
        )

        if not invoice_arap_lines:
            return result

        payment_moves = self.env['account.move']

        # البحث عن الدفعات المرتبطة بالفاتورة
        for arap_line in invoice_arap_lines:
            matched_lines = self.env['account.move.line']

            # للفواتير اللي فيها Debit (فواتير المبيعات - Receivable)
            if arap_line.debit > 0:
                for partial in arap_line.matched_credit_ids:
                    matched_lines |= partial.credit_move_id
            # للفواتير اللي فيها Credit (فواتير المشتريات - Payable)
            else:
                for partial in arap_line.matched_debit_ids:
                    matched_lines |= partial.debit_move_id

            for line in matched_lines:
                if line.move_id and line.move_id.id != invoice.id:
                    payment_moves |= line.move_id

        total_invoice_amount = invoice.amount_total
        total_invoice_tax = invoice.amount_tax

        for payment_move in payment_moves:
            # في كل الدفعات: Cash/Bank بيكون Debit لما بنستلم فلوس (Receipt)
            # وبيكون Credit لما بندفع فلوس (Payment)
            # لكن الحسابات اللي بندور عليها (Cash, Bank) بتكون Debit في حالة الاستلام
            
            # ابحث عن السطور اللي فيها الحسابات المطلوبة
            for line in payment_move.line_ids:
                account_id = line.account_id.id
                # نجيب المبلغ سواء Debit أو Credit
                amount = line.debit if line.debit > 0 else line.credit
                
                if amount <= 0:
                    continue
                    
                # تجاهل سطور الـ Receivable/Payable
                if line.account_id.account_type in ('asset_receivable', 'liability_payable'):
                    continue

                if account_id == cash_account_id:
                    result['cash'].append(('cash', amount))
                elif account_id == bank_account_id:
                    result['bank'].append(('bank', amount))
                elif account_id == commission_account_id:
                    result['commission'].append(('commission', amount))
                elif account_id == commission_tax_account_id:
                    result['commission_tax'].append(('commission_tax', amount))
                else:
                    if line.partner_id and line.account_id.account_type == 'expense' and line.debit > 0:
                        result['other'].append({
                            'partner': line.partner_id.name,
                            'partner_id': line.partner_id.id,
                            'account': f"{line.account_id.code} - {line.account_id.name}",
                            'account_id': line.account_id.id,
                            'amount': amount,
                            'date': payment_move.date.strftime('%d/%m/%Y') if payment_move.date else '',
                        })

        # حساب الضريبة النسبية
        for category in ['cash', 'bank', 'commission', 'commission_tax']:
            updated = []
            for item_type, amount in result[category]:
                if total_invoice_amount > 0:
                    proportional_tax = (amount / total_invoice_amount) * total_invoice_tax
                else:
                    proportional_tax = 0.0
                updated.append((item_type, amount, proportional_tax))
            result[category] = updated

        return result

    def _get_purchase_distributions(self, invoice, cash_account_id, bank_account_id):
        """حساب المدفوعات من المشتريات (الفلوس اللي خرجت)"""
        result = {
            'cash': 0,
            'bank': 0,
        }

        # البحث عن سطور الـ Payable في الفاتورة
        invoice_payable_lines = invoice.line_ids.filtered(
            lambda l: l.account_id.account_type == 'liability_payable'
        )

        if not invoice_payable_lines:
            return result

        payment_moves = self.env['account.move']

        # البحث عن الدفعات المرتبطة بالفاتورة
        for payable_line in invoice_payable_lines:
            # فواتير المشتريات: Payable بيكون Credit، والدفعة بتكون Debit
            if payable_line.credit > 0:
                for partial in payable_line.matched_debit_ids:
                    if partial.debit_move_id.move_id and partial.debit_move_id.move_id.id != invoice.id:
                        payment_moves |= partial.debit_move_id.move_id

        for payment_move in payment_moves:
            # في دفعات المشتريات: Cash/Bank بيكون Credit (الفلوس خرجت)
            for line in payment_move.line_ids:
                if line.credit > 0 and line.account_id.account_type not in ('asset_receivable', 'liability_payable'):
                    if line.account_id.id == cash_account_id:
                        result['cash'] += line.credit
                    elif line.account_id.id == bank_account_id:
                        result['bank'] += line.credit

        return result
