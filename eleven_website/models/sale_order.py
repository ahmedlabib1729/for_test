# -*- coding: utf-8 -*-
from odoo import models, api


class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _get_product_url(self):
        """Override product URL to use custom product page"""
        self.ensure_one()
        if self.product_id:
            return f'/product/{self.product_id.id}'
        return super()._get_product_url()


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def _cart_find_product_line(self, product_id=None, line_id=None, **kwargs):
        """Override to ensure we work with product variants"""
        lines = super()._cart_find_product_line(product_id=product_id, line_id=line_id, **kwargs)
        return lines