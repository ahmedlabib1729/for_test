# -*- coding: utf-8 -*-
from odoo import models, fields


class ProductProduct(models.Model):
    _inherit = 'product.product'

    is_best_seller = fields.Boolean(
        string='Best Seller',
        default=False,
        help='Enable this to show product variant in Best Sellers section on homepage'
    )