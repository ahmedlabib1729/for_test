// lib/services/odoo_service.dart - إصدار كامل ومصحح
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import '../models/leave_type.dart';
import '../models/leave_request.dart';
import '../models/announcement.dart';
import '../models/payslip.dart';

class OdooService {
  late String baseUrl;
  final String database;

  String? sessionId;
  int? uid;

  final String serviceUsername = 'admin';
  final String servicePassword = 'admin';

  int? employeeId;
  Employee? currentEmployee;

  OdooService({
    required String url,
    required this.database,
  }) {
    if (url.endsWith('/')) {
      this.baseUrl = url;
    } else {
      this.baseUrl = url + '/';
    }
    print("تم تهيئة OdooService مع baseUrl: ${this.baseUrl}");
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال الاتصال والمصادقة
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> testApiConnection() async {
    try {
      final testUrl = '${baseUrl}api/mobile/test';
      final response = await http.get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('خطأ في اختبار اتصال API: $e');
      return false;
    }
  }

  Future<bool> testServerConnection() async {
    try {
      final response = await http.get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print("خطأ في الاتصال بالخادم: $e");
      return false;
    }
  }

  Future<bool> loginWithService() async {
    try {
      print("محاولة تسجيل الدخول باستخدام مستخدم الخدمة");

      final loginUrl = '${baseUrl}web/session/authenticate';
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'db': database,
            'login': serviceUsername,
            'password': servicePassword,
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return false;
      }

      final result = jsonDecode(response.body);

      if (result['result'] != null && result['result']['uid'] != null) {
        uid = result['result']['uid'];

        String? cookies = response.headers['set-cookie'];
        if (cookies != null) {
          final sessionRegex = RegExp(r'session_id=([^;]+)');
          final match = sessionRegex.firstMatch(cookies);
          if (match != null) {
            sessionId = match.group(1);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('session_id', sessionId!);
            await prefs.setInt('uid', uid!);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      print("خطأ في تسجيل الدخول: $e");
      return false;
    }
  }

  Future<Employee?> authenticateEmployee(String username, String password) async {
    return await loginEmployee(username, password);
  }

  Future<Employee?> loginEmployee(String username, String password) async {
    try {
      print("محاولة تسجيل دخول الموظف: $username");

      bool serviceLoggedIn = await loginWithService();
      if (!serviceLoggedIn) {
        throw Exception('فشل في الاتصال بالخادم');
      }

      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['mobile_username', '=', username],
                ['mobile_pin', '=', password],
                ['allow_mobile_access', '=', true]
              ],
              ['id', 'name', 'job_id', 'department_id', 'work_email', 'work_phone', 'mobile_phone', 'image_1920']
            ],
            'kwargs': {'limit': 1},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] != null && result['result'].isNotEmpty) {
        final employeeData = result['result'][0];

        final employee = Employee(
          id: employeeData['id'] ?? 0,
          name: employeeData['name'] ?? 'Unknown',
          jobTitle: (employeeData['job_id'] != null && employeeData['job_id'] != false)
              ? employeeData['job_id'][1].toString()
              : '',
          department: (employeeData['department_id'] != null && employeeData['department_id'] != false)
              ? employeeData['department_id'][1].toString()
              : '',
          workEmail: (employeeData['work_email'] != null && employeeData['work_email'] != false)
              ? employeeData['work_email'].toString()
              : '',
          workPhone: (employeeData['work_phone'] != null && employeeData['work_phone'] != false)
              ? employeeData['work_phone'].toString()
              : '',
          mobilePhone: (employeeData['mobile_phone'] != null && employeeData['mobile_phone'] != false)
              ? employeeData['mobile_phone'].toString()
              : '',
          imageUrl: (employeeData['image_1920'] != null && employeeData['image_1920'] != false)
              ? 'data:image/jpeg;base64,${employeeData['image_1920']}'
              : null,
        );

        employeeId = employee.id;
        currentEmployee = employee;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('employee_id', employee.id);

        return employee;
      }

      return null;
    } catch (e) {
      print("خطأ في تسجيل دخول الموظف: $e");
      return null;
    }
  }

  Future<Employee?> getCurrentEmployee() async {
    if (currentEmployee != null) {
      return currentEmployee;
    }

    if (employeeId != null) {
      try {
        if (sessionId == null) {
          await loginWithService();
        }

        final url = '${baseUrl}web/dataset/call_kw';
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'session_id=$sessionId',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'model': 'hr.employee',
              'method': 'search_read',
              'args': [
                [['id', '=', employeeId]],
                ['id', 'name', 'job_id', 'department_id', 'work_email', 'work_phone', 'mobile_phone', 'image_1920']
              ],
              'kwargs': {'limit': 1},
            },
            'id': DateTime.now().millisecondsSinceEpoch
          }),
        ).timeout(const Duration(seconds: 15));

        final result = jsonDecode(response.body);

        if (result.containsKey('result') && result['result'] != null && result['result'].isNotEmpty) {
          final data = result['result'][0];
          currentEmployee = Employee(
            id: data['id'] ?? 0,
            name: data['name'] ?? 'Unknown',
            jobTitle: (data['job_id'] != null && data['job_id'] != false)
                ? data['job_id'][1].toString()
                : '',
            department: (data['department_id'] != null && data['department_id'] != false)
                ? data['department_id'][1].toString()
                : '',
            workEmail: (data['work_email'] != null && data['work_email'] != false)
                ? data['work_email'].toString()
                : '',
            workPhone: (data['work_phone'] != null && data['work_phone'] != false)
                ? data['work_phone'].toString()
                : '',
            mobilePhone: (data['mobile_phone'] != null && data['mobile_phone'] != false)
                ? data['mobile_phone'].toString()
                : '',
            imageUrl: (data['image_1920'] != null && data['image_1920'] != false)
                ? 'data:image/jpeg;base64,${data['image_1920']}'
                : null,
          );
          return currentEmployee;
        }
      } catch (e) {
        print('خطأ في جلب الموظف الحالي: $e');
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال الحضور والانصراف
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCurrentAttendanceStatus(int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/status';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result']['success'] == true) {
        return result['result']['attendance_status'] ?? {
          'is_checked_in': false,
          'check_in': null,
          'attendance_id': null
        };
      }
      return {'is_checked_in': false, 'check_in': null, 'attendance_id': null};
    } catch (e) {
      print('خطأ في getCurrentAttendanceStatus: $e');
      return {'is_checked_in': false, 'check_in': null, 'attendance_id': null};
    }
  }

  Future<Map<String, dynamic>> checkInWithLocation(int employeeId, double latitude, double longitude) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/check_in';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'latitude': latitude,
            'longitude': longitude,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result')) {
        return result['result'];
      }
      return {'success': false, 'error': 'خطأ غير متوقع'};
    } catch (e) {
      print('خطأ في checkInWithLocation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkOutWithLocation(int employeeId, double latitude, double longitude) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/check_out';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'latitude': latitude,
            'longitude': longitude,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result')) {
        return result['result'];
      }
      return {'success': false, 'error': 'خطأ غير متوقع'};
    } catch (e) {
      print('خطأ في checkOutWithLocation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkInWithPhoto({
    required int employeeId,
    required double latitude,
    required double longitude,
    required String photoBase64,
    String? actionPerformed,
  }) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/check_in_photo';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'latitude': latitude,
            'longitude': longitude,
            'photo_base64': photoBase64,
            'action_performed': actionPerformed,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 30));

      final result = jsonDecode(response.body);

      if (result.containsKey('result')) {
        return result['result'];
      }
      return {'success': false, 'error': 'خطأ غير متوقع'};
    } catch (e) {
      print('خطأ في checkInWithPhoto: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkOutWithPhoto({
    required int employeeId,
    required double latitude,
    required double longitude,
    required String photoBase64,
    String? actionPerformed,
  }) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/check_out_photo';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'latitude': latitude,
            'longitude': longitude,
            'photo_base64': photoBase64,
            'action_performed': actionPerformed,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 30));

      final result = jsonDecode(response.body);

      if (result.containsKey('result')) {
        return result['result'];
      }
      return {'success': false, 'error': 'خطأ غير متوقع'};
    } catch (e) {
      print('خطأ في checkOutWithPhoto: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkIn(int employeeId) async {
    return await checkInWithLocation(employeeId, 0.0, 0.0);
  }

  Future<Map<String, dynamic>> checkOut(int employeeId) async {
    return await checkOutWithLocation(employeeId, 0.0, 0.0);
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/attendance/history';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'limit': 10,
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result']['success'] == true) {
        return List<Map<String, dynamic>>.from(result['result']['attendance_history'] ?? []);
      }
      return [];
    } catch (e) {
      print('خطأ في getAttendanceHistory: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال الإجازات
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getEmployeeLeaveBalance(int employeeId) async {
    try {
      print('📊 جلب رصيد الإجازات للموظف: $employeeId');

      try {
        final apiResult = await _getLeaveBalanceFromApi(employeeId);
        if (apiResult['success'] == true) {
          return apiResult['balance_data'] ?? {};
        }
      } catch (e) {
        print('⚠️ فشل API، سيتم استخدام الطريقة المباشرة: $e');
      }

      return await _getLeaveBalanceDirect(employeeId);
    } catch (e) {
      print('❌ خطأ في جلب رصيد الإجازات: $e');
      return _getEmptyLeaveBalance(employeeId);
    }
  }

  Future<Map<String, dynamic>> _getLeaveBalanceFromApi(int employeeId) async {
    if (sessionId == null) {
      bool success = await loginWithService();
      if (!success) throw Exception('فشل تسجيل الدخول');
    }

    final url = '${baseUrl}api/mobile/leave/balance';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'employee_id': employeeId,
        },
        'id': DateTime.now().millisecondsSinceEpoch
      }),
    ).timeout(const Duration(seconds: 15));

    final result = jsonDecode(response.body);

    if (result.containsKey('result')) {
      return result['result'];
    }

    return {'success': false};
  }

  Future<Map<String, dynamic>> _getLeaveBalanceDirect(int employeeId) async {
    final allocations = await _getEmployeeAllocations(employeeId);

    if (allocations.isEmpty) {
      return _getEmptyLeaveBalance(employeeId);
    }

    final usedLeaves = await _getApprovedLeaves(employeeId);

    Map<String, dynamic> balanceData = {};
    double totalAllocated = 0;
    double totalUsed = 0;
    double totalRemaining = 0;

    Map<int, double> allocationByType = {};
    Map<int, String> typeNames = {};
    Map<int, String> typeColors = {};

    for (var alloc in allocations) {
      int typeId = alloc['leave_type_id'];
      double days = (alloc['allocated_days'] ?? 0).toDouble();

      allocationByType[typeId] = (allocationByType[typeId] ?? 0) + days;

      if (alloc['leave_type_name'] != null) {
        typeNames[typeId] = alloc['leave_type_name'];
      }
      if (alloc['color'] != null) {
        typeColors[typeId] = alloc['color'];
      }
    }

    for (var entry in allocationByType.entries) {
      int typeId = entry.key;
      double allocatedDays = entry.value;
      String typeName = typeNames[typeId] ?? 'إجازة #$typeId';
      String color = typeColors[typeId] ?? '#2196F3';

      double usedDays = usedLeaves
          .where((leave) => leave['leave_type_id'] == typeId)
          .fold(0.0, (sum, leave) => sum + (leave['number_of_days'] ?? 0).toDouble());

      double remainingDays = (allocatedDays - usedDays).clamp(0.0, allocatedDays);

      balanceData[typeName] = {
        'type_id': typeId,
        'type_name': typeName,
        'allocated': allocatedDays,
        'used': usedDays,
        'remaining': remainingDays,
        'color': color,
      };

      totalAllocated += allocatedDays;
      totalUsed += usedDays;
      totalRemaining += remainingDays;
    }

    double usagePercentage = totalAllocated > 0
        ? (totalUsed / totalAllocated * 100)
        : 0;

    return {
      'employee_id': employeeId,
      'total_allocated': totalAllocated,
      'total_used': totalUsed,
      'total_remaining': totalRemaining,
      'usage_percentage': usagePercentage,
      'leave_types': balanceData,
    };
  }

  Future<List<Map<String, dynamic>>> _getEmployeeAllocations(int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave.allocation',
            'method': 'search_read',
            'args': [
              [
                ['employee_id', '=', employeeId],
                ['state', '=', 'validate'],
              ],
              ['holiday_status_id', 'number_of_days']
            ],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] is List) {
        List<Map<String, dynamic>> allocations = [];

        for (var allocation in result['result']) {
          var holidayStatus = allocation['holiday_status_id'];
          int typeId;
          String typeName = '';

          if (holidayStatus is List && holidayStatus.length >= 2) {
            typeId = holidayStatus[0];
            typeName = holidayStatus[1];
          } else {
            typeId = holidayStatus;
          }

          allocations.add({
            'leave_type_id': typeId,
            'leave_type_name': typeName,
            'allocated_days': allocation['number_of_days'],
            'color': '#2196F3',
          });
        }

        return allocations;
      }

      return [];
    } catch (e) {
      print('❌ خطأ في جلب تخصيصات الإجازات: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getApprovedLeaves(int employeeId) async {
    try {
      final currentYear = DateTime.now().year;
      final url = '${baseUrl}web/dataset/call_kw';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave',
            'method': 'search_read',
            'args': [
              [
                ['employee_id', '=', employeeId],
                ['state', '=', 'validate'],
                ['date_from', '>=', '$currentYear-01-01'],
                ['date_to', '<=', '$currentYear-12-31'],
              ],
              ['holiday_status_id', 'number_of_days']
            ],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] is List) {
        return List<Map<String, dynamic>>.from(
            result['result'].map((leave) {
              var holidayStatus = leave['holiday_status_id'];
              int typeId = holidayStatus is List ? holidayStatus[0] : holidayStatus;

              return {
                'leave_type_id': typeId,
                'number_of_days': leave['number_of_days'],
              };
            })
        );
      }

      return [];
    } catch (e) {
      print('❌ خطأ في جلب الإجازات المعتمدة: $e');
      return [];
    }
  }

  Map<String, dynamic> _getEmptyLeaveBalance(int employeeId) {
    return {
      'employee_id': employeeId,
      'total_allocated': 0.0,
      'total_used': 0.0,
      'total_remaining': 0.0,
      'usage_percentage': 0.0,
      'leave_types': {},
      'message': 'لا توجد تخصيصات إجازات لهذا الموظف',
    };
  }

  Future<Map<String, dynamic>> getQuickLeaveBalance(int employeeId) async {
    try {
      final balanceData = await getEmployeeLeaveBalance(employeeId);

      return {
        'total_remaining': balanceData['total_remaining'] ?? 0.0,
        'total_used': balanceData['total_used'] ?? 0.0,
        'total_allocated': balanceData['total_allocated'] ?? 0.0,
        'usage_percentage': balanceData['usage_percentage'] ?? 0.0,
        'has_allocations': (balanceData['leave_types'] as Map?)?.isNotEmpty ?? false,
      };
    } catch (e) {
      return {
        'total_remaining': 0.0,
        'total_used': 0.0,
        'total_allocated': 0.0,
        'usage_percentage': 0.0,
        'has_allocations': false,
      };
    }
  }

  // قائمة أنواع الإجازات الافتراضية
  List<LeaveType> _getDefaultLeaveTypes() {
    return [
      LeaveType(
        id: 1,
        name: 'إجازة سنوية',
        maxDays: 30,
        color: '#4CAF50',
        requiresApproval: true,
      ),
      LeaveType(
        id: 2,
        name: 'إجازة مرضية',
        maxDays: 15,
        color: '#F44336',
        requiresApproval: true,
      ),
      LeaveType(
        id: 3,
        name: 'إجازة طارئة',
        maxDays: 5,
        color: '#FF9800',
        requiresApproval: true,
      ),
    ];
  }

  Future<List<LeaveType>> getLeaveTypes({int? employeeId}) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      if (employeeId != null) {
        final allocations = await _getEmployeeAllocations(employeeId);

        if (allocations.isEmpty) {
          return _getDefaultLeaveTypes();
        }

        Set<int> typeIds = {};
        Map<int, String> typeNames = {};

        for (var alloc in allocations) {
          int typeId = alloc['leave_type_id'];
          typeIds.add(typeId);
          if (alloc['leave_type_name'] != null) {
            typeNames[typeId] = alloc['leave_type_name'];
          }
        }

        List<LeaveType> leaveTypes = [];
        for (int typeId in typeIds) {
          leaveTypes.add(LeaveType(
            id: typeId,
            name: typeNames[typeId] ?? 'إجازة #$typeId',
            color: '#2196F3',
            maxDays: 30,
            requiresApproval: true,
          ));
        }

        return leaveTypes.isEmpty ? _getDefaultLeaveTypes() : leaveTypes;
      }

      return await _getAllLeaveTypes();
    } catch (e) {
      print('❌ خطأ في جلب أنواع الإجازات: $e');
      return _getDefaultLeaveTypes();
    }
  }

  Future<List<LeaveType>> _getAllLeaveTypes() async {
    try {
      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave.type',
            'method': 'search_read',
            'args': [
              [['active', '=', true]],
              ['id', 'name', 'color']
            ],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] is List) {
        return List<LeaveType>.from(
            result['result'].map((type) => LeaveType(
              id: type['id'],
              name: type['name'],
              color: _getColorFromInt(type['color']),
              maxDays: 30,
              requiresApproval: true,
            ))
        );
      }

      return _getDefaultLeaveTypes();
    } catch (e) {
      return _getDefaultLeaveTypes();
    }
  }

  Future<List<LeaveType>> getLeaveTypesFromRequests(List<LeaveRequest> requests) async {
    try {
      Map<int, LeaveType> typesMap = {};
      final colors = ['#4CAF50', '#F44336', '#FF9800', '#2196F3', '#9C27B0', '#00BCD4'];
      int colorIndex = 0;

      for (var request in requests) {
        if (request.leaveTypeId > 0 && !typesMap.containsKey(request.leaveTypeId)) {
          typesMap[request.leaveTypeId] = LeaveType(
            id: request.leaveTypeId,
            name: request.leaveTypeName,
            color: colors[colorIndex % colors.length],
            maxDays: 30,
            requiresApproval: true,
          );
          colorIndex++;
        }
      }

      return typesMap.isEmpty ? _getDefaultLeaveTypes() : typesMap.values.toList();
    } catch (e) {
      return _getDefaultLeaveTypes();
    }
  }

  String _getColorFromInt(dynamic color) {
    if (color == null) return '#2196F3';

    Map<int, String> colorMap = {
      0: '#FFFFFF', 1: '#F44336', 2: '#E91E63', 3: '#9C27B0',
      4: '#673AB7', 5: '#3F51B5', 6: '#2196F3', 7: '#03A9F4',
      8: '#00BCD4', 9: '#009688', 10: '#4CAF50', 11: '#8BC34A',
    };

    if (color is int) {
      return colorMap[color] ?? '#2196F3';
    }

    return '#2196F3';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال طلبات الإجازة
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave',
            'method': 'search_read',
            'args': [
              [['employee_id', '=', employeeId]],
              ['id', 'name', 'holiday_status_id', 'date_from', 'date_to', 'number_of_days', 'state']
            ],
            'kwargs': {
              'order': 'create_date desc',
              'limit': 50,
            },
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] is List) {
        List<LeaveRequest> requests = [];

        for (var item in result['result']) {
          try {
            var holidayStatus = item['holiday_status_id'];
            int leaveTypeId = holidayStatus is List ? holidayStatus[0] : (holidayStatus ?? 0);
            String leaveTypeName = holidayStatus is List && holidayStatus.length > 1
                ? holidayStatus[1]
                : 'غير محدد';

            requests.add(LeaveRequest(
              id: item['id'] ?? 0,
              employeeId: employeeId,
              leaveTypeId: leaveTypeId,
              leaveTypeName: leaveTypeName,
              dateFrom: item['date_from'] != null
                  ? DateTime.parse(item['date_from'])
                  : DateTime.now(),
              dateTo: item['date_to'] != null
                  ? DateTime.parse(item['date_to'])
                  : DateTime.now(),
              numberOfDays: (item['number_of_days'] ?? 0).toDouble(),
              reason: item['name'] ?? '',
              state: item['state'] ?? 'draft',
              stateText: _getStateText(item['state'] ?? 'draft'),
              stateIcon: _getStateIcon(item['state'] ?? 'draft'),
              stateColor: _getStateColor(item['state'] ?? 'draft'),
              createdDate: DateTime.now(),
            ));
          } catch (e) {
            print('خطأ في معالجة طلب إجازة: $e');
          }
        }

        return requests;
      }

      return [];
    } catch (e) {
      print('خطأ في getLeaveRequests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createLeaveRequest({
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? reason,
  }) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final allocations = await _getEmployeeAllocations(employeeId);
      bool hasAllocation = allocations.any((a) => a['leave_type_id'] == leaveTypeId);

      if (!hasAllocation) {
        return {
          'success': false,
          'error': 'لا يوجد رصيد مخصص لهذا النوع من الإجازات'
        };
      }

      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave',
            'method': 'create',
            'args': [{
              'employee_id': employeeId,
              'holiday_status_id': leaveTypeId,
              'date_from': dateFrom.toIso8601String(),
              'date_to': dateTo.toIso8601String(),
              'name': reason ?? '',
            }],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result') && result['result'] != null) {
        return {
          'success': true,
          'leave_id': result['result'],
          'message': 'تم إنشاء طلب الإجازة بنجاح'
        };
      } else if (result.containsKey('error')) {
        return {
          'success': false,
          'error': result['error']['data']['message'] ?? 'حدث خطأ'
        };
      }

      return {'success': false, 'error': 'خطأ غير متوقع'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelLeaveRequest(int leaveRequestId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}web/dataset/call_kw';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'hr.leave',
            'method': 'action_refuse',
            'args': [[leaveRequestId]],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (result.containsKey('result')) {
        return {'success': true, 'message': 'تم إلغاء طلب الإجازة بنجاح'};
      }

      return {'success': false, 'error': 'خطأ في إلغاء الطلب'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String _getStateText(String state) {
    switch (state) {
      case 'draft': return 'مسودة';
      case 'confirm': return 'قيد المراجعة';
      case 'validate1': return 'مراجعة أولى';
      case 'validate': return 'مقبولة';
      case 'refuse': return 'مرفوضة';
      case 'cancel': return 'ملغاة';
      default: return 'غير محدد';
    }
  }

  String _getStateIcon(String state) {
    switch (state) {
      case 'draft': return '📝';
      case 'confirm': return '⏳';
      case 'validate1': return '👁️';
      case 'validate': return '✅';
      case 'refuse': return '❌';
      case 'cancel': return '🚫';
      default: return '❓';
    }
  }

  String _getStateColor(String state) {
    switch (state) {
      case 'draft': return '#9E9E9E';
      case 'confirm': return '#FFA500';
      case 'validate1': return '#2196F3';
      case 'validate': return '#4CAF50';
      case 'refuse': return '#F44336';
      case 'cancel': return '#9E9E9E';
      default: return '#9E9E9E';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال الإعلانات
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Announcement>> getAnnouncements(int employeeId, {int limit = 20, int offset = 0}) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/announcements/list';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'limit': limit,
            'offset': offset,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null) {
          final result = jsonResponse['result'];

          if (result is Map && result['success'] == true && result['announcements'] != null) {
            final announcementsData = result['announcements'];
            if (announcementsData is List) {
              return announcementsData
                  .map((data) => Announcement.fromJson(data))
                  .toList();
            }
          }

          if (result is List) {
            return result.map((data) => Announcement.fromJson(data)).toList();
          }
        }
      }

      return [];
    } catch (e) {
      print('خطأ في جلب الإعلانات: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAnnouncementCategories() async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/announcements/categories';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {},
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null && jsonResponse['result'] is List) {
          return List<Map<String, dynamic>>.from(jsonResponse['result']);
        }
      }

      return [
        {'id': 0, 'name': 'الكل', 'icon': '📋'},
        {'id': 1, 'name': 'عام', 'icon': '📢'},
        {'id': 2, 'name': 'مهم', 'icon': '⚠️'},
      ];
    } catch (e) {
      print('خطأ في جلب فئات الإعلانات: $e');
      return [
        {'id': 0, 'name': 'الكل', 'icon': '📋'},
      ];
    }
  }

  // البحث في الإعلانات - مصححة
  Future<List<Announcement>> searchAnnouncements(
      int employeeId,
      String query, {
        String category = 'all',
      }) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/announcements/search';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'search_term': query,
            'category': category,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null) {
          // Handle both formats: direct list or {results: [...]}
          List<dynamic> resultsData;
          if (jsonResponse['result'] is List) {
            resultsData = jsonResponse['result'];
          } else if (jsonResponse['result']['results'] != null) {
            resultsData = jsonResponse['result']['results'];
          } else {
            return [];
          }

          return resultsData
              .map((data) => Announcement.fromJson(data))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('خطأ في البحث في الإعلانات: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAnnouncementDetail(int announcementId, int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/announcements/detail';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'announcement_id': announcementId,
            'employee_id': employeeId,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null) {
          return jsonResponse['result'];
        }
      }

      return null;
    } catch (e) {
      print('خطأ في جلب تفاصيل الإعلان: $e');
      return null;
    }
  }

  Future<bool> markAnnouncementAsRead(int announcementId, int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/announcements/mark_read';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'announcement_id': announcementId,
            'employee_id': employeeId,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['result']?['success'] == true;
      }

      return false;
    } catch (e) {
      print('خطأ في تعليم الإعلان كمقروء: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال كشوف الرواتب
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Payslip>> getPayslips(int employeeId, {int? year}) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/payslips/list';
      print('📋 جلب كشوف المرتبات للموظف: $employeeId');
      print('📋 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
            'year': year,
            'limit': 20,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📋 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('📋 Response: $jsonResponse');

        if (jsonResponse['result'] != null &&
            jsonResponse['result']['success'] == true &&
            jsonResponse['result']['payslips'] != null) {
          final payslipsList = jsonResponse['result']['payslips'] as List;
          print('📋 عدد الكشوف: ${payslipsList.length}');

          List<Payslip> payslips = [];
          for (var data in payslipsList) {
            try {
              payslips.add(Payslip.fromJson(data));
            } catch (e) {
              print('❌ خطأ في تحويل كشف: $e');
              print('❌ البيانات: $data');
            }
          }
          return payslips;
        } else if (jsonResponse['result'] != null && jsonResponse['result']['error'] != null) {
          print('❌ API Error: ${jsonResponse['result']['error']}');
        }
      }

      return [];
    } catch (e) {
      print('❌ خطأ في جلب كشوف الرواتب: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPayslipsSummary(int employeeId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/payslips/summary';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'employee_id': employeeId,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null && jsonResponse['result']['success'] == true) {
          return jsonResponse['result']['summary'] ?? {};
        }
      }

      return {
        'total_net': 0.0,
        'average_net': 0.0,
        'last_payment': null,
        'total_count': 0,
        'paid_count': 0,
      };
    } catch (e) {
      print('خطأ في جلب ملخص الرواتب: $e');
      return {
        'total_net': 0.0,
        'average_net': 0.0,
        'last_payment': null,
        'total_count': 0,
        'paid_count': 0,
      };
    }
  }

  // تفاصيل كشف الراتب - مصححة لإرجاع Payslip?
  Future<Payslip?> getPayslipDetails(int payslipId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/payslips/detail';
      print('📋 جلب تفاصيل كشف المرتب: $payslipId');
      print('📋 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'payslip_id': payslipId,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📋 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('📋 Response: $jsonResponse');

        if (jsonResponse['result'] != null && jsonResponse['result']['success'] == true) {
          final payslipData = jsonResponse['result']['payslip'];
          if (payslipData != null) {
            print('📋 Payslip data: $payslipData');
            return Payslip.fromJson(payslipData);
          }
        } else if (jsonResponse['result'] != null && jsonResponse['result']['error'] != null) {
          print('❌ API Error: ${jsonResponse['result']['error']}');
        }
      }

      return null;
    } catch (e) {
      print('❌ خطأ في جلب تفاصيل كشف الراتب: $e');
      return null;
    }
  }

  Future<Uint8List?> downloadPayslipPdf(int payslipId) async {
    try {
      if (sessionId == null) {
        bool success = await loginWithService();
        if (!success) throw Exception('فشل تسجيل الدخول');
      }

      final url = '${baseUrl}api/mobile/payslips/download';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'payslip_id': payslipId,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['result'] != null &&
            jsonResponse['result']['success'] == true &&
            jsonResponse['result']['pdf_data'] != null) {
          return base64Decode(jsonResponse['result']['pdf_data']);
        }
      }

      return null;
    } catch (e) {
      print('خطأ في تحميل ملف PDF: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال تسجيل الخروج
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> logout() async {
    try {
      if (sessionId != null) {
        final url = '${baseUrl}web/session/destroy';
        await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'session_id=$sessionId',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'params': {},
          }),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('خطأ في logout: $e');
    } finally {
      sessionId = null;
      uid = null;
      employeeId = null;
      currentEmployee = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_id');
      await prefs.remove('uid');
      await prefs.remove('employee_id');
    }
  }
}