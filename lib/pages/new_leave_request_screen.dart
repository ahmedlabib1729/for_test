// lib/pages/new_leave_request_screen.dart
// شاشة طلب إجازة جديدة - تصميم جديد مع الحفاظ على الأساسيات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import '../services/leave_service.dart';
import '../services/odoo_service.dart';
import '../models/leave_type.dart';

class NewLeaveRequestScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const NewLeaveRequestScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _NewLeaveRequestScreenState createState() => _NewLeaveRequestScreenState();
}

class _NewLeaveRequestScreenState extends State<NewLeaveRequestScreen> {
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
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late LeaveService _leaveService;

  List<LeaveType> leaveTypes = [];
  LeaveType? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;
  int calculatedDays = 0;

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _leaveService = LeaveService(widget.odooService);
    _loadLeaveTypes();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // الدوال الأساسية - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadLeaveTypes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final types = await _leaveService.getLeaveTypes();

      setState(() {
        leaveTypes = types;
        if (types.isNotEmpty) {
          selectedLeaveType = types.first;
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _calculateDays() {
    if (startDate != null && endDate != null) {
      final difference = endDate!.difference(startDate!);
      setState(() {
        calculatedDays = difference.inDays + 1;
      });
    } else {
      setState(() {
        calculatedDays = 0;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: cardWhite,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = startDate;
        }
      });
      _calculateDays();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: cardWhite,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        endDate = picked;
      });
      _calculateDays();
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedLeaveType == null) {
      _showSnackBar('Please select a leave type', isError: true);
      return;
    }

    if (startDate == null || endDate == null) {
      _showSnackBar('Please select start and end dates', isError: true);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await _leaveService.createLeaveRequest(
        employeeId: widget.employee.id,
        leaveTypeId: selectedLeaveType!.id,
        startDate: startDate!,
        endDate: endDate!,
        reason: _reasonController.text.trim(),
      );

      if (result['success']) {
        _showSnackBar(result['message'] ?? 'Request submitted successfully', isSuccess: true);
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar(result['error'] ?? 'Failed to submit request', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : isError ? Icons.error : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? successGreen : isError ? dangerRed : primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: isLoading
                    ? _buildLoadingState()
                    : errorMessage != null
                    ? _buildErrorState()
                    : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
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
              'New Leave Request',
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
            child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
          ),
          SizedBox(height: 20),
          Text(
            'Loading leave types...',
            style: TextStyle(fontSize: 16, color: textGrey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

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
              child: Icon(Icons.error_outline_rounded, size: 56, color: dangerRed),
            ),
            SizedBox(height: 24),
            Text(
              'Failed to load data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error',
              style: TextStyle(fontSize: 14, color: textGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLeaveTypes,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave Type Card
            _buildSectionCard(
              title: 'Leave Type',
              icon: Icons.category_rounded,
              child: _buildLeaveTypeSelector(),
            ),

            SizedBox(height: 20),

            // Date Selection Card
            _buildSectionCard(
              title: 'Duration',
              icon: Icons.date_range_rounded,
              child: _buildDateSelectors(),
            ),

            SizedBox(height: 20),

            // Days Summary Card
            if (calculatedDays > 0) _buildDaysSummaryCard(),

            if (calculatedDays > 0) SizedBox(height: 20),

            // Reason Card
            _buildSectionCard(
              title: 'Reason (Optional)',
              icon: Icons.description_rounded,
              child: _buildReasonField(),
            ),

            SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: cardWhite,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<LeaveType>(
            value: selectedLeaveType,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue),
            dropdownColor: cardWhite,
            borderRadius: BorderRadius.circular(16),
            style: TextStyle(color: textDark, fontSize: 15),
            items: leaveTypes.map((type) {
              return DropdownMenuItem<LeaveType>(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      type.name,
                      style: TextStyle(color: textDark, fontSize: 15),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedLeaveType = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectors() {
    return Column(
      children: [
        // Start Date
        _buildDateField(
          label: 'Start Date',
          date: startDate,
          icon: Icons.calendar_today_rounded,
          onTap: _selectStartDate,
        ),
        SizedBox(height: 12),
        // End Date
        _buildDateField(
          label: 'End Date',
          date: endDate,
          icon: Icons.event_rounded,
          onTap: _selectEndDate,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lightBlue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryBlue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryBlue, size: 22),
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
                    date != null
                        ? DateFormat('EEEE, MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null ? textDark : textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: textGrey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSummaryCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, darkBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.timer_rounded, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Days',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$calculatedDays ${calculatedDays == 1 ? 'Day' : 'Days'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (selectedLeaveType != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selectedLeaveType!.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Enter reason for leave (optional)...',
        hintStyle: TextStyle(color: textGrey.withOpacity(0.6)),
        filled: true,
        fillColor: lightBlue.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryBlue.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryBlue.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      style: TextStyle(color: textDark, fontSize: 15),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isSubmitting
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_rounded, size: 22),
            SizedBox(width: 10),
            Text(
              'Submit Request',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}