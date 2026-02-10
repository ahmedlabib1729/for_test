# models/res_partner.py
from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


class ResPartner(models.Model):
    _inherit = 'res.partner'

    # Partner Type field
    x_partner_type = fields.Selection([
        ('customer', 'Customer'),
        ('vendor', 'Vendor'),
        ('both', 'Customer & Vendor'),
        ('other', 'Other    ')
    ], string='Partner Type',
        default='customer',
        required=True,
        tracking=True)

    # Override ref to make it readonly
    ref = fields.Char(
        string='Reference',
        copy=False,
        index=True,
        tracking=True,
        readonly=True
    )

    # Make fields required
    mobile = fields.Char(
        string='Mobile',
        required=True,
        tracking=True
    )

    category_id = fields.Many2many(
        'res.partner.category',
        column1='partner_id',
        column2='category_id',
        string='Tags',
        required=True
    )

    country_id = fields.Many2one(
        'res.country',
        string='Country',
        required=True,
        ondelete='restrict'
    )

    @api.model_create_multi
    def create(self, vals_list):
        """Generate reference on creation"""
        for vals in vals_list:
            if not vals.get('ref'):
                partner_type = vals.get('x_partner_type', 'customer')

                # Determine sequence
                if partner_type == 'vendor':
                    sequence_code = 'partner.supplier.reference'
                elif partner_type in ['customer']:
                    sequence_code = 'partner.customer.reference'
                elif partner_type in [ 'both']:
                    sequence_code = 'partner.both.reference'
                else:
                    sequence_code = 'partner.general.reference'

                # Get next sequence
                vals['ref'] = self.env['ir.sequence'].next_by_code(sequence_code) or '/'

            # Validate required fields (skip for internal users)
            if vals.get('partner_share', True):
                if not vals.get('mobile'):
                    raise ValidationError(_('Mobile is required'))
                if not vals.get('category_id'):
                    raise ValidationError(_('At least one tag is required'))
                if not vals.get('country_id'):
                    # Set default country
                    uae = self.env['res.country'].search([('code', '=', 'AE')], limit=1)
                    if uae:
                        vals['country_id'] = uae.id

        return super().create(vals_list)

    @api.constrains('mobile')
    def _check_mobile(self):
        """Validate mobile format"""
        for partner in self:
            if partner.mobile:
                digits = ''.join(c for c in partner.mobile if c.isdigit())
                if len(digits) < 10:
                    raise ValidationError(_('Mobile must be at least 10 digits'))

    @api.model
    def default_get(self, fields_list):
        """Set defaults"""
        defaults = super().default_get(fields_list)

        # Default country
        if 'country_id' in fields_list:
            uae = self.env['res.country'].search([('code', '=', 'AE')], limit=1)
            if uae:
                defaults['country_id'] = uae.id

        # Default type
        if 'x_partner_type' in fields_list:
            defaults['x_partner_type'] = 'customer'

        return defaults

    @api.onchange('country_id')
    def _onchange_country_id(self):
        """Add country code to mobile"""
        if self.country_id and self.country_id.phone_code:
            if not self.mobile:
                self.mobile = '+' + str(self.country_id.phone_code)