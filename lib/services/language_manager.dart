// lib/services/language_manager.dart
// ملف الترجمة الكامل والشامل للتطبيق
// Complete Translation File for HR Mobile App
// تاريخ التحديث: 2025-12-07

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
  'todays_working_hours': "Today's Working Hours",
  'working_hours': 'Working Hours',
  'manage_attendance': 'Manage Attendance',
  'services': 'Services',
  'quick_actions': 'Quick Actions',
  'leave_balance': 'Leave Balance',
  'remaining': 'Remaining',
  'used': 'Used',
  'usage': 'Usage',
  'request_time_off': 'Request time off',
  'company_news': 'Company news',
  'view_salary': 'View salary',
  'events_holidays': 'Events & holidays',
  'today': 'Today',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ATTENDANCE PAGE - صفحة الحضور والانصراف
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'attendance': 'Attendance',
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'check_in_time': 'Check-in time',
  'check_out_time': 'Check-out time',
  'you_are_checked_in': 'You are checked in ✓',
  'you_are_not_checked_in': 'You are not checked in yet',
  'attendance_records': 'Attendance Records',
  'no_records': 'No records',
  'active': 'Active',
  'in': 'In',
  'out': 'Out',
  'check_in_successful': 'Check-in successful',
  'check_out_successful': 'Check-out successful',
  'check_in_failed': 'Check-in failed',
  'check_out_failed': 'Check-out failed',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LOCATION - الموقع
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'location': 'Location',
  'location_determined': 'Location determined',
  'determining_location': 'Determining location...',
  'location_service_disabled': 'Location service disabled',
  'location_permission_denied': 'Location permission denied',
  'location_permanently_denied': 'Location permanently denied',
  'location_error': 'Location error',
  'failed_to_get_location': 'Failed to get location',
  'location_required': 'Location service and permissions required',
  'location_not_determined': 'Location not determined, try again',
  'location_permission_required': 'Location Permission Required',
  'location_permission_message': 'The app needs location permission to record attendance.',
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
  // LEAVE REQUESTS PAGE - صفحة طلبات الإجازة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'leaves': 'Leaves',
  'leave_requests': 'Leave Requests',
  'new_request': 'New Request',
  'view_details': 'View Details',
  'cancel_request': 'Cancel Request',
  'submit_request': 'Submit Request',
  'leave_type': 'Leave Type',
  'start_date': 'Start Date',
  'end_date': 'End Date',
  'reason': 'Reason',
  'status': 'Status',
  'duration': 'Duration',
  'days': 'Days',
  'day': 'Day',
  'half_day': 'Half Day',
  'no_requests': 'No Requests',
  'tap_to_create': 'Tap the button below to create a new leave request.',
  'data_synced_successfully': 'Data synced successfully',
  'cancel_request_title': 'Cancel Request',
  'cancel_request_message': 'Are you sure you want to cancel this request?',
  'request_cancelled': 'Request cancelled successfully',
  'failed_to_cancel': 'Failed to cancel',

  // Leave Types - أنواع الإجازات
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

  // Leave Status - حالات الإجازة
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'cancelled': 'Cancelled',
  'all': 'All',
  'draft': 'Draft',
  'confirm': 'Confirm',
  'validate': 'Validate',
  'refuse': 'Refuse',

  // Leave Balance Screen - شاشة رصيد الإجازات
  'overall_summary': 'Overall Summary',
  'allocated': 'Allocated',
  'usage_rate': 'Usage Rate',
  'details_by_leave_type': 'Details by Leave Type',
  'no_leave_data_available': 'No leave data available',
  'error_loading_leave_balance': 'Error loading leave balance',
  'unable_to_load_data': 'Unable to load data',
  'tap_to_try_again': 'Tap to try again',

  // New Leave Request Screen - شاشة طلب إجازة جديد
  'new_leave_request': 'New Leave Request',
  'select_leave_type': 'Select Leave Type',
  'enter_reason': 'Enter reason (optional)',
  'please_select_leave_type': 'Please select a leave type',
  'please_select_start_date': 'Please select start date',
  'please_select_end_date': 'Please select end date',
  'end_date_before_start': 'End date cannot be before start date',
  'request_submitted': 'Leave request submitted successfully',
  'failed_to_submit': 'Failed to submit request',
  'submitting': 'Submitting...',

  // Leave Request Details Screen - شاشة تفاصيل طلب الإجازة
  'request_details': 'Request Details',
  'request_info': 'Request Information',
  'requested_on': 'Requested On',
  'manager_comment': 'Manager Comment',
  'no_comment': 'No comment',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS PAGE - صفحة الإعلانات
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'announcements': 'Announcements',
  'search_announcements': 'Search announcements...',
  'no_announcements': 'No announcements available',
  'no_announcements_found': 'No announcements found',
  'announcement_details': 'Announcement Details',
  'published_date': 'Published Date',
  'important': 'Important',
  'mark_as_read': 'Mark as Read',
  'unread': 'Unread',
  'new': 'New',
  'author': 'Author',
  'attachments': 'Attachments',
  'failed_to_load_announcements': 'Failed to load announcements',
  'pinned': 'Pinned',
  'priority': 'Priority',
  'high_priority': 'High Priority',
  'urgent': 'Urgent',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PAYSLIPS PAGE - صفحة كشوف المرتبات
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'payslips': 'Payslips',
  'payslip': 'Payslip',
  'payslip_details': 'Payslip Details',
  'salary_summary': 'Salary Summary',
  'salary_breakdown': 'Salary Breakdown',
  'basic_salary': 'Basic Salary',
  'gross_salary': 'Gross Salary',
  'net_salary': 'Net Salary',
  'allowances': 'Allowances',
  'deductions': 'Deductions',
  'total_allowances': 'Total Allowances',
  'total_deductions': 'Total Deductions',
  'housing_allowance': 'Housing Allowance',
  'transportation_allowance': 'Transportation Allowance',
  'food_allowance': 'Food Allowance',
  'phone_allowance': 'Phone Allowance',
  'other_allowances': 'Other Allowances',
  'social_insurance': 'Social Insurance',
  'taxes': 'Taxes',
  'loans': 'Loans',
  'absence_deduction': 'Absence Deduction',
  'other_deductions': 'Other Deductions',
  'total_received': 'Total Received',
  'average_salary': 'Average Salary',
  'last_payment': 'Last Payment',
  'payment_date': 'Payment Date',
  'working_days': 'Working Days',
  'period': 'Period',
  'bank': 'Bank',
  'account': 'Account',
  'download': 'Download',
  'download_failed': 'Download failed',
  'no_payslips': 'No payslips found',
  'paid': 'Paid',
  'under_review': 'Under Review',
  'done': 'Done',
  'verify': 'Verify',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CALENDAR & APPOINTMENTS - التقويم والمواعيد
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'calendar': 'Calendar',
  'appointment': 'Appointment',
  'appointments': 'Appointments',
  'appointment_details': 'Appointment Details',
  'add_appointment': 'Add Appointment',
  'new_appointment': 'New Appointment',
  'edit_appointment': 'Edit Appointment',
  'delete_appointment': 'Delete Appointment',
  'no_appointments_today': 'No appointments today',
  'title': 'Title',
  'description': 'Description',
  'date': 'Date',
  'time': 'Time',
  'date_time': 'Date & Time',
  'notifications': 'Notifications',
  'reminder': 'Reminder',
  'completed': 'Completed',
  'mark_as_completed': 'Mark as Completed',
  'unmark_completed': 'Unmark as Completed',
  'appointment_title': 'Appointment Title',
  'please_enter_title': 'Please enter appointment title',
  'please_enter_description': 'Please enter description',
  'location_optional': 'Location (optional)',
  'appointment_color': 'Appointment Color',
  'enable_notifications': 'Enable Notifications',
  'remind_before': 'Remind before:',
  'notes_optional': 'Notes (optional)',
  'save_changes': 'Save Changes',
  'add_the_appointment': 'Add Appointment',
  'error_occurred_with': 'Error occurred:',
  'confirm_delete': 'Confirm Delete',
  'delete_appointment_message': 'Are you sure you want to delete this appointment?',
  'appointment_marked_completed': 'Appointment marked as completed',
  'appointment_unmarked': 'Appointment unmarked as completed',
  'notifications_enabled': 'Notifications enabled',
  'notifications_disabled': 'Notifications disabled',

  // Calendar Formats - تنسيقات التقويم
  'month': 'Month',
  'week': 'Week',
  'two_weeks': 'Two Weeks',

  // Time Units - وحدات الوقت
  'minutes': 'minutes',
  'minute': 'minute',
  'hour': 'hour',
  'hours': 'hours',
  'one_hour': '1 hour',
  'two_hours': '2 hours',
  'one_day': '1 day',

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
  'no_data': 'No data available',
  'error_occurred': 'Error occurred',
  'error_loading_data': 'Error loading data',
  'try_again': 'Try again',
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
  'manage_attendance': 'إدارة الحضور',
  'services': 'الخدمات',
  'quick_actions': 'إجراءات سريعة',
  'leave_balance': 'رصيد الإجازات',
  'remaining': 'متبقي',
  'used': 'مستخدم',
  'usage': 'النسبة',
  'request_time_off': 'طلب إجازة جديدة',
  'company_news': 'آخر الأخبار',
  'view_salary': 'كشف المرتبات',
  'events_holidays': 'الأحداث والإجازات',
  'today': 'اليوم',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ATTENDANCE PAGE - صفحة الحضور والانصراف
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'attendance': 'الحضور',
  'check_in': 'تسجيل الحضور',
  'check_out': 'تسجيل الانصراف',
  'check_in_time': 'وقت الحضور',
  'check_out_time': 'وقت الانصراف',
  'you_are_checked_in': 'أنت مسجل حضور ✓',
  'you_are_not_checked_in': 'لم تسجل الحضور بعد',
  'attendance_records': 'سجل الحضور',
  'no_records': 'لا توجد سجلات',
  'active': 'نشط',
  'in': 'دخول',
  'out': 'خروج',
  'check_in_successful': 'تم تسجيل الحضور بنجاح',
  'check_out_successful': 'تم تسجيل الانصراف بنجاح',
  'check_in_failed': 'فشل تسجيل الحضور',
  'check_out_failed': 'فشل تسجيل الانصراف',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LOCATION - الموقع
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'location': 'الموقع',
  'location_determined': 'تم تحديد الموقع',
  'determining_location': 'جاري تحديد الموقع...',
  'location_service_disabled': 'خدمة الموقع غير مفعلة',
  'location_permission_denied': 'صلاحية الموقع مرفوضة',
  'location_permanently_denied': 'صلاحية الموقع مرفوضة نهائياً',
  'location_error': 'خطأ في تحديد الموقع',
  'failed_to_get_location': 'فشل تحديد الموقع',
  'location_required': 'يجب تفعيل خدمة الموقع والصلاحيات',
  'location_not_determined': 'لم يتم تحديد الموقع، حاول مرة أخرى',
  'location_permission_required': 'صلاحية الموقع مطلوبة',
  'location_permission_message': 'يحتاج التطبيق لصلاحية الوصول للموقع لتسجيل الحضور والانصراف.',
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
  // LEAVE REQUESTS PAGE - صفحة طلبات الإجازة
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'leaves': 'الإجازات',
  'leave_requests': 'طلبات الإجازة',
  'new_request': 'طلب جديد',
  'view_details': 'عرض التفاصيل',
  'cancel_request': 'إلغاء الطلب',
  'submit_request': 'إرسال الطلب',
  'leave_type': 'نوع الإجازة',
  'start_date': 'تاريخ البداية',
  'end_date': 'تاريخ النهاية',
  'reason': 'السبب',
  'status': 'الحالة',
  'duration': 'المدة',
  'days': 'أيام',
  'day': 'يوم',
  'half_day': 'نصف يوم',
  'no_requests': 'لا توجد طلبات',
  'tap_to_create': 'اضغط على الزر أدناه لإنشاء طلب إجازة جديد.',
  'data_synced_successfully': 'تمت مزامنة البيانات بنجاح',
  'cancel_request_title': 'إلغاء الطلب',
  'cancel_request_message': 'هل أنت متأكد من إلغاء هذا الطلب؟',
  'request_cancelled': 'تم إلغاء الطلب بنجاح',
  'failed_to_cancel': 'فشل في الإلغاء',

  // Leave Types - أنواع الإجازات
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

  // Leave Status - حالات الإجازة
  'pending': 'قيد الانتظار',
  'approved': 'موافق عليها',
  'rejected': 'مرفوضة',
  'cancelled': 'ملغاة',
  'all': 'الكل',
  'draft': 'مسودة',
  'confirm': 'تأكيد',
  'validate': 'اعتماد',
  'refuse': 'رفض',

  // Leave Balance Screen - شاشة رصيد الإجازات
  'overall_summary': 'الملخص العام',
  'allocated': 'المخصص',
  'usage_rate': 'معدل الاستخدام',
  'details_by_leave_type': 'التفاصيل حسب نوع الإجازة',
  'no_leave_data_available': 'لا توجد بيانات إجازات',
  'error_loading_leave_balance': 'خطأ في تحميل رصيد الإجازات',
  'unable_to_load_data': 'غير قادر على تحميل البيانات',
  'tap_to_try_again': 'اضغط للمحاولة مرة أخرى',

  // New Leave Request Screen - شاشة طلب إجازة جديد
  'new_leave_request': 'طلب إجازة جديد',
  'select_leave_type': 'اختر نوع الإجازة',
  'enter_reason': 'أدخل السبب (اختياري)',
  'please_select_leave_type': 'من فضلك اختر نوع الإجازة',
  'please_select_start_date': 'من فضلك اختر تاريخ البداية',
  'please_select_end_date': 'من فضلك اختر تاريخ النهاية',
  'end_date_before_start': 'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية',
  'request_submitted': 'تم إرسال طلب الإجازة بنجاح',
  'failed_to_submit': 'فشل في إرسال الطلب',
  'submitting': 'جاري الإرسال...',

  // Leave Request Details Screen - شاشة تفاصيل طلب الإجازة
  'request_details': 'تفاصيل الطلب',
  'request_info': 'معلومات الطلب',
  'requested_on': 'تاريخ الطلب',
  'manager_comment': 'تعليق المدير',
  'no_comment': 'لا يوجد تعليق',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS PAGE - صفحة الإعلانات
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'announcements': 'الإعلانات',
  'search_announcements': 'البحث في الإعلانات...',
  'no_announcements': 'لا توجد إعلانات',
  'no_announcements_found': 'لا توجد إعلانات',
  'announcement_details': 'تفاصيل الإعلان',
  'published_date': 'تاريخ النشر',
  'important': 'مهم',
  'mark_as_read': 'وضع كمقروء',
  'unread': 'غير مقروء',
  'new': 'جديد',
  'author': 'الكاتب',
  'attachments': 'المرفقات',
  'failed_to_load_announcements': 'فشل تحميل الإعلانات',
  'pinned': 'مثبت',
  'priority': 'الأولوية',
  'high_priority': 'أولوية عالية',
  'urgent': 'عاجل',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // PAYSLIPS PAGE - صفحة كشوف المرتبات
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'payslips': 'كشوف المرتبات',
  'payslip': 'كشف المرتب',
  'payslip_details': 'تفاصيل كشف المرتب',
  'salary_summary': 'ملخص الراتب',
  'salary_breakdown': 'تفصيل الراتب',
  'basic_salary': 'الراتب الأساسي',
  'gross_salary': 'إجمالي الراتب',
  'net_salary': 'صافي الراتب',
  'allowances': 'البدلات',
  'deductions': 'الخصومات',
  'total_allowances': 'إجمالي البدلات',
  'total_deductions': 'إجمالي الخصومات',
  'housing_allowance': 'بدل السكن',
  'transportation_allowance': 'بدل المواصلات',
  'food_allowance': 'بدل الطعام',
  'phone_allowance': 'بدل الهاتف',
  'other_allowances': 'بدلات أخرى',
  'social_insurance': 'التأمينات الاجتماعية',
  'taxes': 'الضرائب',
  'loans': 'السلف',
  'absence_deduction': 'خصم الغياب',
  'other_deductions': 'خصومات أخرى',
  'total_received': 'إجمالي المستلم',
  'average_salary': 'متوسط الراتب',
  'last_payment': 'آخر دفعة',
  'payment_date': 'تاريخ الدفع',
  'working_days': 'أيام العمل',
  'period': 'الفترة',
  'bank': 'البنك',
  'account': 'الحساب',
  'download': 'تحميل',
  'download_failed': 'فشل التحميل',
  'no_payslips': 'لا توجد كشوف مرتبات',
  'paid': 'مدفوع',
  'under_review': 'قيد المراجعة',
  'done': 'مكتمل',
  'verify': 'مراجعة',

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CALENDAR & APPOINTMENTS - التقويم والمواعيد
  // ═══════════════════════════════════════════════════════════════════════════════════════
  'calendar': 'التقويم',
  'appointment': 'موعد',
  'appointments': 'المواعيد',
  'appointment_details': 'تفاصيل الموعد',
  'add_appointment': 'إضافة موعد',
  'new_appointment': 'موعد جديد',
  'edit_appointment': 'تعديل الموعد',
  'delete_appointment': 'حذف الموعد',
  'no_appointments_today': 'لا توجد مواعيد في هذا اليوم',
  'title': 'العنوان',
  'description': 'الوصف',
  'date': 'التاريخ',
  'time': 'الوقت',
  'date_time': 'التاريخ والوقت',
  'notifications': 'الإشعارات',
  'reminder': 'تذكير',
  'completed': 'مكتمل',
  'mark_as_completed': 'تحديد كمكتمل',
  'unmark_completed': 'إلغاء التحديد كمكتمل',
  'appointment_title': 'عنوان الموعد',
  'please_enter_title': 'الرجاء إدخال عنوان الموعد',
  'please_enter_description': 'الرجاء إدخال وصف الموعد',
  'location_optional': 'المكان (اختياري)',
  'appointment_color': 'لون الموعد',
  'enable_notifications': 'تفعيل الإشعارات',
  'remind_before': 'التنبيه قبل الموعد بـ:',
  'notes_optional': 'ملاحظات (اختياري)',
  'save_changes': 'حفظ التعديلات',
  'add_the_appointment': 'إضافة الموعد',
  'error_occurred_with': 'حدث خطأ:',
  'confirm_delete': 'تأكيد الحذف',
  'delete_appointment_message': 'هل أنت متأكد من حذف هذا الموعد؟',
  'appointment_marked_completed': 'تم تحديد الموعد كمكتمل',
  'appointment_unmarked': 'تم إلغاء تحديد الموعد كمكتمل',
  'notifications_enabled': 'الإشعارات مفعلة',
  'notifications_disabled': 'الإشعارات مغلقة',

  // Calendar Formats - تنسيقات التقويم
  'month': 'شهر',
  'week': 'أسبوع',
  'two_weeks': 'أسبوعين',

  // Time Units - وحدات الوقت
  'minutes': 'دقيقة',
  'minute': 'دقيقة',
  'hour': 'ساعة',
  'hours': 'ساعات',
  'one_hour': 'ساعة واحدة',
  'two_hours': 'ساعتين',
  'one_day': 'يوم واحد',

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