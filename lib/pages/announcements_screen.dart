// lib/pages/announcements_screen.dart - Modern Design
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/announcement.dart';
import '../services/odoo_service.dart';
import 'announcement_details_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  final OdooService odooService;
  final Employee employee;

  const AnnouncementsScreen({
    Key? key,
    required this.odooService,
    required this.employee,
  }) : super(key: key);

  @override
  _AnnouncementsScreenState createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
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
  List<Announcement> announcements = [];
  List<Announcement> filteredAnnouncements = [];
  List<Map<String, dynamic>> categories = [];

  bool isLoading = true;
  bool isLoadingMore = false;
  String? errorMessage;

  String selectedCategory = 'all';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  int currentOffset = 0;
  final int pageSize = 20;
  bool hasMore = true;

  final ScrollController scrollController = ScrollController();
  late AnimationController _animationController;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle Methods
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadInitialData();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        _loadMoreAnnouncements();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Methods (Preserved)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final categoriesData = await widget.odooService.getAnnouncementCategories();
      final announcementsData = await widget.odooService.getAnnouncements(
        widget.employee.id,
        limit: pageSize,
        offset: 0,
      );

      setState(() {
        categories = categoriesData;
        announcements = announcementsData;
        filteredAnnouncements = announcementsData;
        currentOffset = announcementsData.length;
        hasMore = announcementsData.length == pageSize;
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreAnnouncements() async {
    if (isLoadingMore || !hasMore || searchQuery.isNotEmpty) return;

    try {
      setState(() {
        isLoadingMore = true;
      });

      final moreAnnouncements = await widget.odooService.getAnnouncements(
        widget.employee.id,
        limit: pageSize,
        offset: currentOffset,
      );

      setState(() {
        announcements.addAll(moreAnnouncements);
        _filterAnnouncements();
        currentOffset += moreAnnouncements.length;
        hasMore = moreAnnouncements.length == pageSize;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void _filterAnnouncements() {
    setState(() {
      filteredAnnouncements = announcements.where((announcement) {
        final matchesCategory = selectedCategory == 'all' ||
            announcement.type == selectedCategory;
        final matchesSearch = searchQuery.isEmpty ||
            announcement.title.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _filterAnnouncements();
  }

  void _onCategoryChanged(String category) {
    setState(() {
      selectedCategory = category;
    });
    _filterAnnouncements();
  }

  void _viewAnnouncementDetails(Announcement announcement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementDetailsScreen(
          announcement: announcement,
          odooService: widget.odooService,
          employee: widget.employee,
        ),
      ),
    ).then((_) {
      _loadInitialData();
    });
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
              _buildSearchBar(),
              _buildCategoryFilters(),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : errorMessage != null
                    ? _buildErrorState()
                    : _buildAnnouncementsList(),
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
    final unreadCount = announcements.where((a) => !a.isRead).length;

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
              'Announcements',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),

          // Unread Badge
          if (unreadCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [urgentRed, urgentRed.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: urgentRed.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '$unreadCount New',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(width: 12),

          // Refresh Button
          GestureDetector(
            onTap: _loadInitialData,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search announcements...',
          hintStyle: TextStyle(color: textGrey.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search_rounded, color: primaryBlue),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: textGrey),
            onPressed: () {
              searchController.clear();
              _onSearchChanged('');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final allCategories = [
      {'id': 'all', 'name': 'All', 'icon': Icons.dashboard_rounded},
      {'id': 'urgent', 'name': 'Urgent', 'icon': Icons.warning_amber_rounded},
      {'id': 'general', 'name': 'General', 'icon': Icons.campaign_rounded},
      {'id': 'event', 'name': 'Events', 'icon': Icons.event_rounded},
    ];

    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = selectedCategory == category['id'];

          return GestureDetector(
            onTap: () => _onCategoryChanged(category['id'] as String),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [primaryBlue, darkBlue])
                    : null,
                color: isSelected ? null : cardWhite,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? primaryBlue.withOpacity(0.3)
                        : darkBlue.withOpacity(0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : textGrey,
                  ),
                  SizedBox(width: 8),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textGrey,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    if (filteredAnnouncements.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: primaryBlue,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: filteredAnnouncements.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredAnnouncements.length) {
            return _buildLoadingMoreIndicator();
          }
          return _buildAnnouncementCard(filteredAnnouncements[index], index);
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement, int index) {
    final isUrgent = announcement.type == 'urgent';
    final isUnread = !announcement.isRead;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _animationController.value)),
          child: Opacity(
            opacity: _animationController.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _viewAnnouncementDetails(announcement),
        child: Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: isUnread
                ? Border.all(color: primaryBlue.withOpacity(0.3), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isUrgent
                    ? urgentRed.withOpacity(0.15)
                    : darkBlue.withOpacity(0.08),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isUrgent
                      ? LinearGradient(
                    colors: [urgentRed.withOpacity(0.1), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    // Type Icon
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getTypeColor(announcement.type).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTypeIcon(announcement.type),
                        color: _getTypeColor(announcement.type),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),

                    // Title & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(announcement.createdDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: primaryBlue,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Preview Content
              if (announcement.content.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    _stripHtml(announcement.content),
                    style: TextStyle(
                      fontSize: 14,
                      color: textGrey,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Footer Tags
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // Type Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(announcement.type).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getTypeName(announcement.type),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getTypeColor(announcement.type),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Attachments indicator
                    if (announcement.attachmentCount > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file_rounded, size: 12, color: primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              '${announcement.attachmentCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            'Loading announcements...',
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
              'Failed to load announcements',
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
              onPressed: _loadInitialData,
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

  Widget _buildEmptyState() {
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
            child: Icon(
              Icons.campaign_outlined,
              size: 64,
              color: primaryBlue,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Announcements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty
                ? 'No results match your search'
                : 'No announcements available at the moment',
            style: TextStyle(fontSize: 14, color: textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
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