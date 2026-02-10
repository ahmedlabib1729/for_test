// lib/services/secure_storage_service.dart
// خدمة التخزين الآمن للبيانات الحساسة

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // مفاتيح التخزين
  static const String _sessionIdKey = 'session_id';
  static const String _uidKey = 'uid';
  static const String _employeeIdKey = 'employee_id';
  static const String _serviceUsernameKey = 'service_username';
  static const String _servicePasswordKey = 'service_password';

  // ═══════════════════════════════════════════════════════════════
  // Session Management
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveSession({
    required String sessionId,
    required int uid,
  }) async {
    await _storage.write(key: _sessionIdKey, value: sessionId);
    await _storage.write(key: _uidKey, value: uid.toString());
  }

  Future<String?> getSessionId() async {
    return await _storage.read(key: _sessionIdKey);
  }

  Future<int?> getUid() async {
    final val = await _storage.read(key: _uidKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveEmployeeId(int employeeId) async {
    await _storage.write(key: _employeeIdKey, value: employeeId.toString());
  }

  Future<int?> getEmployeeId() async {
    final val = await _storage.read(key: _employeeIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Service Credentials
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveServiceCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _serviceUsernameKey, value: username);
    await _storage.write(key: _servicePasswordKey, value: password);
  }

  Future<String?> getServiceUsername() async {
    return await _storage.read(key: _serviceUsernameKey);
  }

  Future<String?> getServicePassword() async {
    return await _storage.read(key: _servicePasswordKey);
  }

  // ═══════════════════════════════════════════════════════════════
  // Clear All
  // ═══════════════════════════════════════════════════════════════

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionIdKey);
    await _storage.delete(key: _uidKey);
    await _storage.delete(key: _employeeIdKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
