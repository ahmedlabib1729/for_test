// lib/pages/settings_screen.dart - Modern Dark Theme
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';

class SettingsScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;
  final VoidCallback onLogout;

  const SettingsScreen({
    Key? key,
    required this.odooService,
    required this.employee,
    required this.onLogout,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageManager();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1F38), Color(0xFF2D3250), Color(0xFF424769)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(lang),
                SizedBox(height: 24),
                _buildLanguageSection(lang),
                SizedBox(height: 24),
                _buildPreferencesSection(lang),
                SizedBox(height: 24),
                _buildAccountSection(lang),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(LanguageManager lang) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              lang.isArabic ? 'الإعدادات' : 'Settings',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 12),
              Text(
                lang.isArabic ? 'اللغة' : 'Language',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildLanguageOption(
                  'العربية',
                  lang.isArabic,
                      () async {
                    await LanguageManager().changeLanguage('ar');
                    setState(() {});
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildLanguageOption(
                  'English',
                  !lang.isArabic,
                      () async {
                    await LanguageManager().changeLanguage('en');
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6C63FF).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Color(0xFF6C63FF) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF4ECDC4), size: 22),
              SizedBox(width: 12),
              Text(
                lang.isArabic ? 'التفضيلات' : 'Preferences',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildSwitchTile(
            icon: Icons.notifications_active,
            title: lang.isArabic ? 'الإشعارات' : 'Notifications',
            subtitle: lang.isArabic ? 'تفعيل إشعارات التطبيق' : 'Enable push notifications',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            color: Color(0xFFFF8E53),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 32),
          _buildSwitchTile(
            icon: Icons.dark_mode,
            title: lang.isArabic ? 'الوضع الداكن' : 'Dark Mode',
            subtitle: lang.isArabic ? 'تفعيل الوضع الداكن' : 'Enable dark theme',
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
            color: Color(0xFF764BA2),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Color(0xFF4ECDC4),
        ),
      ],
    );
  }

  Widget _buildAccountSection(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, color: Color(0xFFFF6B6B), size: 22),
              SizedBox(width: 12),
              Text(
                lang.isArabic ? 'الحساب' : 'Account',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: Icon(Icons.logout, color: Colors.white),
              label: Text(
                lang.isArabic ? 'تسجيل الخروج' : 'Logout',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B6B),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    final lang = LanguageManager();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2D3250),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.isArabic ? 'تسجيل الخروج' : 'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.isArabic ? 'هل أنت متأكد من تسجيل الخروج؟' : 'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.isArabic ? 'إلغاء' : 'Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B6B)),
            child: Text(lang.isArabic ? 'خروج' : 'Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}