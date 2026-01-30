// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/language_manager.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/attendance_screen.dart';
import 'pages/requests_screen.dart';
import 'pages/new_leave_request_screen.dart';
import 'pages/leave_request_details_screen.dart';
import 'pages/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة مدير اللغة
  await LanguageManager().initialize();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // الاستماع لتغييرات اللغة
    LanguageManager().addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageManager().removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final langManager = LanguageManager();

    return MaterialApp(
      title: 'HR App',
      debugShowCheckedModeBanner: false,

      // إعدادات اللغة
      locale: langManager.currentLocale,
      supportedLocales: [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // الثيم الداكن
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light,
        fontFamily: langManager.isArabic ? 'Cairo' : 'Roboto',
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF1A1F38),
        fontFamily: langManager.isArabic ? 'Cairo' : 'Roboto',
      ),

      // اتجاه النص
      builder: (context, child) {
        return Directionality(
          textDirection: langManager.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },

      // الصفحة الرئيسية
      home: const LoginPage(),

      // المسارات
      routes: {
        '/login': (context) => const LoginPage(),
      },

      // توليد المسارات الديناميكية
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        switch (settings.name) {
          case '/home':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => HomePage(
                  odooService: args['odooService'],
                  employee: args['employee'],
                  onLogout: args['onLogout'] ?? () {},
                ),
              );
            }
            break;

          case '/attendance':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => AttendanceScreen(
                  odooService: args['odooService'],
                  employee: args['employee'],
                ),
              );
            }
            break;

          case '/requests':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => RequestsScreen(
                  odooService: args['odooService'],
                  employee: args['employee'],
                ),
              );
            }
            break;

          case '/new-leave-request':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => NewLeaveRequestScreen(
                  odooService: args['odooService'],
                  employee: args['employee'],
                ),
              );
            }
            break;

          case '/leave-request-details':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => LeaveRequestDetailsScreen(
                  request: args['request'],
                  odooService: args['odooService'],
                  employee: args['employee'],
                ),
              );
            }
            break;

          case '/profile':
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => ProfilePage(
                  odooService: args['odooService'],
                  employee: args['employee'],
                ),
              );
            }
            break;
        }

        // صفحة خطأ افتراضية
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(LanguageManager().translate('error')),
            ),
            body: Center(
              child: Text(
                LanguageManager().isArabic
                    ? 'الصفحة غير موجودة'
                    : 'Page not found',
              ),
            ),
          ),
        );
      },
    );
  }
}