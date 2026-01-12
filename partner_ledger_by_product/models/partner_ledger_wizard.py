from odoo import models, fields, api
from datetime import datetime, timedelta
from collections import defaultdict
import logging

_logger = logging.getLogger(__name__)


class PartnerLedgerWizard(models.TransientModel):
    _name = 'partner.ledger.wizard'
    _description = 'Partner Ledger by Product Wizard'

    date_from = fields.Date('From Date', default=lambda self: datetime.now().replace(day=1), required=True)
    date_to = fields.Date('To Date', default=fields.Date.today(), required=True)
    partner_ids = fields.Many2many('res.partner', string='Partners')
    partner_type = fields.Selection([
        ('customer', 'Customers Only'),
        ('supplier', 'Suppliers Only'),
        ('all', 'All Partners'),
    ], string='Partner Type', default='all', required=True)
    product_ids = fields.Many2many('product.product', string='Products', domain=[('sale_ok', '=', True)])
    search_text = fields.Char('Search')
    report_html = fields.Html('Report Results', compute='_compute_report_html')

    @api.depends('date_from', 'date_to', 'partner_ids', 'partner_type', 'product_ids', 'search_text')
    def _compute_report_html(self):
        for wizard in self:
            data = wizard._get_report_data()
            wizard.report_html = wizard._generate_html_report(data)

    def _get_opening_balance(self, partner_id):
        domain = [
            ('partner_id', '=', partner_id),
            ('state', '=', 'posted'),
        ]

        invoices = self.env['account.move'].search(
            domain + [
                ('move_type', 'in', ['out_invoice', 'in_invoice', 'out_refund', 'in_refund']),
                ('invoice_date', '<', self.date_from)
            ])

        invoice_balance = 0
        for inv in invoices:
            if inv.move_type in ['out_invoice', 'in_refund']:
                invoice_balance += inv.amount_total
            else:
                invoice_balance -= inv.amount_total

        payments = self.env['account.payment'].search(
            domain + [('date', '<', self.date_from)])

        payment_balance = 0
        for pay in payments:
            if pay.payment_type == 'inbound':
                payment_balance -= pay.amount
            elif pay.payment_type == 'outbound':
                payment_balance += pay.amount

        # جمع IDs الـ moves بتاعة الـ payments عشان نستثنيها
        payment_move_ids = payments.mapped('move_id').ids

        # إضافة Journal Entries الأخرى للـ opening balance
        journal_entry_domain = [
            ('partner_id', '=', partner_id),
            ('move_id.state', '=', 'posted'),
            ('date', '<', self.date_from),
            ('account_id.account_type', 'in', ['asset_receivable', 'liability_payable']),
            ('move_id.move_type', '=', 'entry'),
        ]

        # استثناء الـ moves بتاعة الـ payments
        if payment_move_ids:
            journal_entry_domain.append(('move_id', 'not in', payment_move_ids))

        journal_entries = self.env['account.move.line'].search(journal_entry_domain)

        journal_balance = 0
        for je in journal_entries:
            journal_balance += je.debit - je.credit

        return invoice_balance + payment_balance + journal_balance

    def _get_report_data(self):
        self.ensure_one()

        invoice_domain = [
            ('move_type', 'in', ['out_invoice', 'in_invoice', 'out_refund', 'in_refund']),
            ('state', '=', 'posted'),
            ('invoice_date', '>=', self.date_from),
            ('invoice_date', '<=', self.date_to),
        ]

        if self.partner_ids:
            invoice_domain.append(('partner_id', 'in', self.partner_ids.ids))
        elif self.partner_type == 'customer':
            invoice_domain.append(('partner_id.customer_rank', '>', 0))
            invoice_domain.append(('move_type', 'in', ['out_invoice', 'out_refund']))
        elif self.partner_type == 'supplier':
            invoice_domain.append(('partner_id.supplier_rank', '>', 0))
            invoice_domain.append(('move_type', 'in', ['in_invoice', 'in_refund']))

        invoices = self.env['account.move'].search(invoice_domain, order='invoice_date, name')

        # تصحيح الحالة - في Odoo 18 الحالة هي 'paid' مش 'posted'
        payment_domain = [
            ('state', 'in', ['posted', 'paid']),  # نستخدم الاتنين للأمان
            ('date', '>=', self.date_from),
            ('date', '<=', self.date_to),
            ('partner_id', '!=', False),
        ]

        if self.partner_ids:
            payment_domain.append(('partner_id', 'in', self.partner_ids.ids))
        elif self.partner_type == 'customer':
            payment_domain.append(('partner_id.customer_rank', '>', 0))
            payment_domain.append(('partner_type', '=', 'customer'))
        elif self.partner_type == 'supplier':
            payment_domain.append(('partner_id.supplier_rank', '>', 0))
            payment_domain.append(('partner_type', '=', 'supplier'))

        payments = self.env['account.payment'].search(payment_domain, order='date, name')

        # جمع IDs الـ moves بتاعة الـ payments عشان نستثنيها
        payment_move_ids = payments.mapped('move_id').ids

        # جلب الـ Journal Entries الأخرى (غير الفواتير والدفعات)
        journal_entry_domain = [
            ('move_id.state', '=', 'posted'),
            ('date', '>=', self.date_from),
            ('date', '<=', self.date_to),
            ('partner_id', '!=', False),
            ('account_id.account_type', 'in', ['asset_receivable', 'liability_payable']),
            ('move_id.move_type', '=', 'entry'),  # فقط Journal Entries العادية
        ]

        # استثناء الـ moves بتاعة الـ payments
        if payment_move_ids:
            journal_entry_domain.append(('move_id', 'not in', payment_move_ids))

        if self.partner_ids:
            journal_entry_domain.append(('partner_id', 'in', self.partner_ids.ids))
        elif self.partner_type == 'customer':
            journal_entry_domain.append(('partner_id.customer_rank', '>', 0))
            journal_entry_domain.append(('account_id.account_type', '=', 'asset_receivable'))
        elif self.partner_type == 'supplier':
            journal_entry_domain.append(('partner_id.supplier_rank', '>', 0))
            journal_entry_domain.append(('account_id.account_type', '=', 'liability_payable'))

        journal_entries = self.env['account.move.line'].search(journal_entry_domain, order='date, move_id')

        _logger.info(
            f"Found {len(invoices)} invoices, {len(payments)} payments, and {len(journal_entries)} journal entries")

        if payments:
            _logger.info(f"Payment details: {[(p.name, p.partner_id.name, p.amount, p.state) for p in payments[:5]]}")
        else:
            _logger.warning(f"No payments found with domain: {payment_domain}")

        if not invoices and not payments and not journal_entries:
            return {'summary': {}, 'rows': []}

        partner_data = self._process_partner_transactions(invoices, payments, journal_entries)
        return partner_data

    def _process_partner_transactions(self, invoices, payments, journal_entries):
        partner_dict = defaultdict(lambda: {
            'partner_name': '',
            'partner_id': 0,
            'opening_balance': 0,
            'transactions': [],
            'closing_balance': 0,
        })

        all_partners = set()
        for inv in invoices:
            all_partners.add(inv.partner_id.id)
        for pay in payments:
            all_partners.add(pay.partner_id.id)
        for je in journal_entries:
            all_partners.add(je.partner_id.id)

        for partner_id in all_partners:
            partner = self.env['res.partner'].browse(partner_id)
            partner_dict[partner_id]['partner_name'] = partner.name
            partner_dict[partner_id]['partner_id'] = partner_id
            opening_balance = self._get_opening_balance(partner_id)
            partner_dict[partner_id]['opening_balance'] = opening_balance

            transactions = []

            partner_invoices = invoices.filtered(lambda i: i.partner_id.id == partner_id)
            for invoice in partner_invoices:
                transactions.extend(self._process_invoice(invoice))

            partner_payments = payments.filtered(lambda p: p.partner_id.id == partner_id)
            for payment in partner_payments:
                transactions.append(self._process_payment(payment))

            partner_journal_entries = journal_entries.filtered(lambda j: j.partner_id.id == partner_id)
            for journal_entry in partner_journal_entries:
                transactions.append(self._process_journal_entry(journal_entry))

            transactions.sort(key=lambda x: (x['date'], x['doc_number']))

            running_balance = opening_balance
            for trans in transactions:
                running_balance += trans['current_dr'] - trans['current_cr']
                trans['balance'] = running_balance

            partner_dict[partner_id]['transactions'] = transactions
            partner_dict[partner_id]['closing_balance'] = running_balance

        return self._format_report_data(partner_dict)

    def _process_invoice(self, invoice):
        transactions = []
        invoice_lines = invoice.invoice_line_ids.filtered(lambda l: l.product_id)

        if self.product_ids:
            invoice_lines = invoice_lines.filtered(lambda l: l.product_id.id in self.product_ids.ids)

        if self.search_text:
            search_terms = self.search_text.lower().split()

            def matches_search(line):
                searchable = ' '.join([
                    line.product_id.name or '',
                    line.product_id.default_code or '',
                    invoice.partner_id.name or '',
                ]).lower()
                return all(term in searchable for term in search_terms)

            invoice_lines = invoice_lines.filtered(matches_search)

        if not invoice_lines:
            return transactions

        is_out_invoice = invoice.move_type in ['out_invoice', 'in_refund']
        total_amount = sum(line.price_total for line in invoice_lines)
        current_dr = total_amount if is_out_invoice else 0
        current_cr = total_amount if not is_out_invoice else 0

        main_row = {
            'is_header': True,
            'is_payment': False,
            'is_customer_invoice': is_out_invoice,  # جديد
            'is_supplier_invoice': not is_out_invoice,  # جديد
            'date': invoice.invoice_date,
            'doc_type': 'Invoice',
            'doc_number': invoice.name,
            'supplier_customer': invoice.partner_id.name,
            'current_dr': current_dr,
            'current_cr': current_cr,
            'balance': 0,
            'lines': []
        }

        for line in invoice_lines:
            target_master = ''
            try:
                if hasattr(line.product_id.product_tmpl_id, 'remark_type_id'):
                    if line.product_id.product_tmpl_id.remark_type_id:
                        target_master = line.product_id.product_tmpl_id.remark_type_id.name
            except:
                pass

            line_data = {
                'is_detail': True,
                'product_code': line.product_id.default_code or '',
                'product_name': line.product_id.name or '',
                'target_master': target_master,
                'quantity': line.quantity,
                'rate': line.price_unit,
                'foreign_amount': line.price_total,
                'ledger_account': line.account_id.code + ' - ' + line.account_id.name if line.account_id else '',
            }
            main_row['lines'].append(line_data)

        transactions.append(main_row)
        return transactions

    def _process_payment(self, payment):
        is_inbound = payment.payment_type == 'inbound'
        doc_type = 'Cash Receipt' if is_inbound else 'Cash Payment'
        payment_details = f"{payment.journal_id.name}"

        # في Odoo 18، الـ ref موجود لكن ممكن يكون فاضي
        if hasattr(payment, 'ref') and payment.ref:
            payment_details += f" - Ref: {payment.ref}"

        transaction = {
            'is_header': True,
            'is_payment': True,
            'date': payment.date,
            'doc_type': doc_type,
            'doc_number': payment.name,
            'supplier_customer': payment.partner_id.name,
            'current_dr': 0 if is_inbound else payment.amount,
            'current_cr': payment.amount if is_inbound else 0,
            'balance': 0,
            'lines': [{
                'is_detail': True,
                'product_name': payment_details,
                'target_master': '',
                'quantity': 0,
                'rate': 0,
                'foreign_amount': payment.amount,
                'ledger_account': payment.destination_account_id.code + ' - ' + payment.destination_account_id.name if payment.destination_account_id else '',
            }]
        }

        return transaction

    def _process_journal_entry(self, move_line):
        """معالجة Journal Entry (غير الفواتير والدفعات)"""
        is_debit = move_line.debit > 0
        doc_type = 'Journal Entry'

        # تفاصيل الـ Journal Entry
        entry_details = f"{move_line.move_id.journal_id.name}"
        if move_line.name and move_line.name != '/':
            entry_details += f" - {move_line.name}"
        if move_line.move_id.ref:
            entry_details += f" | Ref: {move_line.move_id.ref}"

        transaction = {
            'is_header': True,
            'is_payment': False,
            'is_journal_entry': True,
            'is_customer_invoice': False,
            'is_supplier_invoice': False,
            'date': move_line.date,
            'doc_type': doc_type,
            'doc_number': move_line.move_id.name,
            'supplier_customer': move_line.partner_id.name,
            'current_dr': move_line.debit,
            'current_cr': move_line.credit,
            'balance': 0,
            'lines': [{
                'is_detail': True,
                'product_name': entry_details,
                'target_master': '',
                'quantity': 0,
                'rate': 0,
                'foreign_amount': move_line.debit or move_line.credit,
                'ledger_account': move_line.account_id.code + ' - ' + move_line.account_id.name if move_line.account_id else '',
            }]
        }

        return transaction

    def _format_report_data(self, partner_dict):
        rows = []
        total_debit = 0
        total_credit = 0

        for partner_id, data in sorted(partner_dict.items(), key=lambda x: x[1]['partner_name']):
            # إضافة partner header
            rows.append({
                'is_partner_header': True,
                'partner_name': data['partner_name'],
            })

            if data['opening_balance'] != 0:
                rows.append({
                    'is_opening': True,
                    'doc_date': self.date_from.strftime('%d %B %Y'),
                    'doc_number': 'OPENING BALANCE',
                    'supplier_customer': data['partner_name'],
                    'current_dr': data['opening_balance'] if data['opening_balance'] > 0 else 0,
                    'current_cr': abs(data['opening_balance']) if data['opening_balance'] < 0 else 0,
                    'balance_dr': data['opening_balance'] if data['opening_balance'] > 0 else 0,
                    'balance_cr': abs(data['opening_balance']) if data['opening_balance'] < 0 else 0,
                })

            for trans in data['transactions']:
                balance = trans['balance']
                row = {
                    'is_header': True,
                    'is_payment': trans.get('is_payment', False),
                    'doc_date': trans['date'].strftime('%d %B %Y'),
                    'doc_number': trans['doc_number'],
                    'doc_type': trans.get('doc_type', ''),
                    'supplier_customer': trans['supplier_customer'],
                    'current_dr': trans['current_dr'],
                    'current_cr': trans['current_cr'],
                    'balance_dr': balance if balance >= 0 else 0,
                    'balance_cr': abs(balance) if balance < 0 else 0,
                }
                rows.append(row)

                total_debit += trans['current_dr']
                total_credit += trans['current_cr']

                for line in trans.get('lines', []):
                    rows.append(line)

            closing_balance = data['closing_balance']
            rows.append({
                'is_closing': True,
                'doc_date': self.date_to.strftime('%d %B %Y'),
                'doc_number': 'CLOSING BALANCE',
                'supplier_customer': data['partner_name'],
                'current_dr': closing_balance if closing_balance > 0 else 0,
                'current_cr': abs(closing_balance) if closing_balance < 0 else 0,
                'balance_dr': closing_balance if closing_balance > 0 else 0,
                'balance_cr': abs(closing_balance) if closing_balance < 0 else 0,
            })

            rows.append({'is_separator': True})

        summary = {
            'partners': len(partner_dict),
            'transactions': len([r for r in rows if r.get('is_header')]),
            'total_debit': total_debit,
            'total_credit': total_credit,
        }

        return {'summary': summary, 'rows': rows}

    def _generate_html_report(self, data):
        if not data or not data.get('rows'):
            return '<div style="text-align:center; padding:50px; color:#999;">No transactions found</div>'

        summary = data.get('summary', {})
        rows = data.get('rows', [])

        html = f'''
        <style>
            .ledger-table {{ width: 100%; border-collapse: collapse; font-size: 11px; }}
            .ledger-table th {{ background: #2c3e50; color: white; padding: 10px 5px; text-align: center; font-weight: 600; border: 1px solid #34495e; }}
            .ledger-table td {{ padding: 6px 5px; border: 1px solid #ddd; }}
            .header-row {{ background: #ecf0f1; font-weight: bold; }}
            .customer-invoice-row {{ background: #d4edda; font-weight: bold; border-left: 4px solid #28a745; }}
            .supplier-invoice-row {{ background: #d1ecf1; font-weight: bold; border-left: 4px solid #17a2b8; }}
            .payment-row {{ background: #e8f5e9; font-weight: bold; border-left: 4px solid #4caf50; }}
            .journal-entry-row {{ background: #fff3cd; font-weight: bold; border-left: 4px solid #ffc107; }}
            .detail-row {{ background: #f8f9fa; }}
            .opening-row {{ background: #d5f4e6; font-weight: bold; }}
            .closing-row {{ background: #fce4e4; font-weight: bold; }}
            .separator-row {{ height: 20px; background: transparent; border: none; }}
            .partner-header-row {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; font-weight: bold; font-size: 13px; padding: 12px 8px !important; border: none; }}
            .partner-header-row td {{ padding: 12px 8px !important; border: none !important; }}
            .text-right {{ text-align: right; }}
            .text-center {{ text-align: center; }}
        </style>

        <div style="margin-bottom: 20px;">
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('partners', 0)}</div>
                    <div style="font-size: 13px; opacity: 0.9;">Partners</div>
                </div>
                <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('transactions', 0)}</div>
                    <div style="font-size: 13px; opacity: 0.9;">Transactions</div>
                </div>
                <div style="background: linear-gradient(135deg, #667eea 0%, #4e54c8 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_debit', 0):,.2f}</div>
                    <div style="font-size: 13px; opacity: 0.9;">Total Debit</div>
                </div>
                <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 20px; border-radius: 10px;">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total_credit', 0):,.2f}</div>
                    <div style="font-size: 13px; opacity: 0.9;">Total Credit</div>
                </div>
            </div>
        </div>

        <div style="overflow-x: auto;">
        <table class="ledger-table">
            <thead>
                <tr>
                    <th rowspan="2" style="width: 8%;">Document<br/>Date</th>
                    <th rowspan="2" style="width: 10%;">Document</th>
                    <th rowspan="2" style="width: 12%;">Supplier /<br/>Customer</th>
                    <th colspan="2" style="border-bottom: 1px solid #34495e;">Current<br/>Amount</th>
                    <th colspan="2" style="border-bottom: 1px solid #34495e;">Closing<br/>Amount</th>
                    <th rowspan="2" style="width: 15%;">Target Master</th>
                    <th rowspan="2" style="width: 8%;">Base<br/>Quantity</th>
                    <th rowspan="2" style="width: 8%;">Rate</th>
                    <th rowspan="2" style="width: 10%;">Foreign Detail<br/>Amount</th>
                    <th rowspan="2" style="width: 15%;">Ledger Account</th>
                </tr>
                <tr>
                    <th style="width: 7%; border-top: 1px solid #34495e;">(Dr)</th>
                    <th style="width: 7%; border-top: 1px solid #34495e;">(Cr)</th>
                    <th style="width: 7%; border-top: 1px solid #34495e;">(Gross)</th>
                    <th style="width: 7%; border-top: 1px solid #34495e;">$</th>
                </tr>
            </thead>
            <tbody>
        '''

        for row in rows:
            if row.get('is_partner_header'):
                html += f'''
                <tr class="partner-header-row">
                    <td colspan="12" style="text-align: left; font-size: 14px;">
                        <span style="font-size: 16px;">👤</span> <strong>Partner:</strong> {row.get('partner_name', '')}
                    </td>
                </tr>
                '''
                continue

            if row.get('is_separator'):
                html += '<tr class="separator-row"><td colspan="12"></td></tr>'
                continue

            if row.get('is_opening'):
                balance_dr = row.get('balance_dr', 0)
                balance_cr = row.get('balance_cr', 0)
                balance_dr_text = f"{balance_dr:,.2f} Dr" if balance_dr > 0 else ""
                balance_cr_text = f"{balance_cr:,.2f} Cr" if balance_cr > 0 else ""
                html += f'''
                <tr class="opening-row">
                    <td class="text-center">{row.get('doc_date', '')}</td>
                    <td><strong>{row.get('doc_number', '')}</strong></td>
                    <td>{row.get('supplier_customer', '')}</td>
                    <td class="text-right">{row.get('current_dr', 0):,.2f}</td>
                    <td class="text-right">{row.get('current_cr', 0):,.2f}</td>
                    <td class="text-right">{balance_dr_text}</td>
                    <td class="text-right">{balance_cr_text}</td>
                    <td colspan="5"></td>
                </tr>
                '''
            elif row.get('is_closing'):
                balance_dr = row.get('balance_dr', 0)
                balance_cr = row.get('balance_cr', 0)
                balance_dr_text = f"{balance_dr:,.2f} Dr" if balance_dr > 0 else ""
                balance_cr_text = f"{balance_cr:,.2f} Cr" if balance_cr > 0 else ""
                html += f'''
                <tr class="closing-row">
                    <td class="text-center">{row.get('doc_date', '')}</td>
                    <td><strong>{row.get('doc_number', '')}</strong></td>
                    <td>{row.get('supplier_customer', '')}</td>
                    <td class="text-right">{row.get('current_dr', 0):,.2f}</td>
                    <td class="text-right">{row.get('current_cr', 0):,.2f}</td>
                    <td class="text-right"><strong>{balance_dr_text}</strong></td>
                    <td class="text-right"><strong>{balance_cr_text}</strong></td>
                    <td colspan="5"></td>
                </tr>
                '''
            elif row.get('is_header'):
                if row.get('is_payment'):
                    row_class = 'payment-row'
                elif row.get('is_journal_entry'):
                    row_class = 'journal-entry-row'
                elif row.get('is_customer_invoice'):
                    row_class = 'customer-invoice-row'
                elif row.get('is_supplier_invoice'):
                    row_class = 'supplier-invoice-row'
                else:
                    row_class = 'header-row'
                balance_dr = row.get('balance_dr', 0)
                balance_cr = row.get('balance_cr', 0)
                balance_dr_text = f"{balance_dr:,.2f} Dr" if balance_dr > 0 else ""
                balance_cr_text = f"{balance_cr:,.2f} Cr" if balance_cr > 0 else ""
                html += f'''
                <tr class="{row_class}">
                    <td class="text-center">{row.get('doc_date', '')}</td>
                    <td>{'💵 ' if row.get('is_payment') else ''}{'📝 ' if row.get('is_journal_entry') else ''}{row.get('doc_number', '')}</td>
                    <td>{row.get('supplier_customer', '')}</td>
                    <td class="text-right">{row.get('current_dr', 0):,.2f}</td>
                    <td class="text-right">{row.get('current_cr', 0):,.2f}</td>
                    <td class="text-right">{balance_dr_text}</td>
                    <td class="text-right">{balance_cr_text}</td>
                    <td colspan="5"></td>
                </tr>
                '''
            elif row.get('is_detail'):
                html += f'''
                <tr class="detail-row">
                    <td colspan="7"></td>
                    <td style="padding-left: 15px;">{row.get('product_code', '')} {row.get('product_name', '')}<br/><small style="color: #666;">{row.get('target_master', '')}</small></td>
                    <td class="text-right">{row.get('quantity', 0):,.2f}</td>
                    <td class="text-right">{row.get('rate', 0):,.2f}</td>
                    <td class="text-right">{row.get('foreign_amount', 0):,.2f}</td>
                    <td><small>{row.get('ledger_account', '')}</small></td>
                </tr>
                '''

        html += f'''
            </tbody>
        </table>
        </div>
        <div style="margin-top: 20px; padding: 15px; background: #ecf0f1; border-radius: 8px;">
            <p style="margin: 0; color: #7f8c8d; font-size: 12px;">
                Report Period: <strong>{self.date_from.strftime('%d/%m/%Y')} to {self.date_to.strftime('%d/%m/%Y')}</strong> | 
                Generated: <strong>{fields.Datetime.now().strftime('%d/%m/%Y %H:%M')}</strong>
            </p>
        </div>
        '''

        return html

    def action_export_excel(self):
        import xlsxwriter
        import io
        import base64

        data = self._get_report_data()
        if not data or not data.get('rows'):
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {'message': 'No data to export', 'type': 'warning'}
            }

        output = io.BytesIO()
        workbook = xlsxwriter.Workbook(output)
        worksheet = workbook.add_worksheet('Partner Ledger')

        header_format = workbook.add_format(
            {'bold': True, 'bg_color': '#2c3e50', 'font_color': 'white', 'border': 1, 'align': 'center'})
        partner_header_format = workbook.add_format(
            {'bold': True, 'bg_color': '#667eea', 'font_color': 'white', 'border': 1, 'align': 'left', 'font_size': 12})
        opening_format = workbook.add_format({'bold': True, 'bg_color': '#d5f4e6', 'border': 1})
        closing_format = workbook.add_format({'bold': True, 'bg_color': '#fce4e4', 'border': 1})
        payment_format = workbook.add_format({'bold': True, 'bg_color': '#e8f5e9', 'border': 1})
        journal_entry_format = workbook.add_format({'bold': True, 'bg_color': '#fff3cd', 'border': 1})
        money_format = workbook.add_format({'num_format': '#,##0.00', 'border': 1})

        headers = ['Document Date', 'Document', 'Supplier/Customer', 'Current (Dr)', 'Current (Cr)',
                   'Closing (Gross)', 'Closing ($)', 'Target Master', 'Base Quantity', 'Rate',
                   'Foreign Detail Amount', 'Ledger Account']

        row = 0
        for col, header in enumerate(headers):
            worksheet.write(row, col, header, header_format)

        row = 1
        rows = data.get('rows', [])

        for data_row in rows:
            if data_row.get('is_partner_header'):
                worksheet.merge_range(row, 0, row, 11, f"Partner: {data_row.get('partner_name', '')}",
                                      partner_header_format)
                row += 1
                continue

            if data_row.get('is_separator'):
                row += 1
                continue

            if data_row.get('is_opening') or data_row.get('is_closing'):
                fmt = opening_format if data_row.get('is_opening') else closing_format
                balance_dr = data_row.get('balance_dr', 0)
                balance_cr = data_row.get('balance_cr', 0)
                balance_dr_text = f"{balance_dr:,.2f} Dr" if balance_dr > 0 else ""
                balance_cr_text = f"{balance_cr:,.2f} Cr" if balance_cr > 0 else ""
                worksheet.write(row, 0, data_row.get('doc_date', ''), fmt)
                worksheet.write(row, 1, data_row.get('doc_number', ''), fmt)
                worksheet.write(row, 2, data_row.get('supplier_customer', ''), fmt)
                worksheet.write(row, 3, data_row.get('current_dr', 0), money_format)
                worksheet.write(row, 4, data_row.get('current_cr', 0), money_format)
                worksheet.write(row, 5, balance_dr_text, fmt)
                worksheet.write(row, 6, balance_cr_text, fmt)
                row += 1
            elif data_row.get('is_header'):
                if data_row.get('is_payment'):
                    fmt = payment_format
                elif data_row.get('is_journal_entry'):
                    fmt = journal_entry_format
                else:
                    fmt = money_format
                balance_dr = data_row.get('balance_dr', 0)
                balance_cr = data_row.get('balance_cr', 0)
                balance_dr_text = f"{balance_dr:,.2f} Dr" if balance_dr > 0 else ""
                balance_cr_text = f"{balance_cr:,.2f} Cr" if balance_cr > 0 else ""
                worksheet.write(row, 0, data_row.get('doc_date', ''))
                worksheet.write(row, 1, data_row.get('doc_number', ''))
                worksheet.write(row, 2, data_row.get('supplier_customer', ''))
                worksheet.write(row, 3, data_row.get('current_dr', 0), fmt)
                worksheet.write(row, 4, data_row.get('current_cr', 0), fmt)
                worksheet.write(row, 5, balance_dr_text, fmt)
                worksheet.write(row, 6, balance_cr_text, fmt)
                row += 1
            elif data_row.get('is_detail'):
                worksheet.write(row, 7, f"{data_row.get('product_code', '')} {data_row.get('product_name', '')}")
                worksheet.write(row, 8, data_row.get('quantity', 0), money_format)
                worksheet.write(row, 9, data_row.get('rate', 0), money_format)
                worksheet.write(row, 10, data_row.get('foreign_amount', 0), money_format)
                worksheet.write(row, 11, data_row.get('ledger_account', ''))
                row += 1

        workbook.close()
        output.seek(0)

        attachment = self.env['ir.attachment'].create({
            'name': f'partner_ledger_{fields.Date.today()}.xlsx',
            'type': 'binary',
            'datas': base64.b64encode(output.read()),
            'mimetype': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        })

        return {
            'type': 'ir.actions.act_url',
            'url': f'/web/content/{attachment.id}?download=true',
            'target': 'new',
        }