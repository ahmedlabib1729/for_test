// lib/services/face_detection_service.dart
// خدمة اكتشاف الوجه والحركات باستخدام Google ML Kit

import 'dart:math';
import 'dart:ui' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

/// أنواع الحركات المطلوبة
enum FaceAction {
  smile,      // ابتسم
  blinkLeft,  // اغمض عينك اليسار
  blinkRight, // اغمض عينك اليمين
  turnLeft,   // لف رأسك يسار
  turnRight,  // لف رأسك يمين
}

/// نتيجة اكتشاف الوجه
class FaceDetectionResult {
  final bool faceDetected;
  final bool actionCompleted;
  final double? smileProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? headRotationY; // دوران الرأس يمين/يسار
  final double? headRotationX; // ميل الرأس فوق/تحت
  final String? message;

  FaceDetectionResult({
    required this.faceDetected,
    required this.actionCompleted,
    this.smileProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headRotationY,
    this.headRotationX,
    this.message,
  });
}

class FaceDetectionService {
  static final FaceDetectionService _instance = FaceDetectionService._internal();
  factory FaceDetectionService() => _instance;
  FaceDetectionService._internal();

  FaceDetector? _faceDetector;
  FaceAction? _currentAction;
  bool _isProcessing = false;

  // عتبات الاكتشاف (Thresholds)
  static const double _smileThreshold = 0.7;        // 70% احتمال ابتسامة
  static const double _eyeClosedThreshold = 0.3;    // أقل من 30% = عين مغلقة
  static const double _headTurnThreshold = 25.0;    // 25 درجة دوران

  /// تهيئة الخدمة
  void initialize() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,  // للابتسامة وفتح/غلق العين
        enableTracking: true,        // تتبع الوجه
        enableLandmarks: true,       // نقاط الوجه
        enableContours: false,       // لا نحتاجها
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,          // حجم الوجه الأدنى 15% من الصورة
      ),
    );

    print('✅ FaceDetectionService initialized');
  }

  /// إغلاق الخدمة
  Future<void> dispose() async {
    await _faceDetector?.close();
    _faceDetector = null;
    print('🔴 FaceDetectionService disposed');
  }

  /// الحصول على حركة عشوائية
  FaceAction getRandomAction() {
    final random = Random();
    final actions = FaceAction.values;
    _currentAction = actions[random.nextInt(actions.length)];
    print('🎲 Random action selected: $_currentAction');
    return _currentAction!;
  }

  /// تعيين حركة محددة
  void setAction(FaceAction action) {
    _currentAction = action;
    print('📌 Action set to: $_currentAction');
  }

  /// الحصول على نص الحركة بالعربية
  String getActionTextAr(FaceAction action) {
    switch (action) {
      case FaceAction.smile:
        return 'ابتسم 😊';
      case FaceAction.blinkLeft:
        return 'اغمض عينك اليسار 😉';
      case FaceAction.blinkRight:
        return 'اغمض عينك اليمين 😉';
      case FaceAction.turnLeft:
        return 'لف رأسك لليسار 👈';
      case FaceAction.turnRight:
        return 'لف رأسك لليمين 👉';
    }
  }

  /// الحصول على نص الحركة بالإنجليزية
  String getActionTextEn(FaceAction action) {
    switch (action) {
      case FaceAction.smile:
        return 'Smile 😊';
      case FaceAction.blinkLeft:
        return 'Blink your left eye 😉';
      case FaceAction.blinkRight:
        return 'Blink your right eye 😉';
      case FaceAction.turnLeft:
        return 'Turn your head left 👈';
      case FaceAction.turnRight:
        return 'Turn your head right 👉';
    }
  }

  /// الحصول على اسم الحركة للحفظ
  String getActionName(FaceAction action) {
    return action.toString().split('.').last;
  }

  /// معالجة صورة الكاميرا
  Future<FaceDetectionResult> processImage(CameraImage cameraImage, CameraDescription camera) async {
    if (_faceDetector == null) {
      return FaceDetectionResult(
        faceDetected: false,
        actionCompleted: false,
        message: 'Face detector not initialized',
      );
    }

    if (_isProcessing) {
      return FaceDetectionResult(
        faceDetected: false,
        actionCompleted: false,
        message: 'Processing previous frame',
      );
    }

    _isProcessing = true;

    try {
      // تحويل CameraImage إلى InputImage
      final inputImage = _convertCameraImage(cameraImage, camera);

      if (inputImage == null) {
        return FaceDetectionResult(
          faceDetected: false,
          actionCompleted: false,
          message: 'Failed to convert image',
        );
      }

      // اكتشاف الوجوه
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(
          faceDetected: false,
          actionCompleted: false,
          message: 'No face detected',
        );
      }

      // نأخذ أول وجه فقط
      final face = faces.first;

      // استخراج البيانات
      final smileProbability = face.smilingProbability;
      final leftEyeOpen = face.leftEyeOpenProbability;
      final rightEyeOpen = face.rightEyeOpenProbability;
      final headRotationY = face.headEulerAngleY; // دوران يمين/يسار
      final headRotationX = face.headEulerAngleX; // ميل فوق/تحت

      // التحقق من الحركة المطلوبة
      bool actionCompleted = false;

      if (_currentAction != null) {
        actionCompleted = _checkAction(
          _currentAction!,
          smileProbability,
          leftEyeOpen,
          rightEyeOpen,
          headRotationY,
        );
      }

      return FaceDetectionResult(
        faceDetected: true,
        actionCompleted: actionCompleted,
        smileProbability: smileProbability,
        leftEyeOpenProbability: leftEyeOpen,
        rightEyeOpenProbability: rightEyeOpen,
        headRotationY: headRotationY,
        headRotationX: headRotationX,
        message: actionCompleted ? 'Action completed!' : 'Waiting for action...',
      );
    } catch (e) {
      print('❌ Error processing image: $e');
      return FaceDetectionResult(
        faceDetected: false,
        actionCompleted: false,
        message: 'Error: $e',
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// التحقق من الحركة
  bool _checkAction(
      FaceAction action,
      double? smileProbability,
      double? leftEyeOpen,
      double? rightEyeOpen,
      double? headRotationY,
      ) {
    switch (action) {
      case FaceAction.smile:
        return (smileProbability ?? 0) >= _smileThreshold;

      case FaceAction.blinkLeft:
      // العين اليسار مغلقة واليمين مفتوحة
        return (leftEyeOpen ?? 1) <= _eyeClosedThreshold &&
            (rightEyeOpen ?? 0) > 0.5;

      case FaceAction.blinkRight:
      // العين اليمين مغلقة واليسار مفتوحة
        return (rightEyeOpen ?? 1) <= _eyeClosedThreshold &&
            (leftEyeOpen ?? 0) > 0.5;

      case FaceAction.turnLeft:
      // دوران الرأس لليسار (قيمة سالبة)
        return (headRotationY ?? 0) <= -_headTurnThreshold;

      case FaceAction.turnRight:
      // دوران الرأس لليمين (قيمة موجبة)
        return (headRotationY ?? 0) >= _headTurnThreshold;
    }
  }

  /// تحويل CameraImage إلى InputImage
  InputImage? _convertCameraImage(CameraImage cameraImage, CameraDescription camera) {
    try {
      // تحديد اتجاه الصورة
      final imageRotation = _getImageRotation(camera);

      if (imageRotation == null) {
        return null;
      }

      // تحديد format الصورة
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);

      if (format == null) {
        return null;
      }

      // بناء البيانات
      final plane = cameraImage.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
          rotation: imageRotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      print('❌ Error converting camera image: $e');
      return null;
    }
  }

  /// الحصول على اتجاه الصورة
  InputImageRotation? _getImageRotation(CameraDescription camera) {
    // الكاميرا الأمامية تحتاج معالجة خاصة
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;

    switch (sensorOrientation) {
      case 0:
        rotation = InputImageRotation.rotation0deg;
        break;
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    return rotation;
  }

  /// إعادة تعيين الخدمة
  void reset() {
    _currentAction = null;
    _isProcessing = false;
    print('🔄 FaceDetectionService reset');
  }
}