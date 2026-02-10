// lib/pages/leave_request_details_screen.dart
// شاشة تفاصيل طلب الإجازة - تصميم جديد مع الحفاظ على الأساسيات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import '../services/leave_service.dart';
import '../services/odoo_service.dart';

class LeaveRequestDetailsScreen extends StatefulWidget {
  final LeaveRequest request;
  final OdooService odooService;
  final Employee employee;

  const LeaveRequestDetailsScreen({
    Key? key,
    required this.request,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _LeaveRequestDetailsScreenState createState() => _LeaveRequestDetailsScreenState();
}

class _LeaveRequestDetailsScreenState extends State<LeaveRequestDetailsScreen> {
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
  late LeaveService _leaveService;
  late LeaveRequest currentRequest;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _leaveService = LeaveService(widget.odooService);
    currentRequest = widget.request;
  }

  // ═══════════════════════════════════════════════════════════════
  // الدوال الأساسية - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded, color: warningOrange),
            ),
            SizedBox(width: 12),
            Text('Cancel Request', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to cancel this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        isLoading = true;
      });

      final result = await _leaveService.cancelLeaveRequest(currentRequest.id);

      if (result['success']) {
        _showSnackBar(
          result['message'] ?? 'Request cancelled successfully',
          isSuccess: result['offline'] != true,
          isWarning: result['offline'] == true,
        );
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar(result['error'] ?? 'Failed to cancel request', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false, bool isWarning = false}) {
    Color bgColor = primaryBlue;
    IconData icon = Icons.info;

    if (isSuccess) {
      bgColor = successGreen;
      icon = Icons.check_circle;
    } else if (isError) {
      bgColor = dangerRed;
      icon = Icons.error;
    } else if (isWarning) {
      bgColor = warningOrange;
      icon = Icons.warning;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Color _getStateColor() {
    switch (currentRequest.state) {
      case 'draft':
        return textGrey;
      case 'confirm':
        return warningOrange;
      case 'validate':
      case 'validate1':
        return successGreen;
      case 'refuse':
        return dangerRed;
      default:
        return textGrey;
    }
  }

  IconData _getStateIcon() {
    switch (currentRequest.state) {
      case 'draft':
        return Icons.edit_rounded;
      case 'confirm':
        return Icons.schedule_rounded;
      case 'validate':
      case 'validate1':
        return Icons.check_circle_rounded;
      case 'refuse':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getStateText() {
    switch (currentRequest.state) {
      case 'draft':
        return 'Draft';
      case 'confirm':
        return 'Pending Approval';
      case 'validate':
      case 'validate1':
        return 'Approved';
      case 'refuse':
        return 'Rejected';
      default:
        return currentRequest.state;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _getStateColor();

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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStatusCard(stateColor),
                      SizedBox(height: 20),
                      _buildDetailsCard(),
                      SizedBox(height: 20),
                      _buildDatesCard(),
                      SizedBox(height: 20),
                      if (currentRequest.reason != null && currentRequest.reason!.isNotEmpty)
                        _buildReasonCard(),
                      SizedBox(height: 20),
                      _buildTimelineCard(stateColor),
                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _canCancel() ? _buildBottomBar() : null,
    );
  }

  bool _canCancel() {
    return currentRequest.state == 'draft' || currentRequest.state == 'confirm';
  }

  // ═══════════════════════════════════════════════════════════════
  // UI Components
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 16, 8),
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
              child: Icon(Icons.arrow_back_ios_new, color: textDark, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              'Request Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color stateColor) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stateColor, stateColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: stateColor.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStateIcon(), color: Colors.white, size: 40),
          ),
          SizedBox(height: 16),

          // Status Text
          Text(
            _getStateText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),

          // Leave Type
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentRequest.leaveTypeName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.person_rounded,
            label: 'Employee',
            value: widget.employee.name,
          ),
          Divider(height: 1, indent: 60),
          _buildDetailRow(
            icon: Icons.beach_access_rounded,
            label: 'Leave Type',
            value: currentRequest.leaveTypeName,
          ),
          Divider(height: 1, indent: 60),
          _buildDetailRow(
            icon: Icons.timer_rounded,
            label: 'Duration',
            value: '${currentRequest.numberOfDays.toStringAsFixed(0)} ${currentRequest.numberOfDays == 1 ? 'Day' : 'Days'}',
            valueColor: primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textGrey),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.date_range_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Date Range Visual
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateItem(
                    'FROM',
                    currentRequest.dateFrom,
                    Icons.login_rounded,
                    primaryBlue,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 2,
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${currentRequest.numberOfDays.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Days',
                        style: TextStyle(fontSize: 10, color: textGrey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildDateItem(
                    'TO',
                    currentRequest.dateTo,
                    Icons.logout_rounded,
                    darkBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String label, DateTime date, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          DateFormat('MMM dd').format(date),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        Text(
          DateFormat('yyyy').format(date),
          style: TextStyle(fontSize: 13, color: textGrey),
        ),
      ],
    );
  }

  Widget _buildReasonCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Reason',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentRequest.reason ?? 'No reason provided',
              style: TextStyle(
                fontSize: 14,
                color: textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Color stateColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timeline_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Request Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Timeline Items
          _buildTimelineItem(
            'Request Created',
            currentRequest.createdDate != null
                ? DateFormat('MMM dd, yyyy • HH:mm').format(currentRequest.createdDate!)
                : 'N/A',
            Icons.add_circle_rounded,
            primaryBlue,
            isFirst: true,
          ),
          _buildTimelineItem(
            'Current Status',
            _getStateText(),
            _getStateIcon(),
            stateColor,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String title,
      String subtitle,
      IconData icon,
      Color color, {
        bool isFirst = false,
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: color.withOpacity(0.3),
              ),
          ],
        ),
        SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: textGrey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: dangerRed.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _cancelRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_rounded, size: 22),
                SizedBox(width: 10),
                Text(
                  'Cancel Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}