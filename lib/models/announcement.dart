// lib/models/announcement.dart
class Announcement {
  final int id;
  final String title;
  final String summary;
  final String content;
  final String type;
  final String priority;
  final bool isPinned;
  final bool isRead;
  final DateTime? createdDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String author;
  final List<Map<String, dynamic>> attachments;
  final int readCount;
  final int targetCount;
  final int attachmentCount;

  Announcement({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.type,
    required this.priority,
    required this.isPinned,
    required this.isRead,
    this.createdDate,
    this.startDate,
    this.endDate,
    required this.author,
    required this.attachments,
    required this.readCount,
    required this.targetCount,
    this.attachmentCount = 0,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    try {
      // معالجة attachments بشكل صحيح
      List<Map<String, dynamic>> attachmentsList = [];

      // إذا كان attachments موجود
      if (json['attachments'] != null) {
        // إذا كان List (array من المرفقات)
        if (json['attachments'] is List) {
          attachmentsList = List<Map<String, dynamic>>.from(json['attachments']);
        }
        // إذا كان int (عدد المرفقات فقط من API)
        else if (json['attachments'] is int) {
          // نترك القائمة فارغة - عدد المرفقات فقط
          attachmentsList = [];
        }
        // إذا كان Map (مرفق واحد)
        else if (json['attachments'] is Map) {
          attachmentsList = [json['attachments'] as Map<String, dynamic>];
        }
      }

      return Announcement(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        summary: json['summary'] ?? '',
        content: json['content'] ?? '',
        type: json['type'] ?? 'general',
        priority: json['priority'] ?? 'normal',
        isPinned: json['is_pinned'] ?? false,
        isRead: json['is_read'] ?? false,
        createdDate: json['created_date'] != null
            ? DateTime.parse(json['created_date'])
            : null,
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'])
            : null,
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'])
            : null,
        author: json['author'] ?? '',
        attachments: attachmentsList,
        readCount: json['read_count'] ?? 0,
        targetCount: json['target_count'] ?? 0,
        attachmentCount: json['attachments'] is int ? json['attachments'] : attachmentsList.length,
      );
    } catch (e) {

      rethrow;
    }
  }

  // خصائص مساعدة
  String get typeText {
    switch (type) {
      case 'general':
        return 'إعلان عام';
      case 'department':
        return 'إعلان القسم';
      case 'job':
        return 'إعلان وظيفي';
      case 'personal':
        return 'إعلان شخصي';
      case 'urgent':
        return 'إعلان عاجل';
      default:
        return 'إعلان';
    }
  }

  String get typeIcon {
    switch (type) {
      case 'general':
        return '📢';
      case 'department':
        return '🏢';
      case 'job':
        return '💼';
      case 'personal':
        return '👤';
      case 'urgent':
        return '🚨';
      default:
        return '📣';
    }
  }

  String get typeColor {
    switch (type) {
      case 'general':
        return '#4CAF50';
      case 'department':
        return '#FF9800';
      case 'job':
        return '#2196F3';
      case 'personal':
        return '#9C27B0';
      case 'urgent':
        return '#F44336';
      default:
        return '#757575';
    }
  }

  String get priorityIcon {
    switch (priority) {
      case 'low':
        return '▽';
      case 'normal':
        return '◇';
      case 'high':
        return '△';
      case 'urgent':
        return '⚠️';
      default:
        return '◇';
    }
  }

  String get priorityColor {
    switch (priority) {
      case 'low':
        return '#9E9E9E';
      case 'normal':
        return '#2196F3';
      case 'high':
        return '#FF9800';
      case 'urgent':
        return '#F44336';
      default:
        return '#2196F3';
    }
  }
}