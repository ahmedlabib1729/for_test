// lib/services/config_service.dart
// خدمة إدارة إعدادات الاتصال - تقرأ من Connection String أو QR Code

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const String _serverUrlKey = 'server_url';
  static const String _databaseKey = 'database';
  static const String _tokenKey = 'company_token';
  static const String _companyNameKey = 'company_name';
  static const String _isConfiguredKey = 'is_configured';

  // البيانات المحفوظة في الذاكرة
  String? _serverUrl;
  String? _database;
  String? _token;
  String? _companyName;

  // Getters
  String? get serverUrl => _serverUrl;
  String? get database => _database;
  String? get token => _token;
  String? get companyName => _companyName;

  /// التحقق من وجود إعدادات محفوظة
  Future<bool> isConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConfigured = prefs.getBool(_isConfiguredKey) ?? false;

      if (isConfigured) {
        await loadConfig();
        return _serverUrl != null &&
            _serverUrl!.isNotEmpty &&
            _database != null &&
            _database!.isNotEmpty;
      }

      return false;
    } catch (e) {

      return false;
    }
  }

  /// تحميل الإعدادات المحفوظة
  Future<bool> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _serverUrl = prefs.getString(_serverUrlKey);
      _database = prefs.getString(_databaseKey);
      _token = prefs.getString(_tokenKey);
      _companyName = prefs.getString(_companyNameKey);


      return _serverUrl != null && _database != null;
    } catch (e) {

      return false;
    }
  }

  /// حفظ الإعدادات
  Future<bool> saveConfig({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
    String? serviceUsername,
    String? servicePassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تطبيع الـ URL
      serverUrl = _normalizeUrl(serverUrl);

      await prefs.setString(_serverUrlKey, serverUrl);
      await prefs.setString(_databaseKey, database);
      await prefs.setBool(_isConfiguredKey, true);

      if (token != null) {
        await prefs.setString(_tokenKey, token);
      }
      if (companyName != null) {
        await prefs.setString(_companyNameKey, companyName);
      }

      // Save service credentials to secure storage
      if (serviceUsername != null && servicePassword != null &&
          serviceUsername.isNotEmpty && servicePassword.isNotEmpty) {
        final secureStorage = SecureStorageService();
        await secureStorage.saveServiceCredentials(
          username: serviceUsername,
          password: servicePassword,
        );
      }

      // تحديث القيم في الذاكرة
      _serverUrl = serverUrl;
      _database = database;
      _token = token;
      _companyName = companyName;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// مسح الإعدادات
  Future<bool> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_serverUrlKey);
      await prefs.remove(_databaseKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_companyNameKey);
      await prefs.setBool(_isConfiguredKey, false);

      _serverUrl = null;
      _database = null;
      _token = null;
      _companyName = null;


      return true;
    } catch (e) {

      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// تحليل Connection String أو QR Code
  /// ═══════════════════════════════════════════════════════════════

  /// تحليل الكود المدخل (Connection String أو QR Code)
  Future<ParseResult> parseConnectionCode(String code, {int depth = 0}) async {
    code = code.trim();

    // الصيغة 1: Connection String (url|token|db)
    if (code.contains('|')) {
      return _parseConnectionString(code);
    }

    // الصيغة 2: JSON (من QR Code)
    if (code.startsWith('{') && code.endsWith('}')) {
      return _parseJsonCode(code);
    }

    // الصيغة 3: Base64 Encoded (with recursion depth limit)
    if (depth < 2 && _isBase64(code)) {
      try {
        final decoded = utf8.decode(base64Decode(code));
        return parseConnectionCode(decoded, depth: depth + 1);
      } catch (e) {
        return ParseResult.failure('صيغة Base64 غير صالحة');
      }
    }

    return ParseResult.failure(
        'صيغة الكود غير صالحة.\n\n'
            'الصيغ المدعومة:\n'
            '• Connection String: url|token|database\n'
            '• QR Code JSON: {"url":"...","db":"...","token":"..."}'
    );
  }

  /// تحليل Connection String بصيغة: url|token|db أو url|token|db|service_user|service_pass
  ParseResult _parseConnectionString(String code) {
    try {
      final parts = code.split('|');

      if (parts.length < 3) {
        return ParseResult.failure(
            'Connection String غير مكتمل.\n'
                'الصيغة المطلوبة: url|token|database\n'
                'مثال: http://192.168.70.221:8018|TOKEN|Mbile'
        );
      }

      final serverUrl = _normalizeUrl(parts[0]);
      final token = parts[1].trim();
      final database = parts[2].trim();

      // Parse optional service credentials (5-part format)
      String? serviceUsername;
      String? servicePassword;
      if (parts.length >= 5) {
        serviceUsername = parts[3].trim();
        servicePassword = parts[4].trim();
      }

      if (serverUrl.isEmpty) {
        return ParseResult.failure('رابط السيرفر فارغ');
      }
      if (database.isEmpty) {
        return ParseResult.failure('اسم قاعدة البيانات فارغ');
      }

      return ParseResult.success(
        serverUrl: serverUrl,
        database: database,
        token: token,
        serviceUsername: serviceUsername,
        servicePassword: servicePassword,
      );
    } catch (e) {
      return ParseResult.failure('خطأ في تحليل Connection String');
    }
  }

  /// تحليل JSON من QR Code
  ParseResult _parseJsonCode(String code) {
    try {
      final Map<String, dynamic> data = jsonDecode(code);

      // استخراج القيم - دعم أسماء مختلفة للحقول
      final serverUrl = _normalizeUrl(
          data['url'] ?? data['server_url'] ?? data['serverUrl'] ?? ''
      );
      final database = (data['db'] ?? data['database'] ?? '').toString().trim();
      final token = (data['token'] ?? '').toString().trim();
      final companyName = (data['name'] ?? data['company_name'] ?? '').toString().trim();

      // Extract optional service credentials
      final serviceUsername = (data['service_username'] ?? data['service_user'] ?? '').toString().trim();
      final servicePassword = (data['service_password'] ?? data['service_pass'] ?? '').toString().trim();

      if (serverUrl.isEmpty) {
        return ParseResult.failure('رابط السيرفر غير موجود في الـ QR Code');
      }
      if (database.isEmpty) {
        return ParseResult.failure('اسم قاعدة البيانات غير موجود في الـ QR Code');
      }

      return ParseResult.success(
        serverUrl: serverUrl,
        database: database,
        token: token,
        companyName: companyName,
        serviceUsername: serviceUsername.isNotEmpty ? serviceUsername : null,
        servicePassword: servicePassword.isNotEmpty ? servicePassword : null,
      );
    } catch (e) {
      return ParseResult.failure('صيغة JSON غير صالحة');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// التحقق من الاتصال بالسيرفر
  /// ═══════════════════════════════════════════════════════════════

  Future<VerifyResult> verifyConnection(ParseResult parseResult) async {
    if (!parseResult.isSuccess) {
      return VerifyResult.failure(parseResult.errorMessage ?? 'خطأ غير معروف');
    }

    final serverUrl = parseResult.serverUrl!;
    final database = parseResult.database!;

    debugPrint('[ConfigService] verifyConnection: serverUrl=$serverUrl, db=$database');

    try {
      // محاولة 1: اختبار /api/mobile/version
      final apiUrl = '$serverUrl/api/mobile/version';
      debugPrint('[ConfigService] Trying: $apiUrl');

      try {
        final response = await http.get(
          Uri.parse(apiUrl),
        ).timeout(const Duration(seconds: 10));

        debugPrint('[ConfigService] /api/mobile/version -> ${response.statusCode}');

        if (response.statusCode == 200) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
            serviceUsername: parseResult.serviceUsername,
            servicePassword: parseResult.servicePassword,
          );
        }
      } catch (e) {
        debugPrint('[ConfigService] /api/mobile/version failed: $e');
      }

      // محاولة 2: اختبار /api/mobile/config_info (module endpoint with company info)
      final configUrl = '$serverUrl/api/mobile/config_info';
      debugPrint('[ConfigService] Trying: $configUrl');

      try {
        final response = await http.get(
          Uri.parse(configUrl),
        ).timeout(const Duration(seconds: 10));

        debugPrint('[ConfigService] /api/mobile/config_info -> ${response.statusCode}');

        if (response.statusCode == 200) {
          // Try to extract company name and database from response
          String? companyName = parseResult.companyName;
          try {
            final body = jsonDecode(response.body);
            final result = body['result'] ?? body;
            if (result['company_name'] != null && result['company_name'].toString().isNotEmpty) {
              companyName = result['company_name'];
            }
          } catch (_) {}

          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: companyName,
            serviceUsername: parseResult.serviceUsername,
            servicePassword: parseResult.servicePassword,
          );
        }
      } catch (e) {
        debugPrint('[ConfigService] /api/mobile/config_info failed: $e');
      }

      // محاولة 3: اختبار /web/webclient/version_info (standard Odoo endpoint)
      final webUrl = '$serverUrl/web/webclient/version_info';
      debugPrint('[ConfigService] Trying: $webUrl');

      try {
        final response = await http.post(
          Uri.parse(webUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"jsonrpc": "2.0", "method": "call", "params": {}}),
        ).timeout(const Duration(seconds: 10));

        debugPrint('[ConfigService] /web/webclient/version_info -> ${response.statusCode}');

        if (response.statusCode == 200) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
            serviceUsername: parseResult.serviceUsername,
            servicePassword: parseResult.servicePassword,
          );
        }
      } catch (e) {
        debugPrint('[ConfigService] /web/webclient/version_info failed: $e');
      }

      // محاولة 3: اختبار /web/login (standard Odoo login page)
      final loginUrl = '$serverUrl/web/login';
      debugPrint('[ConfigService] Trying: $loginUrl');

      try {
        final response = await http.get(
          Uri.parse(loginUrl),
        ).timeout(const Duration(seconds: 10));

        debugPrint('[ConfigService] /web/login -> ${response.statusCode}');

        // Any response (200, 303, 302) means server is reachable
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
            serviceUsername: parseResult.serviceUsername,
            servicePassword: parseResult.servicePassword,
          );
        }
      } catch (e) {
        debugPrint('[ConfigService] /web/login failed: $e');
      }

      // محاولة 4: اختبار الصفحة الرئيسية
      debugPrint('[ConfigService] Trying root: $serverUrl');

      try {
        final mainResponse = await http.get(
          Uri.parse(serverUrl),
        ).timeout(const Duration(seconds: 10));

        debugPrint('[ConfigService] root -> ${mainResponse.statusCode}');

        // Accept any response as proof the server exists
        if (mainResponse.statusCode >= 200 && mainResponse.statusCode < 500) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
            serviceUsername: parseResult.serviceUsername,
            servicePassword: parseResult.servicePassword,
          );
        }
      } catch (e) {
        debugPrint('[ConfigService] root failed: $e');
      }

      debugPrint('[ConfigService] All verification attempts failed');
      return VerifyResult.failure(
          'لا يمكن الاتصال بالسيرفر.\n'
              'تأكد من:\n'
              '• الرابط صحيح: $serverUrl\n'
              '• السيرفر يعمل\n'
              '• الشبكة متصلة'
      );
    } catch (e) {
      debugPrint('[ConfigService] verifyConnection exception: $e');
      return VerifyResult.failure('فشل الاتصال بالسيرفر: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Helper Methods
  /// ═══════════════════════════════════════════════════════════════

  /// تطبيع URL
  String _normalizeUrl(String url) {
    url = url.trim();

    // Default to https:// for security
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // إزالة / من النهاية
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  /// التحقق من Base64
  bool _isBase64(String str) {
    if (str.length < 20) return false;
    if (str.length % 4 != 0) return false;

    final regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return regex.hasMatch(str);
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Result Classes
/// ═══════════════════════════════════════════════════════════════

class ParseResult {
  final bool isSuccess;
  final String? serverUrl;
  final String? database;
  final String? token;
  final String? companyName;
  final String? serviceUsername;
  final String? servicePassword;
  final String? errorMessage;

  ParseResult._({
    required this.isSuccess,
    this.serverUrl,
    this.database,
    this.token,
    this.companyName,
    this.serviceUsername,
    this.servicePassword,
    this.errorMessage,
  });

  factory ParseResult.success({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
    String? serviceUsername,
    String? servicePassword,
  }) {
    return ParseResult._(
      isSuccess: true,
      serverUrl: serverUrl,
      database: database,
      token: token,
      companyName: companyName,
      serviceUsername: serviceUsername,
      servicePassword: servicePassword,
    );
  }

  factory ParseResult.failure(String message) {
    return ParseResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

class VerifyResult {
  final bool isSuccess;
  final String? serverUrl;
  final String? database;
  final String? token;
  final String? companyName;
  final String? serviceUsername;
  final String? servicePassword;
  final String? errorMessage;
  final String? warning;

  VerifyResult._({
    required this.isSuccess,
    this.serverUrl,
    this.database,
    this.token,
    this.companyName,
    this.serviceUsername,
    this.servicePassword,
    this.errorMessage,
    this.warning,
  });

  factory VerifyResult.success({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
    String? serviceUsername,
    String? servicePassword,
    String? warning,
  }) {
    return VerifyResult._(
      isSuccess: true,
      serverUrl: serverUrl,
      database: database,
      token: token,
      companyName: companyName,
      serviceUsername: serviceUsername,
      servicePassword: servicePassword,
      warning: warning,
    );
  }

  factory VerifyResult.failure(String message) {
    return VerifyResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}