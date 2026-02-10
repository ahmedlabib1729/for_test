/** @odoo-module **/
import { registry } from "@web/core/registry";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";

const { Component, useState, onWillStart } = owl;

export class DailyRegisterDashboard extends Component {
    static template = "daily_cash_register.Dashboard";

    setup() {
        this.actionService = useService("action");
        this.orm = useService("orm");

        this.state = useState({
            // KPIs
            totalRegisters: 0,
            totalDebit: 0,
            totalCredit: 0,
            totalTax: 0,
            netBalance: 0,

            // Report Data
            reportData: { journals: [], totals: {} },

            // Expanded states
            expandedJournals: {},
            expandedRegisters: {},

            // Filters
            journals: [],
            selectedJournals: [],
            dateFrom: this.getFirstDayOfMonth(),
            dateTo: this.getTodayDate(),
            period: 'month',

            // UI
            isLoading: true,
        });

        onWillStart(async () => {
            await this.loadJournals();
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

    async loadJournals() {
        try {
            this.state.journals = await this.orm.call(
                'daily.register.dashboard', 'get_journals', []
            );
        } catch (error) {
            console.error("Error loading journals:", error);
        }
    }

    async loadReportData() {
        this.state.isLoading = true;
        try {
            const journalIds = this.state.selectedJournals.length > 0
                ? this.state.selectedJournals
                : false;

            const data = await this.orm.call(
                'daily.register.dashboard',
                'get_report_data',
                [journalIds, this.state.dateFrom, this.state.dateTo]
            );

            this.state.reportData = data;

            // Update KPIs from totals
            const totals = data.totals || {};
            this.state.totalDebit = totals.debit || 0;
            this.state.totalCredit = totals.credit || 0;
            this.state.totalTax = totals.tax || 0;
            this.state.netBalance = totals.balance || 0;
            this.state.totalRegisters = data.journals.reduce((sum, j) => sum + j.registers.length, 0);

        } catch (error) {
            console.error("Error loading report data:", error);
        }
        this.state.isLoading = false;
    }

    // Format number
    formatNumber(num) {
        return (num || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    // Toggle expand/collapse
    toggleJournal(journalId) {
        this.state.expandedJournals[journalId] = !this.state.expandedJournals[journalId];
    }

    toggleRegister(registerId) {
        this.state.expandedRegisters[registerId] = !this.state.expandedRegisters[registerId];
    }

    isJournalExpanded(journalId) {
        return this.state.expandedJournals[journalId] || false;
    }

    isRegisterExpanded(registerId) {
        return this.state.expandedRegisters[registerId] || false;
    }

    // Period change
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

    // Date change
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

    // Journal filter change
    async onChangeJournal(ev) {
        const journalId = parseInt(ev.target.value);
        const isChecked = ev.target.checked;

        if (isChecked) {
            if (!this.state.selectedJournals.includes(journalId)) {
                this.state.selectedJournals.push(journalId);
            }
        } else {
            this.state.selectedJournals = this.state.selectedJournals.filter(id => id !== journalId);
        }

        await this.loadReportData();
    }

    isJournalSelected(journalId) {
        return this.state.selectedJournals.includes(journalId);
    }

    // Refresh
    async onRefresh() {
        await this.loadReportData();
    }

    // Export Excel
    async onExportExcel() {
        // Create CSV content
        let csv = 'Description,Date,Debit,Credit,Tax,Balance\n';

        for (const journal of this.state.reportData.journals) {
            csv += `"${journal.name}",,${journal.totals.debit},${journal.totals.credit},${journal.totals.tax},${journal.totals.balance}\n`;

            for (const reg of journal.registers) {
                csv += `"  ${reg.name}",${reg.date},${reg.debit},${reg.credit},${reg.tax},${reg.balance}\n`;

                for (const line of reg.lines) {
                    csv += `"    [${line.account_code}] ${line.description}",,${line.debit},${line.credit},${line.tax_amount},${line.balance}\n`;
                }
            }
        }

        const totals = this.state.reportData.totals;
        csv += `"GRAND TOTAL",,${totals.debit},${totals.credit},${totals.tax},${totals.balance}\n`;

        // Download
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = `daily_register_report_${this.state.dateFrom}_${this.state.dateTo}.csv`;
        link.click();
    }

    // Print
    onPrint() {
        window.print();
    }

    // Open register
    openRegister(registerId) {
        this.actionService.doAction({
            type: "ir.actions.act_window",
            name: _t("Daily Register"),
            res_model: "daily.cash.register",
            res_id: registerId,
            views: [[false, "form"]],
            target: "current",
        });
    }

    // Create new register
    createNewRegister() {
        this.actionService.doAction({
            type: "ir.actions.act_window",
            name: _t("New Daily Register"),
            res_model: "daily.cash.register",
            views: [[false, "form"]],
            target: "current",
        });
    }
}

DailyRegisterDashboard.template = "daily_cash_register.Dashboard";
registry.category("actions").add("daily_register_dashboard", DailyRegisterDashboard);