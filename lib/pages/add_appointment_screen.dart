// pages/add_appointment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

class AddAppointmentScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Appointment? appointmentToEdit;

  const AddAppointmentScreen({
    Key? key,
    this.selectedDate,
    this.appointmentToEdit,
  }) : super(key: key);

  @override
  _AddAppointmentScreenState createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Focus Nodes
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _notificationEnabled = true;
  int _notificationMinutes = 15;
  int _selectedColorIndex = 0;
  bool _isLoading = false;

  final List<int> _notificationOptions = [5, 10, 15, 30, 60, 120, 1440];

  @override
  void initState() {
    super.initState();

    if (widget.appointmentToEdit != null) {
      final appointment = widget.appointmentToEdit!;
      _titleController.text = appointment.title;
      _descriptionController.text = appointment.description;
      _locationController.text = appointment.location ?? '';
      _notesController.text = appointment.notes ?? '';
      _selectedDate = appointment.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(appointment.dateTime);
      _notificationEnabled = appointment.isNotificationEnabled;
      _notificationMinutes = appointment.notificationMinutesBefore;
      _selectedColorIndex = appointment.colorIndex;
    } else {
      _selectedDate = widget.selectedDate ?? DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _locationFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  String _getNotificationText(int minutes) {
    if (minutes < 60) {
      return '$minutes دقيقة';
    } else if (minutes == 60) {
      return 'ساعة واحدة';
    } else if (minutes == 120) {
      return 'ساعتين';
    } else if (minutes == 1440) {
      return 'يوم واحد';
    } else {
      return '${minutes ~/ 60} ساعات';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // تحقق من التاريخ
      if (dateTime.isBefore(DateTime.now()) && widget.appointmentToEdit == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن إنشاء موعد في الماضي'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final appointment = Appointment(
        id: widget.appointmentToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: dateTime,
        isNotificationEnabled: _notificationEnabled,
        notificationMinutesBefore: _notificationMinutes,
        location: _locationController.text.isNotEmpty
            ? _locationController.text.trim()
            : null,
        notes: _notesController.text.isNotEmpty
            ? _notesController.text.trim()
            : null,
        colorIndex: _selectedColorIndex,
        isCompleted: widget.appointmentToEdit?.isCompleted ?? false,
      );

      if (widget.appointmentToEdit != null) {
        await AppointmentService.updateAppointment(appointment);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الموعد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await AppointmentService.saveAppointment(appointment);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة الموعد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تنبيه'),
          content: Text('هل تريد المغادرة بدون حفظ التغييرات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('المغادرة'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppointmentService.getAppointmentColors();
    final isEdit = widget.appointmentToEdit != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'تعديل الموعد' : 'موعد جديد'),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // عنوان الموعد
              TextFormField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_descriptionFocusNode);
                },
                decoration: InputDecoration(
                  labelText: 'عنوان الموعد',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال عنوان الموعد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // وصف الموعد
              TextFormField(
                controller: _descriptionController,
                focusNode: _descriptionFocusNode,
                textInputAction: TextInputAction.next,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال وصف الموعد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // التاريخ والوقت
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'التاريخ',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          DateFormat('yyyy/MM/dd').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'الوقت',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // المكان
              TextFormField(
                controller: _locationController,
                focusNode: _locationFocusNode,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'المكان (اختياري)',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // اللون
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لون الموعد',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(colors.length, (index) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedColorIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(colors[index]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorIndex == index
                                  ? Colors.black
                                  : Colors.grey.shade300,
                              width: _selectedColorIndex == index ? 3 : 1,
                            ),
                            boxShadow: _selectedColorIndex == index
                                ? [
                              BoxShadow(
                                color: Color(colors[index]).withOpacity(0.4),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ]
                                : null,
                          ),
                          child: _selectedColorIndex == index
                              ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 22,
                          )
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // الإشعارات
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تفعيل الإشعارات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          Switch(
                            value: _notificationEnabled,
                            onChanged: (value) {
                              setState(() {
                                _notificationEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_notificationEnabled) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'التنبيه قبل الموعد بـ:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _notificationOptions.map((minutes) {
                            return ChoiceChip(
                              label: Text(_getNotificationText(minutes)),
                              selected: _notificationMinutes == minutes,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _notificationMinutes = minutes;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ملاحظات
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // زر الحفظ
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAppointment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  isEdit ? 'حفظ التعديلات' : 'إضافة الموعد',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}