// lib/services/odoo_service_factory.dart
// Factory لإنشاء OdooService من الإعدادات المحفوظة

import 'odoo_service.dart';
import 'config_service.dart';

class OdooServiceFactory {
  static final OdooServiceFactory _instance = OdooServiceFactory._internal();
  factory OdooServiceFactory() => _instance;
  OdooServiceFactory._internal();

  final ConfigService _configService = ConfigService();
  OdooService? _cachedService;

  /// الحصول على OdooService من الإعدادات المحفوظة
  Future<OdooService?> getService() async {
    // إذا كان هناك service محفوظ، ارجعه
    if (_cachedService != null) {
      return _cachedService;
    }

    // تحميل الإعدادات
    final isConfigured = await _configService.isConfigured();

    if (!isConfigured) {
      print('❌ OdooServiceFactory: لا توجد إعدادات محفوظة');
      return null;
    }

    // إنشاء OdooService من الإعدادات
    final serverUrl = _configService.serverUrl;
    final database = _configService.database;

    if (serverUrl == null || database == null) {
      print('❌ OdooServiceFactory: الإعدادات غير مكتملة');
      return null;
    }

    print('✅ OdooServiceFactory: إنشاء OdooService');
    print('   Server: $serverUrl');
    print('   Database: $database');

    _cachedService = OdooService(
      url: serverUrl,
      database: database,
    );

    return _cachedService;
  }

  /// إنشاء OdooService جديد بإعدادات محددة
  OdooService createService({
    required String serverUrl,
    required String database,
  }) {
    _cachedService = OdooService(
      url: serverUrl,
      database: database,
    );
    return _cachedService!;
  }

  /// مسح الـ service المحفوظ
  void clearService() {
    _cachedService = null;
  }

  /// التحقق من وجود إعدادات
  Future<bool> hasConfig() async {
    return await _configService.isConfigured();
  }

  /// الحصول على معلومات الإعدادات الحالية
  Map<String, String?> getConfigInfo() {
    return {
      'serverUrl': _configService.serverUrl,
      'database': _configService.database,
      'companyName': _configService.companyName,
    };
  }
}