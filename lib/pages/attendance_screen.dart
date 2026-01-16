// lib/pages/attendance_screen.dart - تصميم مبهج وعصري مع إصلاح مشكلة الوقت
// Modern & Cheerful Attendance Screen with Timezone Fix

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/odoo_service.dart';
import '../models/employee.dart';
import '../services/language_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const AttendanceScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool isCheckedIn = false;
  DateTime? checkInTime;
  String workingHours = "0:00";
  int workingSeconds = 0;

  List<Map<String, dynamic>> attendanceRecords = [];

  late DateTime currentTime;
  late Timer timer;
  bool isLoading = true;
  bool isButtonLoading = false;

  // Location variables
  Position? currentPosition;
  String locationStatus = "Determining location...";
  bool isLocationEnabled = false;
  bool hasLocationPermission = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    currentTime = DateTime.now();

    // Animation setup
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    // Timer for current time
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentTime = DateTime.now();
        _updateWorkingHours();
      });
    });

    _loadAttendanceData();
    _checkLocationPermissions();
  }

  @override
  void dispose() {
    timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ✅ دالة تحويل الوقت من UTC إلى Local
  DateTime _convertToLocalTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return DateTime.now();
    }

    try {
      DateTime parsedTime;

      if (timeStr.contains('T') || timeStr.endsWith('Z')) {
        parsedTime = DateTime.parse(timeStr);
      } else {
        // صيغة Odoo العادية - الوقت بـ UTC
        parsedTime = DateTime.parse(timeStr);
        parsedTime = DateTime.utc(
          parsedTime.year,
          parsedTime.month,
          parsedTime.day,
          parsedTime.hour,
          parsedTime.minute,
          parsedTime.second,
        );
      }

      return parsedTime.toLocal();
    } catch (e) {
      print('Error parsing time: $e');
      return DateTime.now();
    }
  }

  // ✅ تحويل وقت string إلى Local time string
  String _formatTimeToLocal(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == 'N/A') {
      return 'N/A';
    }

    try {
      // لو الوقت already formatted (مثلاً "PM 12:16" أو "12:16 PM")
      // نحاول نحوله للـ timezone الصحيح
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        // الوقت جاي formatted من السيرفر
        // نحتاج نضيف 4 ساعات (فرق توقيت دبي)
        try {
          // Parse the time - handle both "PM 12:16" and "12:16 PM" formats
          String cleanTime = timeStr.trim();
          bool isPM = cleanTime.toUpperCase().contains('PM');
          bool isAM = cleanTime.toUpperCase().contains('AM');

          // Extract time part
          String timePart = cleanTime
              .replaceAll('PM', '')
              .replaceAll('AM', '')
              .replaceAll('pm', '')
              .replaceAll('am', '')
              .trim();

          List<String> parts = timePart.split(':');
          if (parts.length >= 2) {
            int hour = int.parse(parts[0].trim());
            int minute = int.parse(parts[1].trim());

            // Convert to 24-hour format
            if (isPM && hour != 12) hour += 12;
            if (isAM && hour == 12) hour = 0;

            // Add timezone offset (4 hours for Dubai)
            final now = DateTime.now();
            final utcTime = DateTime.utc(now.year, now.month, now.day, hour, minute);
            final localTime = utcTime.toLocal();

            return DateFormat('hh:mm a').format(localTime);
          }
        } catch (e) {
          print('Error parsing formatted time: $e');
        }
        return timeStr; // Return original if parsing fails
      }

      // لو الوقت بصيغة datetime (مثلاً "2025-12-07 12:16:00")
      DateTime parsedTime;
      if (timeStr.contains('T') || timeStr.endsWith('Z')) {
        parsedTime = DateTime.parse(timeStr);
      } else if (timeStr.contains('-') && timeStr.contains(':')) {
        // صيغة Odoo العادية
        parsedTime = DateTime.parse(timeStr);
        parsedTime = DateTime.utc(
          parsedTime.year,
          parsedTime.month,
          parsedTime.day,
          parsedTime.hour,
          parsedTime.minute,
          parsedTime.second,
        );
      } else {
        // مش قادرين نحلل الوقت - نرجعه زي ما هو
        return timeStr;
      }

      final localTime = parsedTime.toLocal();
      return DateFormat('hh:mm a').format(localTime);
    } catch (e) {
      print('Error formatting time: $e');
      return timeStr; // نرجع الوقت الأصلي مش الوقت الحالي!
    }
  }

  Future<void> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationStatus = context.translate('location_service_disabled');
          isLocationEnabled = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            locationStatus = context.translate('location_permission_denied');
            hasLocationPermission = false;
          });
          _showLocationPermissionDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          locationStatus = context.translate('location_permanently_denied');
          hasLocationPermission = false;
        });
        _showPermanentlyDeniedDialog();
        return;
      }

      setState(() {
        isLocationEnabled = true;
        hasLocationPermission = true;
      });

      await _getCurrentLocation();
    } catch (e) {
      print('Error checking location permissions: $e');
      setState(() {
        locationStatus = context.translate('location_error');
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        locationStatus = context.translate('determining_location');
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      setState(() {
        currentPosition = position;
        locationStatus = context.translate('location_determined');
      });
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        locationStatus = context.translate('failed_to_get_location');
      });
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.translate('location_permission_required'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('location_permission_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkLocationPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.translate('allow')),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.translate('location_permission_required'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('location_permanently_denied_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('later')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.translate('open_settings')),
          ),
        ],
      ),
    );
  }

  void _updateWorkingHours() {
    if (isCheckedIn && checkInTime != null) {
      Duration workDuration = currentTime.difference(checkInTime!);
      int hours = workDuration.inHours;
      int minutes = (workDuration.inMinutes % 60);
      workingSeconds = workDuration.inSeconds;
      workingHours = "$hours:${minutes.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() => isLoading = true);

      final attendanceStatus = await widget.odooService.getCurrentAttendanceStatus(widget.employee.id);

      setState(() {
        isCheckedIn = attendanceStatus['is_checked_in'] ?? false;
        if (isCheckedIn && attendanceStatus['check_in'] != null) {
          // ✅ تحويل الوقت من UTC إلى Local
          checkInTime = _convertToLocalTime(attendanceStatus['check_in']);
          print('Server time: ${attendanceStatus['check_in']}');
          print('Local time: $checkInTime');
          _updateWorkingHours();
        } else {
          workingHours = "0:00";
          workingSeconds = 0;
          checkInTime = null;
        }
      });

      // Fetch attendance history
      try {
        final records = await widget.odooService.getAttendanceHistory(widget.employee.id);
        setState(() {
          // ✅ تحويل أوقات السجلات من UTC إلى Local
          attendanceRecords = records.map((record) {
            return {
              ...record,
              'checkIn': _formatTimeToLocal(record['checkIn'] ?? record['check_in']),
              'checkOut': _formatTimeToLocal(record['checkOut'] ?? record['check_out']),
            };
          }).toList();
        });
      } catch (e) {
        print('Error fetching attendance history: $e');
        setState(() => attendanceRecords = []);
      }

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        isLoading = false;
        isCheckedIn = false;
        checkInTime = null;
        workingHours = "0:00";
        workingSeconds = 0;
      });

      _showErrorSnackBar(context.translate('error_loading_data'));
    }
  }

  Future<void> _toggleAttendance() async {
    try {
      if (!hasLocationPermission || !isLocationEnabled) {
        _showErrorSnackBar(
          context.translate('location_required'),
          isWarning: true,
        );
        return;
      }

      await _getCurrentLocation();

      if (currentPosition == null) {
        _showErrorSnackBar(
          context.translate('location_not_determined'),
        );
        return;
      }

      setState(() => isButtonLoading = true);

      if (isCheckedIn) {
        // Check out
        final result = await widget.odooService.checkOutWithLocation(
          widget.employee.id,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        if (result['success']) {
          setState(() {
            isCheckedIn = false;
            checkInTime = null;
            workingHours = "0:00";
            workingSeconds = 0;
          });
          _showSuccessSnackBar(context.translate('check_out_successful'));
          _loadAttendanceData();
        } else {
          _showErrorSnackBar(result['error'] ?? context.translate('check_out_failed'));
        }
      } else {
        // Check in
        final result = await widget.odooService.checkInWithLocation(
          widget.employee.id,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        if (result['success']) {
          _showSuccessSnackBar(context.translate('check_in_successful'));
          _loadAttendanceData();
        } else {
          _showErrorSnackBar(result['error'] ?? context.translate('check_in_failed'));
        }
      }
    } catch (e) {
      print('Error toggling attendance: $e');
      _showErrorSnackBar('${context.translate('error_occurred')}: $e');
    } finally {
      setState(() => isButtonLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_rounded : Icons.error_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isWarning ? Color(0xFFFF9800) : Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
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
            _buildAppBar(isArabic),
            Expanded(
              child: isLoading
                  ? _buildLoadingState()
                  : RefreshIndicator(
                onRefresh: _loadAttendanceData,
                color: Color(0xFF6366F1),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildTimeCard(isArabic),
                      SizedBox(height: 20),
                      _buildWorkingHoursCard(isArabic),
                      SizedBox(height: 20),
                      _buildLocationCard(isArabic),
                      SizedBox(height: 20),
                      _buildStatusCard(isArabic),
                      SizedBox(height: 24),
                      _buildActionButton(isArabic),
                      SizedBox(height: 28),
                      _buildAttendanceHistory(isArabic),
                      SizedBox(height: 20),
                    ],
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
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
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
              context.translate('attendance'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _loadAttendanceData,
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: Color(0xFF64748B),
                size: 20,
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
            context.translate('loading'),
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

  Widget _buildTimeCard(bool isArabic) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
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
          Text(
            DateFormat('EEEE, d MMMM yyyy', isArabic ? 'ar' : 'en').format(currentTime),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            DateFormat('hh:mm:ss a').format(currentTime),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard(bool isArabic) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: Color(0xFF6366F1),
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('working_hours'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  workingHours,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
          ),
          if (isCheckedIn)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    context.translate('active'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
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

  Widget _buildLocationCard(bool isArabic) {
    IconData icon;
    Color statusColor;
    String statusText;

    if (!isLocationEnabled || !hasLocationPermission) {
      icon = Icons.location_off_rounded;
      statusColor = Color(0xFFE53935);
      statusText = locationStatus;
    } else if (currentPosition != null) {
      icon = Icons.location_on_rounded;
      statusColor = Color(0xFF4CAF50);
      statusText = locationStatus;
    } else {
      icon = Icons.location_searching_rounded;
      statusColor = Color(0xFFFF9800);
      statusText = locationStatus;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentPosition != null) ...[
                  SizedBox(height: 4),
                  Text(
                    '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!hasLocationPermission || !isLocationEnabled)
            TextButton(
              onPressed: () => openAppSettings(),
              child: Text(
                context.translate('settings'),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isArabic) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCheckedIn ? Color(0xFF4CAF50).withOpacity(0.08) : Color(0xFFFF9800).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckedIn ? Color(0xFF4CAF50).withOpacity(0.2) : Color(0xFFFF9800).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCheckedIn ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: isCheckedIn ? Color(0xFF4CAF50) : Color(0xFFFF9800),
            size: 24,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCheckedIn
                    ? context.translate('you_are_checked_in')
                    : context.translate('you_are_not_checked_in'),
                style: TextStyle(
                  fontSize: 16,
                  color: isCheckedIn ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCheckedIn && checkInTime != null) ...[
                SizedBox(height: 4),
                Text(
                  '${context.translate('check_in_time')}: ${DateFormat('hh:mm a').format(checkInTime!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4CAF50).withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isArabic) {
    return ScaleTransition(
      scale: isCheckedIn ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCheckedIn
                ? [Color(0xFFE53935), Color(0xFFEF5350)]
                : [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isCheckedIn ? Color(0xFFE53935) : Color(0xFF4CAF50)).withOpacity(0.35),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isButtonLoading ? null : _toggleAttendance,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: isButtonLoading
              ? SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: Colors.white,
                size: 26,
              ),
              SizedBox(width: 12),
              Text(
                isCheckedIn
                    ? context.translate('check_out')
                    : context.translate('check_in'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.history_rounded,
                color: Color(0xFF6366F1),
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Text(
              context.translate('attendance_records'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (attendanceRecords.isEmpty)
          Container(
            padding: EdgeInsets.all(32),
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
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Text(
                    context.translate('no_records'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: attendanceRecords.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final record = attendanceRecords[index];
                return _buildRecordItem(record, isArabic);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record, bool isArabic) {
    final checkIn = record['checkIn'] ?? 'N/A';
    final checkOut = record['checkOut'] ?? 'N/A';
    final date = record['date'] ?? '';
    final duration = record['duration'] ?? '0:00';

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 4),
                        Text(
                          '${context.translate('duration')}: $duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildTimeChip(context.translate('in'), checkIn, Color(0xFF4CAF50)),
                  SizedBox(height: 6),
                  _buildTimeChip(
                    context.translate('out'),
                    checkOut,
                    checkOut != 'N/A' ? Color(0xFFE53935) : Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
          // Location info
          if (record['check_in_location'] != null) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF4CAF50)),
                SizedBox(width: 4),
                Text(
                  'In: ${record['check_in_location']}',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}