import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/services/face_verification_service.dart';
import 'package:iskoako/services/audit_log_service.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum _VerificationStep {
  intro,
  idSelect,
  idCaptureFront,
  idCaptureBack,
  idVerifying,
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

  // ID Verification Info
  String? _selectedIdType;
  String? _customIdName;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  String _regFirstName = '';
  String _regLastName = '';
  String _regBirthDate = '';
  IdExtractResult? _idExtractResult;

  static const List<String> _validIdTypes = [
    'Student ID / School ID',
    'PhilSys National ID',
    'Driver\'s License',
    'Philippine Passport',
    'UMID / SSS ID',
    'Postal ID',
    'PRC ID',
    'Voter\'s ID',
    'Other / Custom ID',
  ];

  final _customIdController = TextEditingController();

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _cameraError = false;
  bool _isClassifyingPhoto = false;
  String? _cameraScanError;

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
    _loadScholarDetails();
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
    _customIdController.dispose();
    super.dispose();
  }

  Future<void> _loadScholarDetails() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('scholar')
            .select('first_name, last_name, birth_date')
            .eq('user_id', user.id)
            .maybeSingle();
        if (res != null) {
          setState(() {
            _regFirstName = res['first_name']?.toString() ?? '';
            _regLastName = res['last_name']?.toString() ?? '';
            _regBirthDate = res['birth_date']?.toString() ?? '';
          });
        }
      } catch (e) {
        debugPrint('[FaceVerification] Error loading scholar details: $e');
      }
    }
  }


  Future<void> _runIdVerification() async {
    _goToStep(_VerificationStep.idVerifying);
    final idTypeName = _selectedIdType == 'Other / Custom ID'
        ? (_customIdName ?? _customIdController.text.trim())
        : (_selectedIdType ?? 'ID');

    try {
      final result = await FaceVerificationService.verifyIdDetails(
        frontImageBytes: _idFrontBytes!,
        backImageBytes: _idBackBytes!,
        idType: idTypeName,
        regFirstName: _regFirstName,
        regLastName: _regLastName,
        regBirthDate: _regBirthDate,
      );

      _idExtractResult = result;

      if (result.isMatch) {
        // If it matches, immediately proceed to the first liveness step (blink)!
        _goToStep(_VerificationStep.blink);
      } else {
        // If not matched, reject/flag it in the database and go to result step
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          try {
            await Supabase.instance.client.from('scholar').update({
              'face_verification_status': 'failed',
              'face_verification_reason': 'ID Data Mismatch: ${result.reason}',
              'face_verified_at': null,
            }).eq('user_id', user.id);
          } catch (e) {
            debugPrint('[FaceVerification] Error logging ID mismatch: $e');
          }
        }
        
        setState(() {
          _verificationSuccess = false;
          _resultReason = 'ID Verification Failed: ${result.reason}';
          _step = _VerificationStep.result;
        });
      }
    } catch (e) {
      setState(() {
        _verificationSuccess = false;
        _resultReason = 'Failed to verify ID details: $e';
        _step = _VerificationStep.result;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initCamera({bool front = true}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _cameraError = true);
      return;
    }
    
    // If camera is already ready, but direction is different, dispose first
    if (_cameraController != null) {
      final currentDirection = _cameraController!.description.lensDirection;
      final targetDirection = front ? CameraLensDirection.front : CameraLensDirection.back;
      if (currentDirection != targetDirection) {
        _disposeCamera();
      } else {
        // Already initialized to the correct camera
        return;
      }
    }
    
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Select camera based on direction
      final direction = front ? CameraLensDirection.front : CameraLensDirection.back;
      final selectedCam = _cameras!.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _cameras!.first,
      );
      
      _cameraController = CameraController(
        selectedCam,
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
        // Capture 2 rapid frames across the single natural blink (at ~380ms and ~760ms)
        await Future.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
        final f1 = await _cameraController!.takePicture();
        actionBytes = await f1.readAsBytes();

        await Future.delayed(const Duration(milliseconds: 380));
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
        idImageBytes: _idFrontBytes!,
        selfieBytes: _selfieBytes!,
      );

      final status = result.isMatch ? 'verified' : 'failed';
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        String? idUrl;
        String? selfieUrl;

        // 1. Upload ID Front document to Supabase Storage
        try {
          final idPath = 'face_verification/id_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('scholar-documents').uploadBinary(
                idPath,
                _idFrontBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          idUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(idPath);
          debugPrint('[FaceVerification] ID document uploaded to storage: $idUrl');
        } catch (e) {
          debugPrint('[FaceVerification] ID storage upload error: $e');
        }

        // Upload ID Back document to Supabase Storage
        try {
          final idBackPath = 'face_verification/id_back_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('scholar-documents').uploadBinary(
                idBackPath,
                _idBackBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          final backUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(idBackPath);
          debugPrint('[FaceVerification] ID Back document uploaded: $backUrl');
        } catch (e) {
          debugPrint('[FaceVerification] ID Back storage upload error: $e');
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
          // Fallback update
          await Supabase.instance.client.from('scholar').update({
            'face_verification_status': status,
            'face_verified_at': result.isMatch ? DateTime.now().toIso8601String() : null,
            'face_verification_reason': result.reason,
          }).eq('user_id', user.id);
        }
      }
      
      if (result.isMatch) {
        AuditLogService.createAuditLog(
          action: 'FACE VERIFICATION SUCCESS',
          target: 'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
        );
      } else {
        AuditLogService.createAuditLog(
          action: 'FACE VERIFICATION FAILED',
          target: result.reason,
        );
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
      _VerificationStep.idCaptureFront,
      _VerificationStep.idCaptureBack,
      _VerificationStep.blink,
      _VerificationStep.turnLeft,
      _VerificationStep.turnRight,
      _VerificationStep.selfie,
    ].contains(step);

    if (needsCamera) {
      final useFront = ![
        _VerificationStep.idCaptureFront,
        _VerificationStep.idCaptureBack,
      ].contains(step);
      await _initCamera(front: useFront);
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
      _idFrontBytes = null;
      _idBackBytes = null;
      _selectedIdType = null;
      _customIdName = null;
      _customIdController.clear();
      _idExtractResult = null;
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
      backgroundColor: const Color(0xFFFAFCFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            _buildStepIndicator(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      color: const Color(0xFFFAFCFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_step != _VerificationStep.analyzing)
            GestureDetector(
              onTap: () {
                if (_step == _VerificationStep.intro) {
                  Navigator.pop(context);
                } else {
                  _resetAll();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.arrowLeft,
                  color: Color(0xFF111827),
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 40, height: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 13,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'BIOMETRIC VERIFICATION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getHeaderTitle(),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  _getHeaderSubtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/books-hats-icon.png',
            width: 75,
            height: 65,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_step) {
      case _VerificationStep.intro:
        return 'Verify Identity';
      case _VerificationStep.idSelect:
        return 'Select ID Type';
      case _VerificationStep.idCaptureFront:
        return 'Capture Front ID';
      case _VerificationStep.idCaptureBack:
        return 'Capture Back ID';
      case _VerificationStep.idVerifying:
        return 'AI Verification Check';
      case _VerificationStep.blink:
      case _VerificationStep.turnLeft:
      case _VerificationStep.turnRight:
        return 'Liveness Check';
      case _VerificationStep.selfie:
        return 'Take a Selfie';
      case _VerificationStep.analyzing:
        return 'Analyzing Biometrics';
      case _VerificationStep.result:
        return 'Verification Result';
    }
  }

  String _getHeaderSubtitle() {
    switch (_step) {
      case _VerificationStep.intro:
        return 'Earn your verified scholar badge';
      case _VerificationStep.idSelect:
        return 'Choose your official government or school ID';
      case _VerificationStep.idCaptureFront:
        return 'Align front of ID inside camera box';
      case _VerificationStep.idCaptureBack:
        return 'Align back of ID inside camera box';
      case _VerificationStep.idVerifying:
        return 'Extracting and matching profile details';
      case _VerificationStep.blink:
        return 'Look directly at camera and blink eyes';
      case _VerificationStep.turnLeft:
        return 'Slowly turn your head to the left';
      case _VerificationStep.turnRight:
        return 'Slowly turn your head to the right';
      case _VerificationStep.selfie:
        return 'Capture a clear portrait selfie photo';
      case _VerificationStep.analyzing:
        return 'Facial similarity & liveness score check';
      case _VerificationStep.result:
        return 'Identity verification review complete';
    }
  }

  Widget _buildStepIndicator() {
    int currentStepNum = 1;
    switch (_step) {
      case _VerificationStep.intro:
        currentStepNum = 1;
        break;
      case _VerificationStep.idSelect:
        currentStepNum = 2;
        break;
      case _VerificationStep.idCaptureFront:
        currentStepNum = 3;
        break;
      case _VerificationStep.idCaptureBack:
        currentStepNum = 4;
        break;
      case _VerificationStep.idVerifying:
        currentStepNum = 4;
        break;
      case _VerificationStep.blink:
      case _VerificationStep.turnLeft:
      case _VerificationStep.turnRight:
        currentStepNum = 5;
        break;
      case _VerificationStep.selfie:
        currentStepNum = 5;
        break;
      case _VerificationStep.analyzing:
      case _VerificationStep.result:
        currentStepNum = 6;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFFAFCFA),
      child: Row(
        children: List.generate(6, (index) {
          final isDone = (index + 1) < currentStepNum;
          final isCurrent = (index + 1) == currentStepNum;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
              decoration: BoxDecoration(
                color: isDone || isCurrent
                    ? const Color(0xFF1E3D2F)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _VerificationStep.intro:
        return _buildIntro();
      case _VerificationStep.idSelect:
        return _buildIdSelect();
      case _VerificationStep.idCaptureFront:
        return _buildIdCaptureFront();
      case _VerificationStep.idCaptureBack:
        return _buildIdCaptureBack();
      case _VerificationStep.idVerifying:
        return _buildIdVerifying();
      case _VerificationStep.blink:
        return _buildLivenessStep(
          key: const ValueKey('blink'),
          stepNumber: 4,
          title: 'Blink Your Eyes',
          subtitle: 'Look directly at the camera and blink both eyes',
          icon: LucideIcons.eye,
          action: LivenessAction.blink,
          done: _blinkDone,
        );
      case _VerificationStep.turnLeft:
        return _buildLivenessStep(
          key: const ValueKey('turnLeft'),
          stepNumber: 5,
          title: 'Turn Head Left',
          subtitle: 'Slowly turn your head to your left',
          icon: LucideIcons.arrowLeft,
          action: LivenessAction.turnLeft,
          done: _turnLeftDone,
        );
      case _VerificationStep.turnRight:
        return _buildLivenessStep(
          key: const ValueKey('turnRight'),
          stepNumber: 5,
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
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7EB),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 56,
                    color: Color(0xFF1E3D2F),
                  ),
                  Positioned(
                    right: 22,
                    bottom: 22,
                    child: Transform.rotate(
                      angle: 0.4,
                      child: const Icon(
                        LucideIcons.leaf,
                        color: Color(0xFF5BA778),
                        size: 26,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 24,
                    right: 24,
                    child: Icon(
                      LucideIcons.sparkles,
                      color: Color(0xFFEAB308),
                      size: 16,
                    ),
                  ),
                  const Positioned(
                    bottom: 30,
                    left: 20,
                    child: Icon(
                      LucideIcons.sparkles,
                      color: Color(0xFFEAB308),
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Verify Your Identity',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a quick 3-step check to earn your verified scholar badge. Your data is secured and never shared.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildStepPreviewCard(
            number: '01',
            icon: LucideIcons.creditCard,
            title: 'ID Selection & Capture',
            desc: 'Choose valid ID type and take front/back photos',
          ),
          const SizedBox(height: 12),
          _buildStepPreviewCard(
            number: '02',
            icon: LucideIcons.shieldCheck,
            title: 'AI Verification Check',
            desc: 'Auto-extracts and matches name/birthdate to profile',
          ),
          const SizedBox(height: 12),
          _buildStepPreviewCard(
            number: '03',
            icon: LucideIcons.scanFace,
            title: 'Liveness & Face Match',
            desc: 'Blink, turn head, and match live selfie face to ID',
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Start Verification',
            icon: LucideIcons.arrowRight,
            onTap: () => _goToStep(_VerificationStep.idSelect),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your biometric data is processed securely and not stored.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
            ),
            child: Icon(icon, color: const Color(0xFF1E3D2F), size: 20),
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
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdSelect() {
    final showCustomInput = _selectedIdType == 'Other / Custom ID';
    return SingleChildScrollView(
      key: const ValueKey('idSelect'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(1, 6),
          const SizedBox(height: 24),
          Text(
            'Select ID Type',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a valid document type that you will take a photo of. Make sure the details and photo are readable.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ..._validIdTypes.map((type) {
            final isSelected = _selectedIdType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedIdType = type;
                  if (type != 'Other / Custom ID') {
                    _customIdName = null;
                  }
                }),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withAlpha(12) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.rule,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type.contains('Passport') ? LucideIcons.globe : LucideIcons.creditCard,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          type,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: AppColors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (showCustomInput) ...[
            const SizedBox(height: 16),
            Text(
              'Specify ID Type *',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _customIdController,
              decoration: InputDecoration(
                hintText: 'e.g. Barangay ID, Library Card, Barangay Certificate',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.rule),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (val) {
                setState(() => _customIdName = val.trim());
              },
            ),
          ],
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Continue to Capture',
            icon: LucideIcons.arrowRight,
            onTap: _selectedIdType != null && (!showCustomInput || (_customIdName != null && _customIdName!.isNotEmpty))
                ? () => _goToStep(_VerificationStep.idCaptureFront)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildIdCaptureFront() {
    final displayIdType = _selectedIdType == 'Other / Custom ID' ? (_customIdName ?? 'Custom ID') : (_selectedIdType ?? 'ID');
    return SingleChildScrollView(
      key: const ValueKey('idCaptureFront'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(2, 6),
          const SizedBox(height: 24),
          Text(
            'Capture Front of ID',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Align the front side of your $displayIdType within the frame and capture it. Ensure good lighting and zero glare.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildIdCameraScanner(
            bytes: _idFrontBytes,
            isFront: true,
            idType: displayIdType,
            onCapture: () => _captureLivePhoto(true),
          ),
          if (_idFrontBytes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'ID Front image captured',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _idFrontBytes = null),
                  child: Text(
                    'Retake',
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
            label: 'Continue to Back of ID',
            icon: LucideIcons.arrowRight,
            onTap: _idFrontBytes != null
                ? () => _goToStep(_VerificationStep.idCaptureBack)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildIdCaptureBack() {
    final displayIdType = _selectedIdType == 'Other / Custom ID' ? (_customIdName ?? 'Custom ID') : (_selectedIdType ?? 'ID');
    return SingleChildScrollView(
      key: const ValueKey('idCaptureBack'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(3, 6),
          const SizedBox(height: 24),
          Text(
            'Capture Back of ID',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Align the back side of your $displayIdType within the frame and capture it.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildIdCameraScanner(
            bytes: _idBackBytes,
            isFront: false,
            idType: displayIdType,
            onCapture: () => _captureLivePhoto(false),
          ),
          if (_idBackBytes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'ID Back image captured',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _idBackBytes = null),
                  child: Text(
                    'Retake',
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
            label: 'Submit for AI Verification Check',
            icon: LucideIcons.shieldCheck,
            onTap: _idBackBytes != null ? _runIdVerification : null,
          ),
        ],
      ),
    );
  }

  Widget _buildIdVerifying() {
    return Center(
      key: const ValueKey('idVerifying'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Running AI Verification Check',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Matching your ID details (First Name, Last Name, Birth Date) against your registered scholar profile...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                _buildProgressBar(stepNumber, 6),
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
            _buildProgressBar(6, 6),
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
              style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
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

          if (!_verificationSuccess && _idExtractResult != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extracted ID details:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildResultComparisonRow(
                    label: 'First Name',
                    registered: _regFirstName,
                    extracted: _idExtractResult!.extractedFirstName,
                    mismatched: _idExtractResult!.mismatchedFields.contains('first_name'),
                  ),
                  const Divider(height: 12),
                  _buildResultComparisonRow(
                    label: 'Last Name',
                    registered: _regLastName,
                    extracted: _idExtractResult!.extractedLastName,
                    mismatched: _idExtractResult!.mismatchedFields.contains('last_name'),
                  ),
                  const Divider(height: 12),
                  _buildResultComparisonRow(
                    label: 'Birth Date',
                    registered: _regBirthDate,
                    extracted: _idExtractResult!.extractedBirthDate,
                    mismatched: _idExtractResult!.mismatchedFields.contains('birth_date'),
                  ),
                ],
              ),
            ),
          ],

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

  Future<void> _captureLivePhoto(bool isFront) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isClassifyingPhoto) return;
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // Show classifying spinner
      setState(() => _isClassifyingPhoto = true);

      final displayIdType = _selectedIdType == 'Other / Custom ID' ? (_customIdName ?? 'ID') : (_selectedIdType ?? 'ID');

      // Classify the ID side & verify document type matching before accepting
      final side = await FaceVerificationService.classifyIdSide(
        imageBytes: bytes,
        selectedIdType: displayIdType,
        isFront: isFront,
      );

      if (!mounted) return;
      setState(() => _isClassifyingPhoto = false);

      final expectedSide = isFront ? 'front' : 'back';

      if (side == 'invalid' || side == 'unknown') {
        setState(() {
          _cameraScanError = '❌ Invalid or mismatched ID card! Please capture your physical $displayIdType.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ID Type Mismatch! You selected "$displayIdType". Please capture your physical $displayIdType.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (side != expectedSide) {
        // Wrong side — reject and show feedback
        final wrongLabel = isFront ? 'back' : 'front';
        final expectedLabel = isFront ? 'front' : 'back';
        setState(() {
          _cameraScanError = '❌ Wrong side detected! Found $wrongLabel side. Please align $expectedLabel side.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wrong side detected! This appears to be the $wrongLabel of the ID. Please capture the $expectedLabel side.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      setState(() {
        _cameraScanError = null;
        if (isFront) {
          _idFrontBytes = bytes;
        } else {
          _idBackBytes = bytes;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isClassifyingPhoto = false);
      debugPrint('[FaceVerification] Shutter capture error: $e');
    }
  }

  Widget _buildIdCameraScanner({
    required Uint8List? bytes,
    required bool isFront,
    required String idType,
    required Future<void> Function() onCapture,
  }) {
    if (bytes != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Photo captured successfully',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (!_cameraReady || _cameraController == null) {
      return Container(
        width: double.infinity,
        height: 380,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.rule),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.height ?? 300.0,
                height: _cameraController!.value.previewSize?.width ?? 400.0,
                child: CameraPreview(_cameraController!),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                const cardWidth = 320.0;
                const cardHeight = 200.0;
                final left = (width - cardWidth) / 2;
                final top = (height - cardHeight) / 2;

                final bracketColor = _cameraScanError != null ? AppColors.error : AppColors.primary;
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: top,
                      child: Container(color: Colors.black.withAlpha(160)),
                    ),
                    Positioned(
                      top: top + cardHeight,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(color: Colors.black.withAlpha(160)),
                    ),
                    Positioned(
                      top: top,
                      left: 0,
                      width: left,
                      height: cardHeight,
                      child: Container(color: Colors.black.withAlpha(160)),
                    ),
                    Positioned(
                      top: top,
                      right: 0,
                      width: left,
                      height: cardHeight,
                      child: Container(color: Colors.black.withAlpha(160)),
                    ),
                    Positioned(
                      top: top - 2,
                      left: left - 2,
                      width: cardWidth + 4,
                      height: cardHeight + 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: bracketColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Positioned(
                      top: top - 4,
                      left: left - 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: bracketColor, width: 4),
                            left: BorderSide(color: bracketColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: top - 4,
                      right: left - 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: bracketColor, width: 4),
                            right: BorderSide(color: bracketColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: top - 4,
                      left: left - 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: bracketColor, width: 4),
                            left: BorderSide(color: bracketColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: top - 4,
                      right: left - 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: bracketColor, width: 4),
                            right: BorderSide(color: bracketColor, width: 4),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: top + cardHeight + 12,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _cameraScanError != null
                                ? AppColors.error.withAlpha(230)
                                : Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _cameraScanError != null ? AppColors.error : AppColors.primary.withAlpha(120),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _cameraScanError != null ? LucideIcons.alertCircle : LucideIcons.scanLine,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _cameraScanError ?? (isFront ? 'Align FRONT of ID inside box & tap camera' : 'Align BACK of ID inside box & tap camera'),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _isClassifyingPhoto ? null : onCapture,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isClassifyingPhoto
                              ? Colors.grey.shade200
                              : Colors.white,
                          border: Border.all(
                            color: _isClassifyingPhoto
                                ? Colors.grey
                                : (_cameraScanError != null ? AppColors.error : AppColors.primary),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isClassifyingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              )
                            : Icon(
                                _cameraScanError != null ? LucideIcons.scanLine : LucideIcons.camera,
                                color: _cameraScanError != null ? AppColors.error : AppColors.primary,
                                size: 26,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isClassifyingPhoto
                            ? 'Detecting & Focusing ID...'
                            : (_cameraScanError != null ? 'Align ID to unlock camera' : 'Tap to Scan & Focus ID'),
                        style: GoogleFonts.inter(
                          color: _cameraScanError != null ? Colors.amberAccent : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultComparisonRow({
    required String label,
    required String registered,
    required String extracted,
    required bool mismatched,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile: $registered',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${extracted.isNotEmpty ? extracted : "Not found"}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: mismatched ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
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
