// lib/models/employee.dart
// نموذج الموظف مع دعم badge_id

class Employee {
  final int id;
  final String name;
  final String jobTitle;
  final String department;
  final String workEmail;
  final String workPhone;
  final String mobilePhone;
  final String? imageUrl;
  final String? badgeId; // رقم البطاقة / Badge ID من Odoo

  Employee({
    required this.id,
    required this.name,
    this.jobTitle = '',
    this.department = '',
    this.workEmail = '',
    this.workPhone = '',
    this.mobilePhone = '',
    this.imageUrl,
    this.badgeId,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      jobTitle: _parseString(json['job_title'] ?? json['job_id']),
      department: _parseString(json['department'] ?? json['department_id']),
      workEmail: _parseString(json['work_email']),
      workPhone: _parseString(json['work_phone']),
      mobilePhone: _parseString(json['mobile_phone']),
      imageUrl: json['image_url'] ?? json['imageUrl'],
      badgeId: _parseString(json['badge_id'] ?? json['barcode']),
    );
  }

  static String _parseString(dynamic value) {
    if (value == null || value == false) return '';
    if (value is List && value.length > 1) {
      return value[1].toString();
    }
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'job_title': jobTitle,
      'department': department,
      'work_email': workEmail,
      'work_phone': workPhone,
      'mobile_phone': mobilePhone,
      'image_url': imageUrl,
      'badge_id': badgeId,
    };
  }

  /// يرجع الـ Badge ID إذا موجود، وإلا يرجع الـ internal ID
  String get displayId => (badgeId != null && badgeId!.isNotEmpty) ? badgeId! : id.toString();

  /// يتحقق إذا كان الموظف لديه صورة
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// يرجع أفضل صورة متاحة
  String? get bestAvailableImage => imageUrl;

  Employee copyWith({
    int? id,
    String? name,
    String? jobTitle,
    String? department,
    String? workEmail,
    String? workPhone,
    String? mobilePhone,
    String? imageUrl,
    String? badgeId,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      department: department ?? this.department,
      workEmail: workEmail ?? this.workEmail,
      workPhone: workPhone ?? this.workPhone,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      imageUrl: imageUrl ?? this.imageUrl,
      badgeId: badgeId ?? this.badgeId,
    );
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $name, badgeId: $badgeId, jobTitle: $jobTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}