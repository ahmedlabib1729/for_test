# models/daily_invoices_report.py
from odoo import models, fields, api
from datetime import datetime
import logging

_logger = logging.getLogger(__name__)


class DailyInvoicesWizard(models.TransientModel):
    _name = 'daily.invoices.wizard'
    _description = 'Daily Invoices Report (Purchases & Sales)'

    date_from = fields.Date(
        'From Date',
        default=fields.Date.today,
        required=True,
        help='Start date for invoice filter'
    )

    date_to = fields.Date(
        'To Date',
        default=fields.Date.today,
        required=True,
        help='End date for invoice filter'
    )

    # حقل لتخزين نتائج التقرير
    report_html = fields.Html('Report Results', compute='_compute_report_html')

    @api.depends('date_from', 'date_to')
    def _compute_report_html(self):
        """حساب وعرض التقرير"""
        for wizard in self:
            data = wizard.get_report_data()
            wizard.report_html = wizard._generate_html_report(data)

    def get_report_data(self):
        """جلب بيانات فواتير المشتريات والمبيعات"""
        self.ensure_one()

        # ======= PURCHASES - فواتير المشتريات =======
        purchase_domain = [
            ('state', '=', 'posted'),
            ('move_type', '=', 'in_invoice'),
            ('create_date', '>=', fields.Datetime.to_datetime(self.date_from)),
            ('create_date', '<=', fields.Datetime.to_datetime(self.date_to).replace(hour=23, minute=59, second=59)),
        ]

        purchase_invoices = self.env['account.move'].search(purchase_domain, order='create_date desc')

        # تقسيم المشتريات حسب حالة الدفع
        paid_purchases = []
        unpaid_purchases = []

        total_paid_amount = 0
        total_paid_tax = 0
        total_unpaid_amount = 0
        total_unpaid_tax = 0

        for invoice in purchase_invoices:
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
            ('create_date', '>=', fields.Datetime.to_datetime(self.date_from)),
            ('create_date', '<=', fields.Datetime.to_datetime(self.date_to).replace(hour=23, minute=59, second=59)),
        ]

        sales_invoices = self.env['account.move'].search(sales_domain, order='create_date desc')

        # جلب الحسابات من الإعدادات
        ICP = self.env['ir.config_parameter'].sudo()
        cash_account_id = int(ICP.get_param('daily_invoices.sales_cash_account_id', 0))
        bank_account_id = int(ICP.get_param('daily_invoices.sales_bank_account_id', 0))
        commission_account_id = int(ICP.get_param('daily_invoices.sales_commission_account_id', 0))
        commission_tax_account_id = int(ICP.get_param('daily_invoices.sales_commission_tax_account_id', 0))

        # تجميع المبيعات
        sales_list = []
        other_payments = []

        total_cash = 0
        total_cash_tax = 0
        total_bank = 0
        total_bank_tax = 0
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
            commission_tax_account_amount = sum(d[1] for d in distributions['commission_tax']) if distributions[
                'commission_tax'] else 0
            commission_tax_account_tax = sum(d[2] for d in distributions['commission_tax']) if distributions[
                'commission_tax'] else 0

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

            # لو في توزيعات أساسية، أضف الفاتورة للقائمة
            if any([cash_amount, bank_amount, commission_amount, commission_tax_account_amount]):
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
                }

                sales_list.append(invoice_data)

                total_cash += cash_amount
                total_cash_tax += cash_tax
                total_bank += bank_amount
                total_bank_tax += bank_tax
                total_commission += commission_amount
                total_commission_tax += commission_tax_val
                total_commission_tax_account += commission_tax_account_amount
                total_commission_tax_account_tax += commission_tax_account_tax

        # ======= OTHER PAYMENTS =======
        all_moves_domain = [
            ('state', '=', 'posted'),
            ('date', '>=', self.date_from),
            ('date', '<=', self.date_to),
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
            },
            'sales': {
                'invoices': sales_list,
                'other_payments': other_payments,
                'total_cash': total_cash,
                'total_cash_tax': total_cash_tax,
                'total_bank': total_bank,
                'total_bank_tax': total_bank_tax,
                'total_commission': total_commission,
                'total_commission_tax': total_commission_tax,
                'total_commission_tax_account': total_commission_tax_account,
                'total_commission_tax_account_tax': total_commission_tax_account_tax,
                'total_other': total_other,
                'grand_total': total_cash + total_bank + total_commission + total_commission_tax_account + total_other,
                'grand_total_tax': total_cash_tax + total_bank_tax + total_commission_tax + total_commission_tax_account_tax,
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

        invoice_arap_lines = invoice.line_ids.filtered(
            lambda l: l.account_id.account_type in ('asset_receivable', 'liability_payable')
        )

        if not invoice_arap_lines:
            return result

        payment_moves = self.env['account.move']

        for arap_line in invoice_arap_lines:
            matched_lines = self.env['account.move.line']

            if arap_line.debit > 0:
                for partial in arap_line.matched_credit_ids:
                    matched_lines |= partial.credit_move_id
            else:
                for partial in arap_line.matched_debit_ids:
                    matched_lines |= partial.debit_move_id

            for line in matched_lines:
                if line.move_id and line.move_id.id != invoice.id:
                    payment_moves |= line.move_id

        total_invoice_amount = invoice.amount_total
        total_invoice_tax = invoice.amount_tax

        for payment_move in payment_moves:
            payment_lines = payment_move.line_ids.filtered(
                lambda l: l.account_id.account_type not in ('asset_receivable', 'liability_payable')
                          and l.debit > 0
            )

            for line in payment_lines:
                account_id = line.account_id.id
                amount = line.debit

                if account_id == cash_account_id:
                    result['cash'].append(('cash', amount))
                elif account_id == bank_account_id:
                    result['bank'].append(('bank', amount))
                elif account_id == commission_account_id:
                    result['commission'].append(('commission', amount))
                elif account_id == commission_tax_account_id:
                    result['commission_tax'].append(('commission_tax', amount))
                else:
                    if line.partner_id and line.account_id.account_type == 'expense':
                        result['other'].append({
                            'partner': line.partner_id.name,
                            'partner_id': line.partner_id.id,
                            'account': f"{line.account_id.code} - {line.account_id.name}",
                            'account_id': line.account_id.id,
                            'amount': amount,
                            'date': payment_move.date.strftime('%d/%m/%Y') if payment_move.date else '',
                        })

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

    def _generate_html_report(self, data):
        """إنشاء تقرير HTML محسن بصريًا"""
        purchases = data.get('purchases', {})
        sales = data.get('sales', {})

        # حساب الإحصائيات
        total_invoices = len(purchases['paid']) + len(purchases['unpaid']) + len(sales['invoices'])
        paid_percentage = (len(purchases['paid']) / (len(purchases['paid']) + len(purchases['unpaid'])) * 100) if (
                                                                                                                              len(
                                                                                                                                  purchases[
                                                                                                                                      'paid']) + len(
                                                                                                                          purchases[
                                                                                                                              'unpaid'])) > 0 else 0

        html = f'''
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #2c3e50; background: #f4f7fa; padding: 0; margin: 0;">

        <!-- Top Statistics Cards -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 20px; margin-bottom: 30px;">

            <!-- Card 1: Total Invoices -->
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 25px; border-radius: 15px; box-shadow: 0 8px 20px rgba(102, 126, 234, 0.3); position: relative; overflow: hidden;">
                <div style="position: absolute; right: -20px; top: -20px; font-size: 100px; opacity: 0.15;">📊</div>
                <div style="position: relative; z-index: 1;">
                    <p style="margin: 0; font-size: 14px; opacity: 0.9; text-transform: uppercase; letter-spacing: 1px;">Total Invoices</p>
                    <h2 style="margin: 10px 0 0 0; font-size: 42px; font-weight: 700;">{total_invoices}</h2>
                </div>
            </div>

            <!-- Card 2: Purchases -->
            <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 25px; border-radius: 15px; box-shadow: 0 8px 20px rgba(245, 87, 108, 0.3); position: relative; overflow: hidden;">
                <div style="position: absolute; right: -20px; top: -20px; font-size: 100px; opacity: 0.15;">🛒</div>
                <div style="position: relative; z-index: 1;">
                    <p style="margin: 0; font-size: 14px; opacity: 0.9; text-transform: uppercase; letter-spacing: 1px;">Total Purchases</p>
                    <h2 style="margin: 10px 0 0 0; font-size: 36px; font-weight: 700;">{purchases['grand_total']:,.0f} <span style="font-size: 20px;">AED</span></h2>
                </div>
            </div>

            <!-- Card 3: Sales -->
            <div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; padding: 25px; border-radius: 15px; box-shadow: 0 8px 20px rgba(79, 172, 254, 0.3); position: relative; overflow: hidden;">
                <div style="position: absolute; right: -20px; top: -20px; font-size: 100px; opacity: 0.15;">💰</div>
                <div style="position: relative; z-index: 1;">
                    <p style="margin: 0; font-size: 14px; opacity: 0.9; text-transform: uppercase; letter-spacing: 1px;">Total Sales</p>
                    <h2 style="margin: 10px 0 0 0; font-size: 36px; font-weight: 700;">{sales['grand_total']:,.0f} <span style="font-size: 20px;">AED</span></h2>
                </div>
            </div>

            <!-- Card 4: Payment Rate -->
            <div style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); color: white; padding: 25px; border-radius: 15px; box-shadow: 0 8px 20px rgba(67, 233, 123, 0.3); position: relative; overflow: hidden;">
                <div style="position: absolute; right: -20px; top: -20px; font-size: 100px; opacity: 0.15;">✅</div>
                <div style="position: relative; z-index: 1;">
                    <p style="margin: 0; font-size: 14px; opacity: 0.9; text-transform: uppercase; letter-spacing: 1px;">Payment Rate</p>
                    <h2 style="margin: 10px 0 0 0; font-size: 42px; font-weight: 700;">{paid_percentage:.0f}%</h2>
                </div>
            </div>
        </div>

        <!-- Date Range Info -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px 30px; margin-bottom: 25px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); text-align: center;">
            <p style="margin: 0; font-size: 16px; font-weight: 500;">
                📅 Report Period: <strong style="font-size: 18px;">{self.date_from.strftime('%d %B %Y')}</strong> to <strong style="font-size: 18px;">{self.date_to.strftime('%d %B %Y')}</strong>
            </p>
        </div>

        <!-- ============ PURCHASES SECTION ============ -->
        <div style="background: white; border-radius: 15px; padding: 30px; margin-bottom: 30px; box-shadow: 0 4px 15px rgba(0,0,0,0.08);">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 25px; padding-bottom: 20px; border-bottom: 3px solid #e74c3c;">
                <div style="display: flex; align-items: center; gap: 15px;">
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 26px; box-shadow: 0 4px 10px rgba(231, 76, 60, 0.3);">🛒</div>
                    <div>
                        <h2 style="margin: 0; font-size: 24px; color: #e74c3c; font-weight: 700;">Purchase Invoices</h2>
                        <p style="margin: 5px 0 0 0; color: #7f8c8d; font-size: 13px;">{len(purchases['paid']) + len(purchases['unpaid'])} total invoices</p>
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 28px; font-weight: 700; color: #2c3e50;">{purchases['grand_total']:,.2f} <span style="font-size: 16px; color: #95a5a6;">AED</span></div>
                    <div style="font-size: 12px; color: #95a5a6; margin-top: 3px;">Tax: {purchases['grand_total_tax']:,.2f} AED</div>
                </div>
            </div>

            <!-- Paid Purchases -->
            <div style="margin-bottom: 30px;">
                <div style="background: linear-gradient(90deg, #27ae60 0%, #2ecc71 100%); color: white; padding: 15px 20px; margin-bottom: 15px; border-radius: 10px; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 3px 10px rgba(39, 174, 96, 0.2);">
                    <div style="display: flex; align-items: center; gap: 12px;">
                        <span style="font-size: 24px;">✅</span>
                        <div>
                            <h3 style="margin: 0; font-size: 18px; font-weight: 600;">Paid Purchases</h3>
                            <p style="margin: 3px 0 0 0; font-size: 13px; opacity: 0.9;">{len(purchases['paid'])} invoices paid</p>
                        </div>
                    </div>
                    <div style="text-align: right;">
                        <div style="font-size: 22px; font-weight: 700;">{purchases['total_paid']:,.2f} AED</div>
                        <div style="font-size: 11px; opacity: 0.8;">Tax: {purchases['total_paid_tax']:,.2f}</div>
                    </div>
                </div>
                {self._generate_purchase_table_modern(purchases['paid'], 'paid')}
            </div>

            <!-- Unpaid Purchases -->
            <div style="margin-bottom: 20px;">
                <div style="background: linear-gradient(90deg, #e67e22 0%, #f39c12 100%); color: white; padding: 15px 20px; margin-bottom: 15px; border-radius: 10px; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 3px 10px rgba(230, 126, 34, 0.2);">
                    <div style="display: flex; align-items: center; gap: 12px;">
                        <span style="font-size: 24px;">⏳</span>
                        <div>
                            <h3 style="margin: 0; font-size: 18px; font-weight: 600;">Unpaid Purchases</h3>
                            <p style="margin: 3px 0 0 0; font-size: 13px; opacity: 0.9;">{len(purchases['unpaid'])} invoices pending</p>
                        </div>
                    </div>
                    <div style="text-align: right;">
                        <div style="font-size: 22px; font-weight: 700;">{purchases['total_unpaid']:,.2f} AED</div>
                        <div style="font-size: 11px; opacity: 0.8;">Tax: {purchases['total_unpaid_tax']:,.2f}</div>
                    </div>
                </div>
                {self._generate_purchase_table_modern(purchases['unpaid'], 'unpaid')}
            </div>
        </div>

        <!-- ============ SALES SECTION ============ -->
        <div style="background: white; border-radius: 15px; padding: 30px; margin-bottom: 30px; box-shadow: 0 4px 15px rgba(0,0,0,0.08);">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 25px; padding-bottom: 20px; border-bottom: 3px solid #3498db;">
                <div style="display: flex; align-items: center; gap: 15px;">
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #3498db 0%, #2980b9 100%); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 26px; box-shadow: 0 4px 10px rgba(52, 152, 219, 0.3);">💰</div>
                    <div>
                        <h2 style="margin: 0; font-size: 24px; color: #3498db; font-weight: 700;">Sales Invoices</h2>
                        <p style="margin: 5px 0 0 0; color: #7f8c8d; font-size: 13px;">{len(sales['invoices'])} total invoices</p>
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 28px; font-weight: 700; color: #2c3e50;">{sales['grand_total']:,.2f} <span style="font-size: 16px; color: #95a5a6;">AED</span></div>
                    <div style="font-size: 12px; color: #95a5a6; margin-top: 3px;">Tax: {sales['grand_total_tax']:,.2f} AED</div>
                </div>
            </div>

            <!-- Payment Breakdown Cards -->
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 25px;">
                <div style="background: linear-gradient(135deg, #16a085 0%, #1abc9c 100%); padding: 18px; border-radius: 10px; text-align: center; color: white; box-shadow: 0 3px 10px rgba(22, 160, 133, 0.2);">
                    <div style="font-size: 24px; margin-bottom: 5px;">💵</div>
                    <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">Cash</div>
                    <div style="font-size: 20px; font-weight: 700;">{sales['total_cash']:,.0f}</div>
                </div>
                <div style="background: linear-gradient(135deg, #2980b9 0%, #3498db 100%); padding: 18px; border-radius: 10px; text-align: center; color: white; box-shadow: 0 3px 10px rgba(41, 128, 185, 0.2);">
                    <div style="font-size: 24px; margin-bottom: 5px;">🏦</div>
                    <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">Bank</div>
                    <div style="font-size: 20px; font-weight: 700;">{sales['total_bank']:,.0f}</div>
                </div>
                <div style="background: linear-gradient(135deg, #e67e22 0%, #f39c12 100%); padding: 18px; border-radius: 10px; text-align: center; color: white; box-shadow: 0 3px 10px rgba(230, 126, 34, 0.2);">
                    <div style="font-size: 24px; margin-bottom: 5px;">💳</div>
                    <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">Commission</div>
                    <div style="font-size: 20px; font-weight: 700;">{sales['total_commission']:,.0f}</div>
                </div>
                <div style="background: linear-gradient(135deg, #8e44ad 0%, #9b59b6 100%); padding: 18px; border-radius: 10px; text-align: center; color: white; box-shadow: 0 3px 10px rgba(142, 68, 173, 0.2);">
                    <div style="font-size: 24px; margin-bottom: 5px;">📊</div>
                    <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">C. Tax</div>
                    <div style="font-size: 20px; font-weight: 700;">{sales['total_commission_tax_account']:,.0f}</div>
                </div>
                <div style="background: linear-gradient(135deg, #34495e 0%, #2c3e50 100%); padding: 18px; border-radius: 10px; text-align: center; color: white; box-shadow: 0 3px 10px rgba(52, 73, 94, 0.2);">
                    <div style="font-size: 24px; margin-bottom: 5px;">👥</div>
                    <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">Other</div>
                    <div style="font-size: 20px; font-weight: 700;">{sales['total_other']:,.0f}</div>
                </div>
            </div>

            {self._generate_unified_sales_table_modern(sales['invoices'])}
        </div>

        <!-- ============ OTHER PAYMENTS SECTION ============ -->
        <div style="background: white; border-radius: 15px; padding: 30px; margin-bottom: 30px; box-shadow: 0 4px 15px rgba(0,0,0,0.08);">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 25px; padding-bottom: 20px; border-bottom: 3px solid #9b59b6;">
                <div style="display: flex; align-items: center; gap: 15px;">
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #9b59b6 0%, #8e44ad 100%); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 26px; box-shadow: 0 4px 10px rgba(155, 89, 182, 0.3);">👥</div>
                    <div>
                        <h2 style="margin: 0; font-size: 24px; color: #9b59b6; font-weight: 700;">Other Payments</h2>
                        <p style="margin: 5px 0 0 0; color: #7f8c8d; font-size: 13px;">{len(sales['other_payments'])} total payments</p>
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 28px; font-weight: 700; color: #2c3e50;">{sales['total_other']:,.2f} <span style="font-size: 16px; color: #95a5a6;">AED</span></div>
                </div>
            </div>

            {self._generate_other_payments_table_modern(sales['other_payments'])}
        </div>

        <!-- Footer Info -->
        <div style="background: linear-gradient(135deg, #34495e 0%, #2c3e50 100%); color: white; padding: 20px 30px; border-radius: 12px; text-align: center; box-shadow: 0 4px 15px rgba(0,0,0,0.1);">
            <div style="display: flex; justify-content: space-around; flex-wrap: wrap; gap: 20px;">
                <div>
                    <p style="margin: 0; font-size: 12px; opacity: 0.8; text-transform: uppercase; letter-spacing: 1px;">Generated</p>
                    <p style="margin: 5px 0 0 0; font-size: 15px; font-weight: 600;">{fields.Date.today().strftime('%d %B %Y')} at {datetime.now().strftime("%H:%M")}</p>
                </div>
                <div>
                    <p style="margin: 0; font-size: 12px; opacity: 0.8; text-transform: uppercase; letter-spacing: 1px;">Total Invoices</p>
                    <p style="margin: 5px 0 0 0; font-size: 15px; font-weight: 600;">{total_invoices}</p>
                </div>
                <div>
                    <p style="margin: 0; font-size: 12px; opacity: 0.8; text-transform: uppercase; letter-spacing: 1px;">Period Days</p>
                    <p style="margin: 5px 0 0 0; font-size: 15px; font-weight: 600;">{(self.date_to - self.date_from).days + 1}</p>
                </div>
            </div>
        </div>

        </div>
        '''

        return html

    def _generate_purchase_table_modern(self, invoices, category):
        """إنشاء جدول فواتير المشتريات بتصميم عصري"""
        if not invoices:
            return '<div style="text-align: center; padding: 40px; color: #95a5a6; background: #f8f9fa; border-radius: 10px;"><p style="margin: 0; font-size: 14px;">📭 No invoices found</p></div>'

        html = '''
        <div style="overflow-x: auto; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; background: white;">
            <thead>
                <tr style="background: linear-gradient(90deg, #34495e 0%, #2c3e50 100%); color: white;">
                    <th style="padding: 14px 12px; text-align: left; font-weight: 600; border: none;">Invoice</th>
                    <th style="padding: 14px 12px; text-align: left; font-weight: 600; border: none;">Vendor</th>
                    <th style="padding: 14px 12px; text-align: center; font-weight: 600; border: none;">Date</th>
                    <th style="padding: 14px 12px; text-align: center; font-weight: 600; border: none; font-size: 11px;">Created</th>
                    <th style="padding: 14px 12px; text-align: right; font-weight: 600; border: none;">Untaxed</th>
                    <th style="padding: 14px 12px; text-align: right; font-weight: 600; border: none;">Tax</th>
                    <th style="padding: 14px 12px; text-align: right; font-weight: 600; border: none;">Total</th>
                    <th style="padding: 14px 12px; text-align: center; font-weight: 600; border: none;">Status</th>
                </tr>
            </thead>
            <tbody>
        '''

        for idx, invoice in enumerate(invoices):
            row_bg = '#f8f9fa' if idx % 2 == 0 else 'white'
            status_gradient = 'linear-gradient(90deg, #27ae60 0%, #2ecc71 100%)' if category == 'paid' else 'linear-gradient(90deg, #e67e22 0%, #f39c12 100%)'
            status_icon = '✅' if category == 'paid' else '⏳'

            html += f'''
            <tr style="background: {row_bg}; transition: all 0.2s ease;" onmouseover="this.style.background='#ecf0f1'" onmouseout="this.style.background='{row_bg}'">
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1;">
                    <a href="#" class="oe_link" 
                       data-oe-model="account.move" 
                       data-oe-id="{invoice['id']}"
                       style="color: #667eea; font-weight: 600; text-decoration: none; display: flex; align-items: center; gap: 6px;">
                        📄 {invoice['name']}
                    </a>
                </td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; color: #2c3e50;">
                    <a href="#" class="oe_link" 
                       data-oe-model="res.partner" 
                       data-oe-id="{invoice['partner_id']}"
                       style="color: #34495e; text-decoration: none; font-weight: 500;">
                        {invoice['partner']}
                    </a>
                </td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: center; color: #7f8c8d; font-weight: 500;">{invoice['date']}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: center; font-size: 11px; color: #95a5a6;">{invoice['create_date']}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: right; color: #7f8c8d;">{invoice['amount_untaxed']:,.2f}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: right; color: #95a5a6; font-size: 12px;">{invoice['amount_tax']:,.2f}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #2c3e50; font-size: 14px;">{invoice['amount_total']:,.2f}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: center;">
                    <span style="background: {status_gradient}; color: white; padding: 5px 12px; border-radius: 20px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 4px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);">
                        {status_icon} {invoice['payment_state']}
                    </span>
                </td>
            </tr>
            '''

        html += '</tbody></table></div>'
        return html

    def _generate_unified_sales_table_modern(self, invoices):
        """إنشاء جدول موحد لفواتير المبيعات بتصميم عصري"""
        if not invoices:
            return '<div style="text-align: center; padding: 40px; color: #95a5a6; background: #f8f9fa; border-radius: 10px;"><p style="margin: 0; font-size: 14px;">📭 No invoices found</p></div>'

        html = '''
        <div style="overflow-x: auto; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; background: white;">
            <thead>
                <tr style="background: linear-gradient(90deg, #34495e 0%, #2c3e50 100%); color: white;">
                    <th style="padding: 14px 10px; text-align: left; font-weight: 600; border: none;">Invoice</th>
                    <th style="padding: 14px 10px; text-align: left; font-weight: 600; border: none;">Customer</th>
                    <th style="padding: 14px 10px; text-align: center; font-weight: 600; border: none;">Date</th>
                    <th style="padding: 14px 10px; text-align: center; font-weight: 600; border: none; font-size: 11px;">Created</th>
                    <th style="padding: 14px 8px; text-align: right; font-weight: 600; border: none; background: rgba(22, 160, 133, 0.2);">💵 Cash</th>
                    <th style="padding: 14px 8px; text-align: right; font-weight: 600; border: none; background: rgba(41, 128, 185, 0.2);">🏦 Bank</th>
                    <th style="padding: 14px 8px; text-align: right; font-weight: 600; border: none; background: rgba(230, 126, 34, 0.2);">💳 Comm.</th>
                    <th style="padding: 14px 8px; text-align: right; font-weight: 600; border: none; background: rgba(142, 68, 173, 0.2);">📊 C.Tax</th>
                    <th style="padding: 14px 10px; text-align: right; font-weight: 600; border: none;">Total</th>
                </tr>
            </thead>
            <tbody>
        '''

        for idx, invoice in enumerate(invoices):
            row_bg = '#f8f9fa' if idx % 2 == 0 else 'white'

            html += f'''
            <tr style="background: {row_bg}; transition: all 0.2s ease;" onmouseover="this.style.background='#ecf0f1'" onmouseout="this.style.background='{row_bg}'">
                <td style="padding: 12px 10px; border-bottom: 1px solid #ecf0f1;">
                    <a href="#" class="oe_link" 
                       data-oe-model="account.move" 
                       data-oe-id="{invoice['id']}"
                       style="color: #667eea; font-weight: 600; text-decoration: none; display: flex; align-items: center; gap: 6px;">
                        📄 {invoice['name']}
                    </a>
                </td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #ecf0f1; color: #2c3e50;">
                    <a href="#" class="oe_link" 
                       data-oe-model="res.partner" 
                       data-oe-id="{invoice['partner_id']}"
                       style="color: #34495e; text-decoration: none; font-weight: 500;">
                        {invoice['partner']}
                    </a>
                </td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #ecf0f1; text-align: center; color: #7f8c8d; font-weight: 500;">{invoice['date']}</td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #ecf0f1; text-align: center; font-size: 11px; color: #95a5a6;">{invoice['create_date']}</td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #16a085; background: rgba(22, 160, 133, 0.05);">
                    {invoice.get('cash_amount', 0):,.2f}
                </td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #2980b9; background: rgba(41, 128, 185, 0.05);">
                    {invoice.get('bank_amount', 0):,.2f}
                </td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #e67e22; background: rgba(230, 126, 34, 0.05);">
                    {invoice.get('commission_amount', 0):,.2f}
                </td>
                <td style="padding: 12px 8px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #8e44ad; background: rgba(142, 68, 173, 0.05);">
                    {invoice.get('commission_tax_account_amount', 0):,.2f}
                </td>
                <td style="padding: 12px 10px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #2c3e50; font-size: 14px;">
                    {invoice['amount_total']:,.2f}
                </td>
            </tr>
            '''

        html += '</tbody></table></div>'
        return html

    def _generate_other_payments_table_modern(self, payments):
        """إنشاء جدول Other Payments بتصميم عصري"""
        if not payments:
            return '<div style="text-align: center; padding: 40px; color: #95a5a6; background: #f8f9fa; border-radius: 10px;"><p style="margin: 0; font-size: 14px;">📭 No other payments found</p></div>'

        html = '''
        <div style="overflow-x: auto; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; background: white;">
            <thead>
                <tr style="background: linear-gradient(90deg, #34495e 0%, #2c3e50 100%); color: white;">
                    <th style="padding: 14px 12px; text-align: left; font-weight: 600; border: none;">Invoice</th>
                    <th style="padding: 14px 12px; text-align: left; font-weight: 600; border: none;">Partner</th>
                    <th style="padding: 14px 12px; text-align: left; font-weight: 600; border: none;">Account</th>
                    <th style="padding: 14px 12px; text-align: center; font-weight: 600; border: none;">Date</th>
                    <th style="padding: 14px 12px; text-align: right; font-weight: 600; border: none;">Amount</th>
                </tr>
            </thead>
            <tbody>
        '''

        for idx, payment in enumerate(payments):
            row_bg = '#f8f9fa' if idx % 2 == 0 else 'white'

            html += f'''
            <tr style="background: {row_bg}; transition: all 0.2s ease;" onmouseover="this.style.background='#ecf0f1'" onmouseout="this.style.background='{row_bg}'">
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1;">
                    <a href="#" class="oe_link" 
                       data-oe-model="account.move" 
                       data-oe-id="{payment['invoice_id']}"
                       style="color: #667eea; font-weight: 600; text-decoration: none; display: flex; align-items: center; gap: 6px;">
                        📄 {payment['invoice_name']}
                    </a>
                </td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; color: #2c3e50;">
                    <a href="#" class="oe_link" 
                       data-oe-model="res.partner" 
                       data-oe-id="{payment['partner_id']}"
                       style="color: #34495e; text-decoration: none; font-weight: 500;">
                        {payment['partner']}
                    </a>
                </td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; font-size: 12px; color: #7f8c8d;">
                    {payment['account']}
                </td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: center; color: #7f8c8d; font-weight: 500;">{payment['date']}</td>
                <td style="padding: 12px; border-bottom: 1px solid #ecf0f1; text-align: right; font-weight: 700; color: #9b59b6; font-size: 14px;">
                    {payment['amount']:,.2f}
                </td>
            </tr>
            '''

        html += '</tbody></table></div>'
        return html

    def action_export_excel(self):
        """تصدير إلى Excel"""
        import xlsxwriter
        import io
        import base64

        output = io.BytesIO()
        workbook = xlsxwriter.Workbook(output)

        # التنسيقات
        header_format = workbook.add_format({
            'bold': True,
            'bg_color': '#4472C4',
            'font_color': 'white',
            'border': 1,
            'align': 'center',
        })

        money_format = workbook.add_format({
            'num_format': '#,##0.00',
            'border': 1,
        })

        title_format = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'bg_color': '#D9E1F2',
            'border': 1,
        })

        # جلب البيانات
        data = self.get_report_data()
        purchases = data.get('purchases', {})
        sales = data.get('sales', {})

        # ======= Sheet 1: Purchases =======
        ws_purchase = workbook.add_worksheet('Purchases')

        ws_purchase.write(0, 0, 'PURCHASE INVOICES REPORT', title_format)
        ws_purchase.merge_range(0, 0, 0, 7, 'PURCHASE INVOICES REPORT', title_format)

        # Paid Purchases
        row = 2
        ws_purchase.write(row, 0, 'PAID PURCHASES', title_format)
        row += 1

        headers = ['Invoice', 'Vendor', 'Date', 'Created', 'Untaxed', 'Tax', 'Total', 'Status']
        for col, header in enumerate(headers):
            ws_purchase.write(row, col, header, header_format)
        row += 1

        for invoice in purchases['paid']:
            ws_purchase.write(row, 0, invoice['name'])
            ws_purchase.write(row, 1, invoice['partner'])
            ws_purchase.write(row, 2, invoice['date'])
            ws_purchase.write(row, 3, invoice['create_date'])
            ws_purchase.write(row, 4, invoice['amount_untaxed'], money_format)
            ws_purchase.write(row, 5, invoice['amount_tax'], money_format)
            ws_purchase.write(row, 6, invoice['amount_total'], money_format)
            ws_purchase.write(row, 7, invoice['payment_state'])
            row += 1

        ws_purchase.write(row, 5, 'TOTAL:', header_format)
        ws_purchase.write(row, 6, purchases['total_paid'], money_format)
        row += 2

        # Unpaid Purchases
        ws_purchase.write(row, 0, 'UNPAID PURCHASES', title_format)
        row += 1

        for col, header in enumerate(headers):
            ws_purchase.write(row, col, header, header_format)
        row += 1

        for invoice in purchases['unpaid']:
            ws_purchase.write(row, 0, invoice['name'])
            ws_purchase.write(row, 1, invoice['partner'])
            ws_purchase.write(row, 2, invoice['date'])
            ws_purchase.write(row, 3, invoice['create_date'])
            ws_purchase.write(row, 4, invoice['amount_untaxed'], money_format)
            ws_purchase.write(row, 5, invoice['amount_tax'], money_format)
            ws_purchase.write(row, 6, invoice['amount_total'], money_format)
            ws_purchase.write(row, 7, invoice['payment_state'])
            row += 1

        ws_purchase.write(row, 5, 'TOTAL:', header_format)
        ws_purchase.write(row, 6, purchases['total_unpaid'], money_format)
        row += 2

        ws_purchase.write(row, 5, 'GRAND TOTAL:', header_format)
        ws_purchase.write(row, 6, purchases['grand_total'], money_format)

        # ======= Sheet 2: Sales =======
        ws_sales = workbook.add_worksheet('Sales')

        ws_sales.write(0, 0, 'SALES INVOICES REPORT', title_format)
        ws_sales.merge_range(0, 0, 0, 8, 'SALES INVOICES REPORT', title_format)

        row = 2
        ws_sales.write(row, 0, 'SALES INVOICES', title_format)
        row += 1

        headers = ['Invoice', 'Customer', 'Date', 'Created', 'Cash', 'Bank', 'Commission', 'Comm. Tax', 'Invoice Total']
        for col, header in enumerate(headers):
            ws_sales.write(row, col, header, header_format)
        row += 1

        for invoice in sales['invoices']:
            ws_sales.write(row, 0, invoice['name'])
            ws_sales.write(row, 1, invoice['partner'])
            ws_sales.write(row, 2, invoice['date'])
            ws_sales.write(row, 3, invoice['create_date'])
            ws_sales.write(row, 4, invoice.get('cash_amount', 0), money_format)
            ws_sales.write(row, 5, invoice.get('bank_amount', 0), money_format)
            ws_sales.write(row, 6, invoice.get('commission_amount', 0), money_format)
            ws_sales.write(row, 7, invoice.get('commission_tax_account_amount', 0), money_format)
            ws_sales.write(row, 8, invoice['amount_total'], money_format)
            row += 1

        ws_sales.write(row, 3, 'TOTALS:', header_format)
        ws_sales.write(row, 4, sales['total_cash'], money_format)
        ws_sales.write(row, 5, sales['total_bank'], money_format)
        ws_sales.write(row, 6, sales['total_commission'], money_format)
        ws_sales.write(row, 7, sales['total_commission_tax_account'], money_format)
        row += 2

        ws_sales.write(row, 7, 'GRAND TOTAL:', header_format)
        ws_sales.write(row, 8, sales['grand_total'], money_format)

        # ======= Sheet 3: Other Payments =======
        ws_other = workbook.add_worksheet('Other Payments')

        ws_other.write(0, 0, 'OTHER PAYMENTS', title_format)
        ws_other.merge_range(0, 0, 0, 4, 'OTHER PAYMENTS', title_format)

        row = 2
        headers = ['Invoice', 'Partner', 'Account', 'Date', 'Amount']
        for col, header in enumerate(headers):
            ws_other.write(row, col, header, header_format)
        row += 1

        for payment in sales['other_payments']:
            ws_other.write(row, 0, payment['invoice_name'])
            ws_other.write(row, 1, payment['partner'])
            ws_other.write(row, 2, payment['account'])
            ws_other.write(row, 3, payment['date'])
            ws_other.write(row, 4, payment['amount'], money_format)
            row += 1

        ws_other.write(row, 3, 'TOTAL:', header_format)
        ws_other.write(row, 4, sales['total_other'], money_format)

        # ضبط عرض الأعمدة
        for ws in [ws_purchase, ws_sales, ws_other]:
            ws.set_column('A:A', 15)
            ws.set_column('B:B', 25)
            ws.set_column('C:D', 15)
            ws.set_column('E:H', 12)

        ws_other.set_column('C:C', 35)

        workbook.close()
        output.seek(0)

        # إنشاء attachment
        attachment = self.env['ir.attachment'].create({
            'name': f'daily_invoices_report_{fields.Date.today()}.xlsx',
            'type': 'binary',
            'datas': base64.b64encode(output.read()),
            'mimetype': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        })

        return {
            'type': 'ir.actions.act_url',
            'url': f'/web/content/{attachment.id}?download=true',
            'target': 'new',
        }

    def action_refresh(self):
        """تحديث التقرير"""
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'daily.invoices.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': 'current',
        }