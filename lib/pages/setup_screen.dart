// lib/pages/setup_screen.dart
// شاشة إعداد التطبيق - تصميم احترافي جديد

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../services/config_service.dart';
import '../services/language_manager.dart';
import 'login_page.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final ConfigService _configService = ConfigService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// معالجة الكود المدخل
  Future<void> _processCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final code = _codeController.text.trim();
      debugPrint('[Setup] Processing code: ${code.length} chars');

      final parseResult = await _configService.parseConnectionCode(code);
      debugPrint('[Setup] Parse result: success=${parseResult.isSuccess}, '
          'server=${parseResult.serverUrl}, db=${parseResult.database}, '
          'hasServiceCreds=${parseResult.serviceUsername != null}');

      if (!parseResult.isSuccess) {
        debugPrint('[Setup] Parse failed: ${parseResult.errorMessage}');
        setState(() {
          _errorMessage = parseResult.errorMessage;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _successMessage = 'جاري التحقق من الاتصال...';
      });

      debugPrint('[Setup] Verifying connection to ${parseResult.serverUrl}...');
      final verifyResult = await _configService.verifyConnection(parseResult);
      debugPrint('[Setup] Verify result: success=${verifyResult.isSuccess}, '
          'warning=${verifyResult.warning}, error=${verifyResult.errorMessage}');

      if (!verifyResult.isSuccess) {
        debugPrint('[Setup] Verification failed: ${verifyResult.errorMessage}');
        setState(() {
          _errorMessage = verifyResult.errorMessage;
          _isLoading = false;
          _successMessage = null;
        });
        return;
      }

      debugPrint('[Setup] Saving config...');
      final saved = await _configService.saveConfig(
        serverUrl: verifyResult.serverUrl!,
        database: verifyResult.database!,
        token: verifyResult.token,
        companyName: verifyResult.companyName,
        serviceUsername: verifyResult.serviceUsername,
        servicePassword: verifyResult.servicePassword,
      );

      if (!saved) {
        debugPrint('[Setup] Save failed');
        setState(() {
          _errorMessage = 'فشل في حفظ الإعدادات';
          _isLoading = false;
          _successMessage = null;
        });
        return;
      }

      debugPrint('[Setup] Config saved successfully, navigating to login...');

      // نجاح! الانتقال لصفحة تسجيل الدخول
      setState(() {
        _successMessage = 'تم الاتصال بنجاح!';
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      debugPrint('[Setup] Exception: $e');
      setState(() {
        _errorMessage = 'حدث خطأ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildMainCard(),
                      const SizedBox(height: 24),
                      _buildInstructionsCard(),
                      const SizedBox(height: 32),
                      _buildFooter(),
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
  Widget _buildHeader() {
    return Column(
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

        // العنوان
        const Text(
          'Aura HR',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'نظام إدارة الموارد البشرية',
          style: TextStyle(
            fontSize: 16,
            color: textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// البطاقة الرئيسية - إدخال الكود
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            // عنوان البطاقة
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعداد الاتصال',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      Text(
                        'أدخل كود الاتصال أو امسح QR Code',
                        style: TextStyle(
                          fontSize: 13,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // حقل إدخال الكود
            TextFormField(
              controller: _codeController,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: textDark,
              ),
              decoration: InputDecoration(
                hintText:
                'http://server:port|token|database\nأو الصق محتوى QR Code',
                hintStyle: TextStyle(
                  color: textGrey.withOpacity(0.5),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(16),
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
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.content_paste_rounded,
                    color: primaryBlue.withOpacity(0.7),
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _codeController.text = data!.text!;
                    }
                  },
                  tooltip: 'لصق',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال كود الاتصال';
                }
                return null;
              },
            ),

            // رسائل الخطأ والنجاح
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildMessageBox(
                message: _errorMessage!,
                isError: true,
              ),
            ],

            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              _buildMessageBox(
                message: _successMessage!,
                isError: false,
              ),
            ],

            const SizedBox(height: 24),

            // زر الاتصال
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCode,
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
                  children: const [
                    Icon(Icons.link_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'اتصال',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  /// صندوق الرسائل
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildMessageBox({required String message, required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBF7D0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// بطاقة التعليمات
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryBlue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'كيفية الحصول على الكود',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep(
            number: '1',
            text: 'اطلب كود الاتصال من مدير النظام',
          ),
          _buildInstructionStep(
            number: '2',
            text: 'يمكنك مسح QR Code أو نسخ النص',
          ),
          _buildInstructionStep(
            number: '3',
            text: 'الصق الكود في الحقل أعلاه واضغط اتصال',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep({required String number, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textDark.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Footer
  /// ═══════════════════════════════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Powered by Odoo',
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