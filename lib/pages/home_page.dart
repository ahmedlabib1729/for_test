// lib/pages/home_page.dart
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

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

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

      if (mounted) {
        setState(() {
          _isCheckedIn = attendanceStatus['is_checked_in'] ?? false;
          _quickStats = {
            'leave_balance': leaveBalance['total_remaining'] ?? 0,
            'pending_requests': leaveBalance['pending_requests'] ?? 0,
            'worked_hours': attendanceStatus['worked_hours'] ?? '0:00',
          };
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
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
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1F38),
                Color(0xFF2D3250),
                Color(0xFF424769),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
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
        bottomNavigationBar: _buildBottomNav(lang),
      ),
    );
  }

  Widget _buildHeader(LanguageManager lang) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Row(
          children: [
            // Profile Avatar
            GestureDetector(
              onTap: () => _navigateToProfile(),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF6C63FF).withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: EmployeeAvatar(
                  employee: widget.employee,
                  radius: 30,
                ),
              ),
            ),
            SizedBox(width: 16),

            // Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(lang),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.employee.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.employee.jobTitle,
                    style: TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Notification & Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        _currentTime,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _navigateToNotifications(),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(0xFFFF6B6B),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Text(
        widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : 'U',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickStats(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.beach_access_rounded,
              label: lang.isArabic ? 'رصيد الإجازات' : 'Leave Balance',
              value: _isLoadingStats ? '--' : '${_quickStats['leave_balance'] ?? 0}',
              suffix: lang.isArabic ? 'يوم' : 'days',
              gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending_actions_rounded,
              label: lang.isArabic ? 'طلبات معلقة' : 'Pending',
              value: _isLoadingStats ? '--' : '${_quickStats['pending_requests'] ?? 0}',
              suffix: lang.isArabic ? 'طلب' : 'requests',
              gradient: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.schedule_rounded,
              label: lang.isArabic ? 'ساعات العمل' : 'Worked',
              value: _isLoadingStats ? '--' : '${_quickStats['worked_hours'] ?? '0'}',
              suffix: lang.isArabic ? 'ساعة' : 'hrs',
              gradient: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
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
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            suffix,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
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

  Widget _buildAttendanceButton(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: () => _navigateToAttendance(),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isCheckedIn
                    ? [Color(0xFFFF6B6B), Color(0xFFFF8E53)]
                    : [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isCheckedIn ? Color(0xFFFF6B6B) : Color(0xFF4ECDC4)).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCheckedIn
                          ? (lang.isArabic ? 'تسجيل الانصراف' : 'Check Out')
                          : (lang.isArabic ? 'تسجيل الحضور' : 'Check In'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isCheckedIn
                          ? (lang.isArabic ? 'اضغط لتسجيل انصرافك' : 'Tap to check out')
                          : (lang.isArabic ? 'اضغط لتسجيل حضورك' : 'Tap to check in'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isArabic ? 'الخدمات' : 'Services',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  lang.isArabic ? 'عرض الكل' : 'See All',
                  style: TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              _buildServiceItem(
                icon: Icons.calendar_today_rounded,
                label: lang.isArabic ? 'الحضور' : 'Attendance',
                color: Color(0xFF6C63FF),
                onTap: () => _navigateToAttendance(),
              ),
              _buildServiceItem(
                icon: Icons.beach_access_rounded,
                label: lang.isArabic ? 'الإجازات' : 'Leaves',
                color: Color(0xFF4ECDC4),
                onTap: () => _navigateToLeaveBalance(),
              ),
              _buildServiceItem(
                icon: Icons.description_rounded,
                label: lang.isArabic ? 'الطلبات' : 'Requests',
                color: Color(0xFFFF8E53),
                onTap: () => _navigateToRequests(),
              ),
              _buildServiceItem(
                icon: Icons.campaign_rounded,
                label: lang.isArabic ? 'الإعلانات' : 'News',
                color: Color(0xFFFF6B6B),
                onTap: () => _navigateToAnnouncements(),
              ),
              _buildServiceItem(
                icon: Icons.account_balance_wallet_rounded,
                label: lang.isArabic ? 'الرواتب' : 'Payslips',
                color: Color(0xFF44A08D),
                onTap: () => _navigateToPayslips(),
              ),
              _buildServiceItem(
                icon: Icons.history_rounded,
                label: lang.isArabic ? 'السجل' : 'History',
                color: Color(0xFF764BA2),
                onTap: () => _navigateToAttendance(),
              ),
              _buildServiceItem(
                icon: Icons.person_rounded,
                label: lang.isArabic ? 'ملفي' : 'Profile',
                color: Color(0xFF667EEA),
                onTap: () => _navigateToProfile(),
              ),
              _buildServiceItem(
                icon: Icons.settings_rounded,
                label: lang.isArabic ? 'الإعدادات' : 'Settings',
                color: Color(0xFF9E9E9E),
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
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isArabic ? 'النشاط الأخير' : 'Recent Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.white54),
            ],
          ),
          SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.login_rounded,
            title: lang.isArabic ? 'تسجيل حضور' : 'Checked In',
            subtitle: lang.isArabic ? 'اليوم 08:30 ص' : 'Today 08:30 AM',
            color: Color(0xFF4ECDC4),
          ),
          _buildActivityItem(
            icon: Icons.beach_access_rounded,
            title: lang.isArabic ? 'طلب إجازة' : 'Leave Request',
            subtitle: lang.isArabic ? 'أمس - قيد المراجعة' : 'Yesterday - Pending',
            color: Color(0xFFFF8E53),
          ),
          _buildActivityItem(
            icon: Icons.account_balance_wallet_rounded,
            title: lang.isArabic ? 'كشف راتب' : 'Payslip',
            subtitle: lang.isArabic ? 'يناير 2026 - مدفوع' : 'January 2026 - Paid',
            color: Color(0xFF44A08D),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white30,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(LanguageManager lang) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1F38),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: lang.isArabic ? 'الرئيسية' : 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.calendar_today_rounded,
                label: lang.isArabic ? 'الحضور' : 'Attendance',
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
                label: lang.isArabic ? 'حسابي' : 'Profile',
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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6C63FF).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Color(0xFF6C63FF) : Colors.white54,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Color(0xFF6C63FF) : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
            colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 15,
              offset: Offset(0, 5),
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

  // Navigation Methods
  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        break; // Already on home
      case 1:
        _navigateToAttendance();
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