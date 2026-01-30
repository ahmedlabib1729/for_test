// lib/widgets/employee_avatar.dart - ويدجت محدث للعمل مع صور Base64
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/employee.dart';
import '../services/odoo_service.dart';

class EmployeeAvatar extends StatelessWidget {
  final Employee employee;
  final double radius;
  final bool showEditButton;
  final VoidCallback? onEdit;
  final OdooService? odooService;

  const EmployeeAvatar({
    Key? key,
    required this.employee,
    this.radius = 40,
    this.showEditButton = false,
    this.onEdit,
    this.odooService,
  }) : super(key: key);

  // تحويل صورة Base64 إلى Uint8List مع معالجة أفضل للأخطاء
  Uint8List? _getImageBytes() {
    try {
      // التحقق من وجود صورة
      if (!employee.hasImage || employee.bestAvailableImage == null) {
        return null;
      }

      final imageUrl = employee.bestAvailableImage!;

      // تجاهل القيم الفارغة
      if (imageUrl.isEmpty) {
        return null;
      }

      String base64String;

      // التحقق من أن الصورة بصيغة Base64 مع prefix
      if (imageUrl.startsWith('data:image')) {
        // استخراج البيانات Base64 بعد الفاصلة
        final parts = imageUrl.split(',');
        if (parts.length < 2) {
          print('صيغة Base64 غير صحيحة: لا يوجد فاصلة');
          return null;
        }
        base64String = parts.last;
      } else {
        // إذا كانت Base64 بدون prefix
        base64String = imageUrl;
      }

      // تنظيف الـ Base64 من أي whitespace أو newlines
      base64String = base64String.trim().replaceAll(RegExp(r'\s+'), '');

      // التحقق من أن الـ string ليس فارغاً
      if (base64String.isEmpty) {
        print('بيانات Base64 فارغة');
        return null;
      }

      // التحقق من صحة أحرف Base64
      final validBase64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
      if (!validBase64Regex.hasMatch(base64String)) {
        print('بيانات Base64 تحتوي على أحرف غير صالحة');
        return null;
      }

      // محاولة فك التشفير
      final bytes = base64Decode(base64String);

      // التحقق من أن البيانات ليست فارغة
      if (bytes.isEmpty) {
        print('بيانات الصورة فارغة بعد فك التشفير');
        return null;
      }

      // التحقق من أن البيانات تحتوي على header صورة صالح (PNG أو JPEG)
      if (!_isValidImageData(bytes)) {
        print('بيانات الصورة غير صالحة - header غير معروف');
        return null;
      }

      return bytes;
    } catch (e) {
      print('خطأ في تحويل صورة Base64: $e');
      return null;
    }
  }

  // التحقق من أن البيانات هي صورة صالحة
  bool _isValidImageData(Uint8List bytes) {
    if (bytes.length < 8) return false;

    // PNG header: 137 80 78 71 13 10 26 10
    final pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
    bool isPng = true;
    for (int i = 0; i < pngHeader.length && i < bytes.length; i++) {
      if (bytes[i] != pngHeader[i]) {
        isPng = false;
        break;
      }
    }
    if (isPng) return true;

    // JPEG header: 255 216 255
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      return true;
    }

    // GIF header: 47 49 46 38 (GIF8)
    if (bytes[0] == 71 && bytes[1] == 73 && bytes[2] == 70 && bytes[3] == 56) {
      return true;
    }

    // WebP header: 52 49 46 46 (RIFF) + WEBP
    if (bytes[0] == 82 && bytes[1] == 73 && bytes[2] == 70 && bytes[3] == 70) {
      if (bytes.length > 11 && bytes[8] == 87 && bytes[9] == 69 && bytes[10] == 66 && bytes[11] == 80) {
        return true;
      }
    }

    // BMP header: 42 4D (BM)
    if (bytes[0] == 66 && bytes[1] == 77) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _getImageBytes();

    return Stack(
      children: [
        // الصورة الرئيسية
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[300],
          child: imageBytes != null
              ? ClipOval(
            child: Image.memory(
              imageBytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('خطأ في عرض الصورة: $error');
                return _buildDefaultAvatar();
              },
            ),
          )
              : _buildDefaultAvatar(),
        ),

        // زر التعديل (اختياري)
        if (showEditButton && onEdit != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                width: radius * 0.6,
                height: radius * 0.6,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: radius * 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // بناء الأفاتار الافتراضي
  Widget _buildDefaultAvatar() {
    return Icon(
      Icons.person,
      size: radius * 0.8,
      color: Colors.white,
    );
  }
}

// ويدجت متقدم للصورة مع ميزات إضافية
class AdvancedEmployeeAvatar extends StatefulWidget {
  final Employee employee;
  final double radius;
  final bool showBadge;
  final bool showEditButton;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final OdooService? odooService;
  final String? statusText;
  final Color? statusColor;

  const AdvancedEmployeeAvatar({
    Key? key,
    required this.employee,
    this.radius = 40,
    this.showBadge = false,
    this.showEditButton = false,
    this.showBorder = true,
    this.borderColor,
    this.onTap,
    this.onEdit,
    this.odooService,
    this.statusText,
    this.statusColor,
    required int borderWidth,
  }) : super(key: key);

  @override
  _AdvancedEmployeeAvatarState createState() => _AdvancedEmployeeAvatarState();
}

class _AdvancedEmployeeAvatarState extends State<AdvancedEmployeeAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    if (widget.onTap != null) widget.onTap!();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: widget.onTap != null ? _handleTapDown : null,
            onTapUp: widget.onTap != null ? _handleTapUp : null,
            onTapCancel: widget.onTap != null ? _handleTapCancel : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // الصورة مع الحدود
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: widget.showBorder
                        ? Border.all(
                      color: widget.borderColor ?? Colors.blue,
                      width: 3,
                    )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: EmployeeAvatar(
                    employee: widget.employee,
                    radius: widget.radius,
                    odooService: widget.odooService,
                  ),
                ),

                // شارة الحالة
                if (widget.showBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: widget.radius * 0.4,
                      height: widget.radius * 0.4,
                      decoration: BoxDecoration(
                        color: widget.statusColor ?? Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),

                // زر التعديل
                if (widget.showEditButton && widget.onEdit != null)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(
                        width: widget.radius * 0.5,
                        height: widget.radius * 0.5,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: widget.radius * 0.25,
                        ),
                      ),
                    ),
                  ),

                // نص الحالة
                if (widget.statusText != null)
                  Positioned(
                    bottom: -widget.radius * 0.3,
                    left: -widget.radius * 0.2,
                    right: -widget.radius * 0.2,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.statusColor ?? Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.statusText!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.radius * 0.2,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ويدجت قائمة صور الموظفين
class EmployeeAvatarList extends StatelessWidget {
  final List<Employee> employees;
  final double avatarRadius;
  final int maxVisible;
  final VoidCallback? onMoreTap;
  final Function(Employee)? onEmployeeTap;
  final OdooService? odooService;

  const EmployeeAvatarList({
    Key? key,
    required this.employees,
    this.avatarRadius = 25,
    this.maxVisible = 5,
    this.onMoreTap,
    this.onEmployeeTap,
    this.odooService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final visibleEmployees = employees.take(maxVisible).toList();
    final remainingCount = employees.length - maxVisible;

    return Row(
      children: [
        // الموظفين المرئيين
        ...visibleEmployees.asMap().entries.map((entry) {
          final index = entry.key;
          final employee = entry.value;

          return Transform.translate(
            offset: Offset(-index * avatarRadius * 0.7, 0),
            child: GestureDetector(
              onTap: () => onEmployeeTap?.call(employee),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: EmployeeAvatar(
                  employee: employee,
                  radius: avatarRadius,
                  odooService: odooService,
                ),
              ),
            ),
          );
        }).toList(),

        // زر "المزيد"
        if (remainingCount > 0)
          Transform.translate(
            offset: Offset(-maxVisible * avatarRadius * 0.7, 0),
            child: GestureDetector(
              onTap: onMoreTap,
              child: Container(
                width: avatarRadius * 2,
                height: avatarRadius * 2,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      fontSize: avatarRadius * 0.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}