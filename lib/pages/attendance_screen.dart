// lib/pages/attendance_screen.dart
// شاشة الحضور والانصراف - مع التحقق من الوجه والموقع

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
  // حالة الحضور
  bool isLoading = true;
  bool isCheckedIn = false;
  bool isButtonLoading = false;
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
      print('Error getting location: $e');
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

  DateTime? _convertToLocalTime(String? utcTimeString) {
    if (utcTimeString == null) return null;
    try {
      DateTime utcTime = DateTime.parse(utcTimeString);
      if (utcTimeString.endsWith('Z') || utcTimeString.contains('+')) {
        return utcTime.toLocal();
      }
      return DateTime.utc(
        utcTime.year, utcTime.month, utcTime.day,
        utcTime.hour, utcTime.minute, utcTime.second,
      ).toLocal();
    } catch (e) {
      print('Error converting time: $e');
      return null;
    }
  }

  String _formatTimeToLocal(String? utcTimeString) {
    if (utcTimeString == null || utcTimeString == 'N/A') return 'N/A';
    try {
      final localTime = _convertToLocalTime(utcTimeString);
      if (localTime == null) return 'N/A';
      return DateFormat('hh:mm a').format(localTime);
    } catch (e) {
      return 'N/A';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🆕 الدالة الرئيسية للحضور/الانصراف مع التحقق من الوجه
  // ═══════════════════════════════════════════════════════════════
  Future<void> _toggleAttendance() async {
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

      // 2️⃣ فتح شاشة التحقق من الوجه
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
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
        isWarning ? const Color(0xFFFF9800) : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.translate('open_settings')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isArabic),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadAttendanceData,
                color: const Color(0xFF6366F1),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildAppBar(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: const Color(0xFF2D3142),
            ),
          ),
          Expanded(
            child: Text(
              context.translate('attendance'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _loadAttendanceData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE, d MMMM', isArabic ? 'ar' : 'en')
                .format(currentTime),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('hh:mm:ss a').format(currentTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          if (isCheckedIn) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${context.translate('working_hours')}: $workingHours',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool isArabic) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!hasLocationPermission) {
      statusColor = Colors.red;
      statusText = context.translate('location_permission_denied');
      statusIcon = Icons.location_off_rounded;
    } else if (!isLocationEnabled) {
      statusColor = Colors.orange;
      statusText = context.translate('location_service_disabled');
      statusIcon = Icons.location_disabled_rounded;
    } else if (currentPosition != null) {
      statusColor = Colors.green;
      statusText = context.translate('location_determined');
      statusIcon = Icons.location_on_rounded;
    } else {
      statusColor = Colors.blue;
      statusText = context.translate('determining_location');
      statusIcon = Icons.my_location_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
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
                      color: statusColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!hasLocationPermission || !isLocationEnabled)
            TextButton(
              onPressed: () {
                if (!hasLocationPermission) {
                  _requestPermissions();
                } else {
                  openAppSettings();
                }
              },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCheckedIn
            ? const Color(0xFF4CAF50).withOpacity(0.08)
            : const Color(0xFFFF9800).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckedIn
              ? const Color(0xFF4CAF50).withOpacity(0.2)
              : const Color(0xFFFF9800).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCheckedIn
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: isCheckedIn
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800),
            size: 24,
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
                  color: isCheckedIn
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCheckedIn && checkInTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${context.translate('check_in_time')}: ${DateFormat('hh:mm a').format(checkInTime!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF4CAF50).withOpacity(0.8),
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
      scale: isCheckedIn ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCheckedIn
                ? [const Color(0xFFE53935), const Color(0xFFEF5350)]
                : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isCheckedIn
                  ? const Color(0xFFE53935)
                  : const Color(0xFF4CAF50))
                  .withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                isCheckedIn
                    ? Icons.logout_rounded
                    : Icons.login_rounded,
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
              // 🆕 أيقونة الكاميرا للإشارة للتحقق من الوجه
              const Icon(
                Icons.camera_front_rounded,
                color: Colors.white70,
                size: 20,
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF6366F1),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.translate('attendance_records'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (attendanceRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.translate('no_records'),
                    style: const TextStyle(
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
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attendanceRecords.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[100]),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          '${context.translate('duration')}: $duration',
                          style: const TextStyle(
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
                  _buildTimeChip(
                      context.translate('in'), checkIn, const Color(0xFF4CAF50)),
                  const SizedBox(height: 6),
                  _buildTimeChip(
                    context.translate('out'),
                    checkOut,
                    checkOut != 'N/A'
                        ? const Color(0xFFE53935)
                        : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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