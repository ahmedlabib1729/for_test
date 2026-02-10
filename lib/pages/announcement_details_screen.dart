// lib/pages/announcement_details_screen.dart - Modern Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/announcement.dart';
import '../services/odoo_service.dart';

class AnnouncementDetailsScreen extends StatefulWidget {
  final Announcement announcement;
  final OdooService odooService;
  final Employee employee;

  const AnnouncementDetailsScreen({
    Key? key,
    required this.announcement,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _AnnouncementDetailsScreenState createState() => _AnnouncementDetailsScreenState();
}

class _AnnouncementDetailsScreenState extends State<AnnouncementDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // Theme Colors
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primaryBlue = Color(0xFF5B9BD5);
  static const Color darkBlue = Color(0xFF2B579A);
  static const Color lightBlue = Color(0xFFE8F4FC);
  static const Color textDark = Color(0xFF1E3A5F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color bgGradientStart = Color(0xFFF0F7FF);
  static const Color bgGradientEnd = Color(0xFFE1EFFF);
  static const Color cardWhite = Colors.white;
  static const Color urgentRed = Color(0xFFFF3B30);
  static const Color importantOrange = Color(0xFFFF9500);
  static const Color normalGreen = Color(0xFF34C759);

  // ═══════════════════════════════════════════════════════════════════════════
  // State Variables (Preserved)
  // ═══════════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? detailedAnnouncement;
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle Methods
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAnnouncementDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Methods (Preserved)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadAnnouncementDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final details = await widget.odooService.getAnnouncementDetail(
        widget.announcement.id,
        widget.employee.id,
      );

      setState(() {
        detailedAnnouncement = details;
        isLoading = false;
      });

      _animationController.forward();

      // Mark as read if not already
      if (!widget.announcement.isRead) {
        await widget.odooService.markAnnouncementAsRead(
          widget.announcement.id,
          widget.employee.id,
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final url = attachment['url'] ?? '';
    final name = attachment['name'] ?? 'Attachment';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getFileIcon(name),
                color: primaryBlue,
                size: 48,
              ),
            ),
            SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              url,
              style: TextStyle(fontSize: 12, color: textGrey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      Navigator.pop(context);
                      _showSnackBar('Link copied to clipboard');
                    },
                    icon: Icon(Icons.copy_rounded),
                    label: Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: BorderSide(color: primaryBlue),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Open URL logic here
                      _showSnackBar('Opening attachment...');
                    },
                    icon: Icon(Icons.open_in_new_rounded),
                    label: Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: normalGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build Method
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
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
              _buildAppBar(),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI Components
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: darkBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: darkBlue, size: 20),
            ),
          ),
          SizedBox(width: 16),

          // Title
          Expanded(
            child: Text(
              'Announcement',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),

          // Share Button
          GestureDetector(
            onTap: () => _shareAnnouncement(),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: darkBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.share_rounded, color: primaryBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final announcement = widget.announcement;
    final isUrgent = announcement.type == 'urgent';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(announcement, isUrgent),
            SizedBox(height: 20),

            // Content Card
            _buildContentCard(announcement),
            SizedBox(height: 20),

            // Attachments Card
            if (detailedAnnouncement != null &&
                detailedAnnouncement!['attachments'] != null &&
                (detailedAnnouncement!['attachments'] as List).isNotEmpty)
              _buildAttachmentsCard(),

            // Meta Info Card
            _buildMetaInfoCard(announcement),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Announcement announcement, bool isUrgent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [urgentRed, urgentRed.withOpacity(0.8)]
              : [primaryBlue, darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? urgentRed : primaryBlue).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Badge
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getTypeIcon(announcement.type),
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _getTypeName(announcement.type),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    if (!announcement.isRead)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            color: isUrgent ? urgentRed : primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 16),

                // Date
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      announcement.createdDate != null ? DateFormat('EEEE, MMMM dd, yyyy').format(announcement.createdDate!) : '',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Announcement announcement) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.article_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Content Text
          Text(
            _stripHtml(detailedAnnouncement?['content'] ?? announcement.content),
            style: TextStyle(
              fontSize: 15,
              color: textDark,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    final attachments = detailedAnnouncement!['attachments'] as List;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.attach_file_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${attachments.length}',
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Attachments List
          ...attachments.map((attachment) {
            final name = attachment['name'] ?? 'Unknown';
            return GestureDetector(
              onTap: () => _openAttachment(attachment),
              child: Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgGradientStart,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getFileIcon(name),
                        color: primaryBlue,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tap to open',
                            style: TextStyle(
                              fontSize: 12,
                              color: textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: primaryBlue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetaInfoCard(Announcement announcement) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_outline_rounded, color: primaryBlue, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Info Items
          _buildInfoRow(
            Icons.access_time_rounded,
            'Published',
            announcement.createdDate != null ? DateFormat('MMM dd, yyyy • h:mm a').format(announcement.createdDate!) : 'N/A',
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            Icons.category_rounded,
            'Category',
            _getTypeName(announcement.type),
          ),
          if (detailedAnnouncement?['author'] != null) ...[
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.person_rounded,
              'Posted by',
              detailedAnnouncement!['author'].toString(),
            ),
          ],
          if (detailedAnnouncement?['views'] != null) ...[
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.visibility_rounded,
              'Views',
              '${detailedAnnouncement!['views']}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: lightBlue.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryBlue, size: 18),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading details...',
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: urgentRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: urgentRed,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Failed to load details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage ?? 'Please try again',
              style: TextStyle(fontSize: 14, color: textGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnnouncementDetails,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════
  void _shareAnnouncement() {
    final text = '${widget.announcement.title}\n\n${_stripHtml(widget.announcement.content)}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Announcement copied to clipboard');
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'urgent':
        return urgentRed;
      case 'important':
        return importantOrange;
      case 'event':
        return primaryBlue;
      case 'general':
      default:
        return normalGreen;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'important':
        return Icons.priority_high_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'general':
      default:
        return Icons.campaign_rounded;
    }
  }

  String _getTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'urgent':
        return 'Urgent';
      case 'important':
        return 'Important';
      case 'event':
        return 'Event';
      case 'general':
      default:
        return 'General';
    }
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _stripHtml(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}