
import logging
from odoo import models, fields, api, _
from odoo.exceptions import UserError
from odoo.osv import expression

_logger = logging.getLogger(__name__)


class ProductTemplate(models.Model):
    _inherit = 'product.template'

    default_code = fields.Char(
        string='Internal Reference',
        copy=False,
        index=True,
        tracking=True,
    )

    x_remark = fields.Text(
        string='Remark',
        help='Additional remarks or notes about this product',
        tracking=True,
    )

    item_short_code = fields.Char(
        string='Item Short Code',
        help='Additional Short Code for this product',
        tracking=True,
        index=True,
    )

    remark_type_id = fields.Many2one(
        'product.remark.type',
        string='Remark Type',
        help='Select the remark type for this product'
    )

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get('default_code'):
                try:
                    sequence = self.env['ir.sequence'].next_by_code('product.reference')
                    if sequence:
                        vals['default_code'] = sequence
                    else:
                        self._create_sequence_if_not_exists()
                        sequence = self.env['ir.sequence'].next_by_code('product.reference')
                        if sequence:
                            vals['default_code'] = sequence
                except Exception as e:
                    _logger.error(f"Error generating product reference: {str(e)}")
        return super().create(vals_list)

    def _create_sequence_if_not_exists(self):
        sequence = self.env['ir.sequence'].sudo().search([('code', '=', 'product.reference')])
        if not sequence:
            self.env['ir.sequence'].sudo().create({
                'name': 'Product Reference Sequence',
                'code': 'product.reference',
                'prefix': 'PRD-',
                'padding': 5,
                'number_increment': 1,
                'number_next': 1,
            })


class ProductProduct(models.Model):
    _inherit = 'product.product'

    # ═══════════════════════════════════════════════════════════════════════
    # الحل الجديد في Odoo 18: _rec_names_search
    # هذا يضيف الـ fields للبحث في الـ Many2one dropdowns
    # ═══════════════════════════════════════════════════════════════════════
    _rec_names_search = ['name', 'default_code', 'barcode', 'item_short_code']

    x_remark = fields.Text(
        related='product_tmpl_id.x_remark',
        string='Remark',
        readonly=False,
        store=True,
    )

    # Related field - MUST be stored and indexed for search
    item_short_code = fields.Char(
        related='product_tmpl_id.item_short_code',
        string='Item Short Code',
        readonly=False,
        store=True,
        index=True,
    )

    # ═══════════════════════════════════════════════════════════════════════
    # Override _name_search للتأكد من البحث (backup method)
    # ═══════════════════════════════════════════════════════════════════════
    @api.model
    def _name_search(self, name='', domain=None, operator='ilike', limit=None, order=None):
        """
        Search products by item_short_code in Sales/Purchase Orders.
        This is a backup method in case _rec_names_search doesn't work.
        """
        domain = domain or []

        if name:
            # بناء domain للبحث في كل الـ fields
            search_domain = [
                '|', '|', '|',
                ('item_short_code', operator, name),
                ('default_code', operator, name),
                ('name', operator, name),
                ('barcode', operator, name),
            ]
            domain = expression.AND([search_domain, domain])

        return self._search(domain, limit=limit, order=order)

    # ═══════════════════════════════════════════════════════════════════════
    # Display Name - Show Short Code in dropdown
    # ═══════════════════════════════════════════════════════════════════════
    @api.depends('name', 'default_code', 'item_short_code', 'product_template_attribute_value_ids')
    @api.depends_context('display_default_code')
    def _compute_display_name(self):
        """
        Show item_short_code in display name.
        Format: [SHORT_CODE] [INTERNAL_REF] Product Name
        """
        for product in self:
            # Get variant name if exists
            variant = product.product_template_attribute_value_ids._get_combination_name()
            name = variant and f"{product.name} ({variant})" or product.name

            # Check context - default is True
            display_code = self._context.get('display_default_code', True)

            if display_code:
                codes = []
                # Short Code first
                if product.item_short_code:
                    codes.append(f'[{product.item_short_code}]')
                # Then Internal Reference
                if product.default_code:
                    codes.append(f'[{product.default_code}]')

                if codes:
                    name = f"{' '.join(codes)} {name}"

            product.display_name = name

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get('product_tmpl_id') and not vals.get('default_code'):
                try:
                    sequence = self.env['ir.sequence'].next_by_code('product.reference')
                    if sequence:
                        vals['default_code'] = sequence
                except Exception as e:
                    _logger.error(f"Error generating variant reference: {str(e)}")
        return super().create(vals_list)


class RemarkType(models.Model):
    _name = 'product.remark.type'
    _description = 'Product Remark Type'
    _rec_name = 'name'
    _order = 'sequence, name'

    name = fields.Char(string='Remark Type Name', required=True)
    sequence = fields.Integer(string='Sequence', default=10)
    active = fields.Boolean(string='Active', default=True)