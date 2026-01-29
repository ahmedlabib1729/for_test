# models/sales_report.py
from odoo import models, fields, api
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import json
import logging

_logger = logging.getLogger(__name__)


class SalesReportWizard(models.TransientModel):
    _name = 'sales.report.wizard'
    _description = 'Sales Report Wizard'
    _rec_name = 'report_type'

    report_type = fields.Selection([
        ('itemwise_details', 'Invoice Details'),
        ('employeewise_summary', 'Employeewise Summary'),
        ('customerwise_datewise', 'Customerwise Datewise Summary'),
        ('monthly_customer_summary', 'Monthly Customer Summary'),
        ('productwise_sales', 'Items Sales'),
    ], string='Report Type', default='itemwise_details', required=True)

    date_range = fields.Selection([
        ('custom', 'Custom Range'),
        ('today', 'Today'),
        ('yesterday', 'Yesterday'),
        ('this_week', 'This Week'),
        ('last_week', 'Last Week'),
        ('this_month', 'This Month'),
        ('last_month', 'Last Month'),
        ('this_quarter', 'This Quarter'),
        ('last_quarter', 'Last Quarter'),
        ('this_year', 'This Year'),
        ('last_year', 'Last Year'),
    ], string='Date Range', default='custom')

    report_year = fields.Selection(
        selection='_get_year_selection',
        string='Year',
        default=lambda self: str(fields.Date.today().year)
    )

    date_from = fields.Date('From Date', default=lambda self: datetime.now().replace(day=1))
    date_to = fields.Date('To Date', default=fields.Date.today())

    partner_ids = fields.Many2many('res.partner', string='Customers')
    partner_type = fields.Selection([
        ('customer', 'Customer'),
        ('vendor', 'Vendor'),
        ('all', 'All'),
    ], string='Partner Type', default='all')

    salesman_ids = fields.Many2many(
        'res.users',
        'sales_report_user_rel',  # اسم جديد للـ table
        'wizard_id',
        'user_id',
        string='Salesmen',
        domain=[('share', '=', False)]  # Internal users only
    )

    # حقول البحث والفلترة
    search_text = fields.Char('Search', help='Search in product name, code, or remark type')

    # حقل جديد لاختيار المنتجات
    product_ids = fields.Many2many('product.product', string='Products',
                                   domain=[('sale_ok', '=', True)])

    # حقل جديد لفلترة حسب Remark Type
    remark_type_ids = fields.Many2many('product.remark.type', string='Remark Types')

    # حقل لتخزين نتائج البحث
    report_html = fields.Html('Report Results', compute='_compute_report_html')

    partner_tag_ids = fields.Many2many(
        'res.partner.category',
        string='Customer Tags',
        help='Filter customers by tags'
    )

    @api.onchange('report_year')
    def _onchange_report_year(self):
        """Auto-set date range when year is selected for monthly report"""
        if self.report_type == 'monthly_customer_summary' and self.report_year:
            year = int(self.report_year)
            self.date_from = datetime(year, 1, 1).date()
            self.date_to = datetime(year, 12, 31).date()
            self.date_range = 'custom'  # تعيين إلى custom لتجنب التداخل

    @api.onchange('report_type')
    def _onchange_report_type(self):
        """Handle report type change"""
        if self.report_type == 'monthly_customer_summary':
            # عند اختيار التقرير الشهري، حدد السنة الحالية والتواريخ
            if not self.report_year:
                self.report_year = str(fields.Date.today().year)
            year = int(self.report_year)
            self.date_from = datetime(year, 1, 1).date()
            self.date_to = datetime(year, 12, 31).date()
            self.date_range = 'custom'

    @api.model
    def _get_year_selection(self):
        """Generate year selection from 2020 to current year + 1"""
        current_year = fields.Date.today().year
        years = []
        for year in range(2020, current_year + 2):
            years.append((str(year), str(year)))
        return years

    def set_today(self):
        self.date_range = 'today'
        self._onchange_date_range()
        return self.action_refresh()

    def set_this_week(self):
        self.date_range = 'this_week'
        self._onchange_date_range()
        return self.action_refresh()

    def set_this_month(self):
        self.date_range = 'this_month'
        self._onchange_date_range()
        return self.action_refresh()

    def set_last_month(self):
        self.date_range = 'last_month'
        self._onchange_date_range()
        return self.action_refresh()

    def set_this_year(self):
        self.date_range = 'this_year'
        self._onchange_date_range()
        return self.action_refresh()

    def set_custom(self):
        self.date_range = 'custom'
        return self.action_refresh()

    @api.onchange('date_range')
    def _onchange_date_range(self):
        """Auto-set date range based on selection"""
        if self.date_range == 'custom':
            return

        today = fields.Date.today()

        if self.date_range == 'today':
            self.date_from = today
            self.date_to = today

        elif self.date_range == 'yesterday':
            yesterday = today - timedelta(days=1)
            self.date_from = yesterday
            self.date_to = yesterday

        elif self.date_range == 'this_week':
            # بداية الأسبوع (الإثنين)
            start_week = today - timedelta(days=today.weekday())
            self.date_from = start_week
            self.date_to = today

        elif self.date_range == 'last_week':
            # الأسبوع الماضي
            start_week = today - timedelta(days=today.weekday() + 7)
            end_week = start_week + timedelta(days=6)
            self.date_from = start_week
            self.date_to = end_week

        elif self.date_range == 'this_month':
            self.date_from = today.replace(day=1)
            self.date_to = today

        elif self.date_range == 'last_month':
            last_month = today.replace(day=1) - timedelta(days=1)
            self.date_from = last_month.replace(day=1)
            self.date_to = last_month

        elif self.date_range == 'this_quarter':
            # تحديد الربع الحالي
            quarter = (today.month - 1) // 3
            start_month = quarter * 3 + 1
            self.date_from = today.replace(month=start_month, day=1)
            self.date_to = today

        elif self.date_range == 'last_quarter':
            # الربع الماضي
            current_quarter = (today.month - 1) // 3
            if current_quarter == 0:
                # نحن في Q1، نريد Q4 من السنة الماضية
                start_date = today.replace(year=today.year - 1, month=10, day=1)
                end_date = today.replace(year=today.year - 1, month=12, day=31)
            else:
                start_month = (current_quarter - 1) * 3 + 1
                end_month = current_quarter * 3
                start_date = today.replace(month=start_month, day=1)
                last_day = (start_date + relativedelta(months=3) - timedelta(days=1))
                end_date = last_day
            self.date_from = start_date
            self.date_to = end_date

        elif self.date_range == 'this_year':
            self.date_from = today.replace(month=1, day=1)
            self.date_to = today

        elif self.date_range == 'last_year':
            last_year = today.year - 1
            self.date_from = today.replace(year=last_year, month=1, day=1)
            self.date_to = today.replace(year=last_year, month=12, day=31)

    @api.model
    def default_get(self, fields):
        """Override default_get to check if remark type model exists"""
        res = super().default_get(fields)

        # Check if product.remark.type model exists and has access
        try:
            self.env['product.remark.type'].check_access_rights('read')
        except:
            _logger.warning("No access to product.remark.type model")
            # Remove remark_type_ids from view if no access
            if 'remark_type_ids' in res:
                del res['remark_type_ids']

        return res

    @api.onchange('report_type', 'date_from', 'date_to', 'date_range', 'partner_type', 'partner_ids',
                  'search_text', 'product_ids', 'remark_type_ids', 'salesman_ids', 'partner_tag_ids', 'report_year')
    def _onchange_filters(self):
        """تحديث التقرير تلقائياً عند تغيير أي فلتر"""
        pass

    @api.depends('report_type', 'date_from', 'date_to', 'date_range', 'partner_ids',
                 'product_ids', 'remark_type_ids', 'search_text', 'salesman_ids', 'partner_tag_ids', 'report_year')
    def _compute_report_html(self):
        """يُحسب تلقائياً عند تغيير أي فلتر"""
        for wizard in self:
            data = wizard.get_report_data()
            wizard.report_html = wizard._generate_html_report(data)

    def _generate_html_report(self, data):
        """Generate HTML table from report data"""
        if not data or not data.get('rows'):
            return '<div style="text-align: center; padding: 20px; color: #666;">No data found for selected criteria</div>'

        # Summary Cards HTML
        summary = data.get('summary', {})

        # البطاقات العلوية - موحدة لجميع التقارير مع عرض التكلفة والربح
        html = f'''
        <div style="margin-bottom: 20px;">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('invoices', 0)}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Invoices</div>
                </div>
                <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{int(summary.get('items', 0))}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Items</div>
                </div>
                <div style="background: linear-gradient(135deg, #667eea 0%, #4e54c8 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('total', 0):,.2f}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Sales</div>
                </div>
                <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('cost', 0):,.2f}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Cost</div>
                </div>
                <div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('profit', 0):,.2f}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Profit</div>
                </div>
                <div style="background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('profit_margin', 0):.1f}%</div>
                    <div style="font-size: 14px; opacity: 0.9;">Profit Margin</div>
                </div>
                <div style="background: linear-gradient(135deg, #ee9ca7 0%, #ffdde1 100%); color: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <div style="font-size: 28px; font-weight: bold;">{summary.get('tax', 0):,.2f}</div>
                    <div style="font-size: 14px; opacity: 0.9;">Total Tax</div>
                </div>
            </div>
        </div>
        '''

        if self.report_type == 'monthly_customer_summary':
            # عرض إجماليات الشهور كبطاقات
            monthly_totals = summary.get('monthly_totals', {})
            if monthly_totals:
                html += '''
                <div style="margin-bottom: 20px;">
                    <h4 style="color: #2c3e50; margin-bottom: 15px;">📊 Monthly Totals for Year {}</h4>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px;">
                '''.format(self.report_year)

                months = ['january', 'february', 'march', 'april', 'may', 'june',
                          'july', 'august', 'september', 'october', 'november', 'december']
                colors = ['#3498db', '#9b59b6', '#e74c3c', '#f39c12', '#1abc9c', '#2ecc71',
                          '#e67e22', '#95a5a6', '#34495e', '#16a085', '#27ae60', '#2980b9']

                for i, month in enumerate(months):
                    total = monthly_totals.get(month, 0)
                    html += f'''
                    <div style="background: {colors[i]}; color: white; padding: 15px; border-radius: 8px; text-align: center;">
                        <div style="font-size: 12px; opacity: 0.9; text-transform: uppercase;">{month}</div>
                        <div style="font-size: 18px; font-weight: bold; margin-top: 5px;">{total:,.2f}</div>
                    </div>
                    '''

                html += '''
                    </div>
                </div>
                '''

        # Table HTML
        rows = data.get('rows', [])
        if rows:
            html += '<div style="overflow-x: auto; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);"><table class="table table-striped table-bordered" style="width: 100%; font-size: 13px; margin: 0;">'

            # Headers - تخصيص حسب نوع التقرير
            html += '<thead><tr style="background: #2c3e50;">'

            # ترتيب الأعمدة حسب نوع التقرير
            if self.report_type == 'itemwise_details':
                headers_order = ['sale_order', 'invoice_no', 'date', 'customer', 'mobile', 'tags',
                                 'salesman', 'item_code', 'item_short_code', 'item_name', 'remark_type', 'quantity',
                                 'price', 'discount', 'tax', 'total', 'cost', 'profit', 'margin_%']
            elif self.report_type == 'customerwise_datewise':
                headers_order = ['customer', 'tags', 'mobile', 'date', 'salesman', 'invoices',
                                 'total', 'cost', 'profit', 'margin_%']
            elif self.report_type == 'employeewise_summary':
                headers_order = ['employee_code', 'employee', 'invoices', 'quantity',
                                 'total', 'cost', 'profit', 'margin_%', 'percentage']
            elif self.report_type == 'monthly_customer_summary':
                headers_order = ['customer', 'tags', 'phone', 'total_amount',
                                 'january', 'february', 'march', 'april', 'may', 'june',
                                 'july', 'august', 'september', 'october', 'november', 'december']
            elif self.report_type == 'productwise_sales':
                headers_order = ['item_code', 'item_short_code', 'item_name', 'remark_type', 'quantity', 'sales_price',
                                 'cost', 'profit', 'margin_%']
            else:
                headers_order = list(rows[0].keys())

            # عرض الهيدرز بالترتيب المحدد
            for key in headers_order:
                if key in rows[0]:
                    header = key.replace('_', ' ').replace('%', '').title()
                    # تخصيص أسماء بعض الأعمدة
                    if key == 'margin_%':
                        header = 'Margin %'
                    elif key == 'tags':
                        header = 'Customer Tags'
                    elif key == 'mobile':
                        header = 'Mobile/Phone'
                    elif key == 'item_short_code':
                        header = 'Short Code'  # ✅ تخصيص اسم العمود
                    elif key == 'item_code':
                        header = 'SKU'  # ✅ تخصيص اسم العمود
                    html += f'<th style="color: white; padding: 18px 15px; white-space: normal; font-weight: 600; min-width: 120px; line-height: 1.4; vertical-align: middle; text-align: center;">{header}</th>'
            html += '</tr></thead>'

            # Body
            html += '<tbody>'
            for i, row in enumerate(rows):
                # Alternating row colors
                bg_color = '#ffffff' if i % 2 == 0 else '#f8f9fa'
                html += f'<tr style="background: {bg_color};">'

                for key in headers_order:
                    if key in row:
                        value = row[key]

                        if value is None or value == '':
                            html += '<td style="padding: 10px 8px;">-</td>'
                        elif isinstance(value, float):
                            # تلوين الأرباح والخسائر
                            if 'profit' in key.lower():
                                color = '#27ae60' if value >= 0 else '#e74c3c'
                                html += f'<td style="padding: 10px 8px; text-align: right; color: {color}; font-weight: bold;">{value:,.2f}</td>'
                            elif 'cost' in key.lower():
                                html += f'<td style="padding: 10px 8px; text-align: right; color: #e67e22;">{value:,.2f}</td>'
                            elif 'margin' in key.lower() or key == 'percentage':
                                color = '#27ae60' if value >= 0 else '#e74c3c'
                                html += f'<td style="padding: 10px 8px; text-align: right; color: {color}; font-weight: bold;">{value:.1f}%</td>'
                            else:
                                html += f'<td style="padding: 10px 8px; text-align: right;">{value:,.2f}</td>'
                        elif key == 'tags' and value:
                            # عرض Tags بشكل جميل
                            tags_html = ''
                            for tag in value.split(','):
                                tag = tag.strip()
                                if tag:
                                    tags_html += f'<span style="background: #3498db; color: white; padding: 2px 8px; border-radius: 10px; margin: 2px; display: inline-block; font-size: 11px;">{tag}</span>'
                            html += f'<td style="padding: 10px 8px;">{tags_html if tags_html else "-"}</td>'
                        elif key == 'mobile':
                            # تنسيق رقم الموبايل
                            html += f'<td style="padding: 10px 8px; direction: ltr;">{value if value else "-"}</td>'
                        elif key == 'item_short_code':
                            # ✅ تلوين خاص للـ Short Code
                            html += f'<td style="padding: 10px 8px; color: #e67e22; font-weight: bold;">{value if value else "-"}</td>'
                        else:
                            html += f'<td style="padding: 10px 8px;">{value}</td>'
                html += '</tr>'
            html += '</tbody>'

            # Footer with totals - مختلف حسب نوع التقرير
            html += '<tfoot><tr style="font-weight: bold; background: #ecf0f1; border-top: 2px solid #2c3e50;">'

            if self.report_type == 'itemwise_details':
                # Calculate totals for itemwise
                total_qty = sum(r.get('quantity', 0) for r in rows)
                total_sales = sum(r.get('total', 0) for r in rows)
                total_cost = sum(r.get('cost', 0) for r in rows)
                total_profit = sum(r.get('profit', 0) for r in rows)
                total_tax = sum(r.get('tax', 0) for r in rows)
                avg_margin = (total_profit / total_sales * 100) if total_sales else 0

                html += '<td colspan="10" style="text-align: right; padding: 12px; font-size: 14px;">GRAND TOTALS:</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; font-weight: bold;">{total_qty:,.2f}</td>'
                html += '<td></td>'  # Price column
                html += '<td></td>'  # Discount column
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px;">{total_tax:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; background: #e8f8f5;">{total_sales:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: #e67e22;">{total_cost:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if total_profit >= 0 else "#e74c3c"}; background: {"#d5f4e6" if total_profit >= 0 else "#fce4e4"};">{total_profit:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if avg_margin >= 0 else "#e74c3c"};">{avg_margin:.1f}%</td>'

            elif self.report_type == 'customerwise_datewise':
                # Calculate totals for customerwise
                total_invoices = sum(r.get('invoices', 0) for r in rows)
                total_sales = sum(r.get('total', 0) for r in rows)
                total_cost = sum(r.get('cost', 0) for r in rows)
                total_profit = sum(r.get('profit', 0) for r in rows)
                avg_margin = (total_profit / total_sales * 100) if total_sales else 0

                html += '<td colspan="5" style="text-align: right; padding: 12px; font-size: 14px;">GRAND TOTALS:</td>'
                html += f'<td style="text-align: center; padding: 12px; font-size: 14px; font-weight: bold;">{total_invoices}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; background: #e8f8f5;">{total_sales:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: #e67e22;">{total_cost:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if total_profit >= 0 else "#e74c3c"}; background: {"#d5f4e6" if total_profit >= 0 else "#fce4e4"};">{total_profit:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if avg_margin >= 0 else "#e74c3c"};">{avg_margin:.1f}%</td>'

            elif self.report_type == 'employeewise_summary':
                # Calculate totals for employeewise
                total_invoices = sum(r.get('invoices', 0) for r in rows)
                total_qty = sum(r.get('quantity', 0) for r in rows)
                total_sales = sum(r.get('total', 0) for r in rows)
                total_cost = sum(r.get('cost', 0) for r in rows)
                total_profit = sum(r.get('profit', 0) for r in rows)
                avg_margin = (total_profit / total_sales * 100) if total_sales else 0

                html += '<td colspan="2" style="text-align: right; padding: 12px; font-size: 14px;">GRAND TOTALS:</td>'
                html += f'<td style="text-align: center; padding: 12px; font-size: 14px; font-weight: bold;">{total_invoices}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px;">{total_qty:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; background: #e8f8f5;">{total_sales:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: #e67e22;">{total_cost:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if total_profit >= 0 else "#e74c3c"}; background: {"#d5f4e6" if total_profit >= 0 else "#fce4e4"};">{total_profit:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; color: {"#27ae60" if avg_margin >= 0 else "#e74c3c"};">{avg_margin:.1f}%</td>'
                html += '<td style="text-align: right; padding: 12px; font-size: 14px;">100%</td>'

            elif self.report_type == 'monthly_customer_summary':
                # حساب إجماليات الشهور
                totals = {
                    'total_amount': sum(r.get('total_amount', 0) for r in rows),
                    'january': sum(r.get('january', 0) for r in rows),
                    'february': sum(r.get('february', 0) for r in rows),
                    'march': sum(r.get('march', 0) for r in rows),
                    'april': sum(r.get('april', 0) for r in rows),
                    'may': sum(r.get('may', 0) for r in rows),
                    'june': sum(r.get('june', 0) for r in rows),
                    'july': sum(r.get('july', 0) for r in rows),
                    'august': sum(r.get('august', 0) for r in rows),
                    'september': sum(r.get('september', 0) for r in rows),
                    'october': sum(r.get('october', 0) for r in rows),
                    'november': sum(r.get('november', 0) for r in rows),
                    'december': sum(r.get('december', 0) for r in rows),
                }

                html += '<td colspan="3" style="text-align: right; padding: 12px; font-size: 14px; font-weight: bold;">GRAND TOTALS:</td>'
                html += f'<td style="text-align: right; padding: 12px; font-size: 14px; font-weight: bold; background: #e8f8f5;">{totals["total_amount"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["january"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["february"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["march"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["april"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["may"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["june"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["july"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["august"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["september"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["october"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["november"]:,.2f}</td>'
                html += f'<td style="text-align: right; padding: 12px; font-weight: bold;">{totals["december"]:,.2f}</td>'

            elif self.report_type == 'productwise_sales':
                total_qty = sum(r.get('quantity', 0) for r in rows)
                total_sales = sum(r.get('sales_price', 0) for r in rows)
                total_cost = sum(r.get('cost', 0) for r in rows)
                total_profit = sum(r.get('profit', 0) for r in rows)
                avg_margin = (total_profit / total_sales * 100) if total_sales else 0

                html += '<td colspan="2" style="text-align:right; padding:12px; font-size:14px; font-weight:bold;">GRAND TOTALS:</td>'
                html += f'<td style="text-align:right; padding:12px; font-size:14px; font-weight:bold;">{total_qty:,.2f}</td>'
                html += f'<td style="text-align:right; padding:12px; font-size:14px; background:#e8f8f5;">{total_sales:,.2f}</td>'
                html += f'<td style="text-align:right; padding:12px; font-size:14px; color:#e67e22;">{total_cost:,.2f}</td>'
                html += f'<td style="text-align:right; padding:12px; font-size:14px; color:{"#27ae60" if total_profit >= 0 else "#e74c3c"}; background:{"#d5f4e6" if total_profit >= 0 else "#fce4e4"};">{total_profit:,.2f}</td>'
                html += f'<td style="text-align:right; padding:12px; font-size:14px; color:{"#27ae60" if avg_margin >= 0 else "#e74c3c"};">{avg_margin:.1f}%</td>'

            html += '</tr></tfoot>'
            html += '</table></div>'

            # إضافة معلومات إضافية
            html += f'''
            <div style="margin-top: 20px; padding: 15px; background: #ecf0f1; border-radius: 8px;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <p style="margin: 0; color: #7f8c8d; font-size: 12px;">
                            Report Type: <strong>{dict(self._fields['report_type'].selection).get(self.report_type)}</strong> | 
                            Period: <strong>{self.date_from} to {self.date_to}</strong> | 
                            Total Records: <strong>{len(rows)}</strong>
                        </p>
                    </div>
                    <div>
                        <p style="margin: 0; color: #7f8c8d; font-size: 12px;">
                            Generated on: <strong>{fields.Date.today()}</strong> at <strong>{fields.Datetime.now().strftime("%H:%M")}</strong>
                        </p>
                    </div>
                </div>
            </div>
            '''

        return html

    def get_report_data(self):
        """Generate report data based on filters"""
        self.ensure_one()

        domain = [
            ('move_type', '=', 'out_invoice'),
            ('state', '=', 'posted'),
        ]

        if self.date_from:
            domain.append(('invoice_date', '>=', self.date_from))
        if self.date_to:
            domain.append(('invoice_date', '<=', self.date_to))

        if self.salesman_ids:
            domain.append(('invoice_user_id', 'in', self.salesman_ids.ids))

        # فلترة حسب Tags
        if self.partner_tag_ids:
            partners_with_tags = self.env['res.partner'].search([
                ('category_id', 'in', self.partner_tag_ids.ids)
            ])
            if self.partner_ids:
                valid_partners = self.partner_ids & partners_with_tags
                domain.append(('partner_id', 'in', valid_partners.ids))
            else:
                domain.append(('partner_id', 'in', partners_with_tags.ids))
        elif self.partner_ids:
            domain.append(('partner_id', 'in', self.partner_ids.ids))
        elif self.partner_type == 'customer':
            domain.append(('partner_id.customer_rank', '>', 0))
        elif self.partner_type == 'vendor':
            domain.append(('partner_id.supplier_rank', '>', 0))

        invoices = self.env['account.move'].search(domain)

        if not invoices:
            return {'summary': {}, 'rows': []}

        # Summary variables
        total_sales = 0
        total_cost = 0
        total_profit = 0
        total_items = 0

        # Generate report rows based on type
        rows = []

        if self.report_type == 'itemwise_details':
            for invoice in invoices:
                # Get related sale order
                sale_order = self.env['sale.order'].search([
                    ('name', '=', invoice.invoice_origin)
                ], limit=1)

                # Filter invoice lines
                invoice_lines = invoice.invoice_line_ids.filtered(lambda l: l.product_id)

                # Apply product filter if selected
                if self.product_ids:
                    invoice_lines = invoice_lines.filtered(lambda l: l.product_id.id in self.product_ids.ids)

                # Apply remark type filter if selected and accessible
                if self.remark_type_ids:
                    try:
                        invoice_lines = invoice_lines.filtered(lambda l:
                                                               l.product_id.product_tmpl_id.remark_type_id.id in self.remark_type_ids.ids
                                                               if hasattr(l.product_id.product_tmpl_id,
                                                                          'remark_type_id') and l.product_id.product_tmpl_id.remark_type_id
                                                               else False
                                                               )
                    except:
                        _logger.warning("Error filtering by remark type")

                # Apply search text filter if provided
                if self.search_text:
                    search_terms = self.search_text.lower().split()

                    def matches_search(line):
                        """Check if line matches all search terms"""
                        # ✅ إضافة item_short_code في البحث
                        item_short_code = ''
                        try:
                            if 'item_short_code' in line.product_id.product_tmpl_id._fields:
                                item_short_code = line.product_id.product_tmpl_id.item_short_code or ''
                        except:
                            pass

                        searchable_text = ' '.join([
                            (line.product_id.name or ''),
                            (line.product_id.default_code or ''),
                            (line.product_id.barcode or ''),
                            item_short_code,  # ✅ إضافة item_short_code
                        ])

                        # Add remark type name if accessible
                        try:
                            if hasattr(line.product_id.product_tmpl_id,
                                       'remark_type_id') and line.product_id.product_tmpl_id.remark_type_id:
                                searchable_text += ' ' + line.product_id.product_tmpl_id.remark_type_id.name
                        except:
                            pass

                        searchable_text = searchable_text.lower()
                        return all(term in searchable_text for term in search_terms)

                    invoice_lines = invoice_lines.filtered(matches_search)

                # Get customer tags
                customer_tags = ', '.join(
                    invoice.partner_id.category_id.mapped('name')) if invoice.partner_id.category_id else ''

                # Get salesman name (from invoice_user_id)
                salesman_name = ''
                if invoice.invoice_user_id:
                    salesman_name = invoice.invoice_user_id.name

                # Process each line
                for line in invoice_lines:
                    # Calculate cost and profit
                    cost_price = line.product_id.standard_price
                    total_cost_line = cost_price * line.quantity
                    profit = line.price_subtotal - total_cost_line
                    profit_margin = (profit / line.price_subtotal * 100) if line.price_subtotal else 0

                    # Update totals
                    total_sales += line.price_total
                    total_cost += total_cost_line
                    total_profit += profit
                    total_items += line.quantity

                    # Get remark type name safely
                    remark_type_name = ''
                    try:
                        if hasattr(line.product_id.product_tmpl_id,
                                   'remark_type_id') and line.product_id.product_tmpl_id.remark_type_id:
                            remark_type_name = line.product_id.product_tmpl_id.remark_type_id.name
                    except:
                        _logger.warning(f"Could not get remark type for product {line.product_id.name}")

                    # ✅ Get item_short_code safely
                    item_short_code = ''
                    try:
                        tmpl = line.product_id.product_tmpl_id
                        if 'item_short_code' in tmpl._fields:
                            item_short_code = tmpl.item_short_code or ''
                    except:
                        pass

                    rows.append({
                        'sale_order': sale_order.name if sale_order else invoice.invoice_origin or 'N/A',
                        'invoice_no': invoice.name,
                        'date': invoice.invoice_date.strftime('%d/%m/%Y') if invoice.invoice_date else '',
                        'customer': invoice.partner_id.name,
                        'mobile': invoice.partner_id.mobile or invoice.partner_id.phone or '',
                        'tags': customer_tags,
                        'salesman': salesman_name,
                        'item_code': line.product_id.default_code or '',
                        'item_short_code': item_short_code,  # ✅ إضافة item_short_code
                        'item_name': line.product_id.name,
                        'remark_type': remark_type_name,
                        'quantity': line.quantity,
                        'price': line.price_unit,
                        'discount': line.discount,
                        'tax': line.price_total - line.price_subtotal,
                        'total': line.price_total,
                        'cost': total_cost_line,
                        'profit': profit,
                        'margin_%': round(profit_margin, 1),
                    })

        elif self.report_type == 'customerwise_datewise':
            customer_data = {}

            for invoice in invoices:
                key = (invoice.partner_id.id, invoice.invoice_date)

                if key not in customer_data:
                    salesman_name = ''
                    if invoice.invoice_user_id:
                        salesman_name = invoice.invoice_user_id.name

                    # Get customer tags
                    customer_tags = ', '.join(
                        invoice.partner_id.category_id.mapped('name')) if invoice.partner_id.category_id else ''

                    customer_data[key] = {
                        'customer': invoice.partner_id.name,
                        'tags': customer_tags,
                        'mobile': invoice.partner_id.mobile or invoice.partner_id.phone or '',
                        'date': invoice.invoice_date.strftime('%d/%m/%Y') if invoice.invoice_date else '',
                        'salesman': salesman_name,
                        'invoices': 0,
                        'total': 0,
                        'cost': 0,
                        'profit': 0,
                        'margin_%': 0,
                    }

                customer_data[key]['invoices'] += 1
                customer_data[key]['total'] += invoice.amount_total

                # Calculate cost for this invoice
                invoice_cost = 0
                for line in invoice.invoice_line_ids.filtered(lambda l: l.product_id):
                    invoice_cost += line.product_id.standard_price * line.quantity

                customer_data[key]['cost'] += invoice_cost
                customer_data[key]['profit'] += (invoice.amount_total - invoice_cost)

                total_sales += invoice.amount_total
                total_cost += invoice_cost
                total_profit += (invoice.amount_total - invoice_cost)
                total_items += len(invoice.invoice_line_ids.filtered(lambda l: l.product_id))

            # Calculate margin percentage
            for data in customer_data.values():
                if data['total'] > 0:
                    data['margin_%'] = round((data['profit'] / data['total']) * 100, 1)

            rows = list(customer_data.values())
            rows.sort(key=lambda x: x['total'], reverse=True)



        elif self.report_type == 'monthly_customer_summary':
            # تقرير شهري للعملاء
            customer_monthly_data = {}

            # استخدام التواريخ المحددة من حقول date_from و date_to
            # والتي يتم تحديثها تلقائياً عند اختيار السنة
            year_domain = [
                ('move_type', '=', 'out_invoice'),
                ('state', '=', 'posted'),
            ]

            # إضافة فلتر التاريخ بناءً على السنة المختارة
            if self.report_year:
                year = int(self.report_year)
                start_date = datetime(year, 1, 1).date()
                end_date = datetime(year, 12, 31).date()
                year_domain.append(('invoice_date', '>=', start_date))
                year_domain.append(('invoice_date', '<=', end_date))
            elif self.date_from and self.date_to:
                # في حال تم تحديد التواريخ يدوياً
                year_domain.append(('invoice_date', '>=', self.date_from))
                year_domain.append(('invoice_date', '<=', self.date_to))

            # إضافة فلتر العملاء إذا تم تحديدهم
            if self.partner_ids:
                year_domain.append(('partner_id', 'in', self.partner_ids.ids))
            elif self.partner_type == 'customer':
                year_domain.append(('partner_id.customer_rank', '>', 0))

            # إضافة فلتر Tags إذا تم تحديدها
            if self.partner_tag_ids:
                partners_with_tags = self.env['res.partner'].search([
                    ('category_id', 'in', self.partner_tag_ids.ids)
                ])
                if self.partner_ids:
                    valid_partners = self.partner_ids & partners_with_tags
                    year_domain.append(('partner_id', 'in', valid_partners.ids))
                else:
                    year_domain.append(('partner_id', 'in', partners_with_tags.ids))

            # إضافة فلتر Salesman إذا تم تحديده
            if self.salesman_ids:
                year_domain.append(('invoice_user_id', 'in', self.salesman_ids.ids))

            # جلب الفواتير
            invoices = self.env['account.move'].search(year_domain)

            # معالجة الفواتير
            for invoice in invoices:
                customer_id = invoice.partner_id.id
                month = invoice.invoice_date.month if invoice.invoice_date else 1

                if customer_id not in customer_monthly_data:
                    # الحصول على Tags
                    customer_tags = ', '.join(
                        invoice.partner_id.category_id.mapped('name')) if invoice.partner_id.category_id else ''

                    customer_monthly_data[customer_id] = {
                        'customer': invoice.partner_id.name,
                        'tags': customer_tags,
                        'phone': invoice.partner_id.mobile or invoice.partner_id.phone or '',
                        'total_amount': 0,
                        # تهيئة الشهور بصفر
                        'january': 0,
                        'february': 0,
                        'march': 0,
                        'april': 0,
                        'may': 0,
                        'june': 0,
                        'july': 0,
                        'august': 0,
                        'september': 0,
                        'october': 0,
                        'november': 0,
                        'december': 0,
                    }

                # إضافة المبلغ للشهر المناسب
                month_names = {
                    1: 'january', 2: 'february', 3: 'march', 4: 'april',
                    5: 'may', 6: 'june', 7: 'july', 8: 'august',
                    9: 'september', 10: 'october', 11: 'november', 12: 'december'
                }

                month_name = month_names.get(month)
                if month_name:
                    customer_monthly_data[customer_id][month_name] += invoice.amount_total
                    customer_monthly_data[customer_id]['total_amount'] += invoice.amount_total

                total_sales += invoice.amount_total
                total_items += len(invoice.invoice_line_ids.filtered(lambda l: l.product_id))

            # تحويل البيانات إلى قائمة وترتيبها
            rows = list(customer_monthly_data.values())
            rows.sort(key=lambda x: x['total_amount'], reverse=True)

            # حساب إجماليات الشهور
            monthly_totals = {
                'january': sum(r.get('january', 0) for r in rows),
                'february': sum(r.get('february', 0) for r in rows),
                'march': sum(r.get('march', 0) for r in rows),
                'april': sum(r.get('april', 0) for r in rows),
                'may': sum(r.get('may', 0) for r in rows),
                'june': sum(r.get('june', 0) for r in rows),
                'july': sum(r.get('july', 0) for r in rows),
                'august': sum(r.get('august', 0) for r in rows),
                'september': sum(r.get('september', 0) for r in rows),
                'october': sum(r.get('october', 0) for r in rows),
                'november': sum(r.get('november', 0) for r in rows),
                'december': sum(r.get('december', 0) for r in rows),
            }

        elif self.report_type == 'productwise_sales':
            product_map = {}  # key = product_id, value = aggregates dict

            for invoice in invoices:
                # نشتغل على سطور الفاتورة اللي فيها product فقط
                invoice_lines = invoice.invoice_line_ids.filtered(lambda l: l.product_id)

                # فلتر المنتجات المختارة (إن وُجدت)
                if self.product_ids:
                    invoice_lines = invoice_lines.filtered(lambda l: l.product_id.id in self.product_ids.ids)

                # فلتر Remark Types إن وُجد
                if self.remark_type_ids:
                    try:
                        invoice_lines = invoice_lines.filtered(lambda l:
                                                               hasattr(l.product_id.product_tmpl_id, 'remark_type_id')
                                                               and l.product_id.product_tmpl_id.remark_type_id
                                                               and l.product_id.product_tmpl_id.remark_type_id.id in self.remark_type_ids.ids
                                                               )
                    except:
                        pass

                # فلتر البحث النصي (الاسم/الكود/الباركود/الريمَارك تايب/الشورت كود)
                if self.search_text:
                    search_terms = self.search_text.lower().split()

                    def matches_search(line):
                        # ✅ إضافة item_short_code في البحث
                        item_short_code = ''
                        try:
                            if 'item_short_code' in line.product_id.product_tmpl_id._fields:
                                item_short_code = line.product_id.product_tmpl_id.item_short_code or ''
                        except:
                            pass

                        text = ' '.join(filter(None, [
                            line.product_id.name or '',
                            line.product_id.default_code or '',
                            line.product_id.barcode or '',
                            item_short_code,  # ✅ إضافة item_short_code
                            getattr(getattr(line.product_id.product_tmpl_id, 'remark_type_id', False), 'name',
                                    '') or '',
                        ])).lower()
                        return all(term in text for term in search_terms)

                    invoice_lines = invoice_lines.filtered(matches_search)

                # تجميع القيم لكل منتج
                for line in invoice_lines:
                    pid = line.product_id.id
                    if pid not in product_map:
                        # Get remark type name
                        remark_type_name = ''
                        try:
                            if hasattr(line.product_id.product_tmpl_id,
                                       'remark_type_id') and line.product_id.product_tmpl_id.remark_type_id:
                                remark_type_name = line.product_id.product_tmpl_id.remark_type_id.name
                        except:
                            pass

                        # ✅ Get item_short_code
                        item_short_code = ''
                        try:
                            tmpl = line.product_id.product_tmpl_id
                            if 'item_short_code' in tmpl._fields:
                                item_short_code = tmpl.item_short_code or ''
                        except:
                            pass

                        product_map[pid] = {
                            'item_code': line.product_id.default_code or '',  # ✅ إضافة item_code
                            'item_short_code': item_short_code,  # ✅ إضافة item_short_code
                            'item_name': line.product_id.name,
                            'remark_type': remark_type_name,
                            'quantity': 0.0,
                            'sales_price': 0.0,
                            'cost': 0.0,
                            'profit': 0.0,
                            'margin_%': 0.0,
                        }

                    # إجمالي الكمية
                    product_map[pid]['quantity'] += line.quantity

                    # إجمالي المبيعات (بدون ضريبة): price_subtotal
                    product_map[pid]['sales_price'] += float(line.price_subtotal)

                    # التكلفة = standard_price * qty
                    line_cost = float(line.product_id.standard_price) * line.quantity
                    product_map[pid]['cost'] += line_cost

            # احسب الربح ونسبة الربح لكل منتج
            rows = []
            total_sales = 0.0
            total_cost = 0.0
            total_profit = 0.0
            total_items = 0.0

            for data in product_map.values():
                data['profit'] = data['sales_price'] - data['cost']
                data['margin_%'] = round((data['profit'] / data['sales_price'] * 100) if data['sales_price'] else 0.0,
                                         1)

                rows.append(data)

                # تلخيص عام للـ summary
                total_sales += data['sales_price']
                total_cost += data['cost']
                total_profit += data['profit']
                total_items += data['quantity']

            # ترتيب تنازلي بالبيع
            rows.sort(key=lambda r: r.get('sales_price', 0.0), reverse=True)




        elif self.report_type == 'employeewise_summary':
            salesman_data = {}

            for invoice in invoices:
                # Use invoice_user_id
                user = invoice.invoice_user_id or invoice.create_uid
                key = f'user_{user.id}'
                name = user.name
                code = user.partner_id.ref or f'U{user.id}'

                # Calculate cost for this invoice
                invoice_cost = 0
                for line in invoice.invoice_line_ids.filtered(lambda l: l.product_id):
                    invoice_cost += line.product_id.standard_price * line.quantity

                if key not in salesman_data:
                    salesman_data[key] = {
                        'employee_code': code,
                        'employee': name,
                        'invoices': 0,
                        'quantity': 0,
                        'total': 0,
                        'cost': 0,
                        'profit': 0,
                        'margin_%': 0,
                        'percentage': 0,
                    }

                salesman_data[key]['invoices'] += 1
                salesman_data[key]['quantity'] += sum(
                    line.quantity for line in invoice.invoice_line_ids.filtered(lambda l: l.product_id)
                )
                salesman_data[key]['total'] += invoice.amount_total
                salesman_data[key]['cost'] += invoice_cost
                salesman_data[key]['profit'] += (invoice.amount_total - invoice_cost)

                total_sales += invoice.amount_total
                total_cost += invoice_cost
                total_profit += (invoice.amount_total - invoice_cost)
                total_items += sum(line.quantity for line in invoice.invoice_line_ids.filtered(lambda l: l.product_id))

            # Calculate percentages
            for data in salesman_data.values():
                if data['total'] > 0:
                    data['margin_%'] = round((data['profit'] / data['total']) * 100, 1)
                if total_sales > 0:
                    data['percentage'] = round((data['total'] / total_sales * 100), 2)

            rows = list(salesman_data.values())
            rows.sort(key=lambda x: x['total'], reverse=True)

        # Calculate summary
        summary = {
            'invoices': len(invoices),
            'items': int(total_items),
            'total': total_sales,
            'tax': sum(inv.amount_tax for inv in invoices),
            'cost': total_cost,
            'profit': total_profit,
            'profit_margin': round((total_profit / total_sales * 100) if total_sales else 0, 1)
        }

        return {
            'summary': summary,
            'rows': rows,
        }

    def action_generate_report(self):
        """Generate report without creating new record"""
        # فقط حدّث الصفحة الحالية
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'sales.report.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': 'current',
            'flags': {'mode': 'readonly'}
        }

    def action_search(self):
        """Search button action - refresh the view with results"""
        target = self.env.context.get('default_target', 'current')

        return {
            'name': 'Sales Report',  # هذا العنوان الذي سيظهر
            'type': 'ir.actions.act_window',
            'res_model': 'sales.report.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': target,
            'context': dict(self.env.context, show_results=True),
            'flags': {'mode': 'readonly', 'breadcrumbs': False}  # أضف هذا
        }

    @api.onchange('search_text')
    def _onchange_search_text(self):
        """Auto-refresh when search text changes"""
        if self.report_type in ('itemwise_details', 'productwise_sales'):
            # This will trigger the recompute of report_html
            return {}

    def action_refresh(self):
        """Refresh button action"""
        # نفس الشيء للـ refresh
        target = self.env.context.get('default_target', 'current')

        return {
            'name': 'Sales Report',
            'type': 'ir.actions.act_window',
            'res_model': 'sales.report.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': target,
            'context': dict(self.env.context, show_results=True)
        }

    def action_export_excel(self):
        """Export to Excel action"""
        import xlsxwriter
        import io
        import base64

        output = io.BytesIO()
        workbook = xlsxwriter.Workbook(output)
        worksheet = workbook.add_worksheet('Sales Report')

        # Formats
        header_format = workbook.add_format({
            'bold': True,
            'bg_color': '#4472C4',
            'font_color': 'white',
            'border': 1
        })

        money_format = workbook.add_format({
            'num_format': '#,##0.00',
            'border': 1
        })

        profit_format = workbook.add_format({
            'num_format': '#,##0.00',
            'font_color': 'green',
            'border': 1
        })

        loss_format = workbook.add_format({
            'num_format': '#,##0.00',
            'font_color': 'red',
            'border': 1
        })

        # Get report data
        data = self.get_report_data()

        # Write summary
        row = 0
        summary = data.get('summary', {})
        worksheet.write(row, 0, 'SALES REPORT SUMMARY', header_format)
        row += 1
        worksheet.write(row, 0, f"Report Type: {dict(self._fields['report_type'].selection).get(self.report_type)}")
        worksheet.write(row, 1, f"From: {self.date_from}")
        worksheet.write(row, 2, f"To: {self.date_to}")
        row += 1
        worksheet.write(row, 0, f"Total Invoices: {summary.get('invoices', 0)}")
        worksheet.write(row, 1, f"Total Items: {summary.get('items', 0)}")
        worksheet.write(row, 2, f"Total Sales: {summary.get('total', 0):,.2f}")
        if self.report_type == 'itemwise_details':
            worksheet.write(row, 3, f"Total Cost: {summary.get('cost', 0):,.2f}")
            worksheet.write(row, 4, f"Total Profit: {summary.get('profit', 0):,.2f}")
            worksheet.write(row, 5, f"Margin: {summary.get('profit_margin', 0):.1f}%")
        row += 2

        # Write headers
        rows_data = data.get('rows', [])
        if rows_data:
            headers = list(rows_data[0].keys())
            for col, header in enumerate(headers):
                worksheet.write(row, col, header.replace('_', ' ').title(), header_format)

            # Write data
            for row_data in rows_data:
                row += 1
                for col, header in enumerate(headers):
                    value = row_data[header]
                    if header == 'profit':
                        format_to_use = profit_format if value >= 0 else loss_format
                        worksheet.write(row, col, value, format_to_use)
                    elif isinstance(value, float) and header in ['total', 'cost', 'price', 'tax']:
                        worksheet.write(row, col, value, money_format)
                    else:
                        worksheet.write(row, col, value)

        workbook.close()
        output.seek(0)

        # Create attachment
        attachment = self.env['ir.attachment'].create({
            'name': f'sales_report_{self.report_type}_{fields.Date.today()}.xlsx',
            'type': 'binary',
            'datas': base64.b64encode(output.read()),
            'mimetype': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        })

        return {
            'type': 'ir.actions.act_url',
            'url': f'/web/content/{attachment.id}?download=true',
            'target': 'new',
        }

    def action_export_csv(self):
        """Export to CSV action"""
        import csv
        import io
        import base64

        output = io.StringIO()
        data = self.get_report_data()
        rows = data.get('rows', [])

        if rows:
            writer = csv.DictWriter(output, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)

        # Create attachment
        attachment = self.env['ir.attachment'].create({
            'name': f'sales_report_{fields.Date.today()}.csv',
            'type': 'binary',
            'datas': base64.b64encode(output.getvalue().encode()),
            'mimetype': 'text/csv'
        })

        return {
            'type': 'ir.actions.act_url',
            'url': f'/web/content/{attachment.id}?download=true',
            'target': 'new',
        }

    def action_open_fullscreen(self):
        """Open report in fullscreen mode"""
        return {
            'name': 'Sales Report',
            'type': 'ir.actions.act_window',
            'res_model': 'sales.report.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': 'main',  # بدلاً من 'new' لفتحه في الصفحة الرئيسية
            'context': self.env.context,
        }

    def action_print(self):
        """Print action"""
        # For now, just close the window
        return {'type': 'ir.actions.act_window_close'}