// pages/home_page.dart - تصميم مبهج وعصري لتطبيق الموظفين
// Light & Cheerful Design for HR App

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:login_app/pages/profile_page.dart';
import 'dart:async';
import 'dart:ui';
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/offline_manager.dart';
import '../services/connectivity_service.dart';
import '../services/language_manager.dart';
import '../widgets/language_switcher.dart';
import '../pages/attendance_screen.dart';
import '../pages/requests_screen.dart';
import '../pages/login_page.dart';
import '../widgets/employee_avatar.dart';
import '../pages/announcements_screen.dart';
import '../pages/payslips_screen.dart';
import '../pages/calendar_screen.dart';
import '../pages/leave_balance_screen.dart';

class HomePage extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const HomePage({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();

  DateTime currentTime = DateTime.now();
  Timer? _timer;

  // Connection status
  bool isOnline = true;
  int pendingActionsCount = 0;

  // Attendance data
  bool isCheckedIn = false;
  DateTime? checkInTime;
  String workingHours = "0:00";

  // Leave balance data
  Map<String, dynamic>? leaveBalance;
  bool isLoadingLeaveBalance = false;

  // Loading status
  bool isLoading = true;

  // Animation controllers
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _offlineManager.initialize(widget.odooService);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        currentTime = DateTime.now();
        _updateWorkingHours();
      });
    });

    _connectivityService.connectionStatusStream.listen((isConnected) {
      setState(() {
        isOnline = isConnected;
      });

      if (isConnected) {
        _syncDataWhenOnline();
      }
    });

    _loadInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => isLoading = true);

      await Future.wait([
        _loadAttendanceStatus(),
        _loadPendingActionsCount(),
        _loadLeaveBalance(),
      ]);

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAttendanceStatus() async {
    try {
      Map<String, dynamic> status;

      if (isOnline) {
        status = await widget.odooService.getCurrentAttendanceStatus(widget.employee.id);
      } else {
        status = await _offlineManager.getOfflineAttendanceStatus(widget.employee.id);
      }

      setState(() {
        isCheckedIn = status['is_checked_in'] ?? false;

        if (isCheckedIn && status['check_in'] != null) {
          String checkInString = status['check_in'];
          DateTime parsedTime;

          if (checkInString.endsWith('Z')) {
            parsedTime = DateTime.parse(checkInString);
          } else {
            parsedTime = DateTime.parse(checkInString + 'Z');
          }

          checkInTime = parsedTime.toLocal();
          _updateWorkingHours();
        } else {
          checkInTime = null;
          workingHours = "0:00";
        }
      });
    } catch (e) {
      print('Error loading attendance status: $e');
      setState(() {
        isCheckedIn = false;
        checkInTime = null;
        workingHours = "0:00";
      });
    }
  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() => isLoadingLeaveBalance = true);

      try {
        final balance = await widget.odooService.getQuickLeaveBalance(widget.employee.id);
        setState(() => leaveBalance = balance);
      } catch (e) {
        print('Leave balance not available: $e');
        setState(() {
          leaveBalance = {
            'total_remaining': 30.0,
            'total_used': 0.0,
            'total_allocated': 30.0,
            'usage_percentage': 0.0,
          };
        });
      }

      setState(() => isLoadingLeaveBalance = false);
    } catch (e) {
      print('Error loading leave balance: $e');
      setState(() {
        isLoadingLeaveBalance = false;
        leaveBalance = {
          'total_remaining': 30.0,
          'total_used': 0.0,
          'total_allocated': 30.0,
          'usage_percentage': 0.0,
        };
      });
    }
  }

  Future<void> _loadPendingActionsCount() async {
    try {
      final count = await _offlineManager.getPendingActionsCount();
      setState(() => pendingActionsCount = count);
    } catch (e) {
      print('Error loading pending actions count: $e');
    }
  }

  void _updateWorkingHours() {
    if (isCheckedIn && checkInTime != null) {
      final Duration workDuration = currentTime.difference(checkInTime!);
      final int hours = workDuration.inHours;
      final int minutes = (workDuration.inMinutes % 60);
      workingHours = "$hours:${minutes.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _syncDataWhenOnline() async {
    if (!isOnline) return;

    try {
      await _offlineManager.syncOfflineActions();
      await _loadAttendanceStatus();
      await _loadPendingActionsCount();
      await _loadLeaveBalance();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(context.lang.translate('data_synced')),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error syncing data: $e');
    }
  }

  Future<void> _logout() async {
    final lang = context.lang;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 36),
              ),
              SizedBox(height: 20),
              Text(
                lang.translate('logout_confirmation'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              SizedBox(height: 8),
              Text(
                lang.translate('logout_message'),
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        lang.translate('cancel'),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE53935),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        lang.translate('logout'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await widget.odooService.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _safeToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
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
              SizedBox(height: 24),
              Text(
                lang.translate('loading_data'),
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: _buildAppBar(lang),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),

                    // Welcome Card
                    _buildWelcomeCard(lang),

                    SizedBox(height: 20),

                    // Attendance Card
                    _buildAttendanceCard(lang),

                    SizedBox(height: 20),

                    // Stats Row
                    _buildStatsRow(lang),

                    SizedBox(height: 24),

                    // Quick Actions Title
                    Text(
                      lang.isArabic ? 'الخدمات' : 'Services',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Services Grid
                    _buildServicesGrid(lang),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(dynamic lang) {
    String greeting = _getGreeting(lang);
    String formattedDate = lang.isArabic
        ? DateFormat('EEEE، d MMMM', 'ar').format(currentTime)
        : DateFormat('EEEE, d MMMM').format(currentTime);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text('👋', style: TextStyle(fontSize: 16)),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  widget.employee.name.split(' ')[0],
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              // Connection Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Color(0xFF4CAF50) : Color(0xFFE53935),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      isOnline
                          ? (lang.isArabic ? 'متصل' : 'Online')
                          : (lang.isArabic ? 'غير متصل' : 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline ? Color(0xFF4CAF50) : Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // Language Switcher
              LanguageSwitcher(
                showText: false,
                iconColor: Color(0xFF64748B),
                backgroundColor: Color(0xFFF1F5F9),
              ),

              SizedBox(width: 8),

              // Refresh Button
              _buildIconButton(
                icon: Icons.refresh_rounded,
                onTap: _loadInitialData,
              ),

              SizedBox(width: 8),

              // Logout Button
              _buildIconButton(
                icon: Icons.logout_rounded,
                onTap: _logout,
                color: Color(0xFFE53935),
                bgColor: Color(0xFFFFEBEE),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor ?? Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: color ?? Color(0xFF64748B),
          size: 22,
        ),
      ),
    );
  }

  String _getGreeting(dynamic lang) {
    final hour = DateTime.now().hour;
    if (lang.isArabic) {
      if (hour < 12) return 'صباح الخير';
      if (hour < 17) return 'مساء الخير';
      return 'مساء الخير';
    } else {
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }
  }

  Widget _buildWelcomeCard(dynamic lang) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(
              odooService: widget.odooService,
              initialEmployee: widget.employee,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: EmployeeAvatar(
                employee: widget.employee,
                radius: 32,
                odooService: widget.odooService,
              ),
            ),

            SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.employee.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.employee.jobTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.employee.department,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(dynamic lang) {
    final hours = workingHours.split(':')[0].padLeft(2, '0');
    final minutes = workingHours.split(':')[1].padLeft(2, '0');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceScreen(
              odooService: widget.odooService,
              employee: widget.employee,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? Color(0xFFE8F5E9)
                            : Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCheckedIn ? Icons.timer_outlined : Icons.fingerprint_rounded,
                        color: isCheckedIn ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.isArabic ? 'وقت العمل اليوم' : "Today's Work Time",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          isCheckedIn
                              ? (lang.isArabic ? 'أنت في العمل الآن ✨' : "You're clocked in ✨")
                              : (lang.isArabic ? 'اضغط لتسجيل الحضور' : 'Tap to clock in'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCheckedIn ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCheckedIn
                        ? (lang.isArabic ? 'حاضر' : 'Active')
                        : (lang.isArabic ? 'غائب' : 'Away'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Timer Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeUnit(hours, lang.isArabic ? 'ساعة' : 'Hours'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ),
                _buildTimeUnit(minutes, lang.isArabic ? 'دقيقة' : 'Minutes'),
              ],
            ),

            if (checkInTime != null) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, size: 18, color: Color(0xFF4CAF50)),
                    SizedBox(width: 8),
                    Text(
                      '${lang.isArabic ? 'وقت الدخول:' : 'Clocked in at:'} ${DateFormat('hh:mm a').format(checkInTime!)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 20),

            // Check In/Out Button
            ScaleTransition(
              scale: isCheckedIn ? AlwaysStoppedAnimation(1.0) : _scaleAnimation,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCheckedIn
                        ? [Color(0xFFE53935), Color(0xFFD32F2F)]
                        : [Color(0xFF4CAF50), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isCheckedIn ? Color(0xFFE53935) : Color(0xFF4CAF50))
                          .withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceScreen(
                            odooService: widget.odooService,
                            employee: widget.employee,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          isCheckedIn
                              ? lang.translate('manage_attendance')
                              : lang.translate('check_in'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(dynamic lang) {
    final totalRemaining = _safeToDouble(leaveBalance?['total_remaining'], defaultValue: 30.0);
    final totalUsed = _safeToDouble(leaveBalance?['total_used'], defaultValue: 0.0);
    final usagePercentage = _safeToDouble(leaveBalance?['usage_percentage'], defaultValue: 0.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveBalanceScreen(
              odooService: widget.odooService,
              employee: widget.employee,
            ),
          ),
        );
      },
      child: Container(
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.beach_access_rounded,
                        color: Color(0xFF2196F3),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      lang.isArabic ? 'رصيد الإجازات' : 'Leave Balance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),

            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    value: '${totalRemaining.round()}',
                    label: lang.isArabic ? 'متبقي' : 'Remaining',
                    color: Color(0xFF4CAF50),
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildStatItem(
                    value: '${totalUsed.round()}',
                    label: lang.isArabic ? 'مستخدم' : 'Used',
                    color: Color(0xFFFF9800),
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildStatItem(
                    value: '${usagePercentage.round()}%',
                    label: lang.isArabic ? 'النسبة' : 'Usage',
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (usagePercentage / 100).clamp(0.0, 1.0),
                backgroundColor: Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
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

  Widget _buildServicesGrid(dynamic lang) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildServiceCard(
          icon: Icons.description_outlined,
          title: lang.translate('leaves'),
          subtitle: lang.isArabic ? 'طلب إجازة جديدة' : 'Request time off',
          color: Color(0xFF6366F1),
          bgColor: Color(0xFFEEF2FF),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestsScreen(
                odooService: widget.odooService,
                employee: widget.employee,
              ),
            ),
          ),
        ),
        _buildServiceCard(
          icon: Icons.campaign_outlined,
          title: lang.translate('announcements'),
          subtitle: lang.isArabic ? 'آخر الأخبار' : 'Company news',
          color: Color(0xFFFF9800),
          bgColor: Color(0xFFFFF3E0),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnnouncementsScreen(
                odooService: widget.odooService,
                employee: widget.employee,
              ),
            ),
          ),
        ),
        _buildServiceCard(
          icon: Icons.account_balance_wallet_outlined,
          title: lang.translate('payslips'),
          subtitle: lang.isArabic ? 'كشف المرتبات' : 'View salary',
          color: Color(0xFF4CAF50),
          bgColor: Color(0xFFE8F5E9),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PayslipsScreen(
                odooService: widget.odooService,
                employee: widget.employee,
              ),
            ),
          ),
        ),
        _buildServiceCard(
          icon: Icons.calendar_month_outlined,
          title: lang.isArabic ? 'التقويم' : 'Calendar',
          subtitle: lang.isArabic ? 'الأحداث والإجازات' : 'Events & holidays',
          color: Color(0xFF2196F3),
          bgColor: Color(0xFFE3F2FD),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}