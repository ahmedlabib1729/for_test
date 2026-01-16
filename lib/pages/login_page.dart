import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'home_page.dart';
import '../services/odoo_service.dart';
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

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Odoo Service
  final OdooService _odooService = OdooService(
    url: 'http://192.168.70.221:8018',
    database: 'Mbile',
  );

  @override
  void initState() {
    super.initState();

    // Setup animations
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
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

    _checkConnection();
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

  Future<void> _checkConnection() async {
    try {
      final bool serverConnected = await _odooService.testServerConnection();
      print('Server connection test: ${serverConnected ? 'Success' : 'Failed'}');

      final bool apiConnected = await _odooService.testApiConnection();
      print('API connection test: ${apiConnected ? 'Success' : 'Failed'}');

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
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    _showSnackBar(context.lang.translate('signing_in'));

    try {
      print('Login attempt with:');
      print('Username: ${_usernameController.text}');

      final success = await _odooService.loginWithService();

      if (success) {
        print('Service login successful, authenticating employee...');

        final employee = await _odooService.authenticateEmployee(
          _usernameController.text,
          _passwordController.text,
        );

        if (employee != null) {
          print('Employee authenticated successfully: ${employee.name}');

          if (!mounted) return;

          // Animation للانتقال
          await Future.delayed(Duration(milliseconds: 300));

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => HomePage(
                odooService: _odooService,
                employee: employee,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        } else {
          _showSnackBar(context.lang.translate('invalid_credentials'));
        }
      } else {
        _showSnackBar(context.lang.translate('connection_error'));
      }
    } catch (e) {
      print('Login error: $e');
      _showSnackBar('${context.lang.translate('error')}: $e');
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A5F), // أزرق داكن احترافي
              Color(0xFF2E5984), // أزرق متوسط
              Color(0xFF3D7AA8), // أزرق فاتح
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decoration
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

              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and title
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildLogoSection(lang),
                        ),
                      ),

                      SizedBox(height: 48),

                      // Login form
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
      child: CustomPaint(
        painter: BackgroundPainter(),
      ),
    );
  }

  Widget _buildLogoSection(dynamic lang) {
    return Column(
      children: [
        // Logo container with glassmorphism
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
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
                child: Icon(
                  Icons.business_center_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 24),

        // App title
        Text(
          lang.isArabic ? 'نظام إدارة الموارد البشرية' : 'HR Management System',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 8),

        Text(
          lang.isArabic ? 'تسجيل الدخول' : 'Sign In',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(dynamic lang) {
    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome text
            Text(
              lang.translate('welcome_back'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 8),

            Text(
              lang.isArabic
                  ? 'أدخل بياناتك للمتابعة'
                  : 'Enter your credentials to continue',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 32),

            // Username field
            _buildTextField(
              controller: _usernameController,
              label: lang.translate('username'),
              hint: lang.isArabic ? 'أدخل اسم المستخدم' : 'Enter your username',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.translate('please_enter_username');
                }
                return null;
              },
            ),

            SizedBox(height: 20),

            // Password field
            _buildTextField(
              controller: _passwordController,
              label: lang.translate('password'),
              hint: lang.isArabic ? 'أدخل كلمة المرور' : 'Enter your password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return lang.translate('please_enter_password');
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Remember me & Forgot password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: Color(0xFF1E3A5F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      lang.translate('remember_me'),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Forgot password
                  },
                  child: Text(
                    lang.isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 28),

            // Login button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E3A5F),
                    Color(0xFF2E5984),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1E3A5F).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
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
                    ? SizedBox(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    lang.isArabic ? 'أو' : 'OR',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            SizedBox(height: 24),

            // Biometric login button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Biometric login
                _showSnackBar(
                    lang.isArabic
                        ? 'قريباً: تسجيل الدخول بالبصمة'
                        : 'Coming soon: Biometric login'
                );
              },
              icon: Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF1E3A5F),
                size: 24,
              ),
              label: Text(
                lang.isArabic ? 'تسجيل بالبصمة' : 'Biometric Login',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: Color(0xFF1E3A5F).withOpacity(0.3),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: EdgeInsets.only(right: 12),
              child: Icon(
                icon,
                color: Color(0xFF1E3A5F).withOpacity(0.7),
                size: 22,
              ),
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[600],
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Color(0xFF1E3A5F),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.red[300]!,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
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
}

// Custom painter for background decoration
class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Draw circles
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.15),
      100,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.3),
      150,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      120,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.75),
      80,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}