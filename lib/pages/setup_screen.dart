// lib/pages/setup_screen.dart
// شاشة إعداد التطبيق - إدخال Connection String أو مسح QR Code

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

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final ConfigService _configService = ConfigService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
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

      // الخطوة 1: تحليل الكود
      print('═══════════════════════════════════════');
      print('🔄 معالجة الكود...');
      print('═══════════════════════════════════════');

      final parseResult = await _configService.parseConnectionCode(code);

      if (!parseResult.isSuccess) {
        setState(() {
          _errorMessage = parseResult.errorMessage;
          _isLoading = false;
        });
        return;
      }

      // الخطوة 2: التحقق من الاتصال
      setState(() {
        _successMessage = 'جاري التحقق من الاتصال...';
      });

      final verifyResult = await _configService.verifyConnection(parseResult);

      if (!verifyResult.isSuccess) {
        setState(() {
          _errorMessage = verifyResult.errorMessage;
          _isLoading = false;
          _successMessage = null;
        });
        return;
      }

      // الخطوة 3: حفظ الإعدادات
      final saved = await _configService.saveConfig(
        serverUrl: verifyResult.serverUrl!,
        database: verifyResult.database!,
        token: verifyResult.token,
        companyName: verifyResult.companyName,
      );

      if (!saved) {
        setState(() {
          _errorMessage = 'فشل في حفظ الإعدادات';
          _isLoading = false;
          _successMessage = null;
        });
        return;
      }

      // نجاح!
      setState(() {
        _successMessage = verifyResult.warning ?? 'تم الاتصال بنجاح! ✓';
        _isLoading = false;
      });

      // الانتقال لصفحة تسجيل الدخول
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: $e';
        _isLoading = false;
        _successMessage = null;
      });
    }
  }

  /// لصق من الحافظة
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        _codeController.text = data.text!;
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('خطأ في اللصق: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isArabic = lang.isArabic;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A5F),
              Color(0xFF2E5984),
              Color(0xFF3D7AA8),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _buildLogo(),
                    const SizedBox(height: 40),

                    // Setup Card
                    _buildSetupCard(isArabic),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
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
                  Icons.settings_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'إعداد التطبيق',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل كود الاتصال من مدير النظام',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupCard(bool isArabic) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
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
            // العنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF1E3A5F),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كود الاتصال',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      Text(
                        'Connection String أو QR Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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
              ),
              decoration: InputDecoration(
                hintText: 'http://server:port|token|database\nأو الصق محتوى QR Code',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded),
                  color: const Color(0xFF1E3A5F),
                  tooltip: 'لصق من الحافظة',
                  onPressed: _pasteFromClipboard,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'من فضلك أدخل كود الاتصال';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // رسالة الخطأ
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // رسالة النجاح
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // زر الاتصال
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
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
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'اتصال',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // تعليمات
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'كيفية الحصول على الكود:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. اطلب من مدير النظام كود الاتصال\n'
                        '2. يمكن مسح QR Code أو نسخ النص\n'
                        '3. الصق الكود هنا واضغط اتصال',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}