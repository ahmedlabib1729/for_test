// lib/pages/home_page.dart
// الصفحة الرئيسية - تصميم جديد مع الحفاظ على الأساسيات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';
import 'attendance_screen.dart';
import 'leave_balance_screen.dart';
import 'requests_screen.dart';
import 'announcements_screen.dart';
import 'payslips_screen.dart';
import 'profile_page.dart';
import 'settings_screen.dart';
import '../widgets/employee_avatar.dart';

class HomePage extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;
  final VoidCallback? onLogout;

  const HomePage({
    Key? key,
    required this.odooService,
    required this.employee,
    this.onLogout,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isCheckedIn = false;
  String _currentTime = '';
  Map<String, dynamic> _quickStats = {};
  bool _isLoadingStats = true;

  // Recent Activity Data
  List<Map<String, dynamic>> _recentActivities = [];
  Map<String, dynamic>? _lastAttendance;
  Map<String, dynamic>? _lastLeaveRequest;
  Map<String, dynamic>? _lastPayslip;
  Map<String, dynamic>? _lastAnnouncement;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ═══════════════════════════════════════════════════════════════
  // الألوان الجديدة - مستوحاة من التصميم المطلوب
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
    _initAnimations();
    _loadData();
    _updateTime();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      final now = DateTime.now();
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    Future.delayed(const Duration(seconds: 30), _updateTime);
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingStats = true);

    try {
      // تحميل حالة الحضور
      final attendanceStatus = await widget.odooService.getCurrentAttendanceStatus(widget.employee.id);

      // تحميل رصيد الإجازات
      final leaveBalance = await widget.odooService.getEmployeeLeaveBalance(widget.employee.id);

      // تحميل بيانات Recent Activity
      await _loadRecentActivities();

      if (mounted) {
        setState(() {
          _isCheckedIn = attendanceStatus['is_checked_in'] ?? false;
          _quickStats = {
            'leave_balance': leaveBalance['total_remaining'] ?? 0,
            'pending_requests': leaveBalance['pending_requests'] ?? 0,
            'worked_hours': attendanceStatus['worked_hours'] ?? '0:00',
          };

          // حفظ آخر تسجيل حضور
          if (attendanceStatus['check_in'] != null) {
            _lastAttendance = {
              'type': _isCheckedIn ? 'checked_in' : 'checked_out',
              'time': attendanceStatus['check_in'],
              'check_out': attendanceStatus['check_out'],
            };
          }

          _isLoadingStats = false;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      // جلب آخر طلبات الإجازة
      final leaveRequests = await widget.odooService.getLeaveRequests(widget.employee.id);
      if (leaveRequests.isNotEmpty) {
        final lastRequest = leaveRequests.first;
        _lastLeaveRequest = {
          'id': lastRequest.id,
          'type': lastRequest.leaveTypeName,
          'state': lastRequest.state,
          'stateText': lastRequest.stateText,
          'date': lastRequest.dateFrom,
        };
      }

      // جلب آخر كشوف الرواتب
      final payslips = await widget.odooService.getPayslips(widget.employee.id);
      if (payslips.isNotEmpty) {
        final lastPayslip = payslips.first;
        _lastPayslip = {
          'id': lastPayslip.id,
          'period': lastPayslip.periodText,
          'state': lastPayslip.state,
          'stateText': lastPayslip.stateText,
          'amount': lastPayslip.netSalary,
          'currency': lastPayslip.currency,
        };
      }

      // جلب آخر الإعلانات
      final announcements = await widget.odooService.getAnnouncements(widget.employee.id, limit: 1);
      if (announcements.isNotEmpty) {
        final lastAnnouncement = announcements.first;
        _lastAnnouncement = {
          'id': lastAnnouncement.id,
          'title': lastAnnouncement.title,
          'isRead': lastAnnouncement.isRead,
          'date': lastAnnouncement.createdDate,
        };
      }
    } catch (e) {

    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgGradientStart, bgGradientEnd],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: primaryBlue,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(lang),
                  ),

                  // Quick Stats Cards
                  SliverToBoxAdapter(
                    child: _buildQuickStats(lang),
                  ),

                  // Check In/Out Button
                  SliverToBoxAdapter(
                    child: _buildAttendanceButton(lang),
                  ),

                  // Services Grid
                  SliverToBoxAdapter(
                    child: _buildServicesSection(lang),
                  ),

                  // Recent Activity
                  SliverToBoxAdapter(
                    child: _buildRecentActivity(lang),
                  ),

                  SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(lang),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Header - الترحيب والإشعارات
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(LanguageManager lang) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Row(
          children: [
            // Profile Avatar
            GestureDetector(
              onTap: () => _navigateToProfile(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: EmployeeAvatar(
                  employee: widget.employee,
                  radius: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(lang),
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.employee.name,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Settings
            GestureDetector(
              onTap: () => _navigateToSettings(),
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
                  Icons.settings_outlined,
                  color: textDark,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Notifications
            GestureDetector(
              onTap: () => _navigateToNotifications(),
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
                child: Stack(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: textDark,
                      size: 22,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Quick Stats - الإحصائيات السريعة
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildQuickStats(LanguageManager lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.beach_access_rounded,
              label: lang.isArabic ? 'رصيد الإجازات' : 'Leave Balance',
              value: _isLoadingStats ? '--' : '${_quickStats['leave_balance'] ?? 0}',
              suffix: lang.isArabic ? 'يوم' : 'Days',
              color: primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending_actions_rounded,
              label: lang.isArabic ? 'طلبات معلقة' : 'Pending',
              value: _isLoadingStats ? '--' : '${_quickStats['pending_requests'] ?? 0}',
              suffix: lang.isArabic ? 'طلب' : 'Requests',
              color: const Color(0xFFFF9500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.schedule_rounded,
              label: lang.isArabic ? 'ساعات العمل' : 'Hours',
              value: _isLoadingStats ? '--' : '${_quickStats['worked_hours'] ?? '0'}',
              suffix: lang.isArabic ? 'ساعة' : 'Worked',
              color: const Color(0xFF34C759),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String suffix,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            suffix,
            style: TextStyle(
              color: textGrey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Attendance Button - زر تسجيل الحضور
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildAttendanceButton(LanguageManager lang) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: () => _navigateToAttendance(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isCheckedIn
                    ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                    : [primaryBlue, darkBlue],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isCheckedIn ? const Color(0xFFFF6B6B) : primaryBlue)
                      .withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCheckedIn
                          ? (lang.isArabic ? 'تسجيل انصراف' : 'Clock Out')
                          : (lang.isArabic ? 'تسجيل حضور' : 'Clock In'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentTime,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Services Section - قسم الخدمات
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildServicesSection(LanguageManager lang) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isArabic ? 'الخدمات' : 'Services',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  lang.isArabic ? 'عرض الكل' : 'See All',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              _buildServiceItem(
                icon: Icons.calendar_today_rounded,
                label: lang.isArabic ? 'الحضور' : 'Attendance',
                color: primaryBlue,
                onTap: () => _navigateToAttendance(),
              ),
              _buildServiceItem(
                icon: Icons.beach_access_rounded,
                label: lang.isArabic ? 'الإجازات' : 'Leaves',
                color: const Color(0xFF34C759),
                onTap: () => _navigateToLeaveBalance(),
              ),
              _buildServiceItem(
                icon: Icons.description_rounded,
                label: lang.isArabic ? 'الطلبات' : 'Requests',
                color: const Color(0xFFFF9500),
                onTap: () => _navigateToRequests(),
              ),
              _buildServiceItem(
                icon: Icons.campaign_rounded,
                label: lang.isArabic ? 'الإعلانات' : 'News',
                color: const Color(0xFFFF3B30),
                onTap: () => _navigateToAnnouncements(),
              ),
              _buildServiceItem(
                icon: Icons.account_balance_wallet_rounded,
                label: lang.isArabic ? 'الرواتب' : 'Payslips',
                color: const Color(0xFF5856D6),
                onTap: () => _navigateToPayslips(),
              ),
              _buildServiceItem(
                icon: Icons.person_rounded,
                label: lang.isArabic ? 'ملفي' : 'Profile',
                color: const Color(0xFF007AFF),
                onTap: () => _navigateToProfile(),
              ),
              _buildServiceItem(
                icon: Icons.settings_rounded,
                label: lang.isArabic ? 'الإعدادات' : 'Settings',
                color: textGrey,
                onTap: () => _navigateToSettings(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: textDark,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Recent Activity - النشاط الأخير
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildRecentActivity(LanguageManager lang) {
    // بناء قائمة النشاطات الحقيقية
    List<Widget> activityItems = [];

    // 1. آخر تسجيل حضور
    if (_lastAttendance != null) {
      final isCheckedIn = _lastAttendance!['type'] == 'checked_in';
      final checkInTime = _lastAttendance!['time'];
      final checkOutTime = _lastAttendance!['check_out'];

      String subtitle;
      if (isCheckedIn && checkInTime != null) {
        subtitle = lang.isArabic
            ? 'تسجيل دخول - ${_formatTime(checkInTime)}'
            : 'Check In - ${_formatTime(checkInTime)}';
      } else if (checkOutTime != null) {
        subtitle = lang.isArabic
            ? 'تسجيل خروج - ${_formatTime(checkOutTime)}'
            : 'Check Out - ${_formatTime(checkOutTime)}';
      } else {
        subtitle = lang.isArabic ? 'لم يتم التسجيل بعد' : 'Not recorded yet';
      }

      activityItems.add(_buildActivityItem(
        icon: isCheckedIn ? Icons.login_rounded : Icons.logout_rounded,
        title: lang.isArabic ? 'الحضور' : 'Attendance',
        subtitle: subtitle,
        color: isCheckedIn ? const Color(0xFF34C759) : const Color(0xFFFF9500),
        onTap: () => _navigateToAttendance(),
      ));
    }

    // 2. آخر طلب إجازة
    if (_lastLeaveRequest != null) {
      final state = _lastLeaveRequest!['state'] ?? '';
      final stateText = _lastLeaveRequest!['stateText'] ?? '';
      final leaveType = _lastLeaveRequest!['type'] ?? '';

      Color stateColor;
      switch (state) {
        case 'validate':
          stateColor = const Color(0xFF34C759); // أخضر - موافق عليه
          break;
        case 'refuse':
          stateColor = const Color(0xFFFF3B30); // أحمر - مرفوض
          break;
        case 'confirm':
          stateColor = const Color(0xFFFF9500); // برتقالي - قيد الانتظار
          break;
        default:
          stateColor = primaryBlue;
      }

      if (activityItems.isNotEmpty) {
        activityItems.add(const Divider(height: 24));
      }

      activityItems.add(_buildActivityItem(
        icon: Icons.beach_access_rounded,
        title: lang.isArabic ? 'طلب إجازة' : 'Leave Request',
        subtitle: '$leaveType - $stateText',
        color: stateColor,
        onTap: () => _navigateToRequests(),
      ));
    }

    // 3. آخر كشف راتب
    if (_lastPayslip != null) {
      final period = _lastPayslip!['period'] ?? '';
      final stateText = _lastPayslip!['stateText'] ?? '';
      final state = _lastPayslip!['state'] ?? '';

      Color stateColor = state == 'done'
          ? const Color(0xFF34C759)
          : const Color(0xFF5856D6);

      if (activityItems.isNotEmpty) {
        activityItems.add(const Divider(height: 24));
      }

      activityItems.add(_buildActivityItem(
        icon: Icons.account_balance_wallet_rounded,
        title: lang.isArabic ? 'كشف راتب' : 'Payslip',
        subtitle: '$period - $stateText',
        color: stateColor,
        onTap: () => _navigateToPayslips(),
      ));
    }

    // 4. آخر إعلان
    if (_lastAnnouncement != null) {
      final title = _lastAnnouncement!['title'] ?? '';
      final isRead = _lastAnnouncement!['isRead'] ?? false;

      if (activityItems.isNotEmpty) {
        activityItems.add(const Divider(height: 24));
      }

      activityItems.add(_buildActivityItem(
        icon: Icons.campaign_rounded,
        title: lang.isArabic ? 'إعلان جديد' : 'New Announcement',
        subtitle: title,
        color: isRead ? textGrey : const Color(0xFFFF6B6B),
        onTap: () => _navigateToAnnouncements(),
      ));
    }

    // إذا مفيش بيانات، عرض رسالة
    if (activityItems.isEmpty) {
      activityItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 40, color: textGrey.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  lang.isArabic ? 'لا يوجد نشاط حديث' : 'No recent activity',
                  style: TextStyle(color: textGrey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isArabic ? 'النشاط الأخير' : 'Recent Activity',
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoadingStats
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: primaryBlue),
              ),
            )
                : Column(children: activityItems),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final dateTime = DateTime.parse(timeStr);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    } catch (e) {
      return timeStr.length > 5 ? timeStr.substring(11, 16) : timeStr;
    }
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: textGrey.withOpacity(0.5),
            size: 22,
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Bottom Navigation
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildBottomNav(LanguageManager lang) {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: lang.isArabic ? 'الرئيسية' : 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: lang.isArabic ? 'الرواتب' : 'Payslip',
                index: 1,
              ),
              _buildCenterNavButton(lang),
              _buildNavItem(
                icon: Icons.description_rounded,
                label: lang.isArabic ? 'الطلبات' : 'Requests',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: lang.isArabic ? 'الملف' : 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryBlue : textGrey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryBlue : textGrey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavButton(LanguageManager lang) {
    return GestureDetector(
      onTap: () => _navigateToAttendance(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isCheckedIn
                ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                : [primaryBlue, darkBlue],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isCheckedIn ? const Color(0xFFFF6B6B) : primaryBlue)
                  .withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Navigation Methods
  /// ═══════════════════════════════════════════════════════════════
  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        break; // Already on home
      case 1:
        _navigateToPayslips();
        break;
      case 3:
        _navigateToRequests();
        break;
      case 4:
        _navigateToProfile();
        break;
    }
  }

  String _getGreeting(LanguageManager lang) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return lang.isArabic ? 'صباح الخير 👋' : 'Good Morning 👋';
    } else if (hour < 17) {
      return lang.isArabic ? 'مساء الخير 👋' : 'Good Afternoon 👋';
    } else {
      return lang.isArabic ? 'مساء الخير 👋' : 'Good Evening 👋';
    }
  }

  void _navigateToAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToLeaveBalance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveBalanceScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }

  void _navigateToRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestsScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }

  void _navigateToAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementsScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }

  void _navigateToPayslips() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayslipsScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          odooService: widget.odooService,
          employee: widget.employee,
          onLogout: widget.onLogout ?? () {
            widget.odooService.logout();
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          },
        ),
      ),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementsScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
  }
}