# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


class ProductReview(models.Model):
    _name = 'product.review'
    _description = 'Product Review'
    _order = 'create_date desc'
    _inherit = ['mail.thread', 'mail.activity.mixin']  # ← جديد

    product_id = fields.Many2one('product.product', string='Product', required=True, ondelete='cascade', tracking=True)
    product_tmpl_id = fields.Many2one('product.template', string='Product Template',
                                      related='product_id.product_tmpl_id', store=True)
    user_id = fields.Many2one('res.users', string='User', default=lambda self: self.env.user)
    partner_id = fields.Many2one('res.partner', string='Customer', required=True,
                                 default=lambda self: self.env.user.partner_id)

    name = fields.Char(string='Customer Name', required=True, tracking=True)
    email = fields.Char(string='Email')
    rating = fields.Integer(string='Rating', required=True, default=5, tracking=True)
    title = fields.Char(string='Review Title')
    comment = fields.Text(string='Comment', required=True, tracking=True)

    is_verified = fields.Boolean(string='Verified Purchase', default=False, tracking=True)
    is_approved = fields.Boolean(string='Approved', default=True, tracking=True)

    helpful_count = fields.Integer(string='Helpful Count', default=0)

    @api.constrains('rating')
    def _check_rating(self):
        for record in self:
            if record.rating < 1 or record.rating > 5:
                raise ValidationError(_('Rating must be between 1 and 5'))

    def name_get(self):
        result = []
        for record in self:
            name = f"{record.name} - {record.product_id.display_name} ({record.rating}★)"
            result.append((record.id, name))
        return result

    def toggle_approved(self):
        """Toggle approval status"""
        for record in self:
            record.is_approved = not record.is_approved
            if record.is_approved:
                record.message_post(body=_("Review approved"))
            else:
                record.message_post(body=_("Review unapproved"))
        return True

    def mark_as_helpful(self):
        """Mark review as helpful"""
        for record in self:
            record.helpful_count += 1
        return True


class ProductProduct(models.Model):
    _inherit = 'product.product'

    review_ids = fields.One2many('product.review', 'product_id', string='Reviews')
    review_count = fields.Integer(string='Review Count', compute='_compute_review_stats', store=True)
    average_rating = fields.Float(string='Average Rating', compute='_compute_review_stats', store=True, digits=(3, 1))

    @api.depends('review_ids.rating', 'review_ids.is_approved')
    def _compute_review_stats(self):
        for product in self:
            approved_reviews = product.review_ids.filtered(lambda r: r.is_approved)
            product.review_count = len(approved_reviews)
            if product.review_count > 0:
                product.average_rating = sum(approved_reviews.mapped('rating')) / product.review_count
            else:
                product.average_rating = 0.0


class ProductTemplate(models.Model):
    _inherit = 'product.template'

    review_count = fields.Integer(string='Total Reviews', compute='_compute_template_reviews', store=True)
    average_rating = fields.Float(string='Average Rating', compute='_compute_template_reviews', store=True,
                                  digits=(3, 1))

    @api.depends('product_variant_ids.review_count', 'product_variant_ids.average_rating')
    def _compute_template_reviews(self):
        for template in self:
            total_count = sum(template.product_variant_ids.mapped('review_count'))
            template.review_count = total_count

            if total_count > 0:
                total_rating_sum = sum(
                    v.average_rating * v.review_count for v in template.product_variant_ids if v.review_count > 0)
                template.average_rating = total_rating_sum / total_count if total_count > 0 else 0.0
            else:
                template.average_rating = 0.0