// lib/pages/profile_page.dart
// صفحة الملف الشخصي - تصميم جديد واحترافي

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';
import '../widgets/employee_avatar.dart';

class ProfilePage extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const ProfilePage({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  Employee? _employee;
  bool _isLoading = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ═══════════════════════════════════════════════════════════════
  // الألوان - نفس نظام الألوان المستخدم
  // ═══════════════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF5B9BD5);
  static const Color darkBlue = Color(0xFF2B579A);
  static const Color lightBlue = Color(0xFFE8F4FC);
  static const Color accentBlue = Color(0xFF0078D4);
  static const Color textDark = Color(0xFF1E3A5F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color bgGradientStart = Color(0xFFF0F7FF);
  static const Color bgGradientEnd = Color(0xFFE1EFFF);
  static const Color cardWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _isLoading = false;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageManager();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgGradientStart, bgGradientEnd],
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            )
                : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildAppBar(lang),
                      _buildProfileHeader(lang),
                      const SizedBox(height: 24),
                      _buildWorkInfoCard(lang),
                      const SizedBox(height: 16),
                      _buildContactInfoCard(lang),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// AppBar
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar(LanguageManager lang) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              lang.isArabic ? 'الملف الشخصي' : 'My Profile',
              style: const TextStyle(
                color: textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Edit profile action
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: primaryBlue,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Profile Header - بطاقة الملف الشخصي الرئيسية
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildProfileHeader(LanguageManager lang) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, darkBlue],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with border
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: EmployeeAvatar(
                  employee: _employee!,
                  radius: 50,
                ),
              ),
              // Online indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            _employee!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Job Title
          Text(
            _employee!.jobTitle.isNotEmpty
                ? _employee!.jobTitle
                : (lang.isArabic ? 'موظف' : 'Employee'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // Department Badge
          if (_employee!.department.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _employee!.department,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Employee ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'ID: ${_employee!.displayId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Work Information Card - بطاقة معلومات العمل
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildWorkInfoCard(LanguageManager lang) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_rounded,
                  color: primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                lang.isArabic ? 'معلومات العمل' : 'Work Information',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fields
          _buildInfoField(
            icon: Icons.badge_outlined,
            label: lang.isArabic ? 'رقم الموظف' : 'Employee ID',
            value: _employee!.displayId,
            color: primaryBlue,
          ),
          _buildDivider(),
          _buildInfoField(
            icon: Icons.work_outline_rounded,
            label: lang.isArabic ? 'المسمى الوظيفي' : 'Job Title',
            value: _employee!.jobTitle.isNotEmpty ? _employee!.jobTitle : '-',
            color: const Color(0xFF34C759),
          ),
          _buildDivider(),
          _buildInfoField(
            icon: Icons.business_rounded,
            label: lang.isArabic ? 'القسم' : 'Department',
            value: _employee!.department.isNotEmpty ? _employee!.department : '-',
            color: const Color(0xFFFF9500),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Contact Information Card - بطاقة معلومات الاتصال
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildContactInfoCard(LanguageManager lang) {
    final hasContactInfo = _employee!.workEmail.isNotEmpty ||
        _employee!.workPhone.isNotEmpty ||
        _employee!.mobilePhone.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_phone_rounded,
                  color: Color(0xFF34C759),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                lang.isArabic ? 'معلومات الاتصال' : 'Contact Information',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fields
          if (!hasContactInfo)
            _buildEmptyState(lang)
          else ...[
            if (_employee!.workEmail.isNotEmpty) ...[
              _buildContactField(
                icon: Icons.email_rounded,
                label: lang.isArabic ? 'البريد الإلكتروني' : 'Work Email',
                value: _employee!.workEmail,
                color: primaryBlue,
                onTap: () => _copyToClipboard(_employee!.workEmail, lang),
              ),
            ],
            if (_employee!.workEmail.isNotEmpty &&
                (_employee!.workPhone.isNotEmpty || _employee!.mobilePhone.isNotEmpty))
              _buildDivider(),
            if (_employee!.workPhone.isNotEmpty) ...[
              _buildContactField(
                icon: Icons.phone_rounded,
                label: lang.isArabic ? 'هاتف العمل' : 'Work Phone',
                value: _employee!.workPhone,
                color: const Color(0xFF34C759),
                onTap: () => _copyToClipboard(_employee!.workPhone, lang),
              ),
            ],
            if (_employee!.workPhone.isNotEmpty && _employee!.mobilePhone.isNotEmpty)
              _buildDivider(),
            if (_employee!.mobilePhone.isNotEmpty) ...[
              _buildContactField(
                icon: Icons.smartphone_rounded,
                label: lang.isArabic ? 'الجوال' : 'Mobile Phone',
                value: _employee!.mobilePhone,
                color: const Color(0xFFFF9500),
                onTap: () => _copyToClipboard(_employee!.mobilePhone, lang),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageManager lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.contact_mail_outlined,
              color: textGrey.withOpacity(0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              lang.isArabic
                  ? 'لا توجد معلومات اتصال'
                  : 'No contact information available',
              style: TextStyle(
                color: textGrey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactField({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.copy_rounded,
                color: color,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.shade200,
      height: 1,
    );
  }

  void _copyToClipboard(String text, LanguageManager lang) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              lang.isArabic ? 'تم النسخ!' : 'Copied!',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}