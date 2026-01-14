// lib/pages/leave_balance_screen.dart - تصميم مبهج وعصري
// Modern & Cheerful Leave Balance Screen

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
      print('Error loading leave balance: $e');
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
          backgroundColor: Color(0xFFE53935),
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
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(isArabic),

            // Content
            Expanded(
              child: isLoading
                  ? _buildLoadingState()
                  : leaveBalance == null
                  ? _buildErrorState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: _loadLeaveBalance,
                  color: Color(0xFF6366F1),
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
    );
  }

  Widget _buildAppBar(bool isArabic) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isArabic ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),

          Expanded(
            child: Text(
              context.translate('leave_balance'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Refresh Button
          GestureDetector(
            onTap: _loadLeaveBalance,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: Color(0xFF64748B),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          SizedBox(height: 20),
          Text(
            context.translate('loading_data'),
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFFE53935),
            ),
          ),
          SizedBox(height: 20),
          Text(
            context.translate('unable_to_load_data'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3142),
            ),
          ),
          SizedBox(height: 8),
          Text(
            context.isArabic ? 'اضغط للمحاولة مرة أخرى' : 'Tap to try again',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadLeaveBalance,
            icon: Icon(Icons.refresh_rounded),
            label: Text(context.isArabic ? 'إعادة المحاولة' : 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
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
    );
  }

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
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.35),
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

          SizedBox(height: 32),

          // Big Number
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalRemaining.round()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12, left: 8),
                child: Text(
                  '/ ${totalAllocated.round()}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          Text(
            context.translate('days') + ' ' + context.translate('remaining'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: 28),

          // Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.translate('usage_rate'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${usagePercentage.round()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (usagePercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
            color: Color(0xFF2196F3),
            bgColor: Color(0xFFE3F2FD),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_busy_rounded,
            value: '${totalUsed.round()}',
            label: context.translate('used'),
            color: Color(0xFFFF9800),
            bgColor: Color(0xFFFFF3E0),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_rounded,
            value: '${totalRemaining.round()}',
            label: context.translate('remaining'),
            color: Color(0xFF4CAF50),
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
        color: Colors.white,
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
              color: Color(0xFF2D3142),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

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
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.category_rounded,
                color: Color(0xFF6366F1),
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Text(
              context.translate('details_by_leave_type'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
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
        color: Colors.white,
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
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            SizedBox(height: 20),
            Text(
              context.translate('no_leave_data_available'),
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
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
    final colorString = typeData['color'] as String? ?? '#6366F1';

    Color typeColor;
    try {
      typeColor = Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      typeColor = Color(0xFF6366F1);
    }

    final usagePercentage = allocated > 0 ? (used / allocated * 100) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                width: 5,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${remaining.round()} ${context.translate('days')} ${context.translate('remaining')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${usagePercentage.round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildTypeStatItem(
                  context.translate('allocated'),
                  '${allocated.round()}',
                  Color(0xFF2196F3),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildTypeStatItem(
                  context.translate('used'),
                  '${used.round()}',
                  Color(0xFFFF9800),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildTypeStatItem(
                  context.translate('remaining'),
                  '${remaining.round()}',
                  Color(0xFF4CAF50),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (usagePercentage / 100).clamp(0.0, 1.0),
              backgroundColor: typeColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(typeColor),
              minHeight: 8,
            ),
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}