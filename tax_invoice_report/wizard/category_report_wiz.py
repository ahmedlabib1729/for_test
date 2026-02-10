from odoo import models, fields, api, _


class CategoryReportWizard(models.TransientModel):
    _name = 'category.report.wizard'
    _description = 'Category Report Wizard'

    @api.model
    def default_get(self, fields):
        res = super(CategoryReportWizard, self).default_get(fields)
        category_ids = self.env['product.category'].search([('not_default_in_categ_report','=',False)])
        res.update({
            'category_ids': category_ids.ids,
        })
        return res

    date_from = fields.Date(string='From Date', )
    date_to = fields.Date(string='To Date', )
    category_ids = fields.Many2many('product.category', string='Product Categories')

    def get_records(self):
        lines = []
        for categ in self.category_ids:
            domain = [('move_id.move_type', '=', 'out_invoice')]
            domain += [('product_id.categ_id', '=', categ.id)]
            if self.date_from:
                domain += [('move_id.invoice_date', '>=', self.date_from)]
            if self.date_to:
                domain += [('move_id.invoice_date', '<=', self.date_to)]

            print(domain)
            categ_lines = self.sudo().env['account.move.line'].search(domain)
            lines.append(categ_lines)
        print("lll:", lines)
        return lines

    def generate_report(self):
        lines = self.get_records()
        categ_lines = []
        for line in lines:
            if line.ids:
                categ_name = line[0].product_id.categ_id.name
                tot_gov_fee = sum(l.gov_fee for l in line)
                tot_type_fee = sum(l.price_unit * l.quantity for l in line)
                tot_vat = sum(l.price_total - l.price_subtotal for l in line)
                count = sum(l.quantity for l in line)
                categ_lines.append((categ_name,tot_gov_fee,tot_type_fee,tot_vat,count))
        data = {
            'form': self.read()[0],
            'lines': categ_lines,
            }
        return self.env.ref('tax_invoice_report.category_report_analysis').sudo().report_action(self, data=data)
