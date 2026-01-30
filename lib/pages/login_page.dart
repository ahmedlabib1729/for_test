// lib/pages/login_page.dart
// صفحة تسجيل الدخول - تستخدم الإعدادات من ConfigService

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'home_page.dart';
import 'setup_screen.dart';
import '../services/odoo_service.dart';
import '../services/config_service.dart';
import '../services/language_manager.dart';
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
        print('❌ لا توجد إعدادات محفوظة - الانتقال لشاشة الإعداد');
        _navigateToSetup();
        return;
      }

      // الإعدادات موجودة - إنشاء OdooService
      final serverUrl = _configService.serverUrl!;
      final database = _configService.database!;
      _companyName = _configService.companyName;

      print('═══════════════════════════════════════');
      print('✅ تم تحميل الإعدادات:');
      print('   Server: $serverUrl');
      print('   Database: $database');
      print('   Company: $_companyName');
      print('═══════════════════════════════════════');

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
      print('❌ خطأ في تحميل الإعدادات: $e');
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
      print('Server connection: ${serverConnected ? '✅' : '❌'}');

      final apiConnected = await _odooService!.testApiConnection();
      print('API connection: ${apiConnected ? '✅' : '❌'}');

      if (!serverConnected && mounted) {
        _showSnackBar(context.lang.translate('connection_error'));
      }
    } catch (e) {
      print('Connection test error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// تغيير الشركة/السيرفر
  Future<void> _changeCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.business_rounded, color: Color(0xFF1E3A5F)),
            SizedBox(width: 12),
            Text('تغيير الشركة'),
          ],
        ),
        content: const Text(
          'هل تريد تغيير إعدادات الاتصال؟\nسيتم حذف الإعدادات الحالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
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
      _showSnackBar('خطأ في الإعدادات');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    _showSnackBar(context.lang.translate('signing_in'));

    try {
      print('═══════════════════════════════════════');
      print('🔐 محاولة تسجيل الدخول:');
      print('   Username: ${_usernameController.text}');
      print('   Server: ${_odooService!.baseUrl}');
      print('   Database: ${_odooService!.database}');
      print('═══════════════════════════════════════');

      final success = await _odooService!.loginWithService();

      if (success) {
        print('✅ Service login successful');

        final employee = await _odooService!.authenticateEmployee(
          _usernameController.text,
          _passwordController.text,
        );

        if (employee != null) {
          print('✅ Employee authenticated: ${employee.name}');

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
          _showSnackBar(context.lang.translate('invalid_credentials'));
        }
      } else {
        _showSnackBar(context.lang.translate('connection_error'));
      }
    } catch (e) {
      print('❌ Login error: $e');
      _showSnackBar('خطأ: $e');
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
    // عرض شاشة التحميل أثناء تحميل الإعدادات
    if (_isConfigLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF2E5984), Color(0xFF3D7AA8)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final lang = context.lang;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A5F), Color(0xFF2E5984), Color(0xFF3D7AA8)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildBackgroundDecoration(),

              // Language switcher
              Positioned(
                top: 16,
                right: lang.isArabic ? null : 16,
                left: lang.isArabic ? 16 : null,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: LanguageSwitcher(
                    showText: true,
                    iconColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),

              // زر تغيير الشركة
              Positioned(
                top: 16,
                left: lang.isArabic ? null : 16,
                right: lang.isArabic ? 16 : null,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: IconButton(
                    onPressed: _changeCompany,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: Colors.white,
                    tooltip: 'تغيير الشركة',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildLogoSection(lang),
                        ),
                      ),
                      const SizedBox(height: 48),
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildLoginForm(lang),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration() {
    return Positioned.fill(
      child: CustomPaint(painter: BackgroundPainter()),
    );
  }

  Widget _buildLogoSection(dynamic lang) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // اسم الشركة (إذا موجود)
        if (_companyName != null && _companyName!.isNotEmpty) ...[
          Text(
            _companyName!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],

        Text(
          lang.isArabic ? 'نظام إدارة الموارد البشرية' : 'HR Management System',
          style: TextStyle(
            fontSize: _companyName != null ? 14 : 24,
            fontWeight: _companyName != null ? FontWeight.normal : FontWeight.bold,
            color: _companyName != null ? Colors.white70 : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(dynamic lang) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.translate('welcome_back'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              lang.isArabic ? 'أدخل بياناتك للمتابعة' : 'Enter your credentials',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Username
            _buildTextField(
              controller: _usernameController,
              label: lang.translate('username'),
              hint: lang.isArabic ? 'أدخل اسم المستخدم' : 'Enter username',
              icon: Icons.person_outline_rounded,
              validator: (v) => v?.isEmpty == true ? lang.translate('please_enter_username') : null,
            ),
            const SizedBox(height: 20),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: lang.translate('password'),
              hint: lang.isArabic ? 'أدخل كلمة المرور' : 'Enter password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (v) => v?.isEmpty == true ? lang.translate('please_enter_password') : null,
            ),
            const SizedBox(height: 28),

            // Login button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2E5984)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.translate('login'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              lang.translate('powered_by'),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F).withOpacity(0.7)),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 100, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), 120, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.75), 80, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}