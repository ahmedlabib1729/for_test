// lib/app_initializer.dart
// تحديد الشاشة الأولى بناءً على حالة الإعدادات

import 'package:flutter/material.dart';
import 'services/config_service.dart';
import 'pages/setup_screen.dart';
import 'pages/login_page.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final ConfigService _configService = ConfigService();
  bool _isLoading = true;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    try {
      final isConfigured = await _configService.isConfigured();

      setState(() {
        _isConfigured = isConfigured;
        _isLoading = false;
      });
    } catch (e) {

      setState(() {
        _isConfigured = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // شاشة التحميل
    if (_isLoading) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الشعار
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    size: 50,
                    color: Color(0xFF1E3A5F),
                  ),
                ),

                SizedBox(height: 32),

                // مؤشر التحميل
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  'جاري التحميل...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // إذا كانت الإعدادات موجودة -> صفحة الدخول
    // إذا لم تكن موجودة -> شاشة الإعداد
    if (_isConfigured) {
      return const LoginPage();
    } else {
      return const SetupScreen();
    }
  }
}