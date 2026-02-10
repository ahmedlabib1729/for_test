# -*- coding: utf-8 -*-
# from odoo import http


# class SaleOrderReport(http.Controller):
#     @http.route('/sale_order_report/sale_order_report', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/sale_order_report/sale_order_report/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('sale_order_report.listing', {
#             'root': '/sale_order_report/sale_order_report',
#             'objects': http.request.env['sale_order_report.sale_order_report'].search([]),
#         })

#     @http.route('/sale_order_report/sale_order_report/objects/<model("sale_order_report.sale_order_report"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('sale_order_report.object', {
#             'object': obj
#         })

