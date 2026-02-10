from odoo import fields, models, api,_
from num2words import num2words
from datetime import date, datetime, timedelta
from odoo.exceptions import ValidationError



class AccountMove(models.Model):
    _inherit = 'account.move.line'

    gov_fee = fields.Float('Government Fee')
    fee_partner_id = fields.Many2one('res.partner',string='Partner')
    app_no = fields.Char('App. No')
    is_gov_fee_line = fields.Boolean(
        string='Is_gov_fee_line',
        default=False)
    display_type = fields.Selection(selection_add=[
        ('fee', 'Fee'),
    ], ondelete={'fee': 'cascade'})


    @api.onchange('product_id')
    def _onchange_product_id(self):
        for rec in self:
            rec.gov_fee = rec.product_id.gov_fee



class NewModule(models.Model):
    _inherit = 'account.move'

    inv_datetime = fields.Datetime('Inv Date Time')
    employee_id = fields.Many2one('hr.employee', string='Employee')
    token = fields.Char('Token')
    show_related_contact = fields.Boolean('Show Partner Related Contacts')
    invoice_line_ids = fields.One2many(  # /!\ invoice_line_ids is just a subset of line_ids.
        domain=[('display_type', 'in', ('product', 'line_section', 'line_note')),('is_gov_fee_line','=',False)],
    )



    def get_ar_word(self, amount, lang):
        return num2words(amount, lang=lang)

    def action_post(self):
        if self.move_type == 'out_invoice':
            new_fee = sum(self.invoice_line_ids.mapped('gov_fee'))
            gov_fee_product = self.env.ref('tax_invoice_report.gov_feee_product')
            gov_fee_product.lst_price = new_fee
            fee_line_id = self.line_ids.filtered(lambda l: l.is_gov_fee_line)
            if not fee_line_id.ids:
                fee_acc_id = self.env['ir.default'].sudo().get('res.config.settings', 'gov_fee_account_id')
                print(fee_acc_id)
                product_line = self.invoice_line_ids
                if product_line.ids:
                    product_line = product_line[0]
                    line_vals = {
                        'product_id': gov_fee_product.id,
                        'account_id': fee_acc_id,
                        'price_unit':new_fee,
                        'is_gov_fee_line': True,
                        'move_id': self.id,
                        'tax_ids': False,
                        'name':gov_fee_product.display_name,
                    }
                    fee_line_id = product_line.copy(line_vals)
            else:
                fee_line_id = fee_line_id[0]
                fee_line_id.write({'price_unit': new_fee, })
            # fee_line_id._inverse_product_id()

        res = super(NewModule, self).action_post()
        self.inv_datetime = fields.Datetime.now()
        return res




class AmmarTaxInv(models.AbstractModel):
    _name = 'report.tax_invoice_report.tax_invoice_template_id'
    # _inherit = 'report.tax_invoice_report.tax_invoice_template_id'

    @api.model
    def _get_report_values(self, docids, data=None):
        # rslt = super()._get_report_values(docids, data)
        print('docids>>>>>',docids)
        mv_model = self.env['account.move'].sudo()
        docs = mv_model.browse(docids)
        if any(doc.payment_state not in ['paid'] for doc in docs):
            raise ValidationError(_(f"Only Paid Invoice Can Be Printed"))
        return {
            'doc_ids': docids,
            'doc_model': self.env['account.move'],
            # 'data': data['form'],
            'docs': docs,
            # 'time': time,
            # 'Accounts': accounts_res,
            # 'print_journal': codes,
        }

