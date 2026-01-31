# -*- coding: utf-8 -*-
from odoo import http, _
from odoo.http import request
from odoo.addons.portal.controllers.portal import CustomerPortal, pager as portal_pager
from collections import OrderedDict
from odoo.osv.expression import OR, AND
from odoo.exceptions import AccessError, MissingError
import datetime


class ShipmentPortal(CustomerPortal):

    @http.route(['/my', '/my/home'], type='http', auth="user", website=True)
    def home(self, **kw):
        user = request.env.user

        # لو المستخدم عميل (Portal User) → يروح لصفحة الشحنات
        if user.has_group('base.group_portal'):
            return request.redirect('/my/shipments')

        # لو مستخدم داخلي (موظف) → يروح للصفحة العادية
        values = self._prepare_home_portal_values(counters=['shipment_count'])
        return request.render("portal.portal_my_home", values)

    def _prepare_home_portal_values(self, counters):
        values = super()._prepare_home_portal_values(counters)
        user = request.env.user

        if 'shipment_count' in counters:
            shipment_count = request.env['shipment.order'].search_count([
                ('sender_id', '=', user.partner_id.id)
            ]) if request.env['shipment.order'].check_access_rights('read', raise_exception=False) else 0
            values['shipment_count'] = shipment_count

        return values

    def _prepare_portal_layout_values(self):
        """Include shipment count in portal layout"""
        values = super()._prepare_portal_layout_values()
        user = request.env.user

        values['shipment_count'] = request.env['shipment.order'].search_count([
            ('sender_id', '=', user.partner_id.id)
        ])

        return values

    def _get_shipment_financial_data(self, shipment):
        """
        حساب البيانات المالية للشحنة

        Returns:
            dict: {
                'cod_amount': مبلغ COD الإجمالي,
                'invoice_amount': مبلغ الفاتورة (رسوم الشحن),
                'net_amount': المبلغ الصافي المستحق للعميل,
                'invoice': الفاتورة إن وجدت,
                'has_invoice': هل يوجد فاتورة
            }
        """
        # البحث عن فاتورة العميل المرتبطة بالشحنة
        invoice = request.env['account.move'].sudo().search([
            ('shipment_id', '=', shipment.id),
            ('move_type', '=', 'out_invoice'),
            ('state', '!=', 'cancel')
        ], limit=1)

        # مبلغ COD من الحقل المحسوب
        cod_amount = shipment.cod_amount_sheet_excel or 0

        # مبلغ الفاتورة
        invoice_amount = invoice.amount_total if invoice else 0
        invoice_paid = (invoice.amount_total - invoice.amount_residual) if invoice else 0
        invoice_remaining = invoice.amount_residual if invoice else 0

        # المبلغ الصافي المستحق للعميل = COD - مبلغ الفاتورة
        net_amount = cod_amount - invoice_amount

        return {
            'cod_amount': cod_amount,
            'invoice_amount': invoice_amount,
            'invoice_paid': invoice_paid,
            'invoice_remaining': invoice_remaining,
            'net_amount': net_amount,
            'invoice': invoice,
            'has_invoice': bool(invoice),
        }

    def _get_shipments_summary(self, partner_id):
        """
        حساب ملخص مالي لجميع شحنات العميل
        """
        ShipmentOrder = request.env['shipment.order'].sudo()

        # جميع شحنات العميل
        all_shipments = ShipmentOrder.search([
            ('sender_id', '=', partner_id)
        ])

        # شحنات COD فقط
        cod_shipments = all_shipments.filtered(lambda s: s.payment_method == 'cod')

        # الشحنات المسلمة
        delivered_cod = cod_shipments.filtered(lambda s: s.state == 'delivered')

        total_cod = 0
        total_invoices = 0
        total_net_receivable = 0

        for shipment in delivered_cod:
            fin = self._get_shipment_financial_data(shipment)
            total_cod += fin['cod_amount']
            total_invoices += fin['invoice_amount']
            total_net_receivable += fin['net_amount']

        return {
            'total_shipments': len(all_shipments),
            'cod_shipments_count': len(cod_shipments),
            'delivered_count': len(all_shipments.filtered(lambda s: s.state == 'delivered')),
            'in_transit_count': len(
                all_shipments.filtered(lambda s: s.state in ['picked', 'in_transit', 'out_for_delivery'])),
            'total_cod': total_cod,
            'total_invoices': total_invoices,
            'total_net_receivable': total_net_receivable,
        }

    @http.route(['/my/shipments', '/my/shipments/page/<int:page>'], type='http', auth="user", website=True)
    def portal_my_shipments(self, page=1, date_begin=None, date_end=None, sortby=None, filterby=None, **kw):
        values = self._prepare_portal_layout_values()
        user = request.env.user
        ShipmentOrder = request.env['shipment.order']

        domain = [('sender_id', '=', user.partner_id.id)]

        # Archive groups
        archive_groups = self._get_archive_groups('shipment.order', domain) if values.get('my_details') else []

        # Filters
        searchbar_filters = {
            'all': {'label': _('الكل'), 'domain': []},
            'draft': {'label': _('مسودة'), 'domain': [('state', '=', 'draft')]},
            'confirmed': {'label': _('مؤكدة'), 'domain': [('state', '=', 'confirmed')]},
            'in_transit': {'label': _('في الطريق'),
                           'domain': [('state', 'in', ['picked', 'in_transit', 'out_for_delivery'])]},
            'delivered': {'label': _('تم التسليم'), 'domain': [('state', '=', 'delivered')]},
            'returned': {'label': _('مرتجع'), 'domain': [('state', '=', 'returned')]},
            'cancelled': {'label': _('ملغاة'), 'domain': [('state', '=', 'cancelled')]},
            'cod_only': {'label': _('COD فقط'), 'domain': [('payment_method', '=', 'cod')]},
        }

        # Sort by
        searchbar_sortings = {
            'date': {'label': _('الأحدث'), 'order': 'create_date desc'},
            'order_number': {'label': _('رقم الطلب'), 'order': 'order_number'},
            'state': {'label': _('الحالة'), 'order': 'state'},
            'cod_amount': {'label': _('مبلغ COD'), 'order': 'cod_amount_sheet_excel desc'},
        }

        # Default sort and filter
        if not sortby:
            sortby = 'date'
        if not filterby:
            filterby = 'all'

        sort_order = searchbar_sortings[sortby]['order']
        filter_domain = searchbar_filters[filterby]['domain']

        if filter_domain:
            domain = AND([domain, filter_domain])

        # Date filter
        if date_begin and date_end:
            domain = AND([domain, [('create_date', '>', date_begin), ('create_date', '<=', date_end)]])

        # Count for pager
        shipment_count = ShipmentOrder.search_count(domain)

        # Pager
        pager = portal_pager(
            url="/my/shipments",
            url_args={'date_begin': date_begin, 'date_end': date_end, 'sortby': sortby, 'filterby': filterby},
            total=shipment_count,
            page=page,
            step=self._items_per_page
        )

        # Fetch records
        shipments = ShipmentOrder.search(domain, order=sort_order, limit=self._items_per_page, offset=pager['offset'])

        # حساب البيانات المالية لكل شحنة
        shipments_with_financial = []
        page_total_cod = 0
        page_total_invoice = 0
        page_total_net = 0

        for shipment in shipments:
            fin_data = self._get_shipment_financial_data(shipment)
            shipments_with_financial.append({
                'shipment': shipment,
                'financial': fin_data,
            })
            if shipment.payment_method == 'cod':
                page_total_cod += fin_data['cod_amount']
                page_total_invoice += fin_data['invoice_amount']
                page_total_net += fin_data['net_amount']

        # الحصول على الملخص العام
        summary = self._get_shipments_summary(user.partner_id.id)

        values.update({
            'date': date_begin,
            'shipments': shipments,
            'shipments_with_financial': shipments_with_financial,
            'page_name': 'shipment',
            'pager': pager,
            'archive_groups': archive_groups,
            'default_url': '/my/shipments',
            'searchbar_sortings': searchbar_sortings,
            'sortby': sortby,
            'searchbar_filters': OrderedDict(sorted(searchbar_filters.items())),
            'filterby': filterby,
            # إحصائيات الصفحة الحالية
            'page_total_cod': page_total_cod,
            'page_total_invoice': page_total_invoice,
            'page_total_net': page_total_net,
            # الملخص العام
            'summary': summary,
        })

        return request.render("shipping_management_system.portal_my_shipments", values)

    @http.route(['/my/shipment/<int:shipment_id>'], type='http', auth="user", website=True)
    def portal_my_shipment_detail(self, shipment_id=None, access_token=None, **kw):
        try:
            shipment_sudo = self._document_check_access('shipment.order', shipment_id, access_token)
        except (AccessError, MissingError):
            return request.redirect('/my')

        values = self._shipment_get_page_view_values(shipment_sudo, access_token, **kw)

        # إضافة البيانات المالية
        financial = self._get_shipment_financial_data(shipment_sudo)
        values['financial'] = financial

        # البحث عن الدفعات المقدمة إن وجدت
        advance_payments = request.env['account.payment'].sudo().search([
            ('shipment_advance_id', '=', shipment_sudo.id),
            ('state', '!=', 'cancelled')
        ])
        values['advance_payments'] = advance_payments
        values['total_advance_paid'] = sum(advance_payments.mapped('amount'))

        return request.render("shipping_management_system.portal_my_shipment_detail", values)

    def _shipment_get_page_view_values(self, shipment, access_token, **kwargs):
        values = {
            'page_name': 'shipment',
            'shipment': shipment,
            'user': request.env.user
        }
        return self._get_page_view_values(shipment, access_token, values, 'my_shipments_history', False, **kwargs)

    # =====================================================
    # Invoices Portal
    # =====================================================

    @http.route(['/my/invoices', '/my/invoices/page/<int:page>'], type='http', auth="user", website=True)
    def portal_my_invoices(self, page=1, date_begin=None, date_end=None, sortby=None, filterby=None, **kw):
        values = self._prepare_portal_layout_values()
        user = request.env.user
        AccountMove = request.env['account.move']

        values['overdue_invoice_count'] = 0
        values['bills'] = False

        # Domain للفواتير الخاصة بالعميل
        domain = [
            ('move_type', '=', 'out_invoice'),
            ('partner_id', '=', user.partner_id.id),
            ('state', '!=', 'cancel')
        ]

        # Filters
        searchbar_filters = {
            'all': {'label': _('الكل'), 'domain': []},
            'draft': {'label': _('مسودة'), 'domain': [('state', '=', 'draft')]},
            'posted': {'label': _('مؤكدة'), 'domain': [('state', '=', 'posted')]},
            'paid': {'label': _('مدفوعة'), 'domain': [('payment_state', '=', 'paid')]},
            'unpaid': {'label': _('غير مدفوعة'), 'domain': [('payment_state', 'in', ['not_paid', 'partial'])]},
        }

        # Sort by
        searchbar_sortings = {
            'date': {'label': _('الأحدث'), 'order': 'invoice_date desc'},
            'due_date': {'label': _('تاريخ الاستحقاق'), 'order': 'invoice_date_due'},
            'amount': {'label': _('المبلغ'), 'order': 'amount_total desc'},
            'state': {'label': _('الحالة'), 'order': 'state'},
        }

        # Default sort and filter
        if not sortby:
            sortby = 'date'
        if not filterby:
            filterby = 'all'

        sort_order = searchbar_sortings[sortby]['order']
        filter_domain = searchbar_filters[filterby]['domain']

        if filter_domain:
            domain = domain + filter_domain

        # Date filter
        if date_begin and date_end:
            domain += [('invoice_date', '>', date_begin), ('invoice_date', '<=', date_end)]

        # Get invoices
        invoice_count = AccountMove.search_count(domain)

        # Pager
        pager = portal_pager(
            url="/my/invoices",
            url_args={'date_begin': date_begin, 'date_end': date_end, 'sortby': sortby, 'filterby': filterby},
            total=invoice_count,
            page=page,
            step=self._items_per_page
        )

        # Fetch records
        invoices = AccountMove.search(domain, order=sort_order, limit=self._items_per_page, offset=pager['offset'])

        # Calculate statistics
        all_invoices = AccountMove.search([
            ('move_type', '=', 'out_invoice'),
            ('partner_id', '=', user.partner_id.id),
            ('state', '!=', 'cancel')
        ])

        total_amount = sum(all_invoices.mapped('amount_total')) if all_invoices else 0
        paid_amount = sum(
            all_invoices.filtered(lambda i: i.payment_state == 'paid').mapped('amount_total')) if all_invoices else 0
        unpaid_invoices = all_invoices.filtered(
            lambda i: i.payment_state in ['not_paid', 'partial']) if all_invoices else []
        unpaid_amount = sum(unpaid_invoices.mapped('amount_residual')) if unpaid_invoices else 0

        # حساب الفواتير المتأخرة
        from datetime import date
        today = date.today()
        overdue_invoices = []
        if unpaid_invoices:
            for inv in unpaid_invoices:
                if inv.invoice_date_due and inv.invoice_date_due < today:
                    overdue_invoices.append(inv)

        values.update({
            'date': date_begin,
            'invoices': invoices,
            'page_name': 'invoice',
            'pager': pager,
            'default_url': '/my/invoices',
            'searchbar_sortings': searchbar_sortings,
            'sortby': sortby,
            'searchbar_filters': OrderedDict(sorted(searchbar_filters.items())),
            'filterby': filterby,
            'total_amount': total_amount,
            'paid_amount': paid_amount,
            'unpaid_amount': unpaid_amount,
            'invoice_count': len(all_invoices) if all_invoices else 0,
            'paid_count': len(all_invoices.filtered(lambda i: i.payment_state == 'paid')) if all_invoices else 0,
            'unpaid_count': len(unpaid_invoices) if unpaid_invoices else 0,
            'overdue_count': len(overdue_invoices),
            'overdue_invoice_count': len(overdue_invoices),
        })

        return request.render("shipping_management_system.portal_my_invoices", values)

    @http.route(['/my/invoice/<int:invoice_id>'], type='http', auth="user", website=True)
    def portal_my_invoice_detail(self, invoice_id=None, access_token=None, **kw):
        try:
            invoice_sudo = self._document_check_access('account.move', invoice_id, access_token)
        except (AccessError, MissingError):
            return request.redirect('/my')

        # البحث عن الشحنة المرتبطة
        shipment = None
        if invoice_sudo.shipment_id:
            shipment = invoice_sudo.shipment_id

        values = {
            'page_name': 'invoice',
            'invoice': invoice_sudo,
            'shipment': shipment,
            'user': request.env.user
        }

        return request.render("shipping_management_system.portal_my_invoice_detail", values)


class ToroodWebsite(http.Controller):

    @http.route(['/shipment', '/shipment/request'], type='http', auth='public', website=True)
    def shipment_form(self, **kwargs):
        """عرض صفحة طلب الشحن"""
        categories = request.env['product.category'].sudo().search([])
        brands = request.env['product.brand'].sudo().search([('active', '=', True)])

        values = {
            'categories': categories,
            'brands': brands,
            'error': {},
            'success': kwargs.get('success', False)
        }

        values.update(kwargs)
        return request.render('shipping_management_system.shipment_request_form', values)