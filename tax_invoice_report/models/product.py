from odoo import fields, models, api


class ProductTemp(models.Model):
    _inherit = 'product.template'

    gov_fee = fields.Float('Government Fee')
    gov_fee_account_id = fields.Many2one('account.account', string='Government Fee Account')

    @api.onchange('list_price')
    def _onchange_list_price(self):
        for rec in self:
            rec.product_variant_id.lst_price = rec.list_price


class ProductProduct(models.Model):
    _inherit = 'product.product'

    @api.onchange('lst_price')
    def _onchange_lst_price(self):
        for rec in self:
            rec.product_tmpl_id.list_price = rec.lst_price


class ProductCateg(models.Model):
    _inherit = 'product.category'

    not_default_in_categ_report = fields.Boolean(
        string='Not Default In Invoice Category Report',
        required=False)
