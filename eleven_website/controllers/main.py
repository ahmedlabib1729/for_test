# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request
from odoo.addons.website_sale.controllers.main import WebsiteSale


class ElevenWebsite(http.Controller):
    """Custom Eleven Website Routes"""

    @http.route('/contactus', type='http', auth='public', website=True, methods=['GET', 'POST'])
    def contact_us(self, **post):
        """Contact Us Page"""
        if request.httprequest.method == 'POST':
            try:
                request.env['crm.lead'].sudo().create({
                    'name': post.get('subject', 'Contact Form'),
                    'contact_name': post.get('name'),
                    'email_from': post.get('email'),
                    'phone': post.get('phone'),
                    'description': post.get('description'),
                    'type': 'opportunity',
                })
                return request.redirect('/contactus?success=1')
            except Exception as e:
                return request.redirect('/contactus?error=1')

        return request.render('eleven_website.eleven_contact_us_page')

    @http.route('/products', type='http', auth='public', website=True)
    def shop_page(self, page=1, category=None, search='', sort='', **filters):
        """Custom Products/Shop Page"""
        # Products per page
        PPG = 12

        # Base domain
        domain = [
            ('sale_ok', '=', True),
            ('product_tmpl_id.website_published', '=', True),
        ]

        # Category filter
        if category and category != 'all':
            try:
                category_id = int(category)
                domain.append(('public_categ_ids', 'in', [category_id]))
            except:
                pass

        # Search filter
        if search:
            domain.append(('name', 'ilike', search))

        # Sorting
        order = 'sequence, name'
        if sort == 'name_asc':
            order = 'name asc'
        elif sort == 'name_desc':
            order = 'name desc'
        elif sort == 'price_asc':
            order = 'list_price asc'
        elif sort == 'price_desc':
            order = 'list_price desc'

        # Get Product Variants
        Product = request.env['product.product'].sudo()
        total_products = Product.search_count(domain)

        # Pagination
        page = int(page)
        offset = (page - 1) * PPG
        products = Product.search(domain, limit=PPG, offset=offset, order=order)

        # Pager
        pager = request.website.pager(
            url='/products',
            total=total_products,
            page=page,
            step=PPG,
            scope=5,
            url_args=filters,
        )

        # Get ALL public categories
        Category = request.env['product.public.category'].sudo()
        all_categories = Category.search([], order='sequence, name')

        # Filter categories that have products
        categories = []
        for cat in all_categories:
            count = Product.search_count([
                ('sale_ok', '=', True),
                ('product_tmpl_id.website_published', '=', True),
                ('public_categ_ids', 'in', [cat.id])
            ])
            if count > 0:
                categories.append(cat)

        # Get ALL product attributes (colors, sizes, etc)
        colors = set()
        sizes = set()
        other_attributes = {}

        all_products = Product.search([
            ('sale_ok', '=', True),
            ('product_tmpl_id.website_published', '=', True)
        ])

        for product in all_products:
            for ptav in product.product_template_attribute_value_ids:
                attribute = ptav.attribute_id
                attribute_name = attribute.name.lower()
                value_name = ptav.name

                if any(keyword in attribute_name for keyword in ['color', 'colour', 'لون']):
                    colors.add(value_name)
                elif any(keyword in attribute_name for keyword in ['size', 'مقاس', 'حجم']):
                    sizes.add(value_name)
                else:
                    if attribute.name not in other_attributes:
                        other_attributes[attribute.name] = set()
                    other_attributes[attribute.name].add(value_name)

        values = {
            'products': products,
            'categories': categories,
            'category': category or 'all',
            'colors': sorted(list(colors)) if colors else [],
            'sizes': sorted(list(sizes)) if sizes else [],
            'other_attributes': {k: sorted(list(v)) for k, v in other_attributes.items()},
            'pager': pager,
            'search': search,
            'sort': sort,
        }

        return request.render('eleven_website.eleven_shop_page', values)

    @http.route('/product/<int:product_id>', type='http', auth='public', website=True)
    def product_detail(self, product_id, **kwargs):
        """Custom Product Detail Page"""
        Product = request.env['product.product'].sudo()
        product = Product.browse(product_id)

        if not product.exists() or not product.product_tmpl_id.website_published:
            return request.redirect('/products')

        # Get reviews
        reviews = request.env['product.review'].sudo().search([
            ('product_id', '=', product_id),
            ('is_approved', '=', True)
        ], order='create_date desc')

        # Get related products (same category)
        related_products = Product.search([
            ('product_tmpl_id.website_published', '=', True),
            ('sale_ok', '=', True),
            ('public_categ_ids', 'in', product.public_categ_ids.ids),
            ('id', '!=', product_id)
        ], limit=4)

        values = {
            'product': product,
            'reviews': reviews,
            'related_products': related_products,
            'main_object': product,
        }

        return request.render('eleven_website.product_detail_page', values)

    @http.route('/product/<int:product_id>/review', type='http', auth='public', website=True, methods=['POST'],
                csrf=True)
    def submit_review(self, product_id, **post):
        """Submit Product Review"""
        try:
            rating = int(post.get('rating', 0))
            if rating < 1 or rating > 5:
                return request.redirect(f'/product/{product_id}?error=invalid_rating')

            request.env['product.review'].sudo().create({
                'product_id': product_id,
                'name': post.get('name'),
                'email': post.get('email'),
                'rating': rating,
                'title': post.get('title'),
                'comment': post.get('comment'),
                'is_approved': True,
            })

            return request.redirect(f'/product/{product_id}?success=review_submitted')
        except Exception as e:
            return request.redirect(f'/product/{product_id}?error=submission_failed')

    @http.route('/product/<int:product_id>/buy-now', type='http', auth='public', website=True, methods=['POST'],
                csrf=True)
    def buy_now(self, product_id, **post):
        """Add to cart and redirect to checkout"""
        try:
            order = request.website.sale_get_order(force_create=True)
            order._cart_update(
                product_id=int(product_id),
                add_qty=int(post.get('add_qty', 1)),
            )
            return request.redirect('/shop/checkout')
        except Exception as e:
            return request.redirect(f'/product/{product_id}?error=add_to_cart_failed')


    @http.route('/cart', type='http', auth='public', website=True)
    def custom_cart(self, **kwargs):
        """Custom Cart Page"""
        order = request.website.sale_get_order()

        if not order or not order.order_line:
            # Empty cart
            return request.render('eleven_website.eleven_cart_page', {
                'order': None,
                'order_lines': [],
            })

        values = {
            'order': order,
            'order_lines': order.order_line,
            'suggested_products': request.env['product.product'].sudo().search([
                ('sale_ok', '=', True),
                ('product_tmpl_id.website_published', '=', True)
            ], limit=4, order='create_date desc'),
        }

        return request.render('eleven_website.eleven_cart_page', values)


    @http.route('/cart/update', type='http', auth='public', methods=['POST'], website=True, csrf=True)
    def cart_update_json(self, product_id, add_qty=1, set_qty=0, **kwargs):
        """Update cart quantity"""
        order = request.website.sale_get_order(force_create=True)

        if set_qty:
            order._cart_update(
                product_id=int(product_id),
                set_qty=float(set_qty),
            )
        else:
            order._cart_update(
                product_id=int(product_id),
                add_qty=float(add_qty),
            )

        return request.redirect('/cart')


    @http.route('/cart/delete/<int:line_id>', type='http', auth='public', website=True, csrf=True)
    def cart_delete_line(self, line_id, **kwargs):
        """Delete line from cart"""
        order = request.website.sale_get_order()

        if order:
            line = order.order_line.filtered(lambda l: l.id == line_id)
            if line:
                line.unlink()

        return request.redirect('/cart')

    @http.route('/shop/cart/update', type='http', auth='public', methods=['POST'], website=True, csrf=True)
    def shop_cart_update_redirect(self, product_id, add_qty=1, set_qty=0, **kwargs):
        """Override Odoo cart update to redirect to custom cart"""
        order = request.website.sale_get_order(force_create=True)

        if set_qty:
            order._cart_update(
                product_id=int(product_id),
                set_qty=float(set_qty),
            )
        else:
            order._cart_update(
                product_id=int(product_id),
                add_qty=float(add_qty),
            )

        return request.redirect('/cart')

    @http.route('/about', type='http', auth='public', website=True)
    def about_page(self, **kwargs):
        """About Us Page"""
        return request.render('eleven_website.eleven_about_page')