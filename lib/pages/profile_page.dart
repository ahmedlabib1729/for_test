// lib/pages/profile_page.dart - Modern Dark Theme with EmployeeAvatar
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/odoo_service.dart';
import '../services/language_manager.dart';
import '../widgets/employee_avatar.dart';

class ProfilePage extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const ProfilePage({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Employee? _employee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _isLoading = false;
  }

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
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
              : SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(lang),
                _buildProfileHeader(lang),
                SizedBox(height: 24),
                _buildWorkInfoCard(lang),
                SizedBox(height: 16),
                _buildContactInfoCard(lang),
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
              lang.isArabic ? 'الملف الشخصي' : 'My Profile',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.all(24),
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // استخدام EmployeeAvatar بدلاً من Image.network
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: EmployeeAvatar(
              employee: _employee!,
              radius: 50,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _employee!.name,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            _employee!.jobTitle.isNotEmpty ? _employee!.jobTitle : (lang.isArabic ? 'موظف' : 'Employee'),
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID: ${_employee!.id}',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInfoCard(LanguageManager lang) {
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
              Icon(Icons.work, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 12),
              Text(
                lang.isArabic ? 'معلومات العمل' : 'Work Information',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildProfileField(
            lang.isArabic ? 'رقم الموظف' : 'Employee ID',
            _employee!.id.toString(),
            Icons.badge,
            Color(0xFF6C63FF),
          ),
          Divider(color: Colors.white.withOpacity(0.1)),
          _buildProfileField(
            lang.isArabic ? 'المسمى الوظيفي' : 'Job Title',
            _employee!.jobTitle.isNotEmpty ? _employee!.jobTitle : '-',
            Icons.work_outline,
            Color(0xFF4ECDC4),
          ),
          Divider(color: Colors.white.withOpacity(0.1)),
          _buildProfileField(
            lang.isArabic ? 'القسم' : 'Department',
            _employee!.department.isNotEmpty ? _employee!.department : '-',
            Icons.business,
            Color(0xFFFF8E53),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard(LanguageManager lang) {
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
              Icon(Icons.contact_phone, color: Color(0xFF4ECDC4), size: 22),
              SizedBox(width: 12),
              Text(
                lang.isArabic ? 'معلومات الاتصال' : 'Contact Information',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_employee!.workEmail.isNotEmpty)
            _buildProfileField(
              lang.isArabic ? 'البريد الإلكتروني' : 'Work Email',
              _employee!.workEmail,
              Icons.email,
              Color(0xFF4ECDC4),
            ),
          if (_employee!.workEmail.isNotEmpty)
            Divider(color: Colors.white.withOpacity(0.1)),
          if (_employee!.workPhone.isNotEmpty)
            _buildProfileField(
              lang.isArabic ? 'هاتف العمل' : 'Work Phone',
              _employee!.workPhone,
              Icons.phone,
              Color(0xFFFF8E53),
            ),
          if (_employee!.workPhone.isNotEmpty)
            Divider(color: Colors.white.withOpacity(0.1)),
          if (_employee!.mobilePhone.isNotEmpty)
            _buildProfileField(
              lang.isArabic ? 'الجوال' : 'Mobile Phone',
              _employee!.mobilePhone,
              Icons.smartphone,
              Color(0xFF6C63FF),
            ),
          if (_employee!.workEmail.isEmpty && _employee!.workPhone.isEmpty && _employee!.mobilePhone.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  lang.isArabic ? 'لا توجد معلومات اتصال' : 'No contact information available',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}