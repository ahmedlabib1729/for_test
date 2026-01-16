/** @odoo-module **/

import { registry } from "@web/core/registry";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";
import { Component, useState, onWillStart } from "@odoo/owl";

export class DailyInvoicesDashboard extends Component {
    static template = "samad_daily_report.Dashboard";

    setup() {
        this.actionService = useService("action");
        this.orm = useService("orm");

        this.state = useState({
            totalInvoices: 0,
            totalPurchases: 0,
            totalSales: 0,
            paidPercentage: 0,
            reportData: { purchases: {}, sales: {}, totals: {}, payment_summary: {} },
            expandedSections: {
                paidPurchases: false,
                unpaidPurchases: false,
                sales: false,
                otherPayments: false,
            },
            dateFrom: this.getTodayDate(),
            dateTo: this.getTodayDate(),
            period: 'today',
            isLoading: true,
        });

        onWillStart(async () => {
            await this.loadReportData();
        });
    }

    getFirstDayOfMonth() {
        const now = new Date();
        return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
    }

    getTodayDate() {
        const now = new Date();
        return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    }

    async loadReportData() {
        this.state.isLoading = true;
        try {
            const data = await this.orm.call(
                'daily.invoices.dashboard',
                'get_report_data',
                [this.state.dateFrom, this.state.dateTo]
            );

            this.state.reportData = data;

            const totals = data.totals || {};
            this.state.totalInvoices = totals.total_invoices || 0;
            this.state.totalPurchases = totals.purchases_total || 0;
            this.state.totalSales = totals.sales_total || 0;
            this.state.paidPercentage = totals.paid_percentage || 0;

        } catch (error) {
            console.error("Error loading report data:", error);
        }
        this.state.isLoading = false;
    }

    formatNumber(num) {
        return (num || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    toggleSection(section) {
        this.state.expandedSections[section] = !this.state.expandedSections[section];
    }

    isSectionExpanded(section) {
        return this.state.expandedSections[section] || false;
    }

    async onChangePeriod(period) {
        this.state.period = period;
        const now = new Date();

        if (period === 'today') {
            this.state.dateFrom = this.getTodayDate();
            this.state.dateTo = this.getTodayDate();
        } else if (period === 'week') {
            const weekStart = new Date(now);
            weekStart.setDate(now.getDate() - now.getDay());
            this.state.dateFrom = `${weekStart.getFullYear()}-${String(weekStart.getMonth() + 1).padStart(2, '0')}-${String(weekStart.getDate()).padStart(2, '0')}`;
            this.state.dateTo = this.getTodayDate();
        } else if (period === 'month') {
            this.state.dateFrom = this.getFirstDayOfMonth();
            this.state.dateTo = this.getTodayDate();
        } else if (period === 'year') {
            this.state.dateFrom = `${now.getFullYear()}-01-01`;
            this.state.dateTo = this.getTodayDate();
        }

        await this.loadReportData();
    }

    async onChangeDateFrom(ev) {
        this.state.dateFrom = ev.target.value;
        this.state.period = 'custom';
        await this.loadReportData();
    }

    async onChangeDateTo(ev) {
        this.state.dateTo = ev.target.value;
        this.state.period = 'custom';
        await this.loadReportData();
    }

    async onRefresh() {
        await this.loadReportData();
    }

    onExportExcel() {
        const dateFrom = this.state.dateFrom;
        const dateTo = this.state.dateTo;
        window.location.href = `/daily_invoices/export_excel?date_from=${dateFrom}&date_to=${dateTo}`;
    }

    async onExportPDF() {
        const dateFrom = this.state.dateFrom;
        const dateTo = this.state.dateTo;
        
        const wizardId = await this.orm.create('daily.invoices.report.wizard', [{
            date_from: dateFrom,
            date_to: dateTo,
        }]);
        
        return this.actionService.doAction({
            type: 'ir.actions.report',
            report_type: 'qweb-pdf',
            report_name: 'samad_daily_report.report_daily_invoices_document',
            report_file: 'samad_daily_report.report_daily_invoices_document',
            data: { ids: [wizardId] },
        });
    }

    onPrint() {
        window.print();
    }

    openInvoice(invoiceId, moveType) {
        this.actionService.doAction({
            type: "ir.actions.act_window",
            name: _t("Invoice"),
            res_model: "account.move",
            res_id: invoiceId,
            views: [[false, "form"]],
            target: "current",
        });
    }

    openPartner(partnerId) {
        this.actionService.doAction({
            type: "ir.actions.act_window",
            name: _t("Partner"),
            res_model: "res.partner",
            res_id: partnerId,
            views: [[false, "form"]],
            target: "current",
        });
    }
}

registry.category("actions").add("daily_invoices_dashboard", DailyInvoicesDashboard);
