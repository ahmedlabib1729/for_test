// lib/pages/payslip_detail_screen.dart - Modern Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import '../models/payslip.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';

class PayslipDetailScreen extends StatefulWidget {
  final OdooService odooService;
  final int payslipId;

  const PayslipDetailScreen({
    Key? key,
    required this.odooService,
    required this.payslipId,
  }) : super(key: key);

  @override
  _PayslipDetailScreenState createState() => _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends State<PayslipDetailScreen>
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
  Payslip? payslip;
  bool isLoading = true;
  String errorMessage = '';
  bool isDownloading = false;

  // للحصول على صورة من الصفحة
  GlobalKey _repaintBoundaryKey = GlobalKey();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle Methods
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadPayslipDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Methods (PRESERVED - Exact same logic as original)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadPayslipDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final details = await widget.odooService.getPayslipDetails(widget.payslipId);

      setState(() {
        payslip = details;
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
                    : payslip == null
                    ? _buildEmptyState(lang)
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
              lang.translate('payslip_details'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          if (payslip != null) ...[
            GestureDetector(
              onTap: _showDownloadOptions,
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
                child: Icon(
                  isDownloading ? Icons.hourglass_empty_rounded : Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(LanguageManager lang) {
    final formatter = NumberFormat('#,###');

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Header Card
              _buildHeaderCard(lang, formatter),
              SizedBox(height: 20),

              // Net Salary Card
              _buildNetSalaryCard(lang, formatter),
              SizedBox(height: 20),

              // Salary Breakdown
              _buildSalaryBreakdownCard(lang, formatter),
              SizedBox(height: 20),

              // Allowances Card
              if (_hasAllowances())
                Column(
                  children: [
                    _buildAllowancesCard(lang, formatter),
                    SizedBox(height: 20),
                  ],
                ),

              // Deductions Card
              if (_hasDeductions())
                Column(
                  children: [
                    _buildDeductionsCard(lang, formatter),
                    SizedBox(height: 20),
                  ],
                ),

              // Additional Info Card
              _buildAdditionalInfoCard(lang),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(LanguageManager lang, NumberFormat formatter) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: payslip!.isPaid
              ? [successGreen, Color(0xFF2E7D32)]
              : payslip!.state == 'verify'
              ? [warningOrange, Color(0xFFE65100)]
              : [primaryBlue, darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (payslip!.isPaid ? successGreen : primaryBlue).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
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

          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(payslip!.stateIcon, style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            payslip!.stateText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  payslip!.periodText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  payslip!.number.isNotEmpty ? payslip!.number : '#${payslip!.id}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 10),
                      Text(
                        '${DateFormat('dd MMM').format(payslip!.dateFrom)} - ${DateFormat('dd MMM yyyy').format(payslip!.dateTo)}',
                        style: TextStyle(color: Colors.white, fontSize: 14),
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

  Widget _buildNetSalaryCard(LanguageManager lang, NumberFormat formatter) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: primaryBlue, size: 24),
              ),
              SizedBox(width: 14),
              Text(
                lang.translate('net_salary'),
                style: TextStyle(
                  fontSize: 16,
                  color: textGrey,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '${formatter.format(payslip!.netSalary)} ${payslip!.currency}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryBreakdownCard(LanguageManager lang, NumberFormat formatter) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: darkBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calculate_rounded, color: darkBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                lang.translate('salary_breakdown'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildBreakdownRow(
            lang.translate('basic_salary'),
            '${formatter.format(payslip!.basicSalary)} ${payslip!.currency}',
            textDark,
          ),
          Divider(height: 24, color: Colors.grey.shade200),
          _buildBreakdownRow(
            lang.translate('total_allowances'),
            '+${formatter.format(payslip!.totalAllowances)} ${payslip!.currency}',
            successGreen,
          ),
          Divider(height: 24, color: Colors.grey.shade200),
          _buildBreakdownRow(
            lang.translate('gross_salary'),
            '${formatter.format(payslip!.grossSalary)} ${payslip!.currency}',
            textDark,
            isBold: true,
          ),
          Divider(height: 24, color: Colors.grey.shade200),
          _buildBreakdownRow(
            lang.translate('total_deductions'),
            '-${formatter.format(payslip!.totalDeductions)} ${payslip!.currency}',
            errorRed,
          ),
          Divider(height: 24, color: Colors.grey.shade200),
          _buildBreakdownRow(
            lang.translate('net_salary'),
            '${formatter.format(payslip!.netSalary)} ${payslip!.currency}',
            primaryBlue,
            isBold: true,
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor,
      {bool isBold = false, bool isHighlighted = false}) {
    return Container(
      padding: isHighlighted ? EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? textDark : textGrey,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllowancesCard(LanguageManager lang, NumberFormat formatter) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: successGreen.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: successGreen.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: successGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add_circle_outline_rounded, color: successGreen, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                lang.translate('allowances'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (payslip!.housingAllowance > 0)
            _buildDetailRow(lang.translate('housing_allowance'), payslip!.housingAllowance, formatter, successGreen),
          if (payslip!.transportationAllowance > 0)
            _buildDetailRow(lang.translate('transportation_allowance'), payslip!.transportationAllowance, formatter, successGreen),
          if (payslip!.foodAllowance > 0)
            _buildDetailRow(lang.translate('food_allowance'), payslip!.foodAllowance, formatter, successGreen),
          if (payslip!.phoneAllowance > 0)
            _buildDetailRow(lang.translate('phone_allowance'), payslip!.phoneAllowance, formatter, successGreen),
          if (payslip!.otherAllowances > 0)
            _buildDetailRow(lang.translate('other_allowances'), payslip!.otherAllowances, formatter, successGreen),
        ],
      ),
    );
  }

  Widget _buildDeductionsCard(LanguageManager lang, NumberFormat formatter) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: errorRed.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: errorRed.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.remove_circle_outline_rounded, color: errorRed, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                lang.translate('deductions'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (payslip!.socialInsurance > 0)
            _buildDetailRow(lang.translate('social_insurance'), payslip!.socialInsurance, formatter, errorRed),
          if (payslip!.taxes > 0)
            _buildDetailRow(lang.translate('taxes'), payslip!.taxes, formatter, errorRed),
          if (payslip!.loans > 0)
            _buildDetailRow(lang.translate('loans'), payslip!.loans, formatter, errorRed),
          if (payslip!.absence > 0)
            _buildDetailRow(lang.translate('absence'), payslip!.absence, formatter, errorRed),
          if (payslip!.otherDeductions > 0)
            _buildDetailRow(lang.translate('other_deductions'), payslip!.otherDeductions, formatter, errorRed),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, NumberFormat formatter, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: textGrey)),
          Text(
            '${formatter.format(value)} ${payslip!.currency}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_outline_rounded, color: textGrey, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                lang.translate('additional_info'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_month_rounded, lang.translate('working_days'),
              '${payslip!.actualWorkingDays} / ${payslip!.workingDays}'),
          if (payslip!.paymentDate.isNotEmpty)
            _buildInfoRow(Icons.payment_rounded, lang.translate('payment_date'), payslip!.paymentDate),
          if (payslip!.bankName != null && payslip!.bankName!.isNotEmpty)
            _buildInfoRow(Icons.account_balance_rounded, lang.translate('bank'), payslip!.bankName!),
          if (payslip!.bankAccount != null && payslip!.bankAccount!.isNotEmpty)
            _buildInfoRow(Icons.credit_card_rounded, lang.translate('account'), payslip!.bankAccount!),
          if (payslip!.companyName != null && payslip!.companyName!.isNotEmpty)
            _buildInfoRow(Icons.business_rounded, lang.translate('company'), payslip!.companyName!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: textGrey, size: 18),
          SizedBox(width: 10),
          Text('$label:', style: TextStyle(fontSize: 13, color: textGrey)),
          Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textDark)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════
  bool _hasAllowances() {
    if (payslip == null) return false;
    return payslip!.housingAllowance > 0 ||
        payslip!.transportationAllowance > 0 ||
        payslip!.foodAllowance > 0 ||
        payslip!.phoneAllowance > 0 ||
        payslip!.otherAllowances > 0;
  }

  bool _hasDeductions() {
    if (payslip == null) return false;
    return payslip!.socialInsurance > 0 ||
        payslip!.taxes > 0 ||
        payslip!.loans > 0 ||
        payslip!.absence > 0 ||
        payslip!.otherDeductions > 0;
  }

  // PRESERVED - Download options method
  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final lang = context.lang;
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                lang.translate('share_options'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              SizedBox(height: 24),
              _buildShareOption(
                Icons.content_copy_rounded,
                lang.translate('copy_details'),
                lang.translate('copy_to_clipboard'),
                primaryBlue,
                _copyDetails,
              ),
              SizedBox(height: 12),
              _buildShareOption(
                Icons.picture_as_pdf_rounded,
                lang.translate('download_pdf'),
                lang.translate('save_as_pdf'),
                errorRed,
                _downloadPdf,
              ),
              SizedBox(height: 12),
              _buildShareOption(
                Icons.image_rounded,
                lang.translate('share_as_image'),
                lang.translate('share_screenshot'),
                successGreen,
                _shareAsImage,
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
                  SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textGrey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 16),
          ],
        ),
      ),
    );
  }

  // PRESERVED - Copy details method
  void _copyDetails() {
    if (payslip == null) return;
    final lang = context.lang;
    final formatter = NumberFormat('#,###');

    String details = '''
${lang.translate('payslip')} - ${payslip!.periodText}
${'-' * 30}
${lang.translate('number')}: ${payslip!.number.isNotEmpty ? payslip!.number : '#${payslip!.id}'}
${lang.translate('period')}: ${DateFormat('dd/MM/yyyy').format(payslip!.dateFrom)} - ${DateFormat('dd/MM/yyyy').format(payslip!.dateTo)}
${'-' * 30}
${lang.translate('basic_salary')}: ${formatter.format(payslip!.basicSalary)} ${payslip!.currency}
${lang.translate('total_allowances')}: ${formatter.format(payslip!.totalAllowances)} ${payslip!.currency}
${lang.translate('gross_salary')}: ${formatter.format(payslip!.grossSalary)} ${payslip!.currency}
${lang.translate('deductions')}: ${formatter.format(payslip!.totalDeductions)} ${payslip!.currency}
${'-' * 30}
${lang.translate('net_salary')}: ${formatter.format(payslip!.netSalary)} ${payslip!.currency}
''';

    // إضافة تفاصيل البدلات
    if (_hasAllowances()) {
      details += '\n${lang.translate('allowances_details')}:\n';
      if (payslip!.housingAllowance > 0) {
        details += '- ${lang.translate('housing_allowance')}: ${formatter.format(payslip!.housingAllowance)} ${payslip!.currency}\n';
      }
      if (payslip!.transportationAllowance > 0) {
        details += '- ${lang.translate('transportation_allowance')}: ${formatter.format(payslip!.transportationAllowance)} ${payslip!.currency}\n';
      }
      if (payslip!.foodAllowance > 0) {
        details += '- ${lang.translate('food_allowance')}: ${formatter.format(payslip!.foodAllowance)} ${payslip!.currency}\n';
      }
    }

    // إضافة تفاصيل الخصومات
    if (_hasDeductions()) {
      details += '\n${lang.translate('deductions_details')}:\n';
      if (payslip!.socialInsurance > 0) {
        details += '- ${lang.translate('social_insurance')}: ${formatter.format(payslip!.socialInsurance)} ${payslip!.currency}\n';
      }
      if (payslip!.taxes > 0) {
        details += '- ${lang.translate('taxes')}: ${formatter.format(payslip!.taxes)} ${payslip!.currency}\n';
      }
    }

    Clipboard.setData(ClipboardData(text: details));
    _showSnackBar(lang.translate('copied_to_clipboard'));
  }

  // PRESERVED - Download PDF method
  Future<void> _downloadPdf() async {
    if (isDownloading) return;

    setState(() {
      isDownloading = true;
    });

    try {
      final pdfBytes = await widget.odooService.downloadPayslipPdf(widget.payslipId);

      if (pdfBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/payslip_${payslip!.number}.pdf');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'كشف مرتب ${payslip!.periodText}',
        );
      } else {
        _showSnackBar(context.lang.translate('download_failed'), isError: true);
      }
    } catch (e) {
      _showSnackBar('${context.lang.translate('pdf_error_try_image')}', isError: true);
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  // Share as image method
  Future<void> _shareAsImage() async {
    try {
      RenderRepaintBoundary boundary =
      _repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/payslip_${payslip!.number}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'كشف مرتب ${payslip!.periodText}',
      );
    } catch (e) {
      _showSnackBar(context.lang.translate('share_failed'), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? errorRed : successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // State Widgets
  // ═══════════════════════════════════════════════════════════════════════════
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
              onPressed: _loadPayslipDetails,
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
          Text(lang.translate('no_data'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }
}