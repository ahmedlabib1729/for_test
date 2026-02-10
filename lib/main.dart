// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/language_manager.dart';
import 'services/odoo_service.dart';
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

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime? _lastActiveTime;
  static const _sessionTimeoutMinutes = 30;

  @override
  void initState() {
    super.initState();
    LanguageManager().addListener(_onLanguageChanged);
    WidgetsBinding.instance.addObserver(this);
    _lastActiveTime = DateTime.now();
  }

  @override
  void dispose() {
    LanguageManager().removeListener(_onLanguageChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if session has expired while app was in background
      if (_lastActiveTime != null) {
        final elapsed = DateTime.now().difference(_lastActiveTime!);
        if (elapsed.inMinutes >= _sessionTimeoutMinutes) {
          // Session expired - navigate to login
          final navKey = _navigatorKey;
          if (navKey.currentState != null) {
            navKey.currentState!.pushNamedAndRemoveUntil('/login', (_) => false);
          }
        }
      }
      _lastActiveTime = DateTime.now();
    } else if (state == AppLifecycleState.paused) {
      _lastActiveTime = DateTime.now();
    }
  }

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _onLanguageChanged() {
    setState(() {});
  }

  /// Validate that route arguments contain required authenticated data
  bool _isValidAuthArgs(Map<String, dynamic>? args) {
    if (args == null) return false;
    final odooService = args['odooService'];
    final employee = args['employee'];
    return odooService is OdooService &&
        odooService.sessionId != null &&
        employee != null;
  }

  @override
  Widget build(BuildContext context) {
    final langManager = LanguageManager();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'HR App',
      debugShowCheckedModeBanner: false,

      // إعدادات اللغة
      locale: langManager.currentLocale,
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
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
        scaffoldBackgroundColor: const Color(0xFF1A1F38),
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

      // توليد المسارات الديناميكية مع حماية المصادقة
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        // All routes except /login require authentication
        if (settings.name != '/login' && !_isValidAuthArgs(args)) {
          return MaterialPageRoute(
            builder: (context) => const LoginPage(),
          );
        }

        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
              builder: (context) => HomePage(
                odooService: args!['odooService'],
                employee: args['employee'],
                onLogout: args['onLogout'] ?? () {},
              ),
            );

          case '/attendance':
            return MaterialPageRoute(
              builder: (context) => AttendanceScreen(
                odooService: args!['odooService'],
                employee: args['employee'],
              ),
            );

          case '/requests':
            return MaterialPageRoute(
              builder: (context) => RequestsScreen(
                odooService: args!['odooService'],
                employee: args['employee'],
              ),
            );

          case '/new-leave-request':
            return MaterialPageRoute(
              builder: (context) => NewLeaveRequestScreen(
                odooService: args!['odooService'],
                employee: args['employee'],
              ),
            );

          case '/leave-request-details':
            return MaterialPageRoute(
              builder: (context) => LeaveRequestDetailsScreen(
                request: args!['request'],
                odooService: args['odooService'],
                employee: args['employee'],
              ),
            );

          case '/profile':
            return MaterialPageRoute(
              builder: (context) => ProfilePage(
                odooService: args!['odooService'],
                employee: args['employee'],
              ),
            );
        }

        // Unauthenticated/unknown route → login
        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
    );
  }
}