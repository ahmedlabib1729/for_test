// lib/pages/requests_screen.dart
// شاشة طلبات الإجازات - تصميم جديد مع الحفاظ على الأساسيات
// مترجم بالكامل عربي/إنجليزي

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/leave_request.dart';
import '../services/odoo_service.dart';
import '../services/offline_manager.dart';
import '../services/connectivity_service.dart';
import '../services/language_manager.dart';
import 'new_leave_request_screen.dart';
import 'leave_request_details_screen.dart';

class RequestsScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const RequestsScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _RequestsScreenState createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {

  // ═══════════════════════════════════════════════════════════════
  // نظام الألوان الموحد
  // ═══════════════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF5B9BD5);
  static const Color darkBlue = Color(0xFF2B579A);
  static const Color lightBlue = Color(0xFFE8F4FC);
  static const Color textDark = Color(0xFF1E3A5F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color bgGradientStart = Color(0xFFF0F7FF);
  static const Color bgGradientEnd = Color(0xFFE1EFFF);
  static const Color cardWhite = Colors.white;
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color dangerRed = Color(0xFFFF3B30);

  // ═══════════════════════════════════════════════════════════════
  // المتغيرات الأساسية - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  late TabController _tabController;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();

  List<LeaveRequest> allRequests = [];
  List<LeaveRequest> pendingRequests = [];
  List<LeaveRequest> approvedRequests = [];
  List<LeaveRequest> rejectedRequests = [];

  bool isLoading = true;
  bool isOnline = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _connectivityService.connectionStatusStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          isOnline = isConnected;
        });
        if (isConnected) _syncData();
      }
    });

    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // الدوال الأساسية - بدون تغيير
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadRequests() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      List<LeaveRequest> requests;

      if (isOnline) {
        requests = await widget.odooService.getLeaveRequests(widget.employee.id);
        await _offlineManager.saveLeaveRequests(requests);
      } else {
        requests = await _offlineManager.getOfflineLeaveRequests(widget.employee.id);
      }

      _categorizeRequests(requests);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      final lang = LanguageManager();
      setState(() {
        isLoading = false;
        errorMessage = lang.isArabic
            ? 'خطأ في تحميل الطلبات: ${e.toString()}'
            : 'Error loading requests: ${e.toString()}';
      });
    }
  }

  void _categorizeRequests(List<LeaveRequest> requests) {
    allRequests = requests;
    pendingRequests = requests.where((r) => r.state == 'draft' || r.state == 'confirm').toList();
    approvedRequests = requests.where((r) => r.state == 'validate' || r.state == 'validate1').toList();
    rejectedRequests = requests.where((r) => r.state == 'refuse').toList();
  }

  Future<void> _syncData() async {
    if (!isOnline) return;

    try {
      await _offlineManager.syncPendingLeaveRequests();
      await _loadRequests();
      if (mounted) {
        final lang = LanguageManager();
        _showSnackBar(
          lang.isArabic ? 'تمت مزامنة البيانات بنجاح' : 'Data synced successfully',
          isSuccess: true,
        );
      }
    } catch (e) {}
  }

  Future<void> _createNewRequest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewLeaveRequestScreen(
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    );
    if (result == true) {
      _loadRequests();
    }
  }

  void _viewRequestDetails(LeaveRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveRequestDetailsScreen(
          request: request,
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    ).then((_) => _loadRequests());
  }

  Future<void> _cancelRequest(LeaveRequest request) async {
    final lang = LanguageManager();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: warningOrange),
            SizedBox(width: 12),
            Text(lang.isArabic ? 'إلغاء الطلب' : 'Cancel Request'),
          ],
        ),
        content: Text(lang.isArabic
            ? 'هل أنت متأكد من إلغاء هذا الطلب؟'
            : 'Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(lang.isArabic ? 'لا' : 'No', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              lang.isArabic ? 'نعم، إلغاء' : 'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.odooService.cancelLeaveRequest(request.id);
        _showSnackBar(
          lang.isArabic ? 'تم إلغاء الطلب بنجاح' : 'Request cancelled successfully',
          isSuccess: true,
        );
        _loadRequests();
      } catch (e) {
        _showSnackBar(
          '${lang.isArabic ? 'فشل في الإلغاء' : 'Failed to cancel'}: $e',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : isError ? Icons.error : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? successGreen : isError ? dangerRed : primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageManager();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradientStart, bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(lang),
              _buildStatusChips(lang),
              _buildTabBar(lang),
              Expanded(
                child: isLoading
                    ? _buildLoadingState(lang)
                    : errorMessage != null
                    ? _buildErrorWidget(lang)
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(allRequests, lang),
                    _buildRequestsList(pendingRequests, lang),
                    _buildRequestsList(approvedRequests, lang),
                    _buildRequestsList(rejectedRequests, lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(lang),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI Components
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new, color: textDark, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              lang.isArabic ? 'طلبات الإجازة' : 'Leave Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _loadRequests,
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.refresh_rounded, color: primaryBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(LanguageManager lang) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (!isOnline)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dangerRed.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: dangerRed, size: 16),
                  SizedBox(width: 6),
                  Text(
                    lang.isArabic ? 'وضع عدم الاتصال' : 'Offline Mode',
                    style: TextStyle(
                      color: dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(LanguageManager lang) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textGrey,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: EdgeInsets.all(6),
        tabs: [
          _buildTab(lang.isArabic ? 'الكل' : 'All', allRequests.length, Icons.list_alt_rounded),
          _buildTab(lang.isArabic ? 'قيد الانتظار' : 'Pending', pendingRequests.length, Icons.schedule_rounded),
          _buildTab(lang.isArabic ? 'موافق عليها' : 'Approved', approvedRequests.length, Icons.check_circle_rounded),
          _buildTab(lang.isArabic ? 'مرفوضة' : 'Rejected', rejectedRequests.length, Icons.cancel_rounded),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int count, IconData icon) {
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            SizedBox(width: 6),
            Text('$text ($count)'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(LanguageManager lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            lang.isArabic ? 'جاري تحميل الطلبات...' : 'Loading requests...',
            style: TextStyle(
              fontSize: 16,
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(LanguageManager lang) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 56, color: dangerRed),
            ),
            SizedBox(height: 24),
            Text(
              lang.isArabic ? 'فشل في تحميل الطلبات' : 'Failed to load requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage ?? (lang.isArabic ? 'خطأ غير معروف' : 'Unknown error'),
              style: TextStyle(fontSize: 14, color: textGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRequests,
              icon: Icon(Icons.refresh_rounded),
              label: Text(lang.isArabic ? 'إعادة المحاولة' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<LeaveRequest> requests, LanguageManager lang) {
    if (requests.isEmpty) {
      return _buildEmptyState(lang);
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: primaryBlue,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request, lang);
        },
      ),
    );
  }

  Widget _buildEmptyState(LanguageManager lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, size: 64, color: primaryBlue),
          ),
          SizedBox(height: 24),
          Text(
            lang.isArabic ? 'لا توجد طلبات' : 'No Requests Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            lang.isArabic
                ? 'اضغط على + لإنشاء طلب إجازة جديد'
                : 'Tap the + button to create a new leave request',
            style: TextStyle(fontSize: 14, color: textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest request, LanguageManager lang) {
    Color stateColor;
    IconData stateIcon;
    String stateText;

    switch (request.state) {
      case 'draft':
        stateColor = textGrey;
        stateIcon = Icons.edit_rounded;
        stateText = lang.isArabic ? 'مسودة' : 'Draft';
        break;
      case 'confirm':
        stateColor = warningOrange;
        stateIcon = Icons.schedule_rounded;
        stateText = lang.isArabic ? 'قيد الانتظار' : 'Pending';
        break;
      case 'validate':
      case 'validate1':
        stateColor = successGreen;
        stateIcon = Icons.check_circle_rounded;
        stateText = lang.isArabic ? 'موافق عليها' : 'Approved';
        break;
      case 'refuse':
        stateColor = dangerRed;
        stateIcon = Icons.cancel_rounded;
        stateText = lang.isArabic ? 'مرفوضة' : 'Rejected';
        break;
      default:
        stateColor = textGrey;
        stateIcon = Icons.help_rounded;
        stateText = request.state;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewRequestDetails(request),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.beach_access_rounded, color: primaryBlue, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.leaveTypeName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            lang.isArabic
                                ? '${request.numberOfDays.toStringAsFixed(0)} ${request.numberOfDays == 1 ? 'يوم' : 'أيام'}'
                                : '${request.numberOfDays.toStringAsFixed(0)} day(s)',
                            style: TextStyle(
                              fontSize: 13,
                              color: textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(stateIcon, size: 14, color: stateColor),
                          SizedBox(width: 4),
                          Text(
                            stateText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: stateColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Date Range
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.isArabic ? 'من' : 'From',
                                  style: TextStyle(fontSize: 11, color: textGrey),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(request.dateFrom),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward_rounded, size: 20, color: primaryBlue),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded, size: 16, color: darkBlue),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.isArabic ? 'إلى' : 'To',
                                  style: TextStyle(fontSize: 11, color: textGrey),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(request.dateTo),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions for pending requests
                if (request.state == 'draft' || request.state == 'confirm')
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _cancelRequest(request),
                          icon: Icon(Icons.close_rounded, size: 18),
                          label: Text(lang.isArabic ? 'إلغاء' : 'Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: dangerRed,
                          ),
                        ),
                        SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _viewRequestDetails(request),
                          icon: Icon(Icons.visibility_rounded, size: 18),
                          label: Text(lang.isArabic ? 'عرض' : 'View'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(LanguageManager lang) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _createNewRequest,
        backgroundColor: primaryBlue,
        elevation: 0,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          lang.isArabic ? 'طلب جديد' : 'New Request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}