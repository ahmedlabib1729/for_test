// lib/models/company_config.dart
// موديل إعدادات الشركة للاتصال بسيرفر Odoo

import 'dart:convert';

class CompanyConfig {
  final String companyCode;
  final String companyName;
  final String serverUrl;
  final String database;
  final String token;
  final String? logoUrl;
  final String? logoBase64;
  final bool isActive;
  final DateTime? configuredAt;
  final DateTime? tokenExpiry;

  CompanyConfig({
    required this.companyCode,
    required this.companyName,
    required this.serverUrl,
    required this.database,
    required this.token,
    this.logoUrl,
    this.logoBase64,
    this.isActive = true,
    this.configuredAt,
    this.tokenExpiry,
  });

  // التحقق من أن الإعدادات مكتملة
  bool get isValid {
    return companyCode.isNotEmpty &&
        serverUrl.isNotEmpty &&
        database.isNotEmpty &&
        token.isNotEmpty;
  }

  // التحقق من أن الـ Token لم ينتهِ
  bool get isTokenValid {
    if (tokenExpiry == null) return true;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  // التحقق من أن الإعدادات صالحة للاستخدام
  bool get isUsable => isValid && isActive && isTokenValid;

  // نسخ مع تحديث بعض القيم
  CompanyConfig copyWith({
    String? companyCode,
    String? companyName,
    String? serverUrl,
    String? database,
    String? token,
    String? logoUrl,
    String? logoBase64,
    bool? isActive,
    DateTime? configuredAt,
    DateTime? tokenExpiry,
  }) {
    return CompanyConfig(
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      token: token ?? this.token,
      logoUrl: logoUrl ?? this.logoUrl,
      logoBase64: logoBase64 ?? this.logoBase64,
      isActive: isActive ?? this.isActive,
      configuredAt: configuredAt ?? this.configuredAt,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }

  // تحويل إلى JSON للحفظ
  Map<String, dynamic> toJson() {
    return {
      'company_code': companyCode,
      'company_name': companyName,
      'server_url': serverUrl,
      'database': database,
      'token': token,
      'logo_url': logoUrl,
      'logo_base64': logoBase64,
      'is_active': isActive,
      'configured_at': configuredAt?.toIso8601String(),
      'token_expiry': tokenExpiry?.toIso8601String(),
    };
  }

  // إنشاء من JSON
  factory CompanyConfig.fromJson(Map<String, dynamic> json) {
    return CompanyConfig(
      companyCode: json['company_code'] ?? '',
      companyName: json['company_name'] ?? '',
      serverUrl: json['server_url'] ?? '',
      database: json['database'] ?? '',
      token: json['token'] ?? '',
      logoUrl: json['logo_url'],
      logoBase64: json['logo_base64'],
      isActive: json['is_active'] ?? true,
      configuredAt: json['configured_at'] != null
          ? DateTime.parse(json['configured_at'])
          : null,
      tokenExpiry: json['token_expiry'] != null
          ? DateTime.parse(json['token_expiry'])
          : null,
    );
  }

  // إنشاء من بيانات QR Code
  factory CompanyConfig.fromQRData(String qrData) {
    try {
      // محاولة تحليل الـ QR كـ JSON
      // الصيغة المتوقعة: {"url":"...","token":"...","db":"..."}

      // أو الصيغة البسيطة: url|token|database
      if (qrData.contains('|')) {
        final parts = qrData.split('|');
        if (parts.length >= 3) {
          return CompanyConfig(
            companyCode: '', // سيتم ملؤه من السيرفر
            companyName: '', // سيتم ملؤه من السيرفر
            serverUrl: _normalizeUrl(parts[0]),
            token: parts[1],
            database: parts[2],
            configuredAt: DateTime.now(),
          );
        }
      }

      // محاولة تحليل كـ JSON
      final Map<String, dynamic> data = _parseJson(qrData);
      return CompanyConfig(
        companyCode: data['code'] ?? '',
        companyName: data['name'] ?? '',
        serverUrl: _normalizeUrl(data['url'] ?? ''),
        token: data['token'] ?? '',
        database: data['db'] ?? data['database'] ?? '',
        configuredAt: DateTime.now(),
      );
    } catch (e) {
      throw FormatException('صيغة QR Code غير صالحة: $e');
    }
  }

  // تحليل JSON مع معالجة Base64
  static Map<String, dynamic> _parseJson(String data) {
    // محاولة فك Base64 أولاً
    try {
      final decoded = String.fromCharCodes(base64Decode(data));
      return Map<String, dynamic>.from(_jsonDecode(decoded));
    } catch (_) {
      // إذا فشل، نحاول تحليله مباشرة
      return Map<String, dynamic>.from(_jsonDecode(data));
    }
  }

  // دالة مساعدة لتحليل JSON
  static dynamic _jsonDecode(String source) {
    return jsonDecode(source);
  }

  // تطبيع رابط السيرفر
  static String _normalizeUrl(String url) {
    url = url.trim();

    // إضافة https إذا لم يكن موجوداً
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // إزالة / من النهاية
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  @override
  String toString() {
    return 'CompanyConfig(company: $companyName, server: $serverUrl, db: $database)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompanyConfig &&
        other.companyCode == companyCode &&
        other.serverUrl == serverUrl &&
        other.database == database;
  }

  @override
  int get hashCode {
    return companyCode.hashCode ^ serverUrl.hashCode ^ database.hashCode;
  }
}