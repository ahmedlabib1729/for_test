# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import UserError
import logging

_logger = logging.getLogger(__name__)


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    return_picking_ids = fields.Many2many(
        'stock.picking',
        'sale_order_return_picking_rel',
        'sale_id',
        'picking_id',
        string='Return Pickings',
        copy=False
    )

    def action_cancel(self):
        """Override cancel action to handle invoices and stock returns"""
        ICPSudo = self.env['ir.config_parameter'].sudo()
        invoice_method = ICPSudo.get_param('sale_cancel.invoice_method', 'draft_cancel')
        auto_return = ICPSudo.get_param('sale_cancel.auto_return_stock', 'True') == 'True'

        for order in self:
            # Handle invoices based on settings
            if invoice_method != 'nothing' and order.invoice_ids:
                self._cancel_related_invoices(invoice_method)

            # Create stock returns based on settings
            if auto_return and order.picking_ids:
                self._create_return_pickings()

        # Call original cancel function
        return super(SaleOrder, self).action_cancel()

    def _cancel_related_invoices(self, method='draft_cancel'):
        """Cancel all related invoices"""
        for order in self:
            invoices = order.invoice_ids.filtered(lambda inv: inv.state != 'cancel')

            if invoices:
                for invoice in invoices:
                    try:
                        if invoice.state == 'posted':
                            if method == 'draft_cancel':
                                self._reset_invoice_to_draft_and_cancel(invoice)
                            elif method == 'credit_note':
                                self._create_credit_note(invoice)
                        elif invoice.state == 'draft':
                            invoice.button_cancel()
                    except Exception as e:
                        if self.env.context.get('force_cancel'):
                            self.message_post(
                                body=_("Warning: Failed to cancel invoice %s: %s") % (
                                    invoice.name, str(e)
                                )
                            )
                        else:
                            raise UserError(
                                _("Error cancelling invoice %(invoice)s: %(error)s") % {
                                    'invoice': invoice.name,
                                    'error': str(e)
                                }
                            )

    def _reset_invoice_to_draft_and_cancel(self, invoice):
        """Reset posted invoice to draft then cancel it"""
        if invoice.payment_state in ['paid', 'in_payment', 'partial']:
            if self.env.context.get('cancel_payments'):
                self._cancel_invoice_payments(invoice)
            else:
                raise UserError(
                    _("Cannot cancel invoice %s because it has payments. "
                      "Please cancel payments first or use Force Cancel option.") % invoice.name
                )

        invoice.button_draft()
        invoice.message_post(
            body=_("Reset to draft due to sales order cancellation: %s") % self.name
        )
        invoice.button_cancel()
        self.message_post(
            body=_("Invoice cancelled: %s") % invoice.name
        )
        return True

    def _cancel_invoice_payments(self, invoice):
        """Cancel payments related to invoice"""
        payments = invoice._get_reconciled_payments()
        if payments:
            for payment in payments:
                if payment.state == 'posted':
                    payment.action_draft()
                payment.action_cancel()
            self.message_post(
                body=_("Cancelled payments for invoice: %s") % invoice.name
            )

    def _create_credit_note(self, invoice):
        """Create credit note for posted invoice"""
        credit_note_wizard = self.env['account.move.reversal'].create({
            'move_ids': [(6, 0, [invoice.id])],
            'reason': f'Sales order cancellation: {self.name}',
            'journal_id': invoice.journal_id.id,
            'date': fields.Date.today(),
            'refund_method': 'cancel',
        })

        reversal = credit_note_wizard.reverse_moves()
        credit_notes = self.env['account.move'].browse(reversal['res_id'])

        for credit_note in credit_notes:
            if credit_note.state == 'draft':
                credit_note.action_post()

        return credit_notes

    def _create_return_pickings(self):
        """Create return pickings for delivered items - Direct method without wizard"""
        ICPSudo = self.env['ir.config_parameter'].sudo()
        auto_process = ICPSudo.get_param('sale_cancel.auto_process_returns', 'True') == 'True'

        for order in self:
            # Get all done deliveries
            done_pickings = order.picking_ids.filtered(
                lambda p: p.state == 'done' and p.picking_type_code == 'outgoing'
            )

            if not done_pickings:
                order.message_post(body=_("No completed deliveries found to return."))
                continue

            for picking in done_pickings:
                # Check for existing returns
                existing_returns = self.env['stock.picking'].search([
                    ('origin', '=', f'Return of {picking.name}'),
                    ('state', '!=', 'cancel')
                ])

                if existing_returns:
                    order.message_post(
                        body=_("Return already exists for delivery %s") % picking.name
                    )
                    continue

                try:
                    # Create return directly
                    return_picking = self._create_return_picking_directly(picking)

                    if return_picking:
                        # Link return to order
                        order.return_picking_ids = [(4, return_picking.id)]

                        # Log success
                        order.message_post(
                            body=_("Return %s created for delivery %s") % (
                                return_picking.name, picking.name
                            )
                        )

                        # Auto-process if enabled
                        if auto_process:
                            # Try simple validation first
                            self._simple_validate_return(return_picking)
                        else:
                            order.message_post(
                                body=_("Auto-validation disabled. Please validate return %s manually.") %
                                     return_picking.name
                            )
                    else:
                        order.message_post(
                            body=_("Could not create return for delivery %s") % picking.name
                        )

                except Exception as e:
                    error_msg = str(e)
                    if self.env.context.get('force_cancel'):
                        order.message_post(
                            body=_("Warning: Failed to create return for delivery %s: %s") % (
                                picking.name, error_msg
                            )
                        )
                    else:
                        _logger.error(f"Error creating return for {picking.name}: {error_msg}")
                        raise UserError(
                            _("Error creating return for delivery %(picking)s: %(error)s") % {
                                'picking': picking.name,
                                'error': error_msg
                            }
                        )

    def _simple_validate_return(self, return_picking):
        """Simple validation method for returns"""
        try:
            # Step 1: Confirm
            return_picking.action_confirm()

            # Step 2: Force availability (for returns we know stock exists)
            for move in return_picking.move_ids:
                move.force_assign()

            # Step 3: Set quantities and validate
            for move in return_picking.move_ids:
                move.quantity = move.product_uom_qty

            # Step 4: Validate with immediate transfer
            return_picking.with_context(skip_immediate=True, skip_sms=True).button_validate()

            # If not done, force immediate transfer
            if return_picking.state != 'done':
                wizard = self.env['stock.immediate.transfer'].create({
                    'pick_ids': [(6, 0, [return_picking.id])]
                })
                wizard.process()

            self.message_post(
                body=_("✅ Return %s validated automatically") % return_picking.name
            )

        except Exception as e:
            _logger.warning(f"Simple validation failed for {return_picking.name}: {e}")
            # Try advanced validation
            self._process_return_picking(return_picking)

    def _create_return_picking_directly(self, picking):
        """Create return picking directly without using wizard"""
        # Get return picking type
        return_picking_type = picking.picking_type_id.return_picking_type_id
        if not return_picking_type:
            # Find incoming picking type for the warehouse
            warehouse = picking.picking_type_id.warehouse_id
            return_picking_type = self.env['stock.picking.type'].search([
                ('code', '=', 'incoming'),
                ('warehouse_id', '=', warehouse.id)
            ], limit=1)

        if not return_picking_type:
            raise UserError(
                _("No return picking type configured for warehouse %s") %
                picking.picking_type_id.warehouse_id.name
            )

        # Create return picking
        return_vals = {
            'partner_id': picking.partner_id.id,
            'picking_type_id': return_picking_type.id,
            'location_id': picking.location_dest_id.id,  # Swap locations
            'location_dest_id': picking.location_id.id,
            'origin': f'Return of {picking.name}',
            'move_type': picking.move_type,
        }

        return_picking = self.env['stock.picking'].create(return_vals)

        # Create return moves for delivered items
        for move in picking.move_ids.filtered(lambda m: m.state == 'done' and m.quantity > 0):
            return_move_vals = {
                'name': f'Return of {move.name}',
                'product_id': move.product_id.id,
                'product_uom_qty': move.quantity,
                'product_uom': move.product_uom.id,
                'picking_id': return_picking.id,
                'location_id': move.location_dest_id.id,  # Swap locations
                'location_dest_id': move.location_id.id,
                'state': 'draft',
                'origin_returned_move_id': move.id,
                'picking_type_id': return_picking_type.id,
            }
            self.env['stock.move'].create(return_move_vals)

        return return_picking

    def _process_return_picking(self, return_picking):
        """Process and validate return picking automatically"""
        try:
            # Confirm
            if return_picking.state == 'draft':
                return_picking.action_confirm()

            # Assign
            if return_picking.state == 'confirmed':
                return_picking.action_assign()

            # Validate if assigned
            if return_picking.state == 'assigned':
                # Set done quantities
                for move in return_picking.move_ids:
                    move.quantity = move.product_uom_qty

                # Set quantities for move lines
                if return_picking.move_line_ids:
                    for move_line in return_picking.move_line_ids:
                        move_line.quantity = move_line.reserved_uom_qty or move_line.quantity

                # Validate
                return_picking.button_validate()

                # Handle immediate transfer if needed
                if return_picking.state != 'done':
                    immediate_wizard = self.env['stock.immediate.transfer'].create({
                        'pick_ids': [(4, return_picking.id)]
                    })
                    immediate_wizard.process()

            # Log result
            if return_picking.state == 'done':
                self.message_post(
                    body=_("Return %s validated successfully") % return_picking.name
                )
            else:
                self.message_post(
                    body=_("Return %s created but needs manual validation (State: %s)") % (
                        return_picking.name, return_picking.state
                    )
                )

        except Exception as e:
            self.message_post(
                body=_("Warning: Could not auto-validate return %s. Please process manually.\nError: %s") % (
                    return_picking.name, str(e)
                )
            )

    def action_view_returns(self):
        """View return pickings"""
        self.ensure_one()
        action = self.env["ir.actions.actions"]._for_xml_id("stock.action_picking_tree_all")
        action['domain'] = [('id', 'in', self.return_picking_ids.ids)]
        action['context'] = {
            'default_partner_id': self.partner_id.id,
            'default_origin': self.name,
        }
        return action

    def action_cancel_force(self):
        """Force cancel order ignoring errors"""
        return self.with_context(force_cancel=True).action_cancel()


class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    returned_qty = fields.Float(
        string='Returned Qty',
        compute='_compute_returned_qty',
        store=True,
        help='Quantity returned from this line'
    )

    @api.depends('order_id.return_picking_ids.state', 'order_id.return_picking_ids.move_ids')
    def _compute_returned_qty(self):
        """Calculate returned quantity for each line"""
        for line in self:
            returned_qty = 0.0
            if line.order_id.return_picking_ids:
                return_moves = line.order_id.return_picking_ids.mapped('move_ids').filtered(
                    lambda m: m.product_id == line.product_id and
                              m.state == 'done' and
                              m.origin_returned_move_id.sale_line_id == line
                )
                returned_qty = sum(return_moves.mapped('product_uom_qty'))
            line.returned_qty = returned_qty


class StockPicking(models.Model):
    _inherit = 'stock.picking'

    is_sale_return = fields.Boolean(
        string='Sale Return',
        compute='_compute_is_sale_return',
        store=True
    )

    related_sale_id = fields.Many2one(
        'sale.order',
        string='Related Sale Order',
        compute='_compute_related_sale',
        store=True
    )

    @api.depends('origin', 'picking_type_code')
    def _compute_is_sale_return(self):
        """Check if picking is a sale return"""
        for picking in self:
            picking.is_sale_return = (
                    picking.picking_type_code == 'incoming' and
                    'Return of' in (picking.origin or '')
            )

    @api.depends('origin', 'is_sale_return')
    def _compute_related_sale(self):
        """Link return to original sale order"""
        for picking in self:
            if picking.is_sale_return and picking.origin:
                original_picking_name = picking.origin.replace('Return of ', '')
                original_picking = self.search([('name', '=', original_picking_name)], limit=1)
                if original_picking:
                    picking.related_sale_id = original_picking.sale_id
            else:
                picking.related_sale_id = False


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    sale_cancel_invoice_method = fields.Selection([
        ('draft_cancel', 'Reset to Draft & Cancel'),
        ('credit_note', 'Create Credit Note'),
        ('nothing', 'Do Not Cancel Invoices')
    ], string='Invoice Cancellation Method',
        default='draft_cancel',
        config_parameter='sale_cancel.invoice_method',
        help='How to handle posted invoices when cancelling sales orders')

    sale_auto_return_stock = fields.Boolean(
        string='Auto Create Stock Returns',
        default=True,
        config_parameter='sale_cancel.auto_return_stock',
        help='Automatically create stock return pickings when cancelling sales orders'
    )

    sale_auto_process_returns = fields.Boolean(
        string='Auto Validate Returns',
        default=True,
        config_parameter='sale_cancel.auto_process_returns',
        help='Automatically validate return pickings without manual intervention'
    )