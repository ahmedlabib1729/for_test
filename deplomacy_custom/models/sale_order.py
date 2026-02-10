# models/sale_order.py - مُصلح لعرض الكمية المتاحة بشكل صحيح
from odoo import models, fields, api, _
from odoo.exceptions import UserError
from datetime import datetime, timedelta
from collections import defaultdict
import logging

_logger = logging.getLogger(__name__)


class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    # حقل التكلفة
    x_product_cost = fields.Float(
        string='Cost',
        compute='_compute_product_cost',
        store=True,
        readonly=True,
        help='Product cost from standard price'
    )

    # الكمية المتاحة في المخزن - مُحدث
    x_qty_available = fields.Float(
        string='Available',
        compute='_compute_qty_available',
        help='Free to use quantity in stock'
    )

    # صافي الربح
    x_profit_amount = fields.Float(
        string='Net Profit',
        compute='_compute_profit',
        store=True,
        help='Net profit for this line (Price - Cost) * Qty'
    )

    # نسبة الربح
    x_profit_margin = fields.Float(
        string='Profit %',
        compute='_compute_profit',
        store=True,
        help='Profit margin percentage'
    )
    has_product = fields.Boolean(compute='_compute_has_product', store=False)

    product_image = fields.Binary(
        string='Product Image',
        related='product_id.image_128',  # استخدم image_128 للحجم الصغير
        readonly=True,
        store=False
    )

    # أو يمكنك استخدام حقول مختلفة للأحجام المختلفة
    product_image_small = fields.Binary(
        string='Image',
        related='product_id.image_128',
        readonly=True
    )

    product_image_medium = fields.Binary(
        string='Image Medium',
        related='product_id.image_512',
        readonly=True
    )

    @api.depends('product_id')
    def _compute_product_cost(self):
        """Get product cost from standard price"""
        for line in self:
            if line.product_id:
                line.x_product_cost = line.product_id.standard_price
            else:
                line.x_product_cost = 0.0

    @api.depends('product_id', 'product_uom_qty', 'order_id.state', 'order_id.warehouse_id')
    def _compute_qty_available(self):
        """Get free to use quantity correctly for Odoo 18"""
        for line in self:
            if line.product_id:
                # استخدم مباشرة الحقول المتاحة في المنتج
                product = line.product_id

                # جرب الحصول على الكمية المتاحة مباشرة
                if hasattr(product, 'free_qty'):
                    line.x_qty_available = product.free_qty
                elif hasattr(product, 'qty_available'):
                    # احسب الكمية المتاحة = الكمية الموجودة - الكمية المحجوزة
                    qty_on_hand = product.qty_available or 0.0
                    qty_reserved = product.outgoing_qty or 0.0
                    line.x_qty_available = qty_on_hand - qty_reserved
                else:
                    # إذا فشل كل شيء، استخدم 0
                    line.x_qty_available = 0.0
            else:
                line.x_qty_available = 0.0

    @api.depends('price_unit', 'product_uom_qty', 'x_product_cost', 'discount')
    def _compute_profit(self):
        """Calculate profit amount and margin"""
        for line in self:
            # Calculate actual price after discount
            price_after_discount = line.price_unit * (1 - (line.discount or 0.0) / 100.0)

            # Calculate profit per unit
            profit_per_unit = price_after_discount - line.x_product_cost

            # Total profit
            line.x_profit_amount = profit_per_unit * line.product_uom_qty

            # Profit margin percentage
            if price_after_discount > 0:
                line.x_profit_margin = (profit_per_unit / price_after_discount) * 100
            else:
                line.x_profit_margin = 0.0

    @api.onchange('product_id')
    def _onchange_product_id_check_availability(self):
        """Warning if quantity not available + Debug info"""
        if self.product_id and self.product_id.type == 'product':
            StockQuant = self.env['stock.quant']

            # الحصول على المخزن
            warehouse = self.order_id.warehouse_id

            if warehouse:
                location = warehouse.lot_stock_id

                # البحث عن quants
                quants = StockQuant.search([
                    ('product_id', '=', self.product_id.id),
                    ('location_id', '=', location.id)
                ])

                # حساب الكمية المتاحة
                total_qty = sum(quant.quantity for quant in quants)
                reserved_qty = sum(quant.reserved_quantity for quant in quants)
                available = total_qty - reserved_qty
            else:
                # الطريقة البديلة
                available = self.product_id.qty_available - self.product_id.outgoing_qty

            if available <= 0:
                return {
                    'warning': {
                        'title': _('No Stock Available'),
                        'message': _(
                            'Product %s has no available stock!\nTotal Quantity: %s\nReserved: %s\nFree to use: %s') % (
                                       self.product_id.name,
                                       total_qty if warehouse else self.product_id.qty_available,
                                       reserved_qty if warehouse else self.product_id.outgoing_qty,
                                       available
                                   )
                    }
                }
            elif self.product_uom_qty and self.product_uom_qty > available:
                return {
                    'warning': {
                        'title': _('Insufficient Stock'),
                        'message': _('Available quantity (%s) is less than ordered quantity (%s)!') % (
                            available,
                            self.product_uom_qty
                        )
                    }
                }

    @api.depends('product_id')
    def _compute_has_product(self):
        for line in self:
            line.has_product = bool(line.product_id)

    def action_view_product_sales_history(self):
        """فتح نافذة تاريخ مبيعات المنتج"""
        self.ensure_one()

        _logger.info(f"Opening history for product: {self.product_id.name if self.product_id else 'No Product'}")

        if not self.product_id:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'تحذير',
                    'message': 'يرجى اختيار منتج أولاً',
                    'type': 'warning',
                    'sticky': False,
                }
            }

        # إنشاء الـ wizard
        wizard = self.env['product.sales.history.wizard'].create({
            'product_id': self.product_id.id,
            'current_partner_id': self.order_id.partner_id.id if self.order_id else False,
        })

        return {
            'name': f'📊 تاريخ مبيعات: {self.product_id.display_name}',
            'type': 'ir.actions.act_window',
            'res_model': 'product.sales.history.wizard',
            'view_mode': 'form',
            'res_id': wizard.id,
            'target': 'new',
            'context': {'dialog_size': 'extra-large'},
        }


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    traking_num = fields.Text(
        string='Traking Number',

        tracking=True,  # لتتبع التغييرات
    )
    # ==================== إجمالي الكل ====================
    # إجمالي التكلفة
    x_total_cost = fields.Float(
        string='Total Cost',
        compute='_compute_totals',
        store=True,
        help='Total cost of all products'
    )

    # إجمالي الربح
    x_total_profit = fields.Float(
        string='Total Profit',
        compute='_compute_totals',
        store=True,
        help='Total profit for this order'
    )

    # نسبة الربح الإجمالية
    x_profit_margin = fields.Float(
        string='Profit Margin %',
        compute='_compute_totals',
        store=True,
        help='Overall profit margin percentage'
    )

    # ==================== حقول المنتجات المخزنية (Storable Products) ====================
    x_product_total_cost = fields.Float(
        string='Products Cost',
        compute='_compute_totals',
        store=True,
        help='Total cost of storable products only'
    )

    x_product_total_profit = fields.Float(
        string='Products Profit',
        compute='_compute_totals',
        store=True,
        help='Total profit for storable products only'
    )

    x_product_profit_margin = fields.Float(
        string='Products Margin %',
        compute='_compute_totals',
        store=True,
        help='Profit margin percentage for storable products'
    )

    x_product_subtotal = fields.Float(
        string='Products Subtotal',
        compute='_compute_totals',
        store=True,
        help='Subtotal amount for storable products (before tax)'
    )

    # ==================== حقول الخدمات (Services) ====================
    x_service_total_cost = fields.Float(
        string='Services Cost',
        compute='_compute_totals',
        store=True,
        help='Total cost of services only'
    )

    x_service_total_profit = fields.Float(
        string='Services Profit',
        compute='_compute_totals',
        store=True,
        help='Total profit for services only'
    )

    x_service_profit_margin = fields.Float(
        string='Services Margin %',
        compute='_compute_totals',
        store=True,
        help='Profit margin percentage for services'
    )

    x_service_subtotal = fields.Float(
        string='Services Subtotal',
        compute='_compute_totals',
        store=True,
        help='Subtotal amount for services (before tax)'
    )

    @api.depends('order_line.x_product_cost', 'order_line.x_profit_amount', 'order_line.price_subtotal',
                 'order_line.product_id', 'order_line.product_uom_qty', 'amount_untaxed')
    def _compute_totals(self):
        """Calculate order totals - separated by product type"""
        for order in self:
            # متغيرات للمنتجات المخزنية (Storable)
            product_cost = 0.0
            product_profit = 0.0
            product_subtotal = 0.0

            # متغيرات للخدمات (Service)
            service_cost = 0.0
            service_profit = 0.0
            service_subtotal = 0.0

            for line in order.order_line:
                line_cost = line.x_product_cost * line.product_uom_qty
                line_profit = line.x_profit_amount
                line_subtotal = line.price_subtotal

                # التحقق من نوع المنتج
                if line.product_id:
                    if line.product_id.type == 'product':
                        # منتج مخزني (Storable Product)
                        product_cost += line_cost
                        product_profit += line_profit
                        product_subtotal += line_subtotal
                    elif line.product_id.type == 'service':
                        # خدمة (Service)
                        service_cost += line_cost
                        service_profit += line_profit
                        service_subtotal += line_subtotal
                    else:
                        # أنواع أخرى (Consumable, etc.) - نضيفها للمنتجات
                        product_cost += line_cost
                        product_profit += line_profit
                        product_subtotal += line_subtotal

            # تعيين قيم المنتجات المخزنية
            order.x_product_total_cost = product_cost
            order.x_product_total_profit = product_profit
            order.x_product_subtotal = product_subtotal

            # حساب نسبة ربح المنتجات
            if product_subtotal > 0:
                order.x_product_profit_margin = (product_profit / product_subtotal) * 100
            else:
                order.x_product_profit_margin = 0.0

            # تعيين قيم الخدمات
            order.x_service_total_cost = service_cost
            order.x_service_total_profit = service_profit
            order.x_service_subtotal = service_subtotal

            # حساب نسبة ربح الخدمات
            if service_subtotal > 0:
                order.x_service_profit_margin = (service_profit / service_subtotal) * 100
            else:
                order.x_service_profit_margin = 0.0

            # الإجمالي الكلي (المنتجات + الخدمات)
            order.x_total_cost = product_cost + service_cost
            order.x_total_profit = product_profit + service_profit

            # Calculate overall margin
            if order.amount_untaxed > 0:
                order.x_profit_margin = (order.x_total_profit / order.amount_untaxed) * 100
            else:
                order.x_profit_margin = 0.0

    def action_view_profit_analysis(self):
        """عرض تحليل الربحية"""
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Profit Analysis'),
                'message': _('Total Cost: %s\nTotal Profit: %s\nMargin: %s%%') % (
                    self.x_total_cost,
                    self.x_total_profit,
                    round(self.x_profit_margin, 2)
                ),
                'type': 'info',
                'sticky': False,
            }
        }

    def action_create_invoice_direct(self):
        """إنشاء فاتورة مباشرة بدون wizard"""
        self.ensure_one()

        # التحقق من وجود سطور قابلة للفوترة
        if not self.order_line:
            raise UserError(_('Please add at least one product to create an invoice.'))

        # التحقق من حالة الأوردر
        if self.state not in ['sale', 'done']:
            raise UserError(_('You can only create an invoice for confirmed orders.'))

        # التحقق من عدم وجود فاتورة مسبقة لكل الكمية
        if self.invoice_status == 'invoiced':
            raise UserError(_('This order has already been fully invoiced.'))

        # إنشاء الفاتورة مباشرة
        invoice = self._create_invoices(final=True)

        # فتح الفاتورة المنشأة
        return {
            'name': _('Invoice'),
            'type': 'ir.actions.act_window',
            'res_model': 'account.move',
            'view_mode': 'form',
            'res_id': invoice.id if len(invoice) == 1 else invoice[0].id,
            'target': 'current',
        }

    def action_check_stock_availability(self):
        """فحص توفر المخزون لجميع المنتجات في الطلب"""
        message_lines = []
        has_warning = False

        for line in self.order_line:
            if line.product_id and line.product_id.type == 'product':
                available = line.x_qty_available
                needed = line.product_uom_qty

                if available < needed:
                    has_warning = True
                    message_lines.append(
                        _('⚠️ %s: Need %s, Available %s') % (
                            line.product_id.name,
                            needed,
                            available
                        )
                    )
                else:
                    message_lines.append(
                        _('✓ %s: Need %s, Available %s') % (
                            line.product_id.name,
                            needed,
                            available
                        )
                    )

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Stock Availability Check'),
                'message': '\n'.join(message_lines) if message_lines else _('No products to check'),
                'type': 'warning' if has_warning else 'success',
                'sticky': True,
            }
        }


class ProductSalesHistoryWizard(models.TransientModel):
    _name = 'product.sales.history.wizard'
    _description = 'Product Sales History Wizard'

    product_id = fields.Many2one('product.product', string='Product', readonly=True)
    current_partner_id = fields.Many2one('res.partner', string='Current Customer', readonly=True)

    # Filter fields
    date_from = fields.Date(
        string='From Date',
        default=lambda self: fields.Date.today().replace(month=1, day=1)
    )
    date_to = fields.Date(
        string='To Date',
        default=fields.Date.today
    )
    partner_filter_id = fields.Many2one('res.partner', string='Filter by Customer')

    # Statistics fields
    total_quantity_sold = fields.Float(string='Total Quantity Sold', readonly=True)
    total_sales_amount = fields.Monetary(string='Total Sales Amount', readonly=True)
    average_price = fields.Monetary(string='Average Price', readonly=True)
    total_orders = fields.Integer(string='Total Orders', readonly=True)
    unique_customers = fields.Integer(string='Unique Customers', readonly=True)
    currency_id = fields.Many2one('res.currency', default=lambda self: self.env.company.currency_id)

    # IMPORTANT: Add the fields that are shown in tree view directly to wizard
    # This is a workaround for Odoo 17/18 view validation
    order_date = fields.Datetime(string='Order Date', related='history_line_ids.order_date', readonly=True)
    order_name = fields.Char(string='Order Reference', related='history_line_ids.order_name', readonly=True)
    partner_name = fields.Char(string='Customer Name', related='history_line_ids.partner_name', readonly=True)
    quantity = fields.Float(string='Quantity', related='history_line_ids.quantity', readonly=True)
    price_unit = fields.Float(string='Unit Price', related='history_line_ids.price_unit', readonly=True)
    discount = fields.Float(string='Discount (%)', related='history_line_ids.discount', readonly=True)
    price_subtotal = fields.Monetary(string='Subtotal', related='history_line_ids.price_subtotal', readonly=True)
    salesperson_id = fields.Many2one('res.users', string='Salesperson', related='history_line_ids.salesperson_id',
                                     readonly=True)
    order_state = fields.Selection([
        ('draft', 'Quotation'),
        ('sent', 'Quotation Sent'),
        ('sale', 'Sales Order'),
        ('done', 'Locked'),
        ('cancel', 'Cancelled'),
    ], string='Order Status', related='history_line_ids.order_state', readonly=True)

    # History lines
    history_line_ids = fields.One2many(
        'product.sales.history.line',
        'wizard_id',
        string='Sales History'
    )

    @api.onchange('product_id', 'date_from', 'date_to', 'partner_filter_id', 'current_partner_id')
    def _onchange_filters(self):
        """Update history lines when filters change"""
        if not self.product_id:
            self.history_line_ids = False
            self.total_quantity_sold = 0
            self.total_sales_amount = 0
            self.average_price = 0
            self.total_orders = 0
            self.unique_customers = 0
            return

        # Build domain
        domain = [
            ('product_id', '=', self.product_id.id),
            ('order_id.state', 'in', ['sale', 'done']),
        ]

        if self.date_from:
            domain.append(('order_id.date_order', '>=', self.date_from))
        if self.date_to:
            domain.append(('order_id.date_order', '<=', self.date_to))
        if self.partner_filter_id:
            domain.append(('order_id.partner_id', '=', self.partner_filter_id.id))

        # Search sale order lines
        sale_lines = self.env['sale.order.line'].search(domain, limit=100)
        # Create history lines
        history_lines = []
        total_qty = 0
        total_amount = 0
        order_ids = []
        partner_ids = []

        for line in sale_lines:
            history_lines.append((0, 0, {
                'order_id': line.order_id.id,
                'order_name': line.order_id.name,
                'order_date': line.order_id.date_order,
                'partner_id': line.order_id.partner_id.id,
                'partner_name': line.order_id.partner_id.name,
                'quantity': line.product_uom_qty,
                'price_unit': line.price_unit,
                'discount': line.discount,
                'price_subtotal': line.price_subtotal,
                'price_total': line.price_total,
                'currency_id': line.currency_id.id,
                'salesperson_id': line.order_id.user_id.id if line.order_id.user_id else False,
                'order_state': line.order_id.state,
            }))

            total_qty += line.product_uom_qty
            total_amount += line.price_subtotal
            order_ids.append(line.order_id.id)
            partner_ids.append(line.order_id.partner_id.id)

        self.history_line_ids = [(5, 0, 0)] + history_lines

        # Update statistics
        self.total_quantity_sold = total_qty
        self.total_sales_amount = total_amount
        self.average_price = total_amount / total_qty if total_qty > 0 else 0
        self.total_orders = len(set(order_ids))
        self.unique_customers = len(set(partner_ids))


class ProductSalesHistoryLine(models.TransientModel):
    _name = 'product.sales.history.line'
    _description = 'Product Sales History Line'
    _order = 'order_date desc'

    wizard_id = fields.Many2one('product.sales.history.wizard', string='Wizard', ondelete='cascade')

    # Order fields
    order_id = fields.Many2one('sale.order', string='Sale Order')
    order_name = fields.Char(string='Order Reference', required=True)
    order_date = fields.Datetime(string='Order Date')
    order_state = fields.Selection([
        ('draft', 'Quotation'),
        ('sent', 'Quotation Sent'),
        ('sale', 'Sales Order'),
        ('done', 'Locked'),
        ('cancel', 'Cancelled'),
    ], string='Order Status')

    # Partner fields
    partner_id = fields.Many2one('res.partner', string='Customer')
    partner_name = fields.Char(string='Customer Name')

    # Product fields
    quantity = fields.Float(string='Quantity', digits='Product Unit of Measure')
    price_unit = fields.Float(string='Unit Price', digits='Product Price')
    discount = fields.Float(string='Discount (%)', digits='Discount')
    price_subtotal = fields.Monetary(string='Subtotal')
    price_total = fields.Monetary(string='Total')
    currency_id = fields.Many2one('res.currency', string='Currency')

    salesperson_id = fields.Many2one('res.users', string='Salesperson')

    def action_view_order(self):
        """Open the sale order"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'sale.order',
            'view_mode': 'form',
            'res_id': self.order_id.id,
            'target': 'current',
        }


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # حقل لتتبع عمليات الإرجاع المنشأة
    return_picking_ids = fields.Many2many(
        'stock.picking',
        'sale_order_return_picking_rel',
        'sale_id',
        'picking_id',
        string='عمليات الإرجاع',
        copy=False
    )

    def action_cancel(self):
        """Override cancel action to handle invoices and stock returns"""
        for order in self:
            # التحقق من وجود عمليات تسليم أو فواتير
            if order.picking_ids or order.invoice_ids:
                # إلغاء الفواتير أولاً
                self._cancel_related_invoices()
                # إنشاء عمليات إرجاع للبضاعة
                self._create_return_pickings()

        # استدعاء الدالة الأصلية للإلغاء
        return super(SaleOrder, self).action_cancel()

    def _cancel_related_invoices(self):
        """إلغاء جميع الفواتير المرتبطة بأمر البيع"""
        for order in self:
            invoices = order.invoice_ids.filtered(lambda inv: inv.state != 'cancel')

            if invoices:
                # معالجة الفواتير حسب حالتها
                for invoice in invoices:
                    try:
                        if invoice.state == 'posted':
                            # إرجاع الفاتورة المرحلة إلى مسودة ثم إلغائها
                            self._reset_invoice_to_draft_and_cancel(invoice)
                        elif invoice.state == 'draft':
                            # إلغاء الفواتير في حالة المسودة مباشرة
                            invoice.button_cancel()
                    except Exception as e:
                        raise UserError(_(
                            "خطأ في إلغاء الفاتورة %(invoice)s: %(error)s",
                            invoice=invoice.name,
                            error=str(e)
                        ))

    def _reset_invoice_to_draft_and_cancel(self, invoice):
        """إرجاع الفاتورة المرحلة إلى مسودة ثم إلغائها"""
        # التحقق من إمكانية إرجاع الفاتورة إلى مسودة
        if invoice.payment_state in ['paid', 'in_payment', 'partial']:
            raise UserError(_(
                "لا يمكن إلغاء الفاتورة %(invoice)s لأنها مدفوعة أو مدفوعة جزئياً. "
                "يرجى إلغاء المدفوعات أولاً.",
                invoice=invoice.name
            ))

        # إرجاع الفاتورة إلى مسودة
        invoice.button_draft()

        # إضافة ملاحظة في السجل
        invoice.message_post(
            body=_("تم إرجاع الفاتورة إلى مسودة بسبب إلغاء أمر البيع: %s") % self.name
        )

        # إلغاء الفاتورة
        invoice.button_cancel()

        # إضافة ملاحظة في أمر البيع
        self.message_post(
            body=_("تم إلغاء الفاتورة: %s") % invoice.name
        )

        return True

    def _create_return_pickings(self):
        """إنشاء عمليات إرجاع للبضاعة المستلمة"""
        StockReturnPicking = self.env['stock.return.picking']

        for order in self:
            # الحصول على عمليات التسليم المكتملة
            done_pickings = order.picking_ids.filtered(
                lambda p: p.state == 'done' and p.picking_type_code == 'outgoing'
            )

            for picking in done_pickings:
                # التحقق من عدم وجود إرجاع سابق لهذا التسليم
                existing_returns = self.env['stock.picking'].search([
                    ('origin', 'like', f'Return of {picking.name}'),
                    ('state', '!=', 'cancel')
                ])

                if not existing_returns:
                    try:
                        # إنشاء معالج الإرجاع
                        return_wizard = StockReturnPicking.create({
                            'picking_id': picking.id,
                            'location_id': picking.location_dest_id.id,  # موقع الإرجاع
                        })

                        # تعيين الكميات المرتجعة
                        return_wizard._onchange_picking_id()

                        # تحديث كميات المنتجات المرتجعة (إرجاع الكل)
                        for return_line in return_wizard.product_return_moves:
                            return_line.quantity = return_line.move_id.product_uom_qty

                        # إنشاء عملية الإرجاع
                        return_pick_action = return_wizard.create_returns()
                        return_pick = self.env['stock.picking'].browse(return_pick_action['res_id'])

                        # إضافة الإرجاع للحقل المخصص
                        order.return_picking_ids = [(4, return_pick.id)]

                        # معالجة الإرجاع تلقائياً
                        self._process_return_picking(return_pick)

                    except Exception as e:
                        raise UserError(_(
                            "خطأ في إنشاء إرجاع للتسليم %(picking)s: %(error)s",
                            picking=picking.name,
                            error=str(e)
                        ))


class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    # Vendor field for each line
    x_line_vendor_id = fields.Many2one(
        'res.partner',
        string='Line Vendor',

        help='Vendor for this line. Leave empty to create customer invoice.'
    )

    # Effective partner (computed)
    x_effective_partner_id = fields.Many2one(
        'res.partner',
        string='Invoice Partner',
        compute='_compute_effective_partner',
        store=True,
        help='Partner who will be invoiced for this line'
    )

    # Invoice type
    x_invoice_type = fields.Selection([
        ('customer', 'Customer Invoice'),
        ('vendor', 'Vendor Bill')
    ], string='Invoice Type', compute='_compute_invoice_type', store=True)

    @api.depends('x_line_vendor_id', 'order_id.partner_id')
    def _compute_effective_partner(self):
        """Compute the effective partner for invoicing"""
        for line in self:
            # If vendor is set, use vendor; otherwise use customer
            line.x_effective_partner_id = line.x_line_vendor_id or line.order_id.partner_id

    @api.depends('x_line_vendor_id')
    def _compute_invoice_type(self):
        """Determine if this line will create vendor bill or customer invoice"""
        for line in self:
            line.x_invoice_type = 'vendor' if line.x_line_vendor_id else 'customer'


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # Multi-vendor fields
    x_multi_vendor_mode = fields.Boolean(
        string='Multi-Vendor Mode',
        default=False,
        help='Enable to create separate invoices for vendors and customers'
    )

    x_vendor_count = fields.Integer(
        string='Vendor Count',
        compute='_compute_vendor_count',
        store=True
    )

    x_customer_line_count = fields.Integer(
        string='Customer Lines',
        compute='_compute_line_counts',
        store=True
    )

    x_vendor_line_count = fields.Integer(
        string='Vendor Lines',
        compute='_compute_line_counts',
        store=True
    )

    # Related vendor bills
    x_vendor_bill_ids = fields.One2many(
        'account.move',
        'x_source_sale_order_id',
        string='Vendor Bills',
        domain=[('move_type', '=', 'in_invoice')]
    )

    x_vendor_bill_count = fields.Integer(
        string='Vendor Bills',
        compute='_compute_bill_count'
    )

    @api.depends('order_line.x_line_vendor_id', 'x_multi_vendor_mode')
    def _compute_vendor_count(self):
        """Count unique vendors in order lines"""
        for order in self:
            if order.x_multi_vendor_mode:
                vendors = order.order_line.filtered('x_line_vendor_id').mapped('x_line_vendor_id')
                order.x_vendor_count = len(vendors)
            else:
                order.x_vendor_count = 0

    @api.depends('order_line.x_line_vendor_id')
    def _compute_line_counts(self):
        """Count customer vs vendor lines"""
        for order in self:
            vendor_lines = order.order_line.filtered('x_line_vendor_id')
            customer_lines = order.order_line.filtered(lambda l: not l.x_line_vendor_id)
            order.x_vendor_line_count = len(vendor_lines)
            order.x_customer_line_count = len(customer_lines)

    @api.depends('x_vendor_bill_ids')
    def _compute_bill_count(self):
        """Count related vendor bills"""
        for order in self:
            order.x_vendor_bill_count = len(order.x_vendor_bill_ids)

    def _create_invoices(self, grouped=False, final=False, date=None):
        """Override to create both customer invoices and vendor bills"""

        # If not in multi-vendor mode, use standard behavior
        if not self.x_multi_vendor_mode:
            return super()._create_invoices(grouped, final, date)

        all_moves = self.env['account.move']

        for order in self:
            # 1. أولاً: إنشاء فاتورة العميل بجميع السطور
            customer_invoice = order._create_full_customer_invoice(date)
            all_moves |= customer_invoice

            # 2. ثانياً: إنشاء فواتير المورد للسطور التي لها vendor
            vendor_bills = order._create_vendor_bills(date)
            all_moves |= vendor_bills

        return all_moves

    def _create_full_customer_invoice(self, date=None):
        """إنشاء فاتورة العميل بجميع السطور"""
        self.ensure_one()

        # إعداد قيم الفاتورة
        invoice_vals = self._prepare_invoice()
        if date:
            invoice_vals['invoice_date'] = date

        # إنشاء الفاتورة
        invoice = self.env['account.move'].with_context(
            default_move_type='out_invoice'
        ).create(invoice_vals)

        # إضافة جميع سطور المبيعات للفاتورة
        for line in self.order_line:
            invoice_line_vals = line._prepare_invoice_line()
            invoice_line_vals['move_id'] = invoice.id

            # إضافة مرجع للـ vendor إذا كان موجود (للمعلومات فقط)
            if line.x_line_vendor_id:
                invoice_line_vals['name'] = f"{line.name}\n[Vendor: {line.x_line_vendor_id.name}]"

            self.env['account.move.line'].with_context(
                check_move_validity=False
            ).create(invoice_line_vals)

        # إضافة ملاحظة في الفاتورة إذا كان هناك موردين
        if self.x_vendor_count > 0:
            invoice.narration = f"This invoice includes {self.x_vendor_count} vendor items. Vendor bills will be created separately."

        return invoice

    def _create_vendor_bills(self, date=None):
        """إنشاء فواتير المورد فقط للسطور التي لها vendor"""
        self.ensure_one()
        vendor_bills = self.env['account.move']

        # تجميع السطور حسب المورد
        vendor_lines = {}
        for line in self.order_line.filtered('x_line_vendor_id'):
            vendor = line.x_line_vendor_id
            if vendor not in vendor_lines:
                vendor_lines[vendor] = self.env['sale.order.line']
            vendor_lines[vendor] |= line

        # إنشاء فاتورة لكل مورد
        for vendor, lines in vendor_lines.items():
            vendor_bill = self._create_single_vendor_bill(vendor, lines, date)
            vendor_bills |= vendor_bill

        return vendor_bills

    def _create_single_vendor_bill(self, vendor, lines, date=None):
        """إنشاء فاتورة مورد واحدة"""
        self.ensure_one()

        # إعداد قيم فاتورة المورد
        invoice_vals = {
            'move_type': 'in_invoice',
            'partner_id': vendor.id,
            'invoice_origin': self.name,
            'x_source_sale_order_id': self.id,
            'currency_id': self.currency_id.id,
            'invoice_date': date or fields.Date.today(),
            'company_id': self.company_id.id,
            'ref': f"SO: {self.name}",
            'invoice_payment_term_id': vendor.property_supplier_payment_term_id.id if vendor.property_supplier_payment_term_id else False,
            'fiscal_position_id': vendor.property_account_position_id.id if vendor.property_account_position_id else False,
        }

        # إنشاء فاتورة المورد
        vendor_bill = self.env['account.move'].create(invoice_vals)

        # إضافة سطور الفاتورة
        for line in lines:
            bill_line_vals = self._prepare_vendor_bill_line(line, vendor_bill)
            self.env['account.move.line'].with_context(
                check_move_validity=False
            ).create(bill_line_vals)

        # إضافة ملاحظة في السجل
        self.message_post(
            body=_(
                "Vendor Bill created for %s: %s<br/>Items: %s"
            ) % (
                     vendor.name,
                     vendor_bill.name,
                     ', '.join(lines.mapped('product_id.name'))
                 )
        )

        return vendor_bill

    def _create_customer_invoice(self, customer, lines, date=None):
        """Create customer invoice for given lines"""
        self.ensure_one()

        invoice_vals = self._prepare_invoice()
        if date:
            invoice_vals['invoice_date'] = date

        # Create invoice
        invoice = self.env['account.move'].with_context(default_move_type='out_invoice').create(invoice_vals)

        # Add invoice lines
        for line in lines:
            invoice_line_vals = line._prepare_invoice_line()
            invoice_line_vals['move_id'] = invoice.id
            self.env['account.move.line'].with_context(check_move_validity=False).create(invoice_line_vals)

        return invoice

    def _create_vendor_bill(self, vendor, lines, date=None):
        """Create vendor bill for given lines"""
        self.ensure_one()

        # Prepare vendor bill values
        invoice_vals = {
            'move_type': 'in_invoice',
            'partner_id': vendor.id,
            'invoice_origin': self.name,
            'x_source_sale_order_id': self.id,
            'currency_id': self.currency_id.id,
            'invoice_date': date or fields.Date.today(),
            'company_id': self.company_id.id,
            'ref': f"SO: {self.name}",
            'invoice_payment_term_id': vendor.property_supplier_payment_term_id.id if vendor.property_supplier_payment_term_id else False,
            'fiscal_position_id': vendor.property_account_position_id.id if vendor.property_account_position_id else False,
        }

        # Create vendor bill
        vendor_bill = self.env['account.move'].create(invoice_vals)

        # Add bill lines
        for line in lines:
            bill_line_vals = self._prepare_vendor_bill_line(line, vendor_bill)
            self.env['account.move.line'].with_context(check_move_validity=False).create(bill_line_vals)

        # Log in chatter
        self.message_post(
            body=_("Vendor Bill created for %s: %s") % (vendor.name, vendor_bill.name)
        )

        return vendor_bill

    def _prepare_vendor_bill_line(self, sale_line, vendor_bill):
        """Prepare vendor bill line from sale order line"""

        # Get expense account
        if sale_line.product_id:
            accounts = sale_line.product_id.product_tmpl_id.get_product_accounts(
                fiscal_pos=vendor_bill.fiscal_position_id
            )
            account = accounts.get('expense')
        else:
            account = self.env['account.account'].search([
                ('account_type', '=', 'expense'),
                ('company_id', '=', self.company_id.id)
            ], limit=1)

        if not account:
            raise UserError(_('Please define an expense account'))

        # Calculate cost (you might want to use a different price logic here)
        # For now, using a percentage of sale price as cost
        cost_price = sale_line.price_unit  # 70% of sale price as example

        return {
            'move_id': vendor_bill.id,
            'product_id': sale_line.product_id.id if sale_line.product_id else False,
            'name': sale_line.name or sale_line.product_id.name,
            'quantity': sale_line.product_uom_qty,
            'price_unit': cost_price,
            'product_uom_id': sale_line.product_uom.id,
            'account_id': account.id,
            'tax_ids': [(6, 0, sale_line.product_id.supplier_taxes_id.ids if sale_line.product_id else [])],
            'sale_line_ids': [(4, sale_line.id)],
        }

    def action_view_vendor_bills(self):
        """View related vendor bills"""
        self.ensure_one()

        action = self.env["ir.actions.actions"]._for_xml_id("account.action_move_in_invoice_type")
        action['domain'] = [('id', 'in', self.x_vendor_bill_ids.ids)]
        action['context'] = {'default_move_type': 'in_invoice'}

        if len(self.x_vendor_bill_ids) == 1:
            action['views'] = [(self.env.ref('account.view_move_form').id, 'form')]
            action['res_id'] = self.x_vendor_bill_ids.id

        return action

    def action_view_invoice_summary(self):
        """Show summary of invoices to be created"""
        self.ensure_one()

        if not self.x_multi_vendor_mode:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Multi-Vendor Mode Disabled',
                    'message': 'Enable Multi-Vendor Mode to see invoice distribution',
                    'type': 'warning',
                }
            }

        # Analyze invoice distribution
        customer_total = 0
        vendor_totals = {}

        for line in self.order_line:
            if line.x_line_vendor_id:
                vendor = line.x_line_vendor_id
                if vendor.id not in vendor_totals:
                    vendor_totals[vendor.id] = {
                        'name': vendor.name,
                        'lines': 0,
                        'total': 0.0
                    }
                vendor_totals[vendor.id]['lines'] += 1
                vendor_totals[vendor.id]['total'] += line.price_subtotal
            else:
                customer_total += line.price_subtotal

        # Build message
        message = "Invoice Distribution:\n\n"

        if customer_total > 0:
            message += f"📤 Customer Invoice: {customer_total:,.2f}\n\n"

        if vendor_totals:
            message += "📥 Vendor Bills:\n"
            for vendor_data in vendor_totals.values():
                message += f"• {vendor_data['name']}: {vendor_data['lines']} lines, Total: {vendor_data['total']:,.2f}\n"

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Invoice Summary',
                'message': message,
                'type': 'info',
                'sticky': True,
            }
        }


class AccountMove(models.Model):
    _inherit = 'account.move'

    x_source_sale_order_id = fields.Many2one(
        'sale.order',
        string='Source Sale Order',
        readonly=True,
        help='Sale order that created this vendor bill'
    )


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # حقل لعرض حالة التسليم
    delivery_status = fields.Selection([
        ('no_delivery', 'No Delivery'),
        ('to_deliver', 'To Deliver'),
        ('partially', 'Partially Delivered'),
        ('delivered', 'Fully Delivered'),
    ], string='Delivery Status', compute='_compute_delivery_status', store=True)

    @api.depends('picking_ids', 'picking_ids.state')
    def _compute_delivery_status(self):
        """حساب حالة التسليم"""
        for order in self:
            if not order.picking_ids:
                order.delivery_status = 'no_delivery'
            elif all(p.state == 'done' for p in order.picking_ids):
                order.delivery_status = 'delivered'
            elif any(p.state == 'done' for p in order.picking_ids):
                order.delivery_status = 'partially'
            else:
                order.delivery_status = 'to_deliver'

    def action_validate_delivery(self):
        """Validate all related pickings directly from Sale Order"""
        self.ensure_one()

        # التحقق من وجود عمليات تسليم
        pickings_to_validate = self.picking_ids.filtered(
            lambda p: p.state not in ['done', 'cancel']
        )

        if not pickings_to_validate:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': _('No Delivery to Validate'),
                    'message': _('There are no pending deliveries to validate.'),
                    'type': 'warning',
                    'sticky': False,
                }
            }

        # تحقق من المخزون وإعداد الكميات
        for picking in pickings_to_validate:
            # التأكد من أن العملية جاهزة
            if picking.state == 'draft':
                picking.action_confirm()
            if picking.state == 'waiting':
                picking.action_assign()

            # تعيين الكميات المتاحة
            for move_line in picking.move_line_ids:
                if not move_line.quantity:
                    move_line.quantity = move_line.reserved_uom_qty

            # للحركات التي ليس لها move_line_ids
            for move in picking.move_ids.filtered(lambda m: not m.move_line_ids and m.state not in ['done', 'cancel']):
                move.quantity = move.product_uom_qty

        # محاولة التحقق من كل عملية تسليم
        validated_pickings = self.env['stock.picking']
        failed_pickings = []

        for picking in pickings_to_validate:
            try:
                # التحقق من العملية
                picking.button_validate()
                validated_pickings |= picking

                # إضافة ملاحظة في السجل
                self.message_post(
                    body=_("Delivery Order %s has been validated") % picking.name
                )

            except UserError as e:
                failed_pickings.append({
                    'name': picking.name,
                    'error': str(e)
                })

        # إعداد الرسالة النهائية
        if validated_pickings and not failed_pickings:
            message = _('Successfully validated %d delivery order(s)') % len(validated_pickings)
            msg_type = 'success'
        elif validated_pickings and failed_pickings:
            message = _('Validated %d order(s). Failed: %s') % (
                len(validated_pickings),
                ', '.join([f"{p['name']}: {p['error']}" for p in failed_pickings])
            )
            msg_type = 'warning'
        else:
            message = _('Failed to validate deliveries: %s') % (
                ', '.join([f"{p['name']}: {p['error']}" for p in failed_pickings])
            )
            msg_type = 'danger'

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Delivery Validation'),
                'message': message,
                'type': msg_type,
                'sticky': True,
            }
        }

    def action_validate_with_backorder(self):
        """Validate delivery with backorder option"""
        self.ensure_one()

        pickings_to_validate = self.picking_ids.filtered(
            lambda p: p.state not in ['done', 'cancel']
        )

        if not pickings_to_validate:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': _('No Delivery'),
                    'message': _('No pending deliveries found.'),
                    'type': 'warning',
                }
            }

        # فتح معالج Backorder
        return {
            'name': _('Create Backorder?'),
            'type': 'ir.actions.act_window',
            'res_model': 'stock.backorder.confirmation',
            'view_mode': 'form',
            'target': 'new',
            'context': {
                'default_pick_ids': [(6, 0, pickings_to_validate.ids)],
                'from_sale_order': True,
            }
        }

    def action_view_deliveries(self):
        """Open delivery orders in list view"""
        self.ensure_one()

        action = self.env["ir.actions.actions"]._for_xml_id("stock.action_picking_tree_all")
        action['domain'] = [('id', 'in', self.picking_ids.ids)]
        action['context'] = {
            'default_partner_id': self.partner_id.id,
            'default_origin': self.name,
        }

        if len(self.picking_ids) == 1:
            action['views'] = [(self.env.ref('stock.view_picking_form').id, 'form')]
            action['res_id'] = self.picking_ids.id

        return action