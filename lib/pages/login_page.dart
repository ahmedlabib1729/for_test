// lib/pages/login_page.dart
// صفحة تسجيل الدخول - تصميم جديد مع الحفاظ على الأساسيات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'home_page.dart';
import 'setup_screen.dart';
import '../services/odoo_service.dart';
import '../services/config_service.dart';
import '../services/language_manager.dart';
import '../services/secure_storage_service.dart';
import '../widgets/language_switcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ConfigService _configService = ConfigService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isConfigLoading = true;

  // Odoo Service - يتم إنشاؤه بعد تحميل الإعدادات
  OdooService? _odooService;
  String? _companyName;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // ═══════════════════════════════════════════════════════════════
  // الألوان الجديدة - مستوحاة من التصميم المطلوب
  // ═══════════════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF5B9BD5);
  static const Color darkBlue = Color(0xFF2B579A);
  static const Color lightBlue = Color(0xFFE8F4FC);
  static const Color accentBlue = Color(0xFF0078D4);
  static const Color textDark = Color(0xFF1E3A5F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color bgGradientStart = Color(0xFFF0F7FF);
  static const Color bgGradientEnd = Color(0xFFE1EFFF);

  @override
  void initState() {
    super.initState();

    // Setup animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    // تحميل الإعدادات
    _loadConfig();
  }

  @override
  void dispose() {
    // Clear password from memory before disposing
    _passwordController.clear();
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// تحميل الإعدادات من ConfigService
  Future<void> _loadConfig() async {
    try {
      final isConfigured = await _configService.isConfigured();

      if (!isConfigured) {
        _navigateToSetup();
        return;
      }

      // الإعدادات موجودة - إنشاء OdooService
      final serverUrl = _configService.serverUrl!;
      final database = _configService.database!;
      _companyName = _configService.companyName;

      // Check if service credentials exist
      final secureStorage = SecureStorageService();
      final svcUser = await secureStorage.getServiceUsername();
      if (svcUser == null || svcUser.isEmpty) {
        // No service credentials - need to re-setup with 5-part connection string
        await _configService.clearConfig();
        _navigateToSetup();
        return;
      }

      _odooService = OdooService(
        url: serverUrl,
        database: database,
      );

      setState(() {
        _isConfigLoading = false;
      });

      // اختبار الاتصال
      _checkConnection();
    } catch (e) {
      _navigateToSetup();
    }
  }

  void _navigateToSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
    });
  }

  Future<void> _checkConnection() async {
    if (_odooService == null) return;

    try {
      final serverConnected = await _odooService!.testServerConnection();

      final apiConnected = await _odooService!.testApiConnection();

      if (!serverConnected && mounted) {
        _showSnackBar(context.lang.translate('connection_error'), isError: true);
      }
    } catch (e) {
      // connection test failed
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// تغيير الشركة/السيرفر
  Future<void> _changeCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تغيير الشركة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل تريد تغيير إعدادات الاتصال؟\nسيتم حذف الإعدادات الحالية.',
          style: TextStyle(color: textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _configService.clearConfig();
      _navigateToSetup();
    }
  }

  Future<void> _loginUser() async {
    if (_odooService == null) {
      _showSnackBar('خطأ في الإعدادات', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    _showSnackBar(context.lang.translate('signing_in'));

    try {
      // authenticateEmployee uses the public login endpoint (no service account needed)
      // and internally establishes the service session on success
      final employee = await _odooService!.authenticateEmployee(
        _usernameController.text,
        _passwordController.text,
      );

      if (employee != null) {
        // Clear PIN from memory after successful auth
        _passwordController.clear();

        if (!mounted) return;

        await Future.delayed(const Duration(milliseconds: 300));

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(
              odooService: _odooService!,
              employee: employee,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        _showSnackBar(context.lang.translate('invalid_credentials'), isError: true);
      }
    } catch (_) {
      _showSnackBar(context.lang.translate('connection_error'), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    // شاشة التحميل
    if (_isConfigLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgGradientStart, bgGradientEnd],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgGradientStart, bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Language Switcher
                      Align(
                        alignment: Alignment.topLeft,
                        child: LanguageSwitcher(),
                      ),

                      const SizedBox(height: 30),
                      _buildHeader(lang),
                      const SizedBox(height: 40),
                      _buildLoginCard(lang),
                      const SizedBox(height: 24),
                      _buildResetButton(lang),
                      const SizedBox(height: 32),
                      _buildFooter(lang),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Header - الشعار والعنوان
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(dynamic lang) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          // الشعار
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, darkBlue],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.business_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // اسم الشركة
          if (_companyName != null && _companyName!.isNotEmpty) ...[
            Text(
              _companyName!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
          ],

          Text(
            lang.isArabic ? 'نظام إدارة الموارد البشرية' : 'HR Management System',
            style: TextStyle(
              fontSize: _companyName != null ? 15 : 28,
              fontWeight: _companyName != null ? FontWeight.w500 : FontWeight.bold,
              color: _companyName != null ? textGrey : textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// بطاقة تسجيل الدخول
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildLoginCard(dynamic lang) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            Center(
              child: Text(
                lang.translate('welcome_back'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                lang.isArabic ? 'أدخل بياناتك للمتابعة' : 'Enter your credentials',
                style: TextStyle(
                  fontSize: 14,
                  color: textGrey,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // حقل اسم المستخدم
            _buildTextField(
              controller: _usernameController,
              label: lang.translate('username'),
              hint: lang.isArabic ? 'أدخل اسم المستخدم' : 'Enter username',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
              v?.isEmpty == true ? lang.translate('please_enter_username') : null,
            ),
            const SizedBox(height: 20),

            // حقل كلمة المرور
            _buildTextField(
              controller: _passwordController,
              label: lang.translate('password'),
              hint: lang.isArabic ? 'أدخل كلمة المرور' : 'Enter password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (v) =>
              v?.isEmpty == true ? lang.translate('please_enter_password') : null,
            ),
            const SizedBox(height: 28),

            // زر تسجيل الدخول
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.translate('login'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// حقل الإدخال المخصص
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(fontSize: 16, color: textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textGrey.withOpacity(0.5), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: primaryBlue.withOpacity(0.7),
              size: 22,
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: textGrey.withOpacity(0.6),
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: primaryBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// زر إعادة الإعداد
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildResetButton(dynamic lang) {
    return TextButton.icon(
      onPressed: _changeCompany,
      icon: Icon(
        Icons.settings_backup_restore_rounded,
        color: textGrey.withOpacity(0.7),
        size: 20,
      ),
      label: Text(
        lang.isArabic ? 'تغيير إعدادات الاتصال' : 'Change connection settings',
        style: TextStyle(
          color: textGrey.withOpacity(0.7),
          fontSize: 14,
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Footer
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildFooter(dynamic lang) {
    return Column(
      children: [
        Text(
          lang.translate('powered_by'),
          style: TextStyle(
            fontSize: 12,
            color: textGrey.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: 11,
            color: textGrey.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}