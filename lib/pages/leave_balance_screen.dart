// lib/pages/leave_balance_screen.dart
// شاشة رصيد الإجازات - تصميم جديد مع الحفاظ على الأساسيات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';

class LeaveBalanceScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const LeaveBalanceScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _LeaveBalanceScreenState createState() => _LeaveBalanceScreenState();
}

class _LeaveBalanceScreenState extends State<LeaveBalanceScreen>
    with SingleTickerProviderStateMixin {

  // ═══════════════════════════════════════════════════════════════
  // نظام الألوان الموحد
  // ═══════════════════════════════════════════════════════════════
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
  static const Color dangerRed = Color(0xFFFF3B30);

  // ═══════════════════════════════════════════════════════════════
  // المتغيرات الأساسية - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  Map<String, dynamic>? leaveBalance;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadLeaveBalance();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // تحميل البيانات - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadLeaveBalance() async {
    try {
      setState(() => isLoading = true);

      final balance = await widget.odooService.getEmployeeLeaveBalance(widget.employee.id);

      setState(() {
        leaveBalance = balance;
        isLoading = false;
      });

      _animationController.forward();
    } catch (e) {

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(context.translate('error_loading_leave_balance')),
            ],
          ),
          backgroundColor: dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

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
              _buildAppBar(isArabic),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : leaveBalance == null
                    ? _buildErrorState()
                    : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadLeaveBalance,
                    color: primaryBlue,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(isArabic),
                          SizedBox(height: 24),
                          _buildQuickStats(isArabic),
                          SizedBox(height: 28),
                          _buildLeaveTypesSection(isArabic),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AppBar
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isArabic) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                color: textDark,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.translate('leave_balance'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: primaryBlue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Loading State
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            context.translate('loading'),
            style: TextStyle(
              fontSize: 16,
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Error State
  // ═══════════════════════════════════════════════════════════════
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: dangerRed,
              ),
            ),
            SizedBox(height: 24),
            Text(
              context.translate('error_loading_data'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              context.isArabic ? 'اضغط للمحاولة مرة أخرى' : 'Tap to try again',
              style: TextStyle(
                fontSize: 14,
                color: textGrey,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLeaveBalance,
              icon: Icon(Icons.refresh_rounded),
              label: Text(context.isArabic ? 'إعادة المحاولة' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Summary Card - البطاقة الرئيسية
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSummaryCard(bool isArabic) {
    final totalRemaining = leaveBalance!['total_remaining']?.toDouble() ?? 0.0;
    final totalAllocated = leaveBalance!['total_allocated']?.toDouble() ?? 0.0;
    final usagePercentage = leaveBalance!['usage_percentage']?.toDouble() ?? 0.0;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, darkBlue],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.4),
            blurRadius: 25,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('overall_summary'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '${DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 28),

          // الرصيد المتبقي
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalRemaining.round()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8, left: 8),
                child: Text(
                  '/ ${totalAllocated.round()}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            context.translate('days_remaining'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),

          // Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.translate('usage'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${usagePercentage.round()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: usagePercentage / 100,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usagePercentage > 80 ? warningOrange : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Quick Stats - الإحصائيات السريعة
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuickStats(bool isArabic) {
    final totalAllocated = leaveBalance!['total_allocated']?.toDouble() ?? 0.0;
    final totalUsed = leaveBalance!['total_used']?.toDouble() ?? 0.0;
    final totalRemaining = leaveBalance!['total_remaining']?.toDouble() ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_available_rounded,
            value: '${totalAllocated.round()}',
            label: context.translate('allocated'),
            color: primaryBlue,
            bgColor: lightBlue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_busy_rounded,
            value: '${totalUsed.round()}',
            label: context.translate('used'),
            color: warningOrange,
            bgColor: Color(0xFFFFF3E0),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_rounded,
            value: '${totalRemaining.round()}',
            label: context.translate('remaining'),
            color: successGreen,
            bgColor: Color(0xFFE8F5E9),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Leave Types Section - أنواع الإجازات
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLeaveTypesSection(bool isArabic) {
    final leaveTypes = leaveBalance!['leave_types'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.category_rounded,
                color: primaryBlue,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Text(
              context.translate('details_by_leave_type'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Leave Types List
        if (leaveTypes.isEmpty)
          _buildEmptyState()
        else
          ...leaveTypes.entries.map((entry) {
            return _buildLeaveTypeCard(entry.key, entry.value as Map<String, dynamic>);
          }).toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 48,
                color: textGrey,
              ),
            ),
            SizedBox(height: 20),
            Text(
              context.translate('no_leave_data_available'),
              style: TextStyle(
                fontSize: 16,
                color: textGrey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeCard(String typeName, Map<String, dynamic> typeData) {
    final allocated = typeData['allocated']?.toDouble() ?? 0.0;
    final used = typeData['used']?.toDouble() ?? 0.0;
    final remaining = typeData['remaining']?.toDouble() ?? 0.0;
    final colorString = typeData['color'] as String? ?? '#5B9BD5';

    Color typeColor;
    try {
      typeColor = Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      typeColor = primaryBlue;
    }

    final usagePercentage = allocated > 0 ? (used / allocated * 100) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${remaining.round()} ${context.translate('days')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: usagePercentage / 100,
              minHeight: 8,
              backgroundColor: typeColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(typeColor),
            ),
          ),
          SizedBox(height: 14),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTypeStatItem(
                context.translate('allocated'),
                '${allocated.round()}',
                primaryBlue,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade200,
              ),
              _buildTypeStatItem(
                context.translate('used'),
                '${used.round()}',
                warningOrange,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade200,
              ),
              _buildTypeStatItem(
                context.translate('remaining'),
                '${remaining.round()}',
                successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textGrey,
          ),
        ),
      ],
    );
  }
}