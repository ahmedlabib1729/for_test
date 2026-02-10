// lib/services/language_manager.dart
// ملف الترجمة الكامل والشامل للتطبيق
// Complete Translation File for HR Mobile App
// تاريخ التحديث: 2026-01-31

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager extends ChangeNotifier {
  static const String _languageKey = 'selected_language';

  Locale _currentLocale = const Locale('en', 'US');
  Map<String, dynamic> _localizedStrings = {};

  Locale get currentLocale => _currentLocale;
  bool get isArabic => _currentLocale.languageCode == 'ar';

  // Singleton pattern
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  // تهيئة اللغة
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey) ?? 'en';

    _currentLocale = Locale(savedLanguage, savedLanguage == 'ar' ? 'SA' : 'US');
    await loadLanguage();
  }

  // تحميل ملف اللغة
  Future<void> loadLanguage() async {
    if (_currentLocale.languageCode == 'ar') {
      _localizedStrings = _arabicStrings;
    } else {
      _localizedStrings = _englishStrings;
    }
    notifyListeners();
  }

  // تغيير اللغة
  Future<void> changeLanguage(String languageCode) async {
    if (languageCode == _currentLocale.languageCode) return;

    _currentLocale = Locale(languageCode, languageCode == 'ar' ? 'SA' : 'US');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);

    await loadLanguage();
  }

  // الحصول على النص المترجم
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // اختصار للترجمة
  String get(String key) => translate(key);
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════════╗
// ║                           ENGLISH STRINGS - النصوص الإنجليزية                          ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

final Map<String, dynamic> _englishStrings = {
  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LOGIN PAGE - صفحة تسجيل الدخول
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'login': 'LOGIN',
  'username': 'Username',
  'password': 'Password',
  'remember_me': 'Remember me',
  'please_enter_username': 'Please enter your username',
  'please_enter_password': 'Please enter your password',
  'signing_in': 'Signing you in...',
  'invalid_credentials': 'Invalid username or password',
  'connection_error': 'Unable to connect to server',
  'powered_by': 'Powered BY ERP Accounting and Auditing',
  'forgot_password': 'Forgot Password?',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // HOME PAGE - الصفحة الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'welcome': 'Welcome',
  'home': 'Home',
  'good_morning': 'Good Morning',
  'good_afternoon': 'Good Afternoon',
  'good_evening': 'Good Evening',
  'todays_working_hours': 'Today\'s Working Hours',
  'working_hours': 'Working Hours',
  'manage': 'Manage',
  'quick_actions': 'Quick Actions',
  'recent_activity': 'Recent Activity',
  'no_recent_activity': 'No recent activity',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // NAVIGATION - التنقل
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'attendance': 'Attendance',
  'leaves': 'Leaves',
  'payslip': 'Payslip',
  'payslips': 'Payslips',
  'more': 'More',
  'announcements': 'Announcements',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ATTENDANCE PAGE - صفحة الحضور
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'checked_in': 'Checked In',
  'checked_out': 'Checked Out',
  'not_checked_in': 'Not Checked In',
  'attendance_history': 'Attendance History',
  'today': 'Today',
  'this_week': 'This Week',
  'this_month': 'This Month',
  'total_hours': 'Total Hours',
  'hours': 'Hours',
  'minutes': 'Minutes',
  'late': 'Late',
  'early': 'Early',
  'on_time': 'On Time',
  'overtime': 'Overtime',
  'location_required': 'Location Required',
  'location_required_message': 'Please enable location services to check in/out.',
  'camera_required': 'Camera Required',
  'camera_required_message': 'Please allow camera access to take attendance photo.',
  'attendance_recorded': 'Attendance recorded successfully',
  'attendance_failed': 'Failed to record attendance',
  'already_checked_in': 'You have already checked in today',
  'already_checked_out': 'You have already checked out today',
  'please_check_in_first': 'Please check in first',
  'outside_allowed_location': 'You are outside the allowed location',
  'location_permission_denied': 'Location Permission Denied',
  'location_permission_denied_message': 'Location permission is required for attendance.',
  'location_permanently_denied': 'Location Permanently Denied',
  'location_permanently_denied_message': 'Location permission permanently denied. Please go to app settings.',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CONNECTION STATUS - حالة الاتصال
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'online': 'Online',
  'offline': 'Offline',
  'no_internet': 'No internet connection',
  'data_synced': 'Data synchronized successfully',
  'sync_error': 'Error syncing data',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PROFILE & ACCOUNT - الملف الشخصي والحساب
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'profile': 'Profile',
  'logout': 'Logout',
  'logout_confirmation': 'Logout Confirmation',
  'logout_message': 'Are you sure you want to logout?',
  'work_information': 'Work Information',
  'contact_information': 'Contact Information',
  'employee_id': 'Employee ID',
  'job_title': 'Job Title',
  'department': 'Department',
  'work_email': 'Work Email',
  'work_phone': 'Work Phone',
  'mobile_phone': 'Mobile Phone',
  'no_data_available': 'No data available',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE REQUESTS PAGE - صفحة طلبات الإجازة ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'leave_requests': 'Leave Requests',
  'my_leave_requests': 'My Leave Requests',
  'new_request': 'New Request',
  'view_details': 'View Details',
  'cancel_request': 'Cancel Request',
  'submit_request': 'Submit Request',
  'leave_type': 'Leave Type',
  'start_date': 'Start Date',
  'end_date': 'End Date',
  'date_from': 'Date From',
  'date_to': 'Date To',
  'reason': 'Reason',
  'status': 'Status',
  'duration': 'Duration',
  'days': 'Days',
  'day': 'Day',
  'half_day': 'Half Day',
  'no_requests': 'No Requests',
  'no_leave_requests': 'No Leave Requests',
  'tap_to_create': 'Tap the button below to create a new leave request.',
  'data_synced_successfully': 'Data synced successfully',
  'cancel_request_title': 'Cancel Request',
  'cancel_request_message': 'Are you sure you want to cancel this request?',
  'request_cancelled': 'Request cancelled successfully',
  'failed_to_cancel': 'Failed to cancel',
  'number_of_days': 'Number of Days',
  'requested_days': 'Requested Days',
  'leave_balance': 'Leave Balance',
  'remaining_balance': 'Remaining Balance',
  'used': 'Used',
  'remaining': 'Remaining',
  'available': 'Available',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE TYPES - أنواع الإجازات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'sick_leave': 'Sick Leave',
  'annual_leave': 'Annual Leave',
  'emergency_leave': 'Emergency Leave',
  'unpaid_leave': 'Unpaid Leave',
  'paid_time_off': 'Paid Time Off',
  'maternity_leave': 'Maternity Leave',
  'paternity_leave': 'Paternity Leave',
  'compensatory_leave': 'Compensatory Leave',
  'bereavement_leave': 'Bereavement Leave',
  'study_leave': 'Study Leave',
  'casual_leave': 'Casual Leave',
  'marriage_leave': 'Marriage Leave',
  'hajj_leave': 'Hajj Leave',
  'personal_leave': 'Personal Leave',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE STATUS - حالات الإجازة ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'refused': 'Refused',
  'cancelled': 'Cancelled',
  'all': 'All',
  'draft': 'Draft',
  'confirm': 'To Approve',
  'validate': 'Approved',
  'validate1': 'First Approval',
  'refuse': 'Refused',
  'cancel': 'Cancelled',
  'waiting_approval': 'Waiting Approval',
  'under_review': 'Under Review',
  'first_approval': 'First Approval',
  'second_approval': 'Second Approval',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE BALANCE SCREEN - شاشة رصيد الإجازات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'overall_summary': 'Overall Summary',
  'allocated': 'Allocated',
  'usage_rate': 'Usage Rate',
  'details_by_leave_type': 'Details by Leave Type',
  'no_leave_data_available': 'No leave data available',
  'error_loading_leave_balance': 'Error loading leave balance',
  'unable_to_load_data': 'Unable to load data',
  'tap_to_try_again': 'Tap to try again',
  'total_allocated': 'Total Allocated',
  'total_used': 'Total Used',
  'total_remaining': 'Total Remaining',
  'no_allocation': 'No Allocation',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // NEW LEAVE REQUEST SCREEN - شاشة طلب إجازة جديد ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'new_leave_request': 'New Leave Request',
  'create_leave_request': 'Create Leave Request',
  'select_leave_type': 'Select Leave Type',
  'choose_leave_type': 'Choose Leave Type',
  'enter_reason': 'Enter reason (optional)',
  'reason_optional': 'Reason (Optional)',
  'reason_placeholder': 'Enter the reason for your leave request...',
  'please_select_leave_type': 'Please select a leave type',
  'please_select_start_date': 'Please select start date',
  'please_select_end_date': 'Please select end date',
  'end_date_before_start': 'End date cannot be before start date',
  'request_submitted': 'Leave request submitted successfully',
  'failed_to_submit': 'Failed to submit request',
  'submitting': 'Submitting...',
  'creating_request': 'Creating request...',
  'calculated_days': 'Calculated Days',
  'insufficient_balance': 'Insufficient Balance',
  'insufficient_balance_message': 'You don\'t have enough leave balance for this request',
  'overlapping_request': 'Overlapping Request',
  'overlapping_request_message': 'You already have a leave request during this period',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE REQUEST DETAILS SCREEN - شاشة تفاصيل طلب الإجازة ✅ جديد
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'request_details': 'Request Details',
  'leave_request_details': 'Leave Request Details',
  'request_info': 'Request Information',
  'request_information': 'Request Information',
  'requested_on': 'Requested On',
  'created_date': 'Created Date',
  'submission_date': 'Submission Date',
  'manager_comment': 'Manager Comment',
  'manager_notes': 'Manager Notes',
  'approver_comment': 'Approver Comment',
  'no_comment': 'No comment',
  'no_notes': 'No notes',
  'approval_info': 'Approval Information',
  'approval_details': 'Approval Details',
  'approved_by': 'Approved By',
  'rejected_by': 'Rejected By',
  'approval_date': 'Approval Date',
  'rejection_date': 'Rejection Date',
  'approver_name': 'Approver Name',
  'can_cancel': 'Can Cancel',
  'can_edit': 'Can Edit',
  'edit_request': 'Edit Request',
  'request_id': 'Request ID',
  'employee_name': 'Employee Name',
  'request_status': 'Request Status',
  'period': 'Period',
  'leave_period': 'Leave Period',
  'request_reason': 'Request Reason',
  'additional_notes': 'Additional Notes',
  'timeline': 'Timeline',
  'request_timeline': 'Request Timeline',
  'request_created': 'Request Created',
  'request_submitted': 'Request Submitted',
  'request_approved': 'Request Approved',
  'request_rejected': 'Request Rejected',
  'pending_approval': 'Pending Approval',
  'actions': 'Actions',
  'available_actions': 'Available Actions',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PAYSLIP PAGE - صفحة كشف الراتب ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'payslip_details': 'Payslip Details',
  'my_payslips': 'My Payslips',
  'salary': 'Salary',
  'basic_salary': 'Basic Salary',
  'gross_salary': 'Gross Salary',
  'net_salary': 'Net Salary',
  'allowances': 'Allowances',
  'deductions': 'Deductions',
  'earnings': 'Earnings',
  'taxes': 'Taxes',
  'bonus': 'Bonus',
  'pay_period': 'Pay Period',
  'payment_date': 'Payment Date',
  'download_payslip': 'Download Payslip',
  'no_payslips': 'No Payslips',
  'no_payslips_message': 'No payslips available for this period',
  'paid': 'Paid',
  'unpaid': 'Unpaid',
  'processing': 'Processing',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS PAGE - صفحة الإعلانات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'announcement_details': 'Announcement Details',
  'no_announcements': 'No Announcements',
  'no_announcements_message': 'There are no announcements at this time',
  'read': 'Read',
  'unread': 'Unread',
  'mark_as_read': 'Mark as Read',
  'mark_all_read': 'Mark All as Read',
  'pinned': 'Pinned',
  'important': 'Important',
  'urgent': 'Urgent',
  'general': 'General',
  'attachments': 'Attachments',
  'no_attachments': 'No attachments',
  'published_on': 'Published On',
  'published_by': 'Published By',
  'valid_until': 'Valid Until',
  'target_audience': 'Target Audience',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // GENERAL / COMMON - عام / مشترك
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'error': 'Error',
  'success': 'Success',
  'warning': 'Warning',
  'info': 'Info',
  'ok': 'OK',
  'yes': 'Yes',
  'no': 'No',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'add': 'Add',
  'close': 'Close',
  'cancel': 'Cancel',
  'search': 'Search',
  'filter': 'Filter',
  'sort': 'Sort',
  'retry': 'Retry',
  'refresh': 'Refresh',
  'loading': 'Loading...',
  'loading_data': 'Loading data...',
  'no_data': 'No data',
  'error_occurred': 'An error occurred',
  'error_loading_data': 'Error loading data',
  'try_again': 'Try Again',
  'notes': 'Notes',
  'details': 'Details',
  'view': 'View',
  'back': 'Back',
  'next': 'Next',
  'previous': 'Previous',
  'submit': 'Submit',
  'update': 'Update',
  'create': 'Create',
  'select': 'Select',
  'select_date': 'Select Date',
  'select_time': 'Select Time',
  'required': 'Required',
  'optional': 'Optional',
  'settings': 'Settings',
  'open_settings': 'Open Settings',
  'allow': 'Allow',
  'deny': 'Deny',
  'later': 'Later',
  'now': 'Now',
  'from': 'From',
  'to': 'To',
  'total': 'Total',
  'clear': 'Clear',
  'apply': 'Apply',
  'done_action': 'Done',
  'share': 'Share',
  'copy': 'Copy',
  'copied': 'Copied',
  'confirm': 'Confirm',
  'confirmation': 'Confirmation',
  'please_wait': 'Please wait...',
  'processing': 'Processing...',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LANGUAGE - اللغة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'language': 'Language',
  'arabic': 'العربية',
  'english': 'English',
  'change_language': 'Change Language',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CURRENCY - العملة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'egp': 'EGP',
  'aed': 'AED',
  'usd': 'USD',
  'sar': 'SAR',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // VALIDATION MESSAGES - رسائل التحقق
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'field_required': 'This field is required',
  'invalid_email': 'Invalid email address',
  'invalid_phone': 'Invalid phone number',
  'min_length': 'Minimum length is',
  'max_length': 'Maximum length is',
  'invalid_date': 'Invalid date',
  'invalid_time': 'Invalid time',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // DAYS OF WEEK - أيام الأسبوع
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'sunday': 'Sunday',
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // MONTHS - الأشهر
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'january': 'January',
  'february': 'February',
  'march': 'March',
  'april': 'April',
  'may': 'May',
  'june': 'June',
  'july': 'July',
  'august': 'August',
  'september': 'September',
  'october': 'October',
  'november': 'November',
  'december': 'December',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ADDITIONAL INFO - معلومات إضافية
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'additional_info': 'Additional Information',
  'version': 'Version',
  'about': 'About',
  'help': 'Help',
  'support': 'Support',
  'contact_us': 'Contact Us',
  'privacy_policy': 'Privacy Policy',
  'terms_of_service': 'Terms of Service',
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════════╗
// ║                             ARABIC STRINGS - النصوص العربية                            ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

final Map<String, dynamic> _arabicStrings = {
  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LOGIN PAGE - صفحة تسجيل الدخول
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'login': 'تسجيل الدخول',
  'username': 'اسم المستخدم',
  'password': 'كلمة المرور',
  'remember_me': 'تذكرني',
  'please_enter_username': 'من فضلك أدخل اسم المستخدم',
  'please_enter_password': 'من فضلك أدخل كلمة المرور',
  'signing_in': 'جاري تسجيل الدخول...',
  'invalid_credentials': 'اسم المستخدم أو كلمة المرور غير صحيحة',
  'connection_error': 'غير قادر على الاتصال بالخادم',
  'powered_by': 'مدعوم من ERP للمحاسبة والمراجعة',
  'forgot_password': 'نسيت كلمة المرور؟',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // HOME PAGE - الصفحة الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'welcome': 'مرحباً',
  'home': 'الرئيسية',
  'good_morning': 'صباح الخير',
  'good_afternoon': 'مساء الخير',
  'good_evening': 'مساء الخير',
  'todays_working_hours': 'ساعات العمل اليوم',
  'working_hours': 'ساعات العمل',
  'manage': 'إدارة',
  'quick_actions': 'إجراءات سريعة',
  'recent_activity': 'النشاط الأخير',
  'no_recent_activity': 'لا يوجد نشاط حديث',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // NAVIGATION - التنقل
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'attendance': 'الحضور',
  'leaves': 'الإجازات',
  'payslip': 'كشف الراتب',
  'payslips': 'كشوف الرواتب',
  'more': 'المزيد',
  'announcements': 'الإعلانات',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ATTENDANCE PAGE - صفحة الحضور
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'check_in': 'تسجيل الحضور',
  'check_out': 'تسجيل الانصراف',
  'checked_in': 'تم تسجيل الحضور',
  'checked_out': 'تم تسجيل الانصراف',
  'not_checked_in': 'لم يتم تسجيل الحضور',
  'attendance_history': 'سجل الحضور',
  'today': 'اليوم',
  'this_week': 'هذا الأسبوع',
  'this_month': 'هذا الشهر',
  'total_hours': 'إجمالي الساعات',
  'hours': 'ساعات',
  'minutes': 'دقائق',
  'late': 'متأخر',
  'early': 'مبكر',
  'on_time': 'في الوقت',
  'overtime': 'إضافي',
  'location_required': 'الموقع مطلوب',
  'location_required_message': 'يرجى تفعيل خدمات الموقع لتسجيل الحضور.',
  'camera_required': 'الكاميرا مطلوبة',
  'camera_required_message': 'يرجى السماح بالوصول للكاميرا لالتقاط صورة الحضور.',
  'attendance_recorded': 'تم تسجيل الحضور بنجاح',
  'attendance_failed': 'فشل في تسجيل الحضور',
  'already_checked_in': 'لقد سجلت حضورك بالفعل اليوم',
  'already_checked_out': 'لقد سجلت انصرافك بالفعل اليوم',
  'please_check_in_first': 'يرجى تسجيل الحضور أولاً',
  'outside_allowed_location': 'أنت خارج الموقع المسموح',
  'location_permission_denied': 'تم رفض صلاحية الموقع',
  'location_permission_denied_message': 'صلاحية الموقع مطلوبة لتسجيل الحضور.',
  'location_permanently_denied': 'تم رفض صلاحية الموقع نهائياً',
  'location_permanently_denied_message': 'تم رفض صلاحية الموقع نهائياً. يرجى الذهاب إلى إعدادات التطبيق.',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CONNECTION STATUS - حالة الاتصال
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'online': 'متصل',
  'offline': 'غير متصل',
  'no_internet': 'لا يوجد اتصال بالإنترنت',
  'data_synced': 'تمت مزامنة البيانات بنجاح',
  'sync_error': 'خطأ في مزامنة البيانات',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PROFILE & ACCOUNT - الملف الشخصي والحساب
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'profile': 'الملف الشخصي',
  'logout': 'تسجيل الخروج',
  'logout_confirmation': 'تأكيد تسجيل الخروج',
  'logout_message': 'هل أنت متأكد من تسجيل الخروج؟',
  'work_information': 'معلومات العمل',
  'contact_information': 'معلومات الاتصال',
  'employee_id': 'رقم الموظف',
  'job_title': 'المسمى الوظيفي',
  'department': 'القسم',
  'work_email': 'البريد الإلكتروني',
  'work_phone': 'هاتف العمل',
  'mobile_phone': 'الهاتف المحمول',
  'no_data_available': 'لا توجد بيانات متاحة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE REQUESTS PAGE - صفحة طلبات الإجازة ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'leave_requests': 'طلبات الإجازة',
  'my_leave_requests': 'طلبات إجازاتي',
  'new_request': 'طلب جديد',
  'view_details': 'عرض التفاصيل',
  'cancel_request': 'إلغاء الطلب',
  'submit_request': 'إرسال الطلب',
  'leave_type': 'نوع الإجازة',
  'start_date': 'تاريخ البداية',
  'end_date': 'تاريخ النهاية',
  'date_from': 'من تاريخ',
  'date_to': 'إلى تاريخ',
  'reason': 'السبب',
  'status': 'الحالة',
  'duration': 'المدة',
  'days': 'أيام',
  'day': 'يوم',
  'half_day': 'نصف يوم',
  'no_requests': 'لا توجد طلبات',
  'no_leave_requests': 'لا توجد طلبات إجازة',
  'tap_to_create': 'اضغط على الزر أدناه لإنشاء طلب إجازة جديد.',
  'data_synced_successfully': 'تمت مزامنة البيانات بنجاح',
  'cancel_request_title': 'إلغاء الطلب',
  'cancel_request_message': 'هل أنت متأكد من إلغاء هذا الطلب؟',
  'request_cancelled': 'تم إلغاء الطلب بنجاح',
  'failed_to_cancel': 'فشل في الإلغاء',
  'number_of_days': 'عدد الأيام',
  'requested_days': 'الأيام المطلوبة',
  'leave_balance': 'رصيد الإجازات',
  'remaining_balance': 'الرصيد المتبقي',
  'used': 'المستخدم',
  'remaining': 'المتبقي',
  'available': 'المتاح',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE TYPES - أنواع الإجازات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'sick_leave': 'إجازة مرضية',
  'annual_leave': 'إجازة سنوية',
  'emergency_leave': 'إجازة طارئة',
  'unpaid_leave': 'إجازة بدون راتب',
  'paid_time_off': 'إجازة مدفوعة',
  'maternity_leave': 'إجازة أمومة',
  'paternity_leave': 'إجازة أبوة',
  'compensatory_leave': 'إجازة تعويضية',
  'bereavement_leave': 'إجازة وفاة',
  'study_leave': 'إجازة دراسية',
  'casual_leave': 'إجازة عارضة',
  'marriage_leave': 'إجازة زواج',
  'hajj_leave': 'إجازة حج',
  'personal_leave': 'إجازة شخصية',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE STATUS - حالات الإجازة ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'pending': 'قيد الانتظار',
  'approved': 'موافق عليها',
  'rejected': 'مرفوضة',
  'refused': 'مرفوضة',
  'cancelled': 'ملغاة',
  'all': 'الكل',
  'draft': 'مسودة',
  'confirm': 'بانتظار الموافقة',
  'validate': 'موافق عليها',
  'validate1': 'الموافقة الأولى',
  'refuse': 'مرفوضة',
  'cancel': 'ملغاة',
  'waiting_approval': 'بانتظار الموافقة',
  'under_review': 'قيد المراجعة',
  'first_approval': 'الموافقة الأولى',
  'second_approval': 'الموافقة الثانية',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE BALANCE SCREEN - شاشة رصيد الإجازات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'overall_summary': 'الملخص العام',
  'allocated': 'المخصص',
  'usage_rate': 'معدل الاستخدام',
  'details_by_leave_type': 'التفاصيل حسب نوع الإجازة',
  'no_leave_data_available': 'لا توجد بيانات إجازات',
  'error_loading_leave_balance': 'خطأ في تحميل رصيد الإجازات',
  'unable_to_load_data': 'غير قادر على تحميل البيانات',
  'tap_to_try_again': 'اضغط للمحاولة مرة أخرى',
  'total_allocated': 'إجمالي المخصص',
  'total_used': 'إجمالي المستخدم',
  'total_remaining': 'إجمالي المتبقي',
  'no_allocation': 'لا يوجد تخصيص',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // NEW LEAVE REQUEST SCREEN - شاشة طلب إجازة جديد ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'new_leave_request': 'طلب إجازة جديد',
  'create_leave_request': 'إنشاء طلب إجازة',
  'select_leave_type': 'اختر نوع الإجازة',
  'choose_leave_type': 'اختر نوع الإجازة',
  'enter_reason': 'أدخل السبب (اختياري)',
  'reason_optional': 'السبب (اختياري)',
  'reason_placeholder': 'أدخل سبب طلب الإجازة...',
  'please_select_leave_type': 'من فضلك اختر نوع الإجازة',
  'please_select_start_date': 'من فضلك اختر تاريخ البداية',
  'please_select_end_date': 'من فضلك اختر تاريخ النهاية',
  'end_date_before_start': 'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية',
  'request_submitted': 'تم إرسال طلب الإجازة بنجاح',
  'failed_to_submit': 'فشل في إرسال الطلب',
  'submitting': 'جاري الإرسال...',
  'creating_request': 'جاري إنشاء الطلب...',
  'calculated_days': 'الأيام المحسوبة',
  'insufficient_balance': 'رصيد غير كافي',
  'insufficient_balance_message': 'ليس لديك رصيد كافي لهذا الطلب',
  'overlapping_request': 'طلب متداخل',
  'overlapping_request_message': 'لديك طلب إجازة خلال هذه الفترة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LEAVE REQUEST DETAILS SCREEN - شاشة تفاصيل طلب الإجازة ✅ جديد
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'request_details': 'تفاصيل الطلب',
  'leave_request_details': 'تفاصيل طلب الإجازة',
  'request_info': 'معلومات الطلب',
  'request_information': 'معلومات الطلب',
  'requested_on': 'تاريخ الطلب',
  'created_date': 'تاريخ الإنشاء',
  'submission_date': 'تاريخ التقديم',
  'manager_comment': 'تعليق المدير',
  'manager_notes': 'ملاحظات المدير',
  'approver_comment': 'تعليق المعتمد',
  'no_comment': 'لا يوجد تعليق',
  'no_notes': 'لا توجد ملاحظات',
  'approval_info': 'معلومات الاعتماد',
  'approval_details': 'تفاصيل الاعتماد',
  'approved_by': 'تمت الموافقة بواسطة',
  'rejected_by': 'تم الرفض بواسطة',
  'approval_date': 'تاريخ الموافقة',
  'rejection_date': 'تاريخ الرفض',
  'approver_name': 'اسم المعتمد',
  'can_cancel': 'يمكن الإلغاء',
  'can_edit': 'يمكن التعديل',
  'edit_request': 'تعديل الطلب',
  'request_id': 'رقم الطلب',
  'employee_name': 'اسم الموظف',
  'request_status': 'حالة الطلب',
  'period': 'الفترة',
  'leave_period': 'فترة الإجازة',
  'request_reason': 'سبب الطلب',
  'additional_notes': 'ملاحظات إضافية',
  'timeline': 'الجدول الزمني',
  'request_timeline': 'الجدول الزمني للطلب',
  'request_created': 'تم إنشاء الطلب',
  'request_submitted': 'تم تقديم الطلب',
  'request_approved': 'تمت الموافقة على الطلب',
  'request_rejected': 'تم رفض الطلب',
  'pending_approval': 'بانتظار الموافقة',
  'actions': 'الإجراءات',
  'available_actions': 'الإجراءات المتاحة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PAYSLIP PAGE - صفحة كشف الراتب ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'payslip_details': 'تفاصيل كشف الراتب',
  'my_payslips': 'كشوف رواتبي',
  'salary': 'الراتب',
  'basic_salary': 'الراتب الأساسي',
  'gross_salary': 'إجمالي الراتب',
  'net_salary': 'صافي الراتب',
  'allowances': 'البدلات',
  'deductions': 'الخصومات',
  'earnings': 'المكتسبات',
  'taxes': 'الضرائب',
  'bonus': 'المكافأة',
  'pay_period': 'فترة الراتب',
  'payment_date': 'تاريخ الدفع',
  'download_payslip': 'تحميل كشف الراتب',
  'no_payslips': 'لا توجد كشوف رواتب',
  'no_payslips_message': 'لا توجد كشوف رواتب متاحة لهذه الفترة',
  'paid': 'مدفوع',
  'unpaid': 'غير مدفوع',
  'processing': 'قيد المعالجة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS PAGE - صفحة الإعلانات ✅ محدث
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'announcement_details': 'تفاصيل الإعلان',
  'no_announcements': 'لا توجد إعلانات',
  'no_announcements_message': 'لا توجد إعلانات في الوقت الحالي',
  'read': 'مقروء',
  'unread': 'غير مقروء',
  'mark_as_read': 'تحديد كمقروء',
  'mark_all_read': 'تحديد الكل كمقروء',
  'pinned': 'مثبت',
  'important': 'مهم',
  'urgent': 'عاجل',
  'general': 'عام',
  'attachments': 'المرفقات',
  'no_attachments': 'لا توجد مرفقات',
  'published_on': 'تاريخ النشر',
  'published_by': 'نشر بواسطة',
  'valid_until': 'صالح حتى',
  'target_audience': 'الفئة المستهدفة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // GENERAL / COMMON - عام / مشترك
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'error': 'خطأ',
  'success': 'نجاح',
  'warning': 'تحذير',
  'info': 'معلومة',
  'ok': 'موافق',
  'yes': 'نعم',
  'no': 'لا',
  'save': 'حفظ',
  'delete': 'حذف',
  'edit': 'تعديل',
  'add': 'إضافة',
  'close': 'إغلاق',
  'cancel': 'إلغاء',
  'search': 'بحث',
  'filter': 'تصفية',
  'sort': 'ترتيب',
  'retry': 'إعادة المحاولة',
  'refresh': 'تحديث',
  'loading': 'جاري التحميل...',
  'loading_data': 'جاري تحميل البيانات...',
  'no_data': 'لا توجد بيانات',
  'error_occurred': 'حدث خطأ',
  'error_loading_data': 'خطأ في تحميل البيانات',
  'try_again': 'حاول مرة أخرى',
  'notes': 'ملاحظات',
  'details': 'التفاصيل',
  'view': 'عرض',
  'back': 'رجوع',
  'next': 'التالي',
  'previous': 'السابق',
  'submit': 'إرسال',
  'update': 'تحديث',
  'create': 'إنشاء',
  'select': 'اختيار',
  'select_date': 'اختر التاريخ',
  'select_time': 'اختر الوقت',
  'required': 'مطلوب',
  'optional': 'اختياري',
  'settings': 'الإعدادات',
  'open_settings': 'فتح الإعدادات',
  'allow': 'السماح',
  'deny': 'رفض',
  'later': 'لاحقاً',
  'now': 'الآن',
  'from': 'من',
  'to': 'إلى',
  'total': 'المجموع',
  'clear': 'مسح',
  'apply': 'تطبيق',
  'done_action': 'تم',
  'share': 'مشاركة',
  'copy': 'نسخ',
  'copied': 'تم النسخ',
  'confirm': 'تأكيد',
  'confirmation': 'تأكيد',
  'please_wait': 'يرجى الانتظار...',
  'processing': 'جاري المعالجة...',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LANGUAGE - اللغة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'language': 'اللغة',
  'arabic': 'العربية',
  'english': 'English',
  'change_language': 'تغيير اللغة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CURRENCY - العملة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'egp': 'جنيه',
  'aed': 'درهم',
  'usd': 'دولار',
  'sar': 'ريال',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // VALIDATION MESSAGES - رسائل التحقق
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'field_required': 'هذا الحقل مطلوب',
  'invalid_email': 'البريد الإلكتروني غير صحيح',
  'invalid_phone': 'رقم الهاتف غير صحيح',
  'min_length': 'الحد الأدنى للطول هو',
  'max_length': 'الحد الأقصى للطول هو',
  'invalid_date': 'التاريخ غير صحيح',
  'invalid_time': 'الوقت غير صحيح',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // DAYS OF WEEK - أيام الأسبوع
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'sunday': 'الأحد',
  'monday': 'الإثنين',
  'tuesday': 'الثلاثاء',
  'wednesday': 'الأربعاء',
  'thursday': 'الخميس',
  'friday': 'الجمعة',
  'saturday': 'السبت',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // MONTHS - الأشهر
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'january': 'يناير',
  'february': 'فبراير',
  'march': 'مارس',
  'april': 'أبريل',
  'may': 'مايو',
  'june': 'يونيو',
  'july': 'يوليو',
  'august': 'أغسطس',
  'september': 'سبتمبر',
  'october': 'أكتوبر',
  'november': 'نوفمبر',
  'december': 'ديسمبر',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ADDITIONAL INFO - معلومات إضافية
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'additional_info': 'معلومات إضافية',
  'version': 'الإصدار',
  'about': 'حول التطبيق',
  'help': 'المساعدة',
  'support': 'الدعم',
  'contact_us': 'اتصل بنا',
  'privacy_policy': 'سياسة الخصوصية',
  'terms_of_service': 'شروط الخدمة',
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// Extension للسهولة في الاستخدام
// ═══════════════════════════════════════════════════════════════════════════════════════
extension LanguageExtension on BuildContext {
  LanguageManager get lang => LanguageManager();
  String translate(String key) => LanguageManager().translate(key);
  bool get isArabic => LanguageManager().isArabic;
}