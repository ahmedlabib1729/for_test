// lib/services/config_service.dart
// خدمة إدارة إعدادات الاتصال - تقرأ من Connection String أو QR Code

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      print('❌ خطأ في التحقق من الإعدادات: $e');
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

      print('═══════════════════════════════════════');
      print('✅ تم تحميل الإعدادات:');
      print('   Server URL: $_serverUrl');
      print('   Database: $_database');
      print('   Company: $_companyName');
      print('═══════════════════════════════════════');

      return _serverUrl != null && _database != null;
    } catch (e) {
      print('❌ خطأ في تحميل الإعدادات: $e');
      return false;
    }
  }

  /// حفظ الإعدادات
  Future<bool> saveConfig({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
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

      // تحديث القيم في الذاكرة
      _serverUrl = serverUrl;
      _database = database;
      _token = token;
      _companyName = companyName;

      print('═══════════════════════════════════════');
      print('✅ تم حفظ الإعدادات:');
      print('   Server URL: $serverUrl');
      print('   Database: $database');
      print('   Company: $companyName');
      print('═══════════════════════════════════════');

      return true;
    } catch (e) {
      print('❌ خطأ في حفظ الإعدادات: $e');
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

      print('✅ تم مسح الإعدادات');
      return true;
    } catch (e) {
      print('❌ خطأ في مسح الإعدادات: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// تحليل Connection String أو QR Code
  /// ═══════════════════════════════════════════════════════════════

  /// تحليل الكود المدخل (Connection String أو QR Code)
  Future<ParseResult> parseConnectionCode(String code) async {
    code = code.trim();

    print('═══════════════════════════════════════');
    print('🔍 تحليل الكود:');
    print('   Input: $code');
    print('═══════════════════════════════════════');

    // ═══════════════════════════════════════════════════════════════
    // الصيغة 1: Connection String (url|token|db)
    // مثال: http://192.168.70.221:8018|ABC123TOKEN|Mbile
    // ═══════════════════════════════════════════════════════════════
    if (code.contains('|')) {
      return _parseConnectionString(code);
    }

    // ═══════════════════════════════════════════════════════════════
    // الصيغة 2: JSON (من QR Code)
    // مثال: {"url":"http://...","db":"Mbile","token":"...","name":"..."}
    // ═══════════════════════════════════════════════════════════════
    if (code.startsWith('{') && code.endsWith('}')) {
      return _parseJsonCode(code);
    }

    // ═══════════════════════════════════════════════════════════════
    // الصيغة 3: Base64 Encoded
    // ═══════════════════════════════════════════════════════════════
    if (_isBase64(code)) {
      try {
        final decoded = utf8.decode(base64Decode(code));
        print('   Decoded Base64: $decoded');
        return parseConnectionCode(decoded); // Recursive call
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

  /// تحليل Connection String بصيغة: url|token|db
  ParseResult _parseConnectionString(String code) {
    try {
      // تقسيم بـ | فقط
      final parts = code.split('|');

      print('   Split by |: ${parts.length} parts');
      for (int i = 0; i < parts.length; i++) {
        print('   Part[$i]: ${parts[i]}');
      }

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

      // التحقق من القيم
      if (serverUrl.isEmpty) {
        return ParseResult.failure('رابط السيرفر فارغ');
      }
      if (database.isEmpty) {
        return ParseResult.failure('اسم قاعدة البيانات فارغ');
      }

      print('   ✅ Parsed successfully:');
      print('      Server: $serverUrl');
      print('      Token: ${token.length > 8 ? token.substring(0, 8) + "..." : token}');
      print('      Database: $database');

      return ParseResult.success(
        serverUrl: serverUrl,
        database: database,
        token: token,
      );
    } catch (e) {
      print('   ❌ Error parsing: $e');
      return ParseResult.failure('خطأ في تحليل Connection String: $e');
    }
  }

  /// تحليل JSON من QR Code
  ParseResult _parseJsonCode(String code) {
    try {
      final Map<String, dynamic> data = jsonDecode(code);

      print('   JSON data: $data');

      // استخراج القيم - دعم أسماء مختلفة للحقول
      final serverUrl = _normalizeUrl(
          data['url'] ?? data['server_url'] ?? data['serverUrl'] ?? ''
      );
      final database = (data['db'] ?? data['database'] ?? '').toString().trim();
      final token = (data['token'] ?? '').toString().trim();
      final companyName = (data['name'] ?? data['company_name'] ?? '').toString().trim();

      if (serverUrl.isEmpty) {
        return ParseResult.failure('رابط السيرفر غير موجود في الـ QR Code');
      }
      if (database.isEmpty) {
        return ParseResult.failure('اسم قاعدة البيانات غير موجود في الـ QR Code');
      }

      print('   ✅ Parsed JSON successfully:');
      print('      Server: $serverUrl');
      print('      Database: $database');
      print('      Company: $companyName');

      return ParseResult.success(
        serverUrl: serverUrl,
        database: database,
        token: token,
        companyName: companyName,
      );
    } catch (e) {
      print('   ❌ Error parsing JSON: $e');
      return ParseResult.failure('صيغة JSON غير صالحة: $e');
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

    print('🔍 التحقق من الاتصال بـ: $serverUrl');

    try {
      // محاولة 1: اختبار /api/mobile/version
      final apiUrl = '$serverUrl/api/mobile/version';
      print('   Testing: $apiUrl');

      try {
        final response = await http.get(
          Uri.parse(apiUrl),
        ).timeout(const Duration(seconds: 10));

        print('   Response: ${response.statusCode}');

        if (response.statusCode == 200) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
          );
        }
      } catch (e) {
        print('   API test failed: $e');
      }

      // محاولة 2: اختبار /web/webclient/version_info
      final webUrl = '$serverUrl/web/webclient/version_info';
      print('   Testing fallback: $webUrl');

      try {
        final response = await http.get(
          Uri.parse(webUrl),
        ).timeout(const Duration(seconds: 10));

        print('   Response: ${response.statusCode}');

        if (response.statusCode == 200) {
          return VerifyResult.success(
            serverUrl: serverUrl,
            database: database,
            token: parseResult.token,
            companyName: parseResult.companyName,
            warning: 'تم الاتصال بالسيرفر. تأكد من صحة اسم قاعدة البيانات.',
          );
        }
      } catch (e) {
        print('   Fallback test failed: $e');
      }

      // محاولة 3: اختبار الصفحة الرئيسية
      print('   Testing main page: $serverUrl');

      final mainResponse = await http.get(
        Uri.parse(serverUrl),
      ).timeout(const Duration(seconds: 10));

      if (mainResponse.statusCode == 200 || mainResponse.statusCode == 303) {
        return VerifyResult.success(
          serverUrl: serverUrl,
          database: database,
          token: parseResult.token,
          companyName: parseResult.companyName,
          warning: 'تم الاتصال بالسيرفر.',
        );
      }

      return VerifyResult.failure(
          'لا يمكن الاتصال بالسيرفر.\n'
              'تأكد من:\n'
              '• الرابط صحيح: $serverUrl\n'
              '• السيرفر يعمل\n'
              '• الشبكة متصلة'
      );
    } catch (e) {
      print('   ❌ Connection error: $e');
      return VerifyResult.failure('فشل الاتصال بالسيرفر: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Helper Methods
  /// ═══════════════════════════════════════════════════════════════

  /// تطبيع URL
  String _normalizeUrl(String url) {
    url = url.trim();

    // إضافة http:// إذا لم يكن موجوداً
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
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
  final String? errorMessage;

  ParseResult._({
    required this.isSuccess,
    this.serverUrl,
    this.database,
    this.token,
    this.companyName,
    this.errorMessage,
  });

  factory ParseResult.success({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
  }) {
    return ParseResult._(
      isSuccess: true,
      serverUrl: serverUrl,
      database: database,
      token: token,
      companyName: companyName,
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
  final String? errorMessage;
  final String? warning;

  VerifyResult._({
    required this.isSuccess,
    this.serverUrl,
    this.database,
    this.token,
    this.companyName,
    this.errorMessage,
    this.warning,
  });

  factory VerifyResult.success({
    required String serverUrl,
    required String database,
    String? token,
    String? companyName,
    String? warning,
  }) {
    return VerifyResult._(
      isSuccess: true,
      serverUrl: serverUrl,
      database: database,
      token: token,
      companyName: companyName,
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