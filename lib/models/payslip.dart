// lib/models/payslip.dart
class Payslip {
  final int id;
  final int employeeId;
  final String employeeName;
  final String number;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String state;
  final String paymentDate;

  // التفاصيل المالية
  final double basicSalary;
  final double grossSalary;
  final double netSalary;

  // البدلات
  final double housingAllowance;
  final double transportationAllowance;
  final double foodAllowance;
  final double phoneAllowance;
  final double otherAllowances;
  final double totalAllowances;

  // الخصومات
  final double socialInsurance;
  final double taxes;
  final double loans;
  final double absence;
  final double otherDeductions;
  final double totalDeductions;

  // معلومات إضافية
  final String? notes;
  final String? bankName;
  final String? bankAccount;
  final String currency;
  final int workingDays;
  final int actualWorkingDays;

  // بيانات الشركة
  final String? companyName;
  final String? companyLogo;

  Payslip({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.number,
    required this.dateFrom,
    required this.dateTo,
    required this.state,
    required this.paymentDate,
    required this.basicSalary,
    required this.grossSalary,
    required this.netSalary,
    this.housingAllowance = 0.0,
    this.transportationAllowance = 0.0,
    this.foodAllowance = 0.0,
    this.phoneAllowance = 0.0,
    this.otherAllowances = 0.0,
    required this.totalAllowances,
    this.socialInsurance = 0.0,
    this.taxes = 0.0,
    this.loans = 0.0,
    this.absence = 0.0,
    this.otherDeductions = 0.0,
    required this.totalDeductions,
    this.notes,
    this.bankName,
    this.bankAccount,
    this.currency = 'EGP',
    this.workingDays = 30,
    this.actualWorkingDays = 30,
    this.companyName,
    this.companyLogo,
  });

  // حساب النسب المئوية
  double get allowancesPercentage {
    if (grossSalary == 0) return 0;
    return (totalAllowances / grossSalary) * 100;
  }

  double get deductionsPercentage {
    if (grossSalary == 0) return 0;
    return (totalDeductions / grossSalary) * 100;
  }

  // التحقق من الحالة
  bool get isPaid => state == 'done';
  bool get isDraft => state == 'draft';
  bool get isCancelled => state == 'cancel';

  // الحصول على لون الحالة
  String get stateColor {
    switch (state) {
      case 'done':
        return '#4CAF50';
      case 'verify':
        return '#FF9800';
      case 'draft':
        return '#9E9E9E';
      case 'cancel':
        return '#F44336';
      default:
        return '#9E9E9E';
    }
  }

  // الحصول على نص الحالة
  String get stateText {
    switch (state) {
      case 'done':
        return 'مدفوع';
      case 'verify':
        return 'قيد المراجعة';
      case 'draft':
        return 'مسودة';
      case 'cancel':
        return 'ملغي';
      default:
        return 'غير محدد';
    }
  }

  // الحصول على أيقونة الحالة
  String get stateIcon {
    switch (state) {
      case 'done':
        return '✅';
      case 'verify':
        return '⏳';
      case 'draft':
        return '📝';
      case 'cancel':
        return '❌';
      default:
        return '❓';
    }
  }

  // تنسيق الفترة
  String get periodText {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${months[dateFrom.month - 1]} ${dateFrom.year}';
  }

  // تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'number': number,
      'date_from': dateFrom.toIso8601String(),
      'date_to': dateTo.toIso8601String(),
      'state': state,
      'payment_date': paymentDate,
      'basic_salary': basicSalary,
      'gross_salary': grossSalary,
      'net_salary': netSalary,
      'housing_allowance': housingAllowance,
      'transportation_allowance': transportationAllowance,
      'food_allowance': foodAllowance,
      'phone_allowance': phoneAllowance,
      'other_allowances': otherAllowances,
      'total_allowances': totalAllowances,
      'social_insurance': socialInsurance,
      'taxes': taxes,
      'loans': loans,
      'absence': absence,
      'other_deductions': otherDeductions,
      'total_deductions': totalDeductions,
      'notes': notes,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'currency': currency,
      'working_days': workingDays,
      'actual_working_days': actualWorkingDays,
      'company_name': companyName,
      'company_logo': companyLogo,
    };
  }

  // إنشاء من JSON
  factory Payslip.fromJson(Map<String, dynamic> json) {
    print('🔄 Parsing Payslip JSON: $json');

    // معالجة التواريخ
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null || dateValue == false) {
        return DateTime.now();
      }
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          print('⚠️ خطأ في تحويل التاريخ: $dateValue');
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    // معالجة الأرقام
    double parseDouble(dynamic value) {
      if (value == null || value == false) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // معالجة النصوص
    String parseString(dynamic value, [String defaultValue = '']) {
      if (value == null || value == false) return defaultValue;
      return value.toString();
    }

    // معالجة الأرقام الصحيحة
    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null || value == false) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    try {
      return Payslip(
        id: parseInt(json['id']),
        employeeId: parseInt(json['employee_id']),
        employeeName: parseString(json['employee_name'], 'Unknown'),
        number: parseString(json['number'], ''),
        dateFrom: parseDate(json['date_from']),
        dateTo: parseDate(json['date_to']),
        state: parseString(json['state'], 'draft'),
        paymentDate: parseString(json['payment_date'], ''),
        basicSalary: parseDouble(json['basic_salary']),
        grossSalary: parseDouble(json['gross_salary']),
        netSalary: parseDouble(json['net_salary']),
        housingAllowance: parseDouble(json['housing_allowance']),
        transportationAllowance: parseDouble(json['transportation_allowance']),
        foodAllowance: parseDouble(json['food_allowance']),
        phoneAllowance: parseDouble(json['phone_allowance']),
        otherAllowances: parseDouble(json['other_allowances']),
        totalAllowances: parseDouble(json['total_allowances']),
        socialInsurance: parseDouble(json['social_insurance']),
        taxes: parseDouble(json['taxes']),
        loans: parseDouble(json['loans']),
        absence: parseDouble(json['absence']),
        otherDeductions: parseDouble(json['other_deductions']),
        totalDeductions: parseDouble(json['total_deductions']),
        notes: json['notes']?.toString(),
        bankName: json['bank_name']?.toString(),
        bankAccount: json['bank_account']?.toString(),
        currency: parseString(json['currency'], 'EGP'),
        workingDays: parseInt(json['working_days'], 30),
        actualWorkingDays: parseInt(json['actual_working_days'], 30),
        companyName: json['company_name']?.toString(),
        companyLogo: json['company_logo']?.toString(),
      );
    } catch (e) {
      print('❌ خطأ في Payslip.fromJson: $e');
      print('❌ البيانات: $json');
      rethrow;
    }
  }

  // نموذج فارغ للاختبار
  factory Payslip.empty() {
    return Payslip(
      id: 0,
      employeeId: 0,
      employeeName: '',
      number: '',
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
      state: 'draft',
      paymentDate: '',
      basicSalary: 0,
      grossSalary: 0,
      netSalary: 0,
      totalAllowances: 0,
      totalDeductions: 0,
    );
  }

  @override
  String toString() {
    return 'Payslip(id: $id, number: $number, period: $periodText, netSalary: $netSalary)';
  }
}