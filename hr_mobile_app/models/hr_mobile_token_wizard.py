# -*- coding: utf-8 -*-
from odoo import models, fields, api


class HrMobileTokenConfirmWizard(models.TransientModel):
    _name = 'hr.mobile.token.confirm.wizard'
    _description = 'Confirm Token Regeneration Wizard'

    settings_id = fields.Many2one(
        'res.config.settings',
        string='Settings',
        readonly=True
    )

    def action_confirm(self):
        """Confirm token regeneration"""
        # Add your token regeneration logic here
        # Example:
        # if self.settings_id:
        #     self.settings_id.regenerate_mobile_token()
        return {'type': 'ir.actions.act_window_close'}