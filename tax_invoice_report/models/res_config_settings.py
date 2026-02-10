# -*- coding: utf-8 -*-

from odoo import api, fields, models, _



class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    gov_fee_account_id = fields.Many2one('account.account', string='Government Fee Account')

    def get_values(self):
        res = super(ResConfigSettings, self).get_values()
        IrDefault = self.env['ir.default'].sudo()
        res.update({
            'gov_fee_account_id': IrDefault.get('res.config.settings', 'gov_fee_account_id'),
        })
        return res

    def set_values(self):
        super(ResConfigSettings, self).set_values()
        IrDefault = self.env['ir.default'].sudo()
        IrDefault.set('res.config.settings', 'gov_fee_account_id', self.gov_fee_account_id.id)
        return True

    # @api.onchange('gov_fee')
    # def onchange_gov_fee(self):
    #     new_fee = sum(self.move_id._origin.invoice_line_ids.mapped('gov_fee')) - self._origin.gov_fee + self.gov_fee
    #     print('new_fee',new_fee)
    #     fee_line_id = self.move_id._origin.line_ids.filtered(lambda l:l.is_gov_fee_line)
    #     if fee_line_id.ids:
    #         fee_line_id = fee_line_id[0]
    #         fee_line_id.sudo().write({'price_unit':new_fee})
    #         print(fee_line_id)
    #     else:
    #         fee_acc_id = self.product_id.gov_fee_account_id.id or self.env['ir.default'].sudo().get('res.config.settings', 'gov_fee_account_id')
    #         print(fee_acc_id)
    #         line_vals = {
    #             'name':'Government Fee',
    #             'account_id':fee_acc_id,
    #             'price_unit':87,
    #             # 'price_unit':new_fee,
    #             'display_type':'fee',
    #             'display_type':'tax',
    #             'is_gov_fee_line':True,
    #         }
    #         self.move_id._origin.write({'line_ids': [(0, 0, line_vals)]})


