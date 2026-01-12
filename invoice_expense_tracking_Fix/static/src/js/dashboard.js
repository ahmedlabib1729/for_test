/** @odoo-module **/

import { Component, useState, onWillStart } from "@odoo/owl";
import { registry } from "@web/core/registry";
import { useService } from "@web/core/utils/hooks";

export class InvoiceProfitabilityDashboard extends Component {
    static template = "invoice_expense_tracking_Fix.Dashboard";

    setup() {
        this.orm = useService("orm");
        this.action = useService("action");
        
        this.state = useState({
            data: null,
            loading: true,
            showFilters: false,
            filters: {
                date_from: false,
                date_to: false,
                partner_ids: false,
                platform: false,
                move_type: false,
                search_term: '',
            }
        });

        onWillStart(async () => {
            await this.loadData();
        });
    }

    async loadData() {
        this.state.loading = true;
        try {
            const data = await this.orm.call(
                'report.invoice.profitability.dashboard',
                'get_dashboard_data',
                [],
                this.state.filters
            );
            this.state.data = data;
        } catch (error) {
            console.error("Error loading dashboard data:", error);
            // Set empty data on error
            this.state.data = {
                invoices: [],
                summary: {
                    total_invoices: 0,
                    total_sales: 0,
                    total_cost: 0,
                    total_expenses: 0,
                    total_profit: 0,
                    avg_profit_margin: 0,
                    profitable_count: 0,
                    loss_count: 0,
                    gross_profit: 0,
                    platform_stats: {}
                }
            };
        } finally {
            this.state.loading = false;
        }
    }

    onSearchInput(ev) {
        this.state.filters.search_term = ev.target.value;
    }

    async onSearchKeypress(ev) {
        if (ev.key === 'Enter') {
            await this.applyFilters();
        }
    }

    async onSearchClick() {
        await this.applyFilters();
    }

    clearSearch() {
        this.state.filters.search_term = '';
        this.applyFilters();
    }

    toggleFilters() {
        this.state.showFilters = !this.state.showFilters;
    }

    onDateFromChange(ev) {
        this.state.filters.date_from = ev.target.value || false;
    }

    onDateToChange(ev) {
        this.state.filters.date_to = ev.target.value || false;
    }

    onPlatformChange(ev) {
        this.state.filters.platform = ev.target.value || false;
    }

    onTypeChange(ev) {
        this.state.filters.move_type = ev.target.value || false;
    }

    async applyFilters() {
        await this.loadData();
    }

    async clearFilters() {
        this.state.filters = {
            date_from: false,
            date_to: false,
            partner_ids: false,
            platform: false,
            move_type: false,
            search_term: '',
        };
        await this.loadData();
    }

    openInvoice(invoiceId) {
        this.action.doAction({
            type: 'ir.actions.act_window',
            res_model: 'account.move',
            res_id: invoiceId,
            views: [[false, 'form']],
            target: 'current',
        });
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(value);
    }

    formatPercent(value) {
        return value.toFixed(2) + '%';
    }

    getProfitClass(profit) {
        if (profit > 0) return 'text-success';
        if (profit < 0) return 'text-danger';
        return 'text-muted';
    }
}

registry.category("actions").add("invoice_profitability_dashboard", InvoiceProfitabilityDashboard);