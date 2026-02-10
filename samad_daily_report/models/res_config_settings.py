# models/res_config_settings.py
from odoo import models, fields, api


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    # الحسابات الأربعة لتصنيف المبيعات
    sales_cash_account_id = fields.Many2one(
        'account.account',
        string='Cash Account',
        config_parameter='daily_invoices.sales_cash_account_id',
        help='Account used for cash payments in invoice lines'
    )

    sales_bank_account_id = fields.Many2one(
        'account.account',
        string='Bank Account',
        config_parameter='daily_invoices.sales_bank_account_id',
        help='Account used for bank payments in invoice lines'
    )

    sales_commission_account_id = fields.Many2one(
        'account.account',
        string='Commission Account',
        config_parameter='daily_invoices.sales_commission_account_id',
        help='Account used for commission in invoice lines'
    )

    sales_commission_tax_account_id = fields.Many2one(
        'account.account',
        string='Commission Tax Account',
        config_parameter='daily_invoices.sales_commission_tax_account_id',
        help='Account used for commission tax in invoice lines'
    )
