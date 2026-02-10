// lib/pages/attendance_screen.dart
// شاشة الحضور والانصراف - تصميم جديد مع الحفاظ على الأساسيات

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';
import 'face_verification_screen.dart';

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
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // الألوان - نفس نظام الألوان المستخدم
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

  // حالة الحضور
  bool isLoading = true;
  bool isCheckedIn = false;
  bool isButtonLoading = false;
  bool _isNavigating = false; // 🛡️ لمنع الضغط المتعدد أثناء فتح الكاميرا
  DateTime? checkInTime;
  String workingHours = "0:00";
  int workingSeconds = 0;

  // الموقع
  Position? currentPosition;
  bool hasLocationPermission = false;
  bool isLocationEnabled = false;

  // الوقت الحالي
  late Timer _timer;
  DateTime currentTime = DateTime.now();

  // سجلات الحضور
  List<Map<String, dynamic>> attendanceRecords = [];

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startTimer();
    _checkPermissions();
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentTime = DateTime.now();
        _updateWorkingHours();
      });
    });
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

  Future<void> _checkPermissions() async {
    final locationStatus = await Permission.location.status;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    setState(() {
      hasLocationPermission = locationStatus.isGranted;
      isLocationEnabled = serviceEnabled;
    });

    if (hasLocationPermission && isLocationEnabled) {
      await _getCurrentLocation();
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      setState(() => hasLocationPermission = true);
      await _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      _showPermanentlyDeniedDialog();
    }
  }

  void _showPermanentlyDeniedDialog() {
    final lang = context.lang;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.isArabic ? 'إذن مطلوب' : 'Permission Required'),
        content: Text(
          lang.isArabic
              ? 'يرجى تفعيل إذن الموقع من الإعدادات'
              : 'Please enable location permission from settings',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: Text(
              lang.isArabic ? 'الإعدادات' : 'Settings',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        currentPosition = position;
      });
    } catch (e) {

    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() => isLoading = true);

      final attendanceStatus = await widget.odooService
          .getCurrentAttendanceStatus(widget.employee.id);

      setState(() {
        isCheckedIn = attendanceStatus['is_checked_in'] ?? false;
        if (isCheckedIn && attendanceStatus['check_in'] != null) {
          checkInTime = _convertToLocalTime(attendanceStatus['check_in']);
          _updateWorkingHours();
        } else {
          workingHours = "0:00";
          workingSeconds = 0;
          checkInTime = null;
        }
      });

      // جلب السجلات
      try {
        final records = await widget.odooService
            .getAttendanceHistory(widget.employee.id);
        setState(() {
          attendanceRecords = records.map((record) {
            return {
              ...record,
              'checkIn': _formatTimeToLocal(
                  record['checkIn'] ?? record['check_in']),
              'checkOut': _formatTimeToLocal(
                  record['checkOut'] ?? record['check_out']),
            };
          }).toList();
        });
      } catch (e) {

      }
    } catch (e) {

      _showErrorSnackBar(context.translate('error_loading_data'));
    } finally {
      setState(() => isLoading = false);
    }
  }

  DateTime? _convertToLocalTime(dynamic time) {
    if (time == null) return null;
    try {
      if (time is String) {
        final utcTime = DateTime.parse(time);
        return utcTime.toLocal();
      }
      return time as DateTime;
    } catch (e) {
      return null;
    }
  }

  String _formatTimeToLocal(dynamic time) {
    if (time == null) return 'N/A';
    try {
      DateTime dateTime;
      if (time is String) {
        dateTime = DateTime.parse(time).toLocal();
      } else {
        dateTime = (time as DateTime).toLocal();
      }
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return time.toString();
    }
  }

  Future<void> _toggleAttendance() async {
    // 🛡️ منع الضغط المتعدد - لو الزر مضغوط أو بينتقل للكاميرا، ارفض
    if (isButtonLoading || _isNavigating) return;

    // تعطيل الزر فوراً
    setState(() {
      isButtonLoading = true;
      _isNavigating = true;
    });

    try {
      // 1️⃣ التحقق من الموقع
      if (!hasLocationPermission || !isLocationEnabled) {
        _showErrorSnackBar(
          context.translate('location_required'),
          isWarning: true,
        );
        return;
      }

      await _getCurrentLocation();

      if (currentPosition == null) {
        _showErrorSnackBar(context.translate('location_not_determined'));
        return;
      }

      // 2️⃣ فتح شاشة التحقق من الوجه (الزر يفضل معطل)
      final verificationResult = await Navigator.of(context).push<FaceVerificationResult>(
        MaterialPageRoute(
          builder: (context) => FaceVerificationScreen(
            isCheckIn: !isCheckedIn,
          ),
        ),
      );

      // التحقق من النتيجة
      if (verificationResult == null || !verificationResult.success) {
        if (verificationResult?.errorMessage != null) {
          _showErrorSnackBar(verificationResult!.errorMessage!);
        }
        return;
      }

      // 3️⃣ إرسال البيانات للسيرفر
      setState(() => isButtonLoading = true);

      if (isCheckedIn) {
        // ═══════════════════════════════════════
        // تسجيل الانصراف
        // ═══════════════════════════════════════
        final result = await widget.odooService.checkOutWithPhoto(
          employeeId: widget.employee.id,
          latitude: currentPosition!.latitude,
          longitude: currentPosition!.longitude,
          photoBase64: verificationResult.imageBase64!,
          actionPerformed: verificationResult.actionPerformed ?? 'unknown',
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
          _showErrorSnackBar(
              result['error'] ?? context.translate('check_out_failed'));
        }
      } else {
        // ═══════════════════════════════════════
        // تسجيل الحضور
        // ═══════════════════════════════════════
        final result = await widget.odooService.checkInWithPhoto(
          employeeId: widget.employee.id,
          latitude: currentPosition!.latitude,
          longitude: currentPosition!.longitude,
          photoBase64: verificationResult.imageBase64!,
          actionPerformed: verificationResult.actionPerformed ?? 'unknown',
        );

        if (result['success']) {
          _showSuccessSnackBar(context.translate('check_in_successful'));
          _loadAttendanceData();
        } else {
          _showErrorSnackBar(
              result['error'] ?? context.translate('check_in_failed'));
        }
      }
    } catch (e) {

      _showErrorSnackBar('${context.translate('error_occurred')}: $e');
    } finally {
      // 🛡️ إعادة تفعيل الزر بعد انتهاء كل شيء
      setState(() {
        isButtonLoading = false;
        _isNavigating = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isWarning ? warningOrange : dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.lang.isArabic;

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
            child: Column(
              children: [
                _buildAppBar(isArabic),
                Expanded(
                  child: isLoading
                      ? const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  )
                      : RefreshIndicator(
                    onRefresh: _loadAttendanceData,
                    color: primaryBlue,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildTimeCard(isArabic),
                          const SizedBox(height: 16),
                          _buildLocationCard(isArabic),
                          const SizedBox(height: 16),
                          _buildStatusCard(isArabic),
                          const SizedBox(height: 24),
                          _buildActionButton(isArabic),
                          const SizedBox(height: 24),
                          _buildAttendanceHistory(isArabic),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// AppBar
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                color: textDark,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.translate('attendance'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          GestureDetector(
            onTap: _loadAttendanceData,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.refresh_rounded,
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
  /// Time Card - بطاقة الوقت والتاريخ
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildTimeCard(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, darkBlue],
        ),
        borderRadius: BorderRadius.circular(24),
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
          // التاريخ
          Text(
            DateFormat('EEEE, d MMMM', isArabic ? 'ar' : 'en')
                .format(currentTime),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // الساعة
          Text(
            DateFormat('hh:mm:ss a').format(currentTime),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),

          // ساعات العمل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: Colors.white.withOpacity(0.9),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  '${context.translate('working_hours')}: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  workingHours,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
  /// Location Card - بطاقة الموقع
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildLocationCard(bool isArabic) {
    final bool locationReady = hasLocationPermission && isLocationEnabled;
    final Color statusColor = locationReady ? successGreen : warningOrange;
    final String statusText = locationReady
        ? (context.translate('location_enabled'))
        : (!hasLocationPermission
        ? context.translate('location_permission_denied')
        : context.translate('location_disabled'));

    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              locationReady ? Icons.location_on_rounded : Icons.location_off_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
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
                  const SizedBox(height: 4),
                  Text(
                    '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!locationReady)
            TextButton(
              onPressed: () {
                if (!hasLocationPermission) {
                  _requestPermissions();
                } else {
                  openAppSettings();
                }
              },
              child: Text(
                context.translate('enable'),
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Status Card - بطاقة الحالة
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildStatusCard(bool isArabic) {
    final Color statusColor = isCheckedIn ? successGreen : warningOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCheckedIn ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: statusColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCheckedIn
                    ? context.translate('you_are_checked_in')
                    : context.translate('you_are_not_checked_in'),
                style: TextStyle(
                  fontSize: 16,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCheckedIn && checkInTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${context.translate('check_in_time')}: ${DateFormat('hh:mm a').format(checkInTime!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Action Button - زر الحضور/الانصراف
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildActionButton(bool isArabic) {
    final Color buttonColor = isCheckedIn ? dangerRed : successGreen;
    final bool isDisabled = isButtonLoading || _isNavigating; // 🛡️ تحقق من الاتنين

    return ScaleTransition(
      scale: isCheckedIn ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCheckedIn
                ? [dangerRed, dangerRed.withOpacity(0.8)]
                : [successGreen, successGreen.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : _toggleAttendance, // 🛡️ استخدام isDisabled
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: isDisabled // 🛡️ استخدام isDisabled
              ? const SizedBox(
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
              const SizedBox(width: 12),
              Text(
                isCheckedIn
                    ? context.translate('check_out')
                    : context.translate('check_in'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.camera_front_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Attendance History - سجل الحضور
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildAttendanceHistory(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.translate('attendance_records'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (attendanceRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
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
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: textGrey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.translate('no_records'),
                    style: TextStyle(
                      fontSize: 16,
                      color: textGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attendanceRecords.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade100,
              ),
              itemBuilder: (context, index) {
                return _buildAttendanceRecord(attendanceRecords[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAttendanceRecord(Map<String, dynamic> record) {
    final checkIn = record['checkIn'] ?? 'N/A';
    final checkOut = record['checkOut'] ?? 'N/A';
    final date = record['date'] ?? '';
    final duration = record['duration'] ?? '0:00';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // التاريخ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: textGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${context.translate('duration')}: $duration',
                      style: TextStyle(
                        fontSize: 12,
                        color: textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // أوقات الدخول والخروج
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTimeChip(context.translate('in'), checkIn, successGreen),
              const SizedBox(height: 6),
              _buildTimeChip(
                context.translate('out'),
                checkOut,
                checkOut != 'N/A' ? dangerRed : textGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}