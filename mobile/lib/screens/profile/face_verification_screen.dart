import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  waitingAction,
  actionPassed,
  analyzing,
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
  Uint8List? _tempCapturedBytes;
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

  // ML Kit Face Detector & Live Tracking
  late final FaceDetector _faceDetector;
  int _detectedFaceCount = 0;
  bool _isFocusVerified = false;
  int _focusContinuousTicks = 0;
  static const int _requiredFocusTicks = 30; // 3.0 seconds (30 * 100ms)
  double _focusHoldProgress = 0.0;
  double _liveActionProgress = 0.0;
  String _liveActionHint = '';
  bool _isActionWrongDirection = false;
  bool _isStreamingFrames = false;
  bool _isProcessingFrame = false;
  bool _isActionPassedNow = false;
  double? _baselineYaw;
  int _completionHoldFrames = 0;
  bool _eyesOpenObserved = false;

  // Selfie
  Uint8List? _selfieBytes;

  // Liveness
  _LivenessStatus _livenessStatus = _LivenessStatus.idle;
  bool _blinkDone = false;
  bool _turnLeftDone = false;
  bool _turnRightDone = false;
  bool _faceDetected = false;
  bool _isCheckingLiveness = false;
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
  late AnimationController _actionPassedController;
  late Animation<double> _actionPassedScale;

  @override
  void initState() {
    super.initState();
    _loadScholarDetails();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

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
    _stopLiveFaceDetection();
    _cameraController?.dispose();
    _faceDetector.close();
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
  // CAMERA & REAL-TIME ML KIT FACE DETECTION
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
        await _stopLiveFaceDetection();
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
      
      final isAndroid = Platform.isAndroid;
      final formatGroup = front
          ? (isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888)
          : ImageFormatGroup.jpeg;

      _cameraController = CameraController(
        selectedCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: formatGroup,
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

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _startLiveFaceDetection() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isStreamingFrames) return;

    _isStreamingFrames = true;
    _isProcessingFrame = false;
    _isActionPassedNow = false;

    try {
      await _cameraController!.startImageStream(_processLiveCameraImage);
    } catch (e) {
      debugPrint('[FaceVerification] Start stream error: $e');
      _isStreamingFrames = false;
    }
  }

  Future<void> _stopLiveFaceDetection() async {
    if (!_isStreamingFrames || _cameraController == null) return;
    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint('[FaceVerification] Stop stream error: $e');
    } finally {
      _isStreamingFrames = false;
    }
  }

  Future<void> _processLiveCameraImage(CameraImage image) async {
    if (_isProcessingFrame || !mounted || _cameraController == null) return;
    _isProcessingFrame = true;

    try {
      final camera = _cameras?.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameraController!.description,
      ) ?? _cameraController!.description;

      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      final count = faces.length;

      if (count == 1) {
        final face = faces.first;

        // Accumulate continuous 1-face focus hold (3.0 seconds total)
        if (!_isFocusVerified) {
          _focusContinuousTicks++;
          _focusHoldProgress = (_focusContinuousTicks / _requiredFocusTicks).clamp(0.0, 1.0);
          if (_focusContinuousTicks >= _requiredFocusTicks) {
            _isFocusVerified = true;
          }
        }

        // Track live action progress if on a liveness action step
        if (_step == _VerificationStep.blink ||
            _step == _VerificationStep.turnLeft ||
            _step == _VerificationStep.turnRight) {
          final expectedAction = _step == _VerificationStep.blink
              ? LivenessAction.blink
              : (_step == _VerificationStep.turnLeft
                  ? LivenessAction.turnLeft
                  : LivenessAction.turnRight);

          if (_isCheckingLiveness && !_isActionPassedNow) {
            // Lock baseline forward yaw when starting turn measurement
            _baselineYaw ??= face.headEulerAngleY;

            // For blink: verify eyes are open first before accepting a blink closure
            if (expectedAction == LivenessAction.blink && !_eyesOpenObserved) {
              final left = face.leftEyeOpenProbability ?? 0.0;
              final right = face.rightEyeOpenProbability ?? 0.0;
              if (left >= 0.65 && right >= 0.65) {
                _eyesOpenObserved = true;
              }
            }

            final actionResult = FaceVerificationService.calculateActionProgress(
              expectedAction: expectedAction,
              face: face,
              baselineYaw: _baselineYaw,
              eyesOpenObserved: _eyesOpenObserved,
            );

            _liveActionProgress = actionResult.progress;
            _liveActionHint = actionResult.hint;
            _isActionWrongDirection = actionResult.isWrongDirection;

            if (actionResult.isCompleted && _liveActionProgress >= 1.0) {
              _completionHoldFrames++;
              // For blink: 1 frame is enough; for turns: require 2 frames to avoid accidental transient jerks
              if (_completionHoldFrames >= (expectedAction == LivenessAction.blink ? 1 : 2)) {
                _handleLivenessActionCompleted(expectedAction);
              }
            } else {
              _completionHoldFrames = 0;
            }
          }
        }

        if (mounted) {
          setState(() {
            _detectedFaceCount = 1;
            _faceDetected = true;
          });
        }
      } else {
        // Either 0 faces or 2+ faces
        _focusContinuousTicks = 0;
        _focusHoldProgress = 0.0;
        _isFocusVerified = false;
        _liveActionProgress = 0.0;
        _liveActionHint = '';
        _isActionWrongDirection = false;
        _baselineYaw = null;
        _completionHoldFrames = 0;
        _eyesOpenObserved = false;

        if (mounted) {
          setState(() {
            _detectedFaceCount = count;
            _faceDetected = count > 0;
          });
        }
      }
    } catch (e) {
      debugPrint('[FaceVerification] Stream process error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleLivenessActionCompleted(LivenessAction action) async {
    if (_isActionPassedNow) return;
    _isActionPassedNow = true;

    setState(() {
      _livenessStatus = _LivenessStatus.actionPassed;
      _liveActionHint = action == LivenessAction.blink
          ? 'Blink detected! ✓'
          : 'Action Passed 100%! ✓';
      if (action == LivenessAction.blink) _blinkDone = true;
      if (action == LivenessAction.turnLeft) _turnLeftDone = true;
      if (action == LivenessAction.turnRight) _turnRightDone = true;
    });

    _actionPassedController.forward();
    _checkController.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    _advanceLivenessStep(action);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVENESS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runGuidedLivenessCheck(LivenessAction action) async {
    if (!_cameraReady || _cameraController == null) return;
    if (_detectedFaceCount != 1 || !_isFocusVerified) return;

    _turnProgressController.reset();
    _actionPassedController.reset();
    _liveActionProgress = 0.0;
    _isActionPassedNow = false;
    _baselineYaw = null;
    _completionHoldFrames = 0;
    _eyesOpenObserved = false;

    setState(() {
      _isCheckingLiveness = true;
      _livenessStatus = _LivenessStatus.waitingAction;
      if (action == LivenessAction.blink) {
        _liveActionHint = 'Blink both eyes now';
      } else if (action == LivenessAction.turnLeft) {
        _liveActionHint = 'Slowly turn your head to the LEFT';
      } else {
        _liveActionHint = 'Slowly turn your head to the RIGHT';
      }
    });

    if (!_isStreamingFrames) {
      await _startLiveFaceDetection();
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
    if (_detectedFaceCount != 1 || !_isFocusVerified) return;

    try {
      await _stopLiveFaceDetection();
      await Future.delayed(const Duration(milliseconds: 100));
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
        final verifiedIdFirstName = FaceVerificationService.cleanExtractedName(
            _idExtractResult?.extractedFirstName.isNotEmpty == true
                ? _idExtractResult!.extractedFirstName
                : _regFirstName);
        final verifiedIdMiddleName = FaceVerificationService.cleanExtractedName(
            _idExtractResult?.extractedMiddleName.isNotEmpty == true
                ? _idExtractResult!.extractedMiddleName
                : '');
        final verifiedIdLastName = FaceVerificationService.cleanExtractedName(
            _idExtractResult?.extractedLastName.isNotEmpty == true
                ? _idExtractResult!.extractedLastName
                : _regLastName);
        final verifiedIdFullName = [verifiedIdFirstName, verifiedIdMiddleName, verifiedIdLastName].where((s) => s.isNotEmpty).join(' ');
        final verifiedIdBirthDate = _idExtractResult?.extractedBirthDate.isNotEmpty == true
            ? _idExtractResult!.extractedBirthDate
            : _regBirthDate;
        final verifiedIdNumber = _idExtractResult?.extractedIdNumber;
        final resolvedIdType = _selectedIdType == 'Other / Custom ID'
            ? (_customIdController.text.trim().isNotEmpty ? _customIdController.text.trim() : 'Custom ID')
            : (_selectedIdType ?? 'Valid ID');

        final verifiedIdData = {
          'id_full_name': verifiedIdFullName,
          'id_first_name': verifiedIdFirstName,
          'id_middle_name': verifiedIdMiddleName,
          'id_last_name': verifiedIdLastName,
          'id_birth_date': verifiedIdBirthDate,
          'id_type': resolvedIdType,
          'id_number': verifiedIdNumber,
          'verified_at': DateTime.now().toIso8601String(),
        };

        // 3. Update scholar row in database (using valid schema columns)
        final scholarPayload = <String, dynamic>{
          'face_verification_status': status,
          'face_verified_at': result.isMatch ? DateTime.now().toIso8601String() : null,
          'face_verification_reason': result.reason,
        };

        try {
          await Supabase.instance.client.from('scholar').update(scholarPayload).eq('user_id', user.id);
        } catch (e) {
          debugPrint('[FaceVerification] Error updating scholar table: $e');
        }

        // 4. Save Verified ID document to scholar_documents table
        if (idUrl != null) {
          try {
            final scholarRow = await Supabase.instance.client
                .from('scholar')
                .select('id')
                .eq('user_id', user.id)
                .maybeSingle();

            if (scholarRow != null) {
              final scholarId = scholarRow['id'];
              await Supabase.instance.client.from('scholar_documents').upsert({
                'scholar_id': scholarId,
                'document_name': 'Verified Government / Student ID',
                'document_url': idUrl,
                'verification_status': result.isMatch ? 'verified' : 'rejected',
                'document_type': 'id_verification',
                'remarks': 'Face & ID Verification ($resolvedIdType) - Holder: $verifiedIdFullName',
                'ai_verification_status': result.isMatch ? 'verified' : 'rejected',
                'ai_confidence_score': result.confidence,
                'ai_model_used': result.modelUsed,
              });
            }
          } catch (docErr) {
            debugPrint('[FaceVerification] Error logging ID to scholar_documents: $docErr');
          }
        }

        // 5. Store verified ID data in auth metadata for duplicate/integrity checks
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'verified_id_data': verifiedIdData}),
          );
        } catch (_) {}
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

    await _stopLiveFaceDetection();

    setState(() {
      _step = step;
      _livenessStatus = _LivenessStatus.idle;
      _isCheckingLiveness = false;
      _faceDetected = false;
      _detectedFaceCount = 0;
      _isFocusVerified = false;
      _focusContinuousTicks = 0;
      _focusHoldProgress = 0.0;
      _liveActionProgress = 0.0;
      _liveActionHint = '';
      _isActionWrongDirection = false;
      _isActionPassedNow = false;
      _baselineYaw = null;
      _completionHoldFrames = 0;
      _eyesOpenObserved = false;
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

      // Start live ML Kit streaming for front-camera liveness/selfie steps
      if (useFront && _cameraReady) {
        await _startLiveFaceDetection();
      }
    }
  }

  void _resetAll() async {
    _livenessTimer?.cancel();
    await _stopLiveFaceDetection();
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
      _detectedFaceCount = 0;
      _isFocusVerified = false;
      _focusContinuousTicks = 0;
      _focusHoldProgress = 0.0;
      _liveActionProgress = 0.0;
      _liveActionHint = '';
      _isActionWrongDirection = false;
      _isActionPassedNow = false;
      _isCheckingLiveness = false;
      _verificationSuccess = false;
      _matchConfidence = 0.0;
      _resultReason = '';
      _modelUsed = '';
      _baselineYaw = null;
      _completionHoldFrames = 0;
      _eyesOpenObserved = false;
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

  Widget _buildStatusBanner() {
    if (_detectedFaceCount >= 2) {
      // RED BANNER
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.users, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multiple Faces Detected ($_detectedFaceCount People)',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF991B1B),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Only 1 person must be in the camera frame. Please ensure you are alone.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB91C1C),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_detectedFaceCount == 1) {
      // BLUE BANNER
      final isVerified = _isFocusVerified;
      final remainingSeconds = ((1.0 - _focusHoldProgress) * 3.0).ceil().clamp(1, 3);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVerified ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isVerified ? const Color(0xFFDBEAFE) : const Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVerified ? LucideIcons.checkCircle2 : LucideIcons.userCheck,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified
                            ? '1 Face Detected — Alone Verified ✓'
                            : 'Focusing on Face (${remainingSeconds}s)...',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified
                            ? 'You are alone in the camera frame. Ready to proceed.'
                            : 'Hold still for 3 seconds to verify you are alone.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF3B82F6),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isVerified) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _focusHoldProgress,
                  backgroundColor: const Color(0xFFDBEAFE),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // 0 FACES - AMBER BANNER
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.scanFace, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Face Detected',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Please look directly into the camera and position your face inside the circle.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB45309),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionProgressBar(LivenessAction action) {
    final isTurnLeft = action == LivenessAction.turnLeft;
    final actionTitle = action == LivenessAction.blink
        ? 'Blink Action Progress'
        : (isTurnLeft ? 'Turn Left Progress' : 'Turn Right Progress');

    final percent = (_liveActionProgress * 100).toInt().clamp(0, 100);
    final isCompleted = _liveActionProgress >= 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppColors.primary
              : (_isActionWrongDirection ? AppColors.error : const Color(0xFFE5E7EB)),
          width: isCompleted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? AppColors.primary : Colors.black).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    action == LivenessAction.blink
                        ? LucideIcons.eye
                        : (isTurnLeft ? LucideIcons.arrowLeft : LucideIcons.arrowRight),
                    size: 16,
                    color: isCompleted ? AppColors.primary : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    actionTitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFDCFCE7)
                      : (_isActionWrongDirection ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isCompleted
                        ? const Color(0xFF166534)
                        : (_isActionWrongDirection ? const Color(0xFF991B1B) : const Color(0xFF1E40AF)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _liveActionProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? AppColors.primary
                    : (_isActionWrongDirection ? AppColors.error : const Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _liveActionHint.isNotEmpty
                  ? _liveActionHint
                  : (action == LivenessAction.blink
                      ? 'Blink both eyes to reach 100%'
                      : (isTurnLeft
                          ? 'Slowly turn head left to reach 100%'
                          : 'Slowly turn head right to reach 100%')),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isActionWrongDirection
                    ? AppColors.error
                    : (isCompleted ? AppColors.primary : AppColors.textSecondary),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
    final isActionPassed = done || _livenessStatus == _LivenessStatus.actionPassed || _isActionPassedNow;
    final isAnalyzing = _livenessStatus == _LivenessStatus.analyzing;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _actionPassedScale]),
      builder: (context, _) {
        return Container(
          key: key,
          color: AppColors.background,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _buildProgressBar(stepNumber, 6),
                  const SizedBox(height: 10),

                  // Top instruction badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.rule),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
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

                  const SizedBox(height: 10),

                  // Live Status Banner (Red / Blue / Amber)
                  _buildStatusBanner(),

                  const SizedBox(height: 12),

                  // Center Oval Face Cutout Viewport
                  _buildOvalFaceViewport(
                    child: _buildCameraWidget(),
                    isActionPassed: isActionPassed,
                    isFaceDetected: _faceDetected,
                  ),

                  const SizedBox(height: 12),

                  // Live Action Progress Bar (0% - 100%) - Only for Turn Actions
                  if (action != LivenessAction.blink) ...[
                    _buildActionProgressBar(action),
                    const SizedBox(height: 12),
                  ],

                  // Status / Guidance Card & Controls
                  _buildLivenessFeedback(
                    action: action,
                    done: done,
                    isActionPassed: isActionPassed,
                    isAnalyzing: isAnalyzing,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
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
  }) {
    const ovalWidth = 230.0;
    const ovalHeight = 290.0;
    const ovalRadius = 115.0;

    Color borderColor;
    double borderWidth = 3.0;
    List<BoxShadow> shadows = [];

    if (isActionPassed) {
      borderColor = AppColors.primary;
      borderWidth = 4.5;
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ];
    } else if (_detectedFaceCount >= 2) {
      borderColor = const Color(0xFFEF4444);
      borderWidth = 3.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ];
    } else if (_detectedFaceCount == 1) {
      borderColor = const Color(0xFF3B82F6);
      borderWidth = 3.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ];
    } else {
      borderColor = const Color(0xFFD1D5DB);
      borderWidth = 2.5;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
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
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera preview inside the oval (pure video with clean border)
              ClipRRect(
                borderRadius: BorderRadius.circular(ovalRadius - borderWidth),
                child: Container(
                  color: AppColors.surfaceAlt,
                  child: child,
                ),
              ),

              // 2. Action Passed Checkmark Overlay
              if (isActionPassed)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(ovalRadius - borderWidth),
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
                              color: AppColors.primary.withValues(alpha: 0.4),
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
      return const SizedBox.shrink();
    }

    final bool canStart = _detectedFaceCount == 1 && _isFocusVerified;

    String buttonLabel = 'Start Check';
    if (_isCheckingLiveness) {
      if (action == LivenessAction.blink) {
        buttonLabel = 'Waiting for Blink...';
      } else {
        final percent = (_liveActionProgress * 100).toInt().clamp(0, 100);
        buttonLabel = 'Tracking Action ($percent%)...';
      }
    } else if (_detectedFaceCount >= 2) {
      buttonLabel = 'Disabled: Multiple People in Camera';
    } else if (_detectedFaceCount == 0) {
      buttonLabel = 'Disabled: Align Face to Enable';
    } else if (_detectedFaceCount == 1 && !_isFocusVerified) {
      final remaining = ((1.0 - _focusHoldProgress) * 3.0).ceil().clamp(1, 3);
      buttonLabel = 'Hold Still (${remaining}s remaining)...';
    }

    return Column(
      children: [
        _buildPrimaryButton(
          label: buttonLabel,
          icon: _isCheckingLiveness ? LucideIcons.scanLine : LucideIcons.play,
          onTap: canStart && !_isCheckingLiveness
              ? () => _runGuidedLivenessCheck(action)
              : null,
        ),
      ],
    );
  }

  Widget _buildSelfieStep() {
    final canTakeSelfie = _detectedFaceCount == 1 && _isFocusVerified;

    return Container(
      key: const ValueKey('selfie'),
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              _buildProgressBar(6, 6),
              const SizedBox(height: 10),

              // Top instruction badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rule),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                            _selfieBytes != null ? 'Selfie Captured' : 'Take a Portrait Selfie',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selfieBytes != null
                                ? 'Looking good! Proceed to final AI match or retake.'
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

              const SizedBox(height: 10),

              // Status Banner
              if (_selfieBytes == null) ...[
                _buildStatusBanner(),
                const SizedBox(height: 12),
              ],

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
                isFaceDetected: _selfieBytes != null || _faceDetected,
              ),

              const SizedBox(height: 16),

              // Bottom action buttons
              _selfieBytes != null
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              setState(() => _selfieBytes = null);
                              await _startLiveFaceDetection();
                            },
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
                  : Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: canTakeSelfie ? _captureSelfie : null,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: canTakeSelfie ? Colors.white : const Color(0xFFF3F4F6),
                                border: Border.all(
                                  color: canTakeSelfie ? AppColors.primary : const Color(0xFFD1D5DB),
                                  width: 3.5,
                                ),
                                boxShadow: canTakeSelfie
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                LucideIcons.camera,
                                color: canTakeSelfie ? AppColors.primary : const Color(0xFF9CA3AF),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canTakeSelfie
                              ? 'Tap camera button to capture selfie'
                              : (_detectedFaceCount >= 2
                                  ? 'Disabled: Multiple faces detected'
                                  : (_detectedFaceCount == 1
                                      ? 'Hold still for 3s focus check...'
                                      : 'Position face inside circle to enable')),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canTakeSelfie ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 16),
            ],
          ),
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

      // Show classifying spinner & captured photo immediately
      setState(() {
        _tempCapturedBytes = bytes;
        _isClassifyingPhoto = true;
      });

      final displayIdType = _selectedIdType == 'Other / Custom ID' ? (_customIdName ?? 'ID') : (_selectedIdType ?? 'ID');

      // Classify the ID side & verify document type matching before accepting
      final side = await FaceVerificationService.classifyIdSide(
        imageBytes: bytes,
        selectedIdType: displayIdType,
        isFront: isFront,
      );

      if (!mounted) return;

      final expectedSide = isFront ? 'front' : 'back';

      if (side == 'invalid' || side == 'unknown') {
        final errorMsg = isFront
            ? 'ID Type Mismatch! You selected "$displayIdType". Please capture the front of your physical $displayIdType.'
            : 'Could not detect back of ID. Please ensure the reverse side of your $displayIdType is clearly in frame.';
        setState(() {
          _tempCapturedBytes = null;
          _isClassifyingPhoto = false;
          _cameraScanError = '❌ $errorMsg';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
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
          _tempCapturedBytes = null;
          _isClassifyingPhoto = false;
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
        _tempCapturedBytes = null;
        _isClassifyingPhoto = false;
        _cameraScanError = null;
        if (isFront) {
          _idFrontBytes = bytes;
        } else {
          _idBackBytes = bytes;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _tempCapturedBytes = null;
          _isClassifyingPhoto = false;
        });
      }
      debugPrint('[FaceVerification] Shutter capture error: $e');
    }
  }

  Widget _buildIdCameraScanner({
    required Uint8List? bytes,
    required bool isFront,
    required String idType,
    required Future<void> Function() onCapture,
  }) {
    final displayBytes = bytes ?? _tempCapturedBytes;
    if (displayBytes != null) {
      final isSaving = _isClassifyingPhoto;
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSaving ? AppColors.primary.withAlpha(150) : AppColors.primary,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    displayBytes,
                    fit: BoxFit.cover,
                  ),
                  if (isSaving)
                    Container(
                      color: Colors.black.withAlpha(80),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSaving ? LucideIcons.loader : LucideIcons.checkCircle2,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isSaving ? 'Analyzing ID card photo...' : 'Photo captured successfully',
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
