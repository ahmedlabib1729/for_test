# -*- coding: utf-8 -*-
import io
import json
from datetime import datetime
from odoo import http
from odoo.http import request, content_disposition


class DailyInvoicesExportController(http.Controller):
    
    @http.route('/daily_invoices/export_excel', type='http', auth='user', methods=['GET'])
    def export_excel(self, date_from=None, date_to=None, **kwargs):
        """Export daily invoices report to Excel with professional formatting"""
        
        try:
            import xlsxwriter
        except ImportError:
            return request.make_response(
                json.dumps({'error': 'xlsxwriter library not installed'}),
                headers=[('Content-Type', 'application/json')]
            )
        
        # Get report data
        dashboard = request.env['daily.invoices.dashboard']
        data = dashboard.get_report_data(date_from, date_to)
        
        # Create Excel file in memory
        output = io.BytesIO()
        workbook = xlsxwriter.Workbook(output, {'in_memory': True})
        
        # Define styles
        styles = self._create_styles(workbook)
        
        # Create Summary Sheet
        self._create_summary_sheet(workbook, styles, data, date_from, date_to)
        
        # Create Purchases Sheet
        self._create_purchases_sheet(workbook, styles, data)
        
        # Create Sales Sheet
        self._create_sales_sheet(workbook, styles, data)
        
        # Create Other Payments Sheet
        if data.get('sales', {}).get('other_payments'):
            self._create_other_payments_sheet(workbook, styles, data)
        
        workbook.close()
        output.seek(0)
        
        # Generate filename
        filename = f"Daily_Report_{date_from}_to_{date_to}.xlsx"
        
        return request.make_response(
            output.read(),
            headers=[
                ('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                ('Content-Disposition', content_disposition(filename)),
            ]
        )
    
    def _create_styles(self, workbook):
        """Create all styles for the workbook"""
        styles = {}
        
        # Title style
        styles['title'] = workbook.add_format({
            'bold': True,
            'font_size': 20,
            'font_color': '#FFFFFF',
            'bg_color': '#2C3E50',
            'align': 'center',
            'valign': 'vcenter',
            'border': 0,
        })
        
        # Subtitle style
        styles['subtitle'] = workbook.add_format({
            'bold': True,
            'font_size': 12,
            'font_color': '#7F8C8D',
            'align': 'center',
            'valign': 'vcenter',
        })
        
        # Section header - Purchases (Red theme)
        styles['section_purchases'] = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#E74C3C',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#C0392B',
        })
        
        # Section header - Sales (Green theme)
        styles['section_sales'] = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#27AE60',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#1E8449',
        })
        
        # Section header - Cash (Teal theme)
        styles['section_cash'] = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#00B894',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        
        # Section header - Bank (Blue theme)
        styles['section_bank'] = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#0984E3',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        
        # Table header
        styles['header'] = workbook.add_format({
            'bold': True,
            'font_size': 11,
            'font_color': '#FFFFFF',
            'bg_color': '#34495E',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#2C3E50',
            'text_wrap': True,
        })
        
        # Table header - Arabic
        styles['header_ar'] = workbook.add_format({
            'bold': True,
            'font_size': 10,
            'font_color': '#BDC3C7',
            'bg_color': '#34495E',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#2C3E50',
        })
        
        # Normal cell
        styles['cell'] = workbook.add_format({
            'font_size': 10,
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
        })
        
        # Cell left aligned (for text)
        styles['cell_left'] = workbook.add_format({
            'font_size': 10,
            'align': 'left',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
        })
        
        # Number cell
        styles['number'] = workbook.add_format({
            'font_size': 10,
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
            'num_format': '#,##0.00',
        })
        
        # Total row - Purchases
        styles['total_purchases'] = workbook.add_format({
            'bold': True,
            'font_size': 11,
            'font_color': '#FFFFFF',
            'bg_color': '#E74C3C',
            'align': 'center',
            'valign': 'vcenter',
            'border': 2,
            'border_color': '#C0392B',
            'num_format': '#,##0.00',
        })
        
        # Total row - Sales
        styles['total_sales'] = workbook.add_format({
            'bold': True,
            'font_size': 11,
            'font_color': '#FFFFFF',
            'bg_color': '#27AE60',
            'align': 'center',
            'valign': 'vcenter',
            'border': 2,
            'border_color': '#1E8449',
            'num_format': '#,##0.00',
        })
        
        # Summary card styles
        styles['summary_card_header'] = workbook.add_format({
            'bold': True,
            'font_size': 11,
            'font_color': '#2C3E50',
            'bg_color': '#ECF0F1',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        
        styles['summary_card_value'] = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#2C3E50',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'num_format': '#,##0.00',
        })
        
        # Cash In (Green)
        styles['cash_in'] = workbook.add_format({
            'font_size': 10,
            'font_color': '#27AE60',
            'align': 'center',
            'valign': 'vcenter',
            'num_format': '#,##0.00',
        })
        
        # Cash Out (Red)
        styles['cash_out'] = workbook.add_format({
            'font_size': 10,
            'font_color': '#E74C3C',
            'align': 'center',
            'valign': 'vcenter',
            'num_format': '#,##0.00',
        })
        
        # Paid status
        styles['paid'] = workbook.add_format({
            'font_size': 10,
            'font_color': '#FFFFFF',
            'bg_color': '#27AE60',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        
        # Unpaid status
        styles['unpaid'] = workbook.add_format({
            'font_size': 10,
            'font_color': '#FFFFFF',
            'bg_color': '#E74C3C',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        
        # Alternate row
        styles['cell_alt'] = workbook.add_format({
            'font_size': 10,
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
            'bg_color': '#F8F9FA',
        })
        
        styles['cell_left_alt'] = workbook.add_format({
            'font_size': 10,
            'align': 'left',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
            'bg_color': '#F8F9FA',
        })
        
        styles['number_alt'] = workbook.add_format({
            'font_size': 10,
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
            'border_color': '#BDC3C7',
            'bg_color': '#F8F9FA',
            'num_format': '#,##0.00',
        })
        
        return styles
    
    def _create_summary_sheet(self, workbook, styles, data, date_from, date_to):
        """Create the summary sheet"""
        sheet = workbook.add_worksheet('📊 Summary')
        sheet.set_column('A:A', 5)
        sheet.set_column('B:G', 20)
        sheet.set_row(0, 40)
        sheet.set_row(1, 25)
        
        # Title
        sheet.merge_range('B1:G1', '📊 Daily Invoices Report - تقرير الفواتير اليومي', styles['title'])
        sheet.merge_range('B2:G2', f'From: {date_from}  To: {date_to}', styles['subtitle'])
        
        row = 4
        
        # Report Totals Section
        sheet.merge_range(row, 1, row, 6, '📈 Report Totals - إجماليات التقرير', styles['section_purchases'])
        row += 2
        
        # Cards row
        totals = data.get('totals', {})
        cards = [
            ('Total Invoices\nإجمالي الفواتير', totals.get('total_invoices', 0)),
            ('Total Purchases\nإجمالي المشتريات', totals.get('purchases_total', 0)),
            ('Total Sales\nإجمالي المبيعات', totals.get('sales_total', 0)),
            ('Payment Rate\nنسبة السداد', f"{totals.get('paid_percentage', 0):.1f}%"),
        ]
        
        col = 1
        for label, value in cards:
            sheet.write(row, col, label, styles['summary_card_header'])
            if isinstance(value, str):
                sheet.write(row + 1, col, value, styles['summary_card_value'])
            else:
                sheet.write(row + 1, col, value, styles['summary_card_value'])
            col += 1
        
        row += 4
        
        # Payment Summary Section
        sheet.merge_range(row, 1, row, 6, '💰 Payment Summary - ملخص المدفوعات', styles['section_sales'])
        row += 2
        
        payment = data.get('payment_summary', {})
        
        # Net Cash Card
        sheet.write(row, 1, 'Net Cash\nصافي الكاش', styles['section_cash'])
        sheet.write(row + 1, 1, payment.get('net_cash', 0), styles['summary_card_value'])
        sheet.write(row + 2, 1, f"▲ In: {payment.get('cash_in', 0):,.2f}", styles['cash_in'])
        sheet.write(row + 3, 1, f"▼ Out: {payment.get('cash_out', 0):,.2f}", styles['cash_out'])
        
        # Net Bank Card
        sheet.write(row, 2, 'Net Bank\nصافي البنك', styles['section_bank'])
        sheet.write(row + 1, 2, payment.get('net_bank', 0), styles['summary_card_value'])
        sheet.write(row + 2, 2, f"▲ In: {payment.get('bank_in', 0):,.2f}", styles['cash_in'])
        sheet.write(row + 3, 2, f"▼ Out: {payment.get('bank_out', 0):,.2f}", styles['cash_out'])
        
        # Commission Card
        commission_style = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#F39C12',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        sheet.write(row, 3, 'Commission\nالعمولة', commission_style)
        sheet.write(row + 1, 3, payment.get('total_commission', 0), styles['summary_card_value'])
        
        # Commission Tax Card
        comm_tax_style = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#9B59B6',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        sheet.write(row, 4, 'Comm. Tax\nضريبة العمولة', comm_tax_style)
        sheet.write(row + 1, 4, payment.get('total_commission_tax_account', 0), styles['summary_card_value'])
        
        # Other Card
        other_style = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#636E72',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        sheet.write(row, 5, 'Other\nأخرى', other_style)
        sheet.write(row + 1, 5, payment.get('total_other', 0), styles['summary_card_value'])
        
        row += 6
        
        # Purchases Summary
        purchases = data.get('purchases', {})
        sheet.merge_range(row, 1, row, 6, '🛒 Purchases Summary - ملخص المشتريات', styles['section_purchases'])
        row += 2
        
        sheet.write(row, 1, 'Paid Invoices\nفواتير مدفوعة', styles['summary_card_header'])
        sheet.write(row, 2, len(purchases.get('paid', [])), styles['summary_card_value'])
        sheet.write(row, 3, 'Amount\nالمبلغ', styles['summary_card_header'])
        sheet.write(row, 4, purchases.get('total_paid', 0), styles['summary_card_value'])
        row += 1
        
        sheet.write(row, 1, 'Unpaid Invoices\nفواتير غير مدفوعة', styles['summary_card_header'])
        sheet.write(row, 2, len(purchases.get('unpaid', [])), styles['summary_card_value'])
        sheet.write(row, 3, 'Amount\nالمبلغ', styles['summary_card_header'])
        sheet.write(row, 4, purchases.get('total_unpaid', 0), styles['summary_card_value'])
        row += 1
        
        sheet.write(row, 1, 'Grand Total\nالإجمالي الكلي', styles['total_purchases'])
        sheet.write(row, 2, len(purchases.get('paid', [])) + len(purchases.get('unpaid', [])), styles['total_purchases'])
        sheet.write(row, 3, '', styles['total_purchases'])
        sheet.write(row, 4, purchases.get('grand_total', 0), styles['total_purchases'])
        
        row += 3
        
        # Sales Summary
        sales = data.get('sales', {})
        sheet.merge_range(row, 1, row, 6, '💰 Sales Summary - ملخص المبيعات', styles['section_sales'])
        row += 2
        
        sheet.write(row, 1, 'Paid Invoices\nفواتير مدفوعة', styles['summary_card_header'])
        sheet.write(row, 2, len(sales.get('paid', [])), styles['summary_card_value'])
        sheet.write(row, 3, 'Amount\nالمبلغ', styles['summary_card_header'])
        sheet.write(row, 4, sales.get('total_paid', 0), styles['summary_card_value'])
        row += 1
        
        sheet.write(row, 1, 'Unpaid Invoices\nفواتير غير مدفوعة', styles['summary_card_header'])
        sheet.write(row, 2, len(sales.get('unpaid', [])), styles['summary_card_value'])
        sheet.write(row, 3, 'Amount\nالمبلغ', styles['summary_card_header'])
        sheet.write(row, 4, sales.get('total_unpaid', 0), styles['summary_card_value'])
        row += 1
        
        sheet.write(row, 1, 'Grand Total\nالإجمالي الكلي', styles['total_sales'])
        sheet.write(row, 2, len(sales.get('paid', [])) + len(sales.get('unpaid', [])), styles['total_sales'])
        sheet.write(row, 3, '', styles['total_sales'])
        sheet.write(row, 4, sales.get('grand_total', 0), styles['total_sales'])
        
        # Footer
        row += 3
        footer_style = workbook.add_format({
            'font_size': 9,
            'font_color': '#7F8C8D',
            'align': 'center',
        })
        sheet.merge_range(row, 1, row, 6, f"Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", footer_style)
    
    def _create_purchases_sheet(self, workbook, styles, data):
        """Create purchases details sheet"""
        sheet = workbook.add_worksheet('🛒 Purchases')
        
        # Set column widths
        sheet.set_column('A:A', 15)  # Invoice
        sheet.set_column('B:B', 30)  # Partner
        sheet.set_column('C:C', 12)  # Date
        sheet.set_column('D:D', 15)  # Payment Type
        sheet.set_column('E:E', 12)  # Status
        sheet.set_column('F:F', 15)  # Untaxed
        sheet.set_column('G:G', 12)  # Tax
        sheet.set_column('H:H', 15)  # Total
        
        row = 0
        
        # Title
        sheet.set_row(row, 35)
        sheet.merge_range(row, 0, row, 7, '🛒 Purchase Invoices - فواتير المشتريات', styles['section_purchases'])
        row += 2
        
        # Headers
        headers = [
            ('Invoice\nالفاتورة', 'A'),
            ('Vendor\nالمورد', 'B'),
            ('Date\nالتاريخ', 'C'),
            ('Payment Type\nنوع الدفع', 'D'),
            ('Status\nالحالة', 'E'),
            ('Untaxed\nقبل الضريبة', 'F'),
            ('Tax\nالضريبة', 'G'),
            ('Total\nالإجمالي', 'H'),
        ]
        
        for col, (header, _) in enumerate(headers):
            sheet.write(row, col, header, styles['header'])
        row += 1
        
        purchases = data.get('purchases', {})
        
        # Paid purchases
        for i, inv in enumerate(purchases.get('paid', [])):
            is_alt = i % 2 == 1
            cell_style = styles['cell_alt'] if is_alt else styles['cell']
            cell_left = styles['cell_left_alt'] if is_alt else styles['cell_left']
            number_style = styles['number_alt'] if is_alt else styles['number']
            
            sheet.write(row, 0, inv.get('name', ''), cell_style)
            sheet.write(row, 1, inv.get('partner', ''), cell_left)
            sheet.write(row, 2, inv.get('date', ''), cell_style)
            sheet.write(row, 3, inv.get('payment_type_label', '-'), cell_style)
            sheet.write(row, 4, 'Paid ✓', styles['paid'])
            sheet.write(row, 5, inv.get('amount_untaxed', 0), number_style)
            sheet.write(row, 6, inv.get('amount_tax', 0), number_style)
            sheet.write(row, 7, inv.get('amount_total', 0), number_style)
            row += 1
        
        # Unpaid purchases
        for i, inv in enumerate(purchases.get('unpaid', [])):
            is_alt = (len(purchases.get('paid', [])) + i) % 2 == 1
            cell_style = styles['cell_alt'] if is_alt else styles['cell']
            cell_left = styles['cell_left_alt'] if is_alt else styles['cell_left']
            number_style = styles['number_alt'] if is_alt else styles['number']
            
            sheet.write(row, 0, inv.get('name', ''), cell_style)
            sheet.write(row, 1, inv.get('partner', ''), cell_left)
            sheet.write(row, 2, inv.get('date', ''), cell_style)
            sheet.write(row, 3, inv.get('payment_type_label', '-'), cell_style)
            sheet.write(row, 4, 'Unpaid ✗', styles['unpaid'])
            sheet.write(row, 5, inv.get('amount_untaxed', 0), number_style)
            sheet.write(row, 6, inv.get('amount_tax', 0), number_style)
            sheet.write(row, 7, inv.get('amount_total', 0), number_style)
            row += 1
        
        # Totals
        row += 1
        sheet.write(row, 0, 'TOTAL', styles['total_purchases'])
        sheet.write(row, 1, '', styles['total_purchases'])
        sheet.write(row, 2, '', styles['total_purchases'])
        sheet.write(row, 3, '', styles['total_purchases'])
        sheet.write(row, 4, '', styles['total_purchases'])
        sheet.write(row, 5, purchases.get('grand_total', 0) - purchases.get('grand_total_tax', 0), styles['total_purchases'])
        sheet.write(row, 6, purchases.get('grand_total_tax', 0), styles['total_purchases'])
        sheet.write(row, 7, purchases.get('grand_total', 0), styles['total_purchases'])
    
    def _create_sales_sheet(self, workbook, styles, data):
        """Create sales details sheet"""
        sheet = workbook.add_worksheet('💰 Sales')
        
        # Set column widths
        sheet.set_column('A:A', 15)  # Invoice
        sheet.set_column('B:B', 30)  # Partner
        sheet.set_column('C:C', 12)  # Date
        sheet.set_column('D:D', 12)  # Status
        sheet.set_column('E:E', 12)  # Cash
        sheet.set_column('F:F', 12)  # Bank
        sheet.set_column('G:G', 12)  # Commission
        sheet.set_column('H:H', 12)  # Comm Tax
        sheet.set_column('I:I', 12)  # Tax
        sheet.set_column('J:J', 15)  # Total
        
        row = 0
        
        # Title
        sheet.set_row(row, 35)
        sheet.merge_range(row, 0, row, 9, '💰 Sales Invoices - فواتير المبيعات', styles['section_sales'])
        row += 2
        
        # Headers
        headers = [
            'Invoice\nالفاتورة',
            'Customer\nالعميل',
            'Date\nالتاريخ',
            'Status\nالحالة',
            'Cash\nكاش',
            'Bank\nبنك',
            'Commission\nعمولة',
            'C.Tax\nض.عمولة',
            'Tax\nالضريبة',
            'Total\nالإجمالي',
        ]
        
        for col, header in enumerate(headers):
            sheet.write(row, col, header, styles['header'])
        row += 1
        
        sales = data.get('sales', {})
        
        # Paid sales
        for i, inv in enumerate(sales.get('paid', [])):
            is_alt = i % 2 == 1
            cell_style = styles['cell_alt'] if is_alt else styles['cell']
            cell_left = styles['cell_left_alt'] if is_alt else styles['cell_left']
            number_style = styles['number_alt'] if is_alt else styles['number']
            
            sheet.write(row, 0, inv.get('name', ''), cell_style)
            sheet.write(row, 1, inv.get('partner', ''), cell_left)
            sheet.write(row, 2, inv.get('date', ''), cell_style)
            sheet.write(row, 3, 'Paid ✓', styles['paid'])
            sheet.write(row, 4, inv.get('cash_amount', 0), number_style)
            sheet.write(row, 5, inv.get('bank_amount', 0), number_style)
            sheet.write(row, 6, inv.get('commission_amount', 0), number_style)
            sheet.write(row, 7, inv.get('commission_tax_account_amount', 0), number_style)
            sheet.write(row, 8, inv.get('amount_tax', 0), number_style)
            sheet.write(row, 9, inv.get('amount_total', 0), number_style)
            row += 1
        
        # Unpaid sales
        for i, inv in enumerate(sales.get('unpaid', [])):
            is_alt = (len(sales.get('paid', [])) + i) % 2 == 1
            cell_style = styles['cell_alt'] if is_alt else styles['cell']
            cell_left = styles['cell_left_alt'] if is_alt else styles['cell_left']
            number_style = styles['number_alt'] if is_alt else styles['number']
            
            sheet.write(row, 0, inv.get('name', ''), cell_style)
            sheet.write(row, 1, inv.get('partner', ''), cell_left)
            sheet.write(row, 2, inv.get('date', ''), cell_style)
            sheet.write(row, 3, 'Unpaid ✗', styles['unpaid'])
            sheet.write(row, 4, inv.get('cash_amount', 0), number_style)
            sheet.write(row, 5, inv.get('bank_amount', 0), number_style)
            sheet.write(row, 6, inv.get('commission_amount', 0), number_style)
            sheet.write(row, 7, inv.get('commission_tax_account_amount', 0), number_style)
            sheet.write(row, 8, inv.get('amount_tax', 0), number_style)
            sheet.write(row, 9, inv.get('amount_total', 0), number_style)
            row += 1
        
        # Totals
        row += 1
        sheet.write(row, 0, 'TOTAL', styles['total_sales'])
        sheet.write(row, 1, '', styles['total_sales'])
        sheet.write(row, 2, '', styles['total_sales'])
        sheet.write(row, 3, '', styles['total_sales'])
        sheet.write(row, 4, sales.get('total_cash_in', 0), styles['total_sales'])
        sheet.write(row, 5, sales.get('total_bank_in', 0), styles['total_sales'])
        sheet.write(row, 6, sales.get('total_commission', 0), styles['total_sales'])
        sheet.write(row, 7, sales.get('total_commission_tax_account', 0), styles['total_sales'])
        sheet.write(row, 8, sales.get('grand_total_tax', 0), styles['total_sales'])
        sheet.write(row, 9, sales.get('grand_total', 0), styles['total_sales'])
    
    def _create_other_payments_sheet(self, workbook, styles, data):
        """Create other payments sheet"""
        sheet = workbook.add_worksheet('👥 Other Payments')
        
        # Set column widths
        sheet.set_column('A:A', 15)  # Entry
        sheet.set_column('B:B', 25)  # Partner
        sheet.set_column('C:C', 30)  # Account
        sheet.set_column('D:D', 12)  # Date
        sheet.set_column('E:E', 15)  # Amount
        
        row = 0
        
        # Title
        other_style = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#FFFFFF',
            'bg_color': '#636E72',
            'align': 'center',
            'valign': 'vcenter',
            'border': 1,
        })
        sheet.set_row(row, 35)
        sheet.merge_range(row, 0, row, 4, '👥 Other Payments - مدفوعات أخرى', other_style)
        row += 2
        
        # Headers
        headers = [
            'Entry\nالقيد',
            'Partner\nالشريك',
            'Account\nالحساب',
            'Date\nالتاريخ',
            'Amount\nالمبلغ',
        ]
        
        for col, header in enumerate(headers):
            sheet.write(row, col, header, styles['header'])
        row += 1
        
        other_payments = data.get('sales', {}).get('other_payments', [])
        total = 0
        
        for i, pay in enumerate(other_payments):
            is_alt = i % 2 == 1
            cell_style = styles['cell_alt'] if is_alt else styles['cell']
            cell_left = styles['cell_left_alt'] if is_alt else styles['cell_left']
            number_style = styles['number_alt'] if is_alt else styles['number']
            
            sheet.write(row, 0, pay.get('invoice_name', ''), cell_style)
            sheet.write(row, 1, pay.get('partner', ''), cell_left)
            sheet.write(row, 2, pay.get('account', ''), cell_left)
            sheet.write(row, 3, pay.get('date', ''), cell_style)
            sheet.write(row, 4, pay.get('amount', 0), number_style)
            total += pay.get('amount', 0)
            row += 1
        
        # Total
        row += 1
        total_style = workbook.add_format({
            'bold': True,
            'font_size': 11,
            'font_color': '#FFFFFF',
            'bg_color': '#636E72',
            'align': 'center',
            'valign': 'vcenter',
            'border': 2,
            'num_format': '#,##0.00',
        })
        sheet.write(row, 0, 'TOTAL', total_style)
        sheet.write(row, 1, '', total_style)
        sheet.write(row, 2, '', total_style)
        sheet.write(row, 3, '', total_style)
        sheet.write(row, 4, total, total_style)
