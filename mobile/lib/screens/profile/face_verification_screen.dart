import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/services/face_verification_service.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum _VerificationStep {
  intro,
  idUpload,
  blink,
  turnLeft,
  turnRight,
  selfie,
  analyzing,
  result,
}

enum _LivenessStatus {
  idle,
  capturingBaseline,
  waitingAction,
  actionPassed,
  analyzing,
  failed,
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with TickerProviderStateMixin {
  _VerificationStep _step = _VerificationStep.intro;

  // ID Upload
  Uint8List? _idImageBytes;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _cameraError = false;

  // Selfie
  Uint8List? _selfieBytes;

  // Liveness
  _LivenessStatus _livenessStatus = _LivenessStatus.idle;
  bool _blinkDone = false;
  bool _turnLeftDone = false;
  bool _turnRightDone = false;
  bool _faceDetected = false;
  bool _isCheckingLiveness = false;
  bool _isAnalyzingFrame = false;
  String _livenessHint = '';
  Timer? _livenessTimer;

  // Result
  bool _verificationSuccess = false;
  double _matchConfidence = 0.0;
  String _resultReason = '';
  String _modelUsed = '';

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late AnimationController _turnProgressController;
  late Animation<double> _turnProgressAnimation;
  late AnimationController _actionPassedController;
  late Animation<double> _actionPassedScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);

    _turnProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _turnProgressAnimation = CurvedAnimation(
      parent: _turnProgressController,
      curve: Curves.easeInOutCubic,
    );

    _actionPassedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _actionPassedScale = CurvedAnimation(
      parent: _actionPassedController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    _turnProgressController.dispose();
    _actionPassedController.dispose();
    _livenessTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _cameraError = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Prefer front camera
      final front = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('[FaceVerification] Camera init error: $e');
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    _cameraReady = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ID UPLOAD
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isIdPdf {
    if (_idImageBytes == null || _idImageBytes!.length < 4) return false;
    return _idImageBytes![0] == 0x25 &&
        _idImageBytes![1] == 0x50 &&
        _idImageBytes![2] == 0x44 &&
        _idImageBytes![3] == 0x46;
  }

  Future<void> _pickId(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _idImageBytes = bytes);
  }

  Future<void> _pickIdPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null && mounted) {
        setState(() => _idImageBytes = bytes);
      }
    } catch (e) {
      debugPrint('[FaceVerification] PDF pick error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVENESS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runGuidedLivenessCheck(LivenessAction action) async {
    if (!_cameraReady || _cameraController == null || _isAnalyzingFrame) return;
    _isAnalyzingFrame = true;
    _turnProgressController.reset();
    _actionPassedController.reset();

    setState(() {
      _isCheckingLiveness = true;
      _faceDetected = false;
      _livenessStatus = _LivenessStatus.capturingBaseline;
      _livenessHint = 'Step 1: Hold still facing forward...';
    });

    try {
      // Step 1: Capture baseline frame (facing forward)
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final baselineFile = await _cameraController!.takePicture();
      final baselineBytes = await baselineFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _faceDetected = true; // Forward face locked
        _livenessStatus = _LivenessStatus.waitingAction;
        if (action == LivenessAction.blink) {
          _livenessHint = 'Step 2: Blink your eyes once now!';
        } else if (action == LivenessAction.turnLeft) {
          _livenessHint = 'Step 2: Turn your head to the LEFT';
          _turnProgressController.forward();
        } else {
          _livenessHint = 'Step 2: Turn your head to the RIGHT';
          _turnProgressController.forward();
        }
      });

      Uint8List actionBytes;
      List<Uint8List> additionalFrames = [];

      if (action == LivenessAction.blink) {
        // Capture 2 rapid frames across the single natural blink (at ~200ms and ~450ms)
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        final f1 = await _cameraController!.takePicture();
        actionBytes = await f1.readAsBytes();

        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        final f2 = await _cameraController!.takePicture();
        final f2Bytes = await f2.readAsBytes();
        additionalFrames.add(f2Bytes);
      } else {
        // For turn actions: allow 1100ms for head turn
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        final f = await _cameraController!.takePicture();
        actionBytes = await f.readAsBytes();
      }

      if (!mounted) return;

      // Start analyzing immediately after user blinks once / turns
      setState(() {
        _livenessStatus = _LivenessStatus.analyzing;
        _livenessHint = action == LivenessAction.blink
            ? 'Analyzing blink...'
            : 'Analyzing movement...';
      });

      // Step 3: Send comparative frames to AI for verification
      final result = await FaceVerificationService.checkLiveness(
        frameBytes: actionBytes,
        baselineFrameBytes: baselineBytes,
        additionalActionFramesBytes: additionalFrames.isNotEmpty ? additionalFrames : null,
        expectedAction: action,
      );

      if (!mounted) return;

      if (result.actionDetected) {
        // Show "Action Passed" confirmation state
        setState(() {
          _faceDetected = true;
          _livenessStatus = _LivenessStatus.actionPassed;
          _livenessHint = 'Action Passed! ✓';
          if (action == LivenessAction.blink) _blinkDone = true;
          if (action == LivenessAction.turnLeft) _turnLeftDone = true;
          if (action == LivenessAction.turnRight) _turnRightDone = true;
        });
        _actionPassedController.forward();
        _checkController.forward();

        // Display "Action Passed" for ~1000ms then advance
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;

        _advanceLivenessStep(action);
      } else {
        setState(() {
          _isCheckingLiveness = false;
          _faceDetected = false;
          _livenessStatus = _LivenessStatus.failed;
          _livenessHint = result.reason.isNotEmpty
              ? 'AI: ${result.reason}\nTap "Start Check" to retry.'
              : 'Action not detected. Please tap "Start Check" to retry.';
        });
        _turnProgressController.reset();
      }
    } catch (e) {
      debugPrint('[FaceVerification] Guided check error: $e');
      if (mounted) {
        setState(() {
          _isCheckingLiveness = false;
          _faceDetected = false;
          _livenessStatus = _LivenessStatus.failed;
          _livenessHint = 'Camera error. Please tap "Start Check" to try again.';
        });
      }
    } finally {
      _isAnalyzingFrame = false;
    }
  }

  void _advanceLivenessStep(LivenessAction completedAction) {
    _checkController.reset();
    _actionPassedController.reset();
    _turnProgressController.reset();
    if (completedAction == LivenessAction.blink) {
      _goToStep(_VerificationStep.turnLeft);
    } else if (completedAction == LivenessAction.turnLeft) {
      _goToStep(_VerificationStep.turnRight);
    } else if (completedAction == LivenessAction.turnRight) {
      _goToStep(_VerificationStep.selfie);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELFIE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _captureSelfie() async {
    if (!_cameraReady || _cameraController == null) return;
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      if (mounted) {
        setState(() => _selfieBytes = bytes);
      }
    } catch (e) {
      debugPrint('[FaceVerification] Selfie capture error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANALYSIS + SUPABASE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runAnalysis() async {
    _goToStep(_VerificationStep.analyzing);
    _disposeCamera();

    try {
      final result = await FaceVerificationService.matchFaces(
        idImageBytes: _idImageBytes!,
        selfieBytes: _selfieBytes!,
      );

      final status = result.isMatch ? 'verified' : 'failed';
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        String? idUrl;
        String? selfieUrl;

        // 1. Upload ID document to Supabase Storage
        try {
          final idExt = _isIdPdf ? 'pdf' : 'jpg';
          final idPath = 'face_verification/id_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$idExt';
          await Supabase.instance.client.storage.from('scholar-documents').uploadBinary(
                idPath,
                _idImageBytes!,
                fileOptions: FileOptions(
                  contentType: _isIdPdf ? 'application/pdf' : 'image/jpeg',
                  upsert: true,
                ),
              );
          idUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(idPath);
          debugPrint('[FaceVerification] ID document uploaded to storage: $idUrl');
        } catch (e) {
          debugPrint('[FaceVerification] ID storage upload error: $e');
        }

        // 2. Upload Selfie to Supabase Storage
        try {
          final selfiePath = 'face_verification/selfie_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('scholar-documents').uploadBinary(
                selfiePath,
                _selfieBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          selfieUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(selfiePath);
          debugPrint('[FaceVerification] Selfie uploaded to storage: $selfieUrl');
        } catch (e) {
          debugPrint('[FaceVerification] Selfie storage upload error: $e');
        }

        // 3. Update scholar row in database
        final updatePayload = <String, dynamic>{
          'face_verification_status': status,
          'face_verified_at': result.isMatch ? DateTime.now().toIso8601String() : null,
          'face_verification_reason': result.reason,
        };
        if (idUrl != null) updatePayload['id_document_url'] = idUrl;
        if (selfieUrl != null) updatePayload['face_selfie_url'] = selfieUrl;

        try {
          await Supabase.instance.client.from('scholar').update(updatePayload).eq('user_id', user.id);
        } catch (e) {
          // If custom URL columns don't exist yet, update core verification columns
          await Supabase.instance.client.from('scholar').update({
            'face_verification_status': status,
            'face_verified_at': result.isMatch ? DateTime.now().toIso8601String() : null,
            'face_verification_reason': result.reason,
          }).eq('user_id', user.id);
        }
      }

      if (mounted) {
        setState(() {
          _verificationSuccess = result.isMatch;
          _matchConfidence = result.confidence;
          _resultReason = result.reason;
          _modelUsed = result.modelUsed;
          _step = _VerificationStep.result;
        });
        if (result.isMatch) _checkController.forward();
      }
    } catch (e) {
      debugPrint('[FaceVerification] Analysis error: $e');
      if (mounted) {
        setState(() {
          _verificationSuccess = false;
          _resultReason = 'An error occurred during analysis. Please try again.';
          _step = _VerificationStep.result;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _goToStep(_VerificationStep step) async {
    _livenessTimer?.cancel();
    _turnProgressController.reset();
    _actionPassedController.reset();
    _checkController.reset();

    String defaultHint = '';
    if (step == _VerificationStep.blink) {
      defaultHint = 'Look straight at the camera, then tap "Start Check"';
    } else if (step == _VerificationStep.turnLeft) {
      defaultHint = 'Look straight at the camera, then tap "Start Check"';
    } else if (step == _VerificationStep.turnRight) {
      defaultHint = 'Look straight at the camera, then tap "Start Check"';
    }

    setState(() {
      _step = step;
      _livenessStatus = _LivenessStatus.idle;
      _livenessHint = defaultHint;
      _isCheckingLiveness = false;
      _faceDetected = false;
    });

    // Init camera when entering a camera step
    final needsCamera = [
      _VerificationStep.blink,
      _VerificationStep.turnLeft,
      _VerificationStep.turnRight,
      _VerificationStep.selfie,
    ].contains(step);

    if (needsCamera && !_cameraReady) {
      await _initCamera();
    }
  }

  void _resetAll() {
    _livenessTimer?.cancel();
    _disposeCamera();
    _checkController.reset();
    _turnProgressController.reset();
    _actionPassedController.reset();
    setState(() {
      _step = _VerificationStep.intro;
      _idImageBytes = null;
      _selfieBytes = null;
      _livenessStatus = _LivenessStatus.idle;
      _blinkDone = false;
      _turnLeftDone = false;
      _turnRightDone = false;
      _faceDetected = false;
      _isCheckingLiveness = false;
      _livenessHint = '';
      _verificationSuccess = false;
      _matchConfidence = 0.0;
      _resultReason = '';
      _modelUsed = '';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _buildCurrentStep(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = {
      _VerificationStep.intro: 'Identity Verification',
      _VerificationStep.idUpload: 'Upload Your ID',
      _VerificationStep.blink: 'Liveness — Blink',
      _VerificationStep.turnLeft: 'Liveness — Turn Left',
      _VerificationStep.turnRight: 'Liveness — Turn Right',
      _VerificationStep.selfie: 'Take a Selfie',
      _VerificationStep.analyzing: 'Analyzing',
      _VerificationStep.result: 'Verification Result',
    };
    return AppBar(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        titles[_step] ?? 'Verification',
        style: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      leading: _step != _VerificationStep.analyzing
          ? IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () {
                if (_step == _VerificationStep.intro) {
                  Navigator.pop(context);
                } else {
                  _resetAll();
                }
              },
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _VerificationStep.intro:
        return _buildIntro();
      case _VerificationStep.idUpload:
        return _buildIdUpload();
      case _VerificationStep.blink:
        return _buildLivenessStep(
          key: const ValueKey('blink'),
          stepNumber: 1,
          title: 'Blink Your Eyes',
          subtitle: 'Look directly at the camera and blink both eyes',
          icon: LucideIcons.eye,
          action: LivenessAction.blink,
          done: _blinkDone,
        );
      case _VerificationStep.turnLeft:
        return _buildLivenessStep(
          key: const ValueKey('turnLeft'),
          stepNumber: 2,
          title: 'Turn Head Left',
          subtitle: 'Slowly turn your head to your left',
          icon: LucideIcons.arrowLeft,
          action: LivenessAction.turnLeft,
          done: _turnLeftDone,
        );
      case _VerificationStep.turnRight:
        return _buildLivenessStep(
          key: const ValueKey('turnRight'),
          stepNumber: 3,
          title: 'Turn Head Right',
          subtitle: 'Slowly turn your head to your right',
          icon: LucideIcons.arrowRight,
          action: LivenessAction.turnRight,
          done: _turnRightDone,
        );
      case _VerificationStep.selfie:
        return _buildSelfieStep();
      case _VerificationStep.analyzing:
        return _buildAnalyzing();
      case _VerificationStep.result:
        return _buildResult();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildIntro() {
    return SingleChildScrollView(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero illustration
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.signatureGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Verify Your Identity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a quick 3-step check to earn your verified scholar badge. Your data is secured and never shared.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          _buildStepPreviewCard(
            number: '01',
            icon: LucideIcons.creditCard,
            title: 'Upload Valid ID',
            desc: 'School ID, government-issued ID',
          ),
          const SizedBox(height: 12),
          _buildStepPreviewCard(
            number: '02',
            icon: LucideIcons.scanFace,
            title: 'Liveness Detection',
            desc: 'Blink, turn left, turn right',
          ),
          const SizedBox(height: 12),
          _buildStepPreviewCard(
            number: '03',
            icon: LucideIcons.camera,
            title: 'Selfie Capture',
            desc: 'AI matches your face to your ID',
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Start Verification',
            icon: LucideIcons.arrowRight,
            onTap: () => _goToStep(_VerificationStep.idUpload),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your biometric data is processed securely and not stored.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPreviewCard({
    required String number,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rule),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.signatureGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $number — $title',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdUpload() {
    return SingleChildScrollView(
      key: const ValueKey('idUpload'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(1, 4),
          const SizedBox(height: 24),
          Text(
            'Upload Your ID',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Take a clear photo of your school ID or any valid government-issued ID. Make sure the face photo is clearly visible.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // ID Preview or placeholder
          GestureDetector(
            onTap: () => _showImagePickerOptions(),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: _idImageBytes != null
                    ? Colors.transparent
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _idImageBytes != null
                      ? AppColors.primary
                      : AppColors.rule,
                  width: _idImageBytes != null ? 2 : 1,
                ),
              ),
              child: _idImageBytes != null
                  ? (_isIdPdf
                      ? Container(
                          color: AppColors.primaryDark.withAlpha(15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.fileText,
                                  color: AppColors.error,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'PDF ID Document Uploaded',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ready for AI face verification check',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.memory(
                            _idImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.upload,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to upload ID photo',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Camera or Gallery',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          if (_idImageBytes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.checkCircle,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  _isIdPdf ? 'PDF ID document uploaded' : 'ID photo uploaded',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Continue to Liveness Check',
            icon: LucideIcons.arrowRight,
            onTap: _idImageBytes != null
                ? () => _goToStep(_VerificationStep.blink)
                : null,
          ),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload ID Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.camera,
                      color: AppColors.primary, size: 18),
                ),
                title: Text('Take Photo',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickId(ImageSource.camera);
                },
              ),
              const Divider(height: 8, color: AppColors.rule),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.image,
                      color: AppColors.amberDeep, size: 18),
                ),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickId(ImageSource.gallery);
                },
              ),
              const Divider(height: 8, color: AppColors.rule),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.fileText,
                      color: AppColors.error, size: 18),
                ),
                title: Text('Upload PDF Document',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickIdPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivenessStep({
    required Key key,
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required LivenessAction action,
    required bool done,
  }) {
    final isTurnAction = action == LivenessAction.turnLeft || action == LivenessAction.turnRight;
    final isTurnLeft = action == LivenessAction.turnLeft;
    final isActionPassed = done || _livenessStatus == _LivenessStatus.actionPassed;
    final isAnalyzing = _livenessStatus == _LivenessStatus.analyzing;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _turnProgressAnimation, _actionPassedScale]),
      builder: (context, _) {
        return Container(
          key: key,
          color: AppColors.background,
          child: SafeArea(
            child: Column(
              children: [
                _buildProgressBar(stepNumber + 1, 4),
                const SizedBox(height: 12),

                // Top instruction badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.rule),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: AppColors.signatureGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Center Oval Face Cutout Viewport with Side Turn Indicator
                _buildOvalFaceViewport(
                  child: _buildCameraWidget(),
                  isActionPassed: isActionPassed,
                  isFaceDetected: _faceDetected,
                  isTurnAction: isTurnAction,
                  isTurnLeft: isTurnLeft,
                  turnProgress: _turnProgressAnimation.value,
                ),

                const Spacer(),

                // Status / Guidance Card & Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildLivenessFeedback(
                    action: action,
                    done: done,
                    isActionPassed: isActionPassed,
                    isAnalyzing: isAnalyzing,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOvalFaceViewport({
    required Widget child,
    required bool isActionPassed,
    required bool isFaceDetected,
    required bool isTurnAction,
    required bool isTurnLeft,
    double turnProgress = 0.0,
  }) {
    const ovalWidth = 230.0;
    const ovalHeight = 300.0;
    const ovalRadius = 115.0;

    List<BoxShadow> shadows = [];
    if (isActionPassed) {
      shadows = [
        BoxShadow(
          color: AppColors.primary.withAlpha(90),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ];
    } else if (isFaceDetected) {
      shadows = [
        BoxShadow(
          color: Colors.blueAccent.withAlpha(70),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ];
    } else {
      shadows = [
        BoxShadow(
          color: Colors.black.withAlpha(15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }

    return Center(
      child: ScaleTransition(
        scale: isActionPassed ? _actionPassedScale : _pulse,
        child: Container(
          width: ovalWidth,
          height: ovalHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ovalRadius),
            boxShadow: shadows,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera preview inside the oval (pure video, NO lines inside)
              ClipRRect(
                borderRadius: BorderRadius.circular(ovalRadius - 3),
                child: Container(
                  color: AppColors.surfaceAlt,
                  child: child,
                ),
              ),

              // 2. Circle line itself as the dynamic indicator
              CustomPaint(
                painter: _CircleBorderPainter(
                  baseColor: AppColors.primary.withAlpha(130),
                  activeColor: AppColors.primary,
                  progress: turnProgress,
                  isTurnLeft: isTurnAction && isTurnLeft,
                  isTurnRight: isTurnAction && !isTurnLeft,
                  isActionPassed: isActionPassed,
                  isFaceDetected: isFaceDetected,
                ),
              ),

              // 3. Action Passed Checkmark Overlay
              if (isActionPassed)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(35),
                    borderRadius: BorderRadius.circular(ovalRadius - 3),
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(100),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraWidget() {
    if (_cameraReady && _cameraController != null) {
      final previewSize = _cameraController!.value.previewSize;
      final previewHeight = previewSize?.height ?? 300.0;
      final previewWidth = previewSize?.width ?? 400.0;

      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewHeight,
          height: previewWidth,
          child: CameraPreview(_cameraController!),
        ),
      );
    } else if (_cameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.cameraOff, color: AppColors.error, size: 36),
              const SizedBox(height: 8),
              Text(
                'Camera Error',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }
  }

  Widget _buildLivenessFeedback({
    required LivenessAction action,
    required bool done,
    required bool isActionPassed,
    required bool isAnalyzing,
  }) {
    if (isActionPassed) {
      return ScaleTransition(
        scale: _actionPassedScale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.checkCircle, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Action Passed!',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(60), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _livenessHint.isNotEmpty ? _livenessHint : 'Analyzing Face Movement...',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_livenessHint.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _livenessStatus == _LivenessStatus.failed
                  ? AppColors.errorBg
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _livenessStatus == _LivenessStatus.failed
                    ? AppColors.error
                    : AppColors.rule,
                width: 1,
              ),
            ),
            child: Text(
              _livenessHint,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _livenessStatus == _LivenessStatus.failed
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildPrimaryButton(
          label: _isAnalyzingFrame
              ? 'Analyzing Movement...'
              : (_isCheckingLiveness ? 'Checking In Progress...' : 'Start Check'),
          icon: LucideIcons.play,
          onTap: _isAnalyzingFrame || _isCheckingLiveness
              ? null
              : () => _runGuidedLivenessCheck(action),
        ),
      ],
    );
  }

  Widget _buildSelfieStep() {
    return Container(
      key: const ValueKey('selfie'),
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(4, 4),
            const SizedBox(height: 12),

            // Top instruction badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rule),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.signatureGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.camera, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selfieBytes != null ? 'Selfie Captured' : 'Take a Selfie',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selfieBytes != null
                                ? 'Looking good! Proceed or retake.'
                                : 'Look straight at the camera and take your photo',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Center Oval Face Cutout Viewport
            _buildOvalFaceViewport(
              child: _selfieBytes != null
                  ? Image.memory(
                      _selfieBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : _buildCameraWidget(),
              isActionPassed: false,
              isFaceDetected: _selfieBytes != null,
              isTurnAction: false,
              isTurnLeft: false,
            ),

            const Spacer(),

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _selfieBytes != null
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _selfieBytes = null),
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: Text(
                              'Retake',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.rule, width: 1.5),
                              backgroundColor: AppColors.surface,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _runAnalysis,
                            icon: const Icon(LucideIcons.brain, size: 16),
                            label: Text(
                              'Run AI Match',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: GestureDetector(
                        onTap: _captureSelfie,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: AppColors.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(80),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.camera,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzing() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.signatureGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Analyzing Your Identity',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Our AI is comparing your ID photo with your selfie.\nThis may take a few seconds.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Result icon
          ScaleTransition(
            scale: _verificationSuccess ? _checkScale : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _verificationSuccess
                    ? AppColors.successBg
                    : AppColors.errorBg,
                border: Border.all(
                  color: _verificationSuccess ? AppColors.primary : AppColors.error,
                  width: 3,
                ),
              ),
              child: Icon(
                _verificationSuccess ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
                size: 48,
                color: _verificationSuccess ? AppColors.primary : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _verificationSuccess ? 'Identity Verified!' : 'Verification Failed',
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _verificationSuccess ? AppColors.primaryDark : AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _resultReason.isNotEmpty
                ? _resultReason
                : (_verificationSuccess
                    ? 'Your identity has been successfully verified.'
                    : 'We could not verify your identity at this time.'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          if (_verificationSuccess) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confidence Score',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${(_matchConfidence * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.cpu, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Powered by $_modelUsed',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (_verificationSuccess) ...[
            _buildPrimaryButton(
              label: 'Back to Profile',
              icon: LucideIcons.user,
              onTap: () => Navigator.pop(context, true),
            ),
          ] else ...[
            _buildPrimaryButton(
              label: 'Try Again',
              icon: LucideIcons.refreshCw,
              onTap: _resetAll,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.rule),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProgressBar(int current, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $current of $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${((current / total) * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              backgroundColor: AppColors.rule,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onTap != null ? AppColors.primary : AppColors.rule,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.rule,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: onTap != null ? 2 : 0,
        ),
      ),
    );
  }
}

// ─── Reticle Painter ──────────────────────────────────────────────────────────

class _CircleBorderPainter extends CustomPainter {
  final Color baseColor;
  final Color activeColor;
  final double progress;
  final bool isTurnLeft;
  final bool isTurnRight;
  final bool isActionPassed;
  final bool isFaceDetected;

  const _CircleBorderPainter({
    required this.baseColor,
    required this.activeColor,
    required this.progress,
    required this.isTurnLeft,
    required this.isTurnRight,
    required this.isActionPassed,
    required this.isFaceDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular((size.width - 4) / 2));

    final basePaint = Paint()
      ..color = isActionPassed
          ? activeColor
          : (isFaceDetected ? Colors.blueAccent : baseColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActionPassed || isFaceDetected ? 4.0 : 2.5;

    canvas.drawRRect(rrect, basePaint);

    if ((isTurnLeft || isTurnRight) && progress > 0.0 && !isActionPassed) {
      final turnPaint = Paint()
        ..color = Color.lerp(Colors.blueAccent, activeColor, progress) ?? activeColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.5;

      const startAngle = -3.14159265 / 2;
      final sweepAngle = isTurnLeft
          ? -3.14159265 * progress
          : 3.14159265 * progress;

      final path = Path()..addArc(rect, startAngle, sweepAngle);
      canvas.drawPath(path, turnPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircleBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isActionPassed != isActionPassed ||
      oldDelegate.isFaceDetected != isFaceDetected ||
      oldDelegate.isTurnLeft != isTurnLeft ||
      oldDelegate.isTurnRight != isTurnRight ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.activeColor != activeColor;
}
