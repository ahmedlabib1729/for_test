// lib/pages/face_verification_screen.dart
// شاشة التحقق من الوجه للحضور والانصراف

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/face_detection_service.dart';
import '../services/language_manager.dart';

/// نتيجة التحقق من الوجه
class FaceVerificationResult {
  final bool success;
  final String? imageBase64;
  final String? actionPerformed;
  final String? errorMessage;

  FaceVerificationResult({
    required this.success,
    this.imageBase64,
    this.actionPerformed,
    this.errorMessage,
  });
}

class FaceVerificationScreen extends StatefulWidget {
  final bool isCheckIn; // true = حضور، false = انصراف

  const FaceVerificationScreen({
    Key? key,
    required this.isCheckIn,
  }) : super(key: key);

  @override
  _FaceVerificationScreenState createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {

  // الكاميرا
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String? _cameraErrorMessage;

  // خدمة اكتشاف الوجه
  final FaceDetectionService _faceService = FaceDetectionService();

  // الحالة
  FaceAction? _currentAction;
  bool _faceDetected = false;
  bool _actionCompleted = false;
  bool _isCapturing = false;
  bool _isProcessingFrame = false;

  // بيانات الوجه
  double? _smileProbability;
  double? _leftEyeOpen;
  double? _rightEyeOpen;
  double? _headRotationY;

  // الصورة الملتقطة
  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _faceService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// تهيئة الكاميرا
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'لا توجد كاميرا متاحة';
        });
        return;
      }

      // البحث عن الكاميرا الأمامية
      CameraDescription? frontCamera;
      for (final camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      // إذا لم توجد كاميرا أمامية، استخدم الخلفية
      final selectedCamera = frontCamera ?? _cameras!.first;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // للأندرويد
      );

      await _cameraController!.initialize();

      // بدء معالجة الإطارات
      await _cameraController!.startImageStream(_processCameraImage);

      // اختيار حركة عشوائية
      _currentAction = _faceService.getRandomAction();

      setState(() {
        _isCameraInitialized = true;
      });


    } catch (e) {

      setState(() {
        _isCameraError = true;
        _cameraErrorMessage = e.toString();
      });
    }
  }

  /// معالجة إطار الكاميرا
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isProcessingFrame || _actionCompleted || _isCapturing) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final result = await _faceService.processImage(
        cameraImage,
        _cameraController!.description,
      );

      if (mounted) {
        setState(() {
          _faceDetected = result.faceDetected;
          _smileProbability = result.smileProbability;
          _leftEyeOpen = result.leftEyeOpenProbability;
          _rightEyeOpen = result.rightEyeOpenProbability;
          _headRotationY = result.headRotationY;
        });

        // إذا تمت الحركة، التقط الصورة
        if (result.actionCompleted && !_actionCompleted) {
          _onActionCompleted();
        }
      }
    } catch (e) {

    } finally {
      _isProcessingFrame = false;
    }
  }

  /// عند إتمام الحركة
  Future<void> _onActionCompleted() async {
    if (_actionCompleted || _isCapturing) return;

    setState(() {
      _actionCompleted = true;
      _isCapturing = true;
    });

    // اهتزاز خفيف
    HapticFeedback.mediumImpact();

    // إيقاف معالجة الإطارات
    await _cameraController?.stopImageStream();

    // انتظار قليلاً ثم التقاط الصورة
    await Future.delayed(const Duration(milliseconds: 300));

    await _capturePhoto();
  }

  /// التقاط الصورة
  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('الكاميرا غير جاهزة');
      return;
    }

    try {

      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      setState(() {
        _capturedImage = bytes;
        _isCapturing = false;
      });


      // إرجاع النتيجة بعد عرض الصورة للمستخدم
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final base64Image = base64Encode(bytes);
        Navigator.of(context).pop(FaceVerificationResult(
          success: true,
          imageBase64: base64Image,
          actionPerformed: _faceService.getActionName(_currentAction!),
        ));
      }
    } catch (e) {

      setState(() {
        _isCapturing = false;
        _actionCompleted = false;
      });

      // إعادة تشغيل معالجة الإطارات
      await _cameraController?.startImageStream(_processCameraImage);

      _showError('فشل التقاط الصورة: $e');
    }
  }

  /// تغيير الحركة
  void _changeAction() {
    setState(() {
      _currentAction = _faceService.getRandomAction();
      _actionCompleted = false;
    });
    HapticFeedback.lightImpact();
  }

  /// إظهار رسالة خطأ
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// إلغاء العملية
  void _cancel() {
    Navigator.of(context).pop(FaceVerificationResult(
      success: false,
      errorMessage: 'تم الإلغاء',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.lang.isArabic;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // خلفية الكاميرا
            _buildCameraPreview(),

            // Overlay
            _buildOverlay(isArabic),

            // Header
            _buildHeader(isArabic),

            // Bottom controls
            _buildBottomControls(isArabic),

            // الصورة الملتقطة
            if (_capturedImage != null) _buildCapturedImage(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isCameraError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _cameraErrorMessage ?? 'خطأ في الكاميرا',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'جاري تشغيل الكاميرا...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Center(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildOverlay(bool isArabic) {
    return Positioned.fill(
      child: CustomPaint(
        painter: FaceOverlayPainter(
          faceDetected: _faceDetected,
          actionCompleted: _actionCompleted,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            // العنوان وزر الإغلاق
            Row(
              children: [
                IconButton(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                Expanded(
                  child: Text(
                    widget.isCheckIn
                        ? (isArabic ? 'تسجيل الحضور' : 'Check In')
                        : (isArabic ? 'تسجيل الانصراف' : 'Check Out'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // للتوازن مع زر الإغلاق
              ],
            ),

            const SizedBox(height: 20),

            // حالة اكتشاف الوجه
            _buildFaceStatus(isArabic),

            const SizedBox(height: 16),

            // الحركة المطلوبة
            if (_currentAction != null && !_actionCompleted)
              _buildActionCard(isArabic),

            // رسالة النجاح
            if (_actionCompleted)
              _buildSuccessMessage(isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceStatus(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _faceDetected
            ? Colors.green.withOpacity(0.8)
            : Colors.orange.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _faceDetected ? Icons.face : Icons.face_outlined,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            _faceDetected
                ? (isArabic ? 'تم اكتشاف الوجه ✓' : 'Face detected ✓')
                : (isArabic ? 'وجّه وجهك للكاميرا' : 'Face the camera'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(bool isArabic) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isArabic ? 'من فضلك قم بالتالي:' : 'Please do the following:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isArabic
                ? _faceService.getActionTextAr(_currentAction!)
                : _faceService.getActionTextEn(_currentAction!),
            style: const TextStyle(
              color: Color(0xFF1E3A5F),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // شريط التقدم
          _buildProgressIndicator(),

          const SizedBox(height: 12),

          // زر تغيير الحركة
          TextButton.icon(
            onPressed: _changeAction,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(isArabic ? 'حركة أخرى' : 'Different action'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    double progress = 0;

    if (_currentAction != null && _faceDetected) {
      switch (_currentAction!) {
        case FaceAction.smile:
          progress = (_smileProbability ?? 0).clamp(0.0, 1.0);
          break;
        case FaceAction.blinkLeft:
          progress = _leftEyeOpen != null
              ? (1 - _leftEyeOpen!).clamp(0.0, 1.0)
              : 0;
          break;
        case FaceAction.blinkRight:
          progress = _rightEyeOpen != null
              ? (1 - _rightEyeOpen!).clamp(0.0, 1.0)
              : 0;
          break;
        case FaceAction.turnLeft:
          progress = _headRotationY != null
              ? ((-_headRotationY!) / 30).clamp(0.0, 1.0)
              : 0;
          break;
        case FaceAction.turnRight:
          progress = _headRotationY != null
              ? ((_headRotationY!) / 30).clamp(0.0, 1.0)
              : 0;
          break;
      }
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.7 ? Colors.green : const Color(0xFF6366F1),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(bool isArabic) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            isArabic ? 'تم التحقق بنجاح! ✓' : 'Verified! ✓',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isArabic) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            // معلومات إضافية
            if (_faceDetected && !_actionCompleted)
              Text(
                isArabic
                    ? 'قم بالحركة المطلوبة لالتقاط الصورة تلقائياً'
                    : 'Perform the action to auto-capture',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 20),

            // زر الإلغاء
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedImage() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الصورة
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  _capturedImage!,
                  width: 300,
                  height: 400,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              // رسالة
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'تم التحقق بنجاح!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'جاري تسجيل الحضور...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// رسم Overlay على الوجه
class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  final bool actionCompleted;

  FaceOverlayPainter({
    required this.faceDetected,
    required this.actionCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 50);
    final ovalWidth = size.width * 0.7;
    final ovalHeight = size.height * 0.45;

    // رسم الإطار البيضاوي للوجه
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = actionCompleted
          ? Colors.green
          : (faceDetected ? Colors.green : Colors.white70);

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawOval(rect, paint);

    // رسم الزوايا
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = actionCompleted
          ? Colors.green
          : (faceDetected ? Colors.green : Colors.white);

    const cornerLength = 40.0;

    // الزوايا الأربع
    // أعلى يسار
    canvas.drawLine(
      Offset(center.dx - ovalWidth / 2, center.dy - ovalHeight / 2 + cornerLength),
      Offset(center.dx - ovalWidth / 2, center.dy - ovalHeight / 2),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - ovalWidth / 2, center.dy - ovalHeight / 2),
      Offset(center.dx - ovalWidth / 2 + cornerLength, center.dy - ovalHeight / 2),
      cornerPaint,
    );

    // أعلى يمين
    canvas.drawLine(
      Offset(center.dx + ovalWidth / 2 - cornerLength, center.dy - ovalHeight / 2),
      Offset(center.dx + ovalWidth / 2, center.dy - ovalHeight / 2),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + ovalWidth / 2, center.dy - ovalHeight / 2),
      Offset(center.dx + ovalWidth / 2, center.dy - ovalHeight / 2 + cornerLength),
      cornerPaint,
    );

    // أسفل يسار
    canvas.drawLine(
      Offset(center.dx - ovalWidth / 2, center.dy + ovalHeight / 2 - cornerLength),
      Offset(center.dx - ovalWidth / 2, center.dy + ovalHeight / 2),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - ovalWidth / 2, center.dy + ovalHeight / 2),
      Offset(center.dx - ovalWidth / 2 + cornerLength, center.dy + ovalHeight / 2),
      cornerPaint,
    );

    // أسفل يمين
    canvas.drawLine(
      Offset(center.dx + ovalWidth / 2 - cornerLength, center.dy + ovalHeight / 2),
      Offset(center.dx + ovalWidth / 2, center.dy + ovalHeight / 2),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + ovalWidth / 2, center.dy + ovalHeight / 2),
      Offset(center.dx + ovalWidth / 2, center.dy + ovalHeight / 2 - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.faceDetected != faceDetected ||
        oldDelegate.actionCompleted != actionCompleted;
  }
}