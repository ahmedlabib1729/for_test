// lib/pages/payslips_screen.dart - Modern Design
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/payslip.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';
import 'payslip_detail_screen.dart';

class PayslipsScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const PayslipsScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _PayslipsScreenState createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // Theme Colors
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF5B9BD5);
  static const Color darkBlue = Color(0xFF2B579A);
  static const Color lightBlue = Color(0xFFE8F4FC);
  static const Color textDark = Color(0xFF1E3A5F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color bgGradientStart = Color(0xFFF0F7FF);
  static const Color bgGradientEnd = Color(0xFFE1EFFF);
  static const Color cardWhite = Colors.white;
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color errorRed = Color(0xFFFF3B30);

  // ═══════════════════════════════════════════════════════════════════════════
  // State Variables (PRESERVED - Exact same as original)
  // ═══════════════════════════════════════════════════════════════════════════
  List<Payslip> payslips = [];
  bool isLoading = true;
  String errorMessage = '';

  // للفلترة
  String selectedState = 'all';
  int selectedYear = DateTime.now().year;

  // الملخص
  Map<String, dynamic> summary = {};

  late AnimationController _animationController;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle Methods
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadPayslips();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Methods (PRESERVED - Exact same logic as original)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadPayslips() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // جلب كشوف المرتبات
      final fetchedPayslips = await widget.odooService.getPayslips(widget.employee.id);

      // جلب الملخص
      final fetchedSummary = await widget.odooService.getPayslipsSummary(widget.employee.id);

      setState(() {
        payslips = fetchedPayslips;
        summary = fetchedSummary;
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // PRESERVED - Exact same getter
  List<Payslip> get filteredPayslips {
    return payslips.where((payslip) {
      // فلترة حسب الحالة
      if (selectedState != 'all' && payslip.state != selectedState) {
        return false;
      }

      // فلترة حسب السنة
      if (payslip.dateFrom.year != selectedYear) {
        return false;
      }

      return true;
    }).toList();
  }

  // PRESERVED - Exact same getter
  List<int> get availableYears {
    final years = payslips.map((p) => p.dateFrom.year).toSet().toList();
    if (years.isEmpty) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build Method
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradientStart, bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(lang),
              Expanded(
                child: isLoading
                    ? _buildLoadingState(lang)
                    : errorMessage.isNotEmpty
                    ? _buildErrorState(lang)
                    : _buildContent(lang),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI Components
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: darkBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: darkBlue, size: 20),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              lang.translate('payslips'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadPayslips,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LanguageManager lang) {
    return RefreshIndicator(
      onRefresh: _loadPayslips,
      color: primaryBlue,
      child: CustomScrollView(
        slivers: [
          if (summary.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard(lang)),
          SliverToBoxAdapter(child: _buildFilters(lang)),
          if (filteredPayslips.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(lang))
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPayslipCard(filteredPayslips[index], lang),
                  childCount: filteredPayslips.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(LanguageManager lang) {
    final formatter = NumberFormat('#,###');
    final totalNet = (summary['total_net'] ?? 0.0).toDouble();
    final averageNet = (summary['average_net'] ?? 0.0).toDouble();
    final paidCount = summary['paid_count'] ?? 0;
    final totalCount = summary['total_count'] ?? 0;

    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue, darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                    ),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.translate('total_earnings'),
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${formatter.format(totalNet)} EGP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          Icons.trending_up_rounded,
                          lang.translate('average'),
                          '${formatter.format(averageNet)}',
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(
                        child: _buildSummaryItem(
                          Icons.check_circle_rounded,
                          lang.translate('paid'),
                          '$paidCount / $totalCount',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFilters(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: darkBlue.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(canvasColor: cardWhite),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue),
                    style: TextStyle(color: textDark, fontSize: 14),
                    items: availableYears.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                            SizedBox(width: 8),
                            Text('$year', style: TextStyle(color: textDark)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedYear = value);
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: darkBlue.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(canvasColor: cardWhite),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedState,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue),
                    style: TextStyle(color: textDark, fontSize: 14),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(lang.translate('all'), style: TextStyle(color: textDark))),
                      DropdownMenuItem(value: 'done', child: Text(lang.translate('paid'), style: TextStyle(color: textDark))),
                      DropdownMenuItem(value: 'verify', child: Text(lang.translate('under_review'), style: TextStyle(color: textDark))),
                      DropdownMenuItem(value: 'draft', child: Text(lang.translate('draft'), style: TextStyle(color: textDark))),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => selectedState = value);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipCard(Payslip payslip, LanguageManager lang) {
    final formatter = NumberFormat('#,###');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PayslipDetailScreen(
              odooService: widget.odooService,
              payslipId: payslip.id,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: darkBlue.withOpacity(0.08), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_getStateColor(payslip.state).withOpacity(0.1), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStateColor(payslip.state).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: _getStateColor(payslip.state), size: 24),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payslip.periodText,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        SizedBox(height: 4),
                        Text(
                          payslip.number.isNotEmpty ? payslip.number : '#${payslip.id}',
                          style: TextStyle(fontSize: 13, color: textGrey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStateColor(payslip.state).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(payslip.stateIcon, style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          payslip.stateText,
                          style: TextStyle(
                            color: _getStateColor(payslip.state),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightBlue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(lang.translate('net_salary'), style: TextStyle(fontSize: 14, color: textGrey)),
                        Text(
                          '${formatter.format(payslip.netSalary)} ${payslip.currency}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          Icons.add_circle_outline_rounded,
                          lang.translate('gross'),
                          '${formatter.format(payslip.grossSalary)}',
                          successGreen,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildMiniStat(
                          Icons.remove_circle_outline_rounded,
                          lang.translate('deductions'),
                          '${formatter.format(payslip.totalDeductions)}',
                          errorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: textGrey)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(LanguageManager lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
            ),
            child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
          ),
          SizedBox(height: 24),
          Text(lang.translate('loading'), style: TextStyle(fontSize: 16, color: textGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildErrorState(LanguageManager lang) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(color: errorRed.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 48, color: errorRed),
            ),
            SizedBox(height: 24),
            Text(lang.translate('error'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            SizedBox(height: 8),
            Text(errorMessage, style: TextStyle(fontSize: 14, color: textGrey), textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPayslips,
              icon: Icon(Icons.refresh_rounded),
              label: Text(lang.translate('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageManager lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(color: lightBlue, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 64, color: primaryBlue),
          ),
          SizedBox(height: 24),
          Text(lang.translate('no_payslips'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
          SizedBox(height: 8),
          Text(
            lang.translate('no_payslips_message'),
            style: TextStyle(fontSize: 14, color: textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════
  Color _getStateColor(String state) {
    switch (state) {
      case 'done': return successGreen;
      case 'verify': return warningOrange;
      case 'draft': return textGrey;
      case 'cancel': return errorRed;
      default: return textGrey;
    }
  }
}