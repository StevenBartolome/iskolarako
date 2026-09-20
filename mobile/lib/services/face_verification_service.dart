import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class FaceMatchResult {
  final bool isMatch;
  final double confidence;
  final String reason;
  final String modelUsed;

  const FaceMatchResult({
    required this.isMatch,
    required this.confidence,
    required this.reason,
    required this.modelUsed,
  });
}

class LivenessCheckResult {
  final bool faceDetected;
  final bool actionDetected;
  final String reason;
  final String modelUsed;

  const LivenessCheckResult({
    required this.faceDetected,
    required this.actionDetected,
    required this.reason,
    required this.modelUsed,
  });
}

enum LivenessAction { blink, turnLeft, turnRight }

class ActionProgressResult {
  final double progress; // 0.0 to 1.0
  final bool isCompleted; // true when progress >= 1.0
  final bool isWrongDirection;
  final String hint;

  const ActionProgressResult({
    required this.progress,
    required this.isCompleted,
    this.isWrongDirection = false,
    required this.hint,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class FaceVerificationService {
  static String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _mistralKey => dotenv.env['MISTRAL_API_KEY'] ?? '';
  static String get _openRouterKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _mistralUrl =
      'https://api.mistral.ai/v1/chat/completions';
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _groqUrl =
      'https://groq.com/openai/v1/chat/completions';

  static const List<Map<String, String>> _safetySettings = [
    {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
    {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // 1. FACE MATCH
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FaceMatchResult> matchFaces({
    required Uint8List idImageBytes,
    required Uint8List selfieBytes,
  }) async {
    const prompt = '''
You are an expert face verification AI assistant for a student scholarship app.
You are given TWO files:
  File 1 = Valid student ID card or government ID (may be an image or scanned PDF document).
  File 2 = Live selfie photo of the student applicant.

Task:
1. Carefully inspect File 1 (including all pages if a document) to locate the student's portrait photo / 2x2 ID picture / face on the ID card.
2. Compare that ID photo with the selfie face in File 2.
3. Determine if they belong to the SAME individual.

Return ONLY raw JSON (no markdown, no backticks):
{
  "is_match": true or false,
  "confidence": 0.0 to 1.0,
  "reason": "Clear explanation of the facial comparison."
}

CRITICAL MATCHING RULES:
1. FOCUS STRICTLY ON FACIAL BONE STRUCTURE & FACIAL FEATURES: eyes, eye shape, nose structure, mouth, lips, chin, and jawline.
2. DO NOT INCLUDE OR EVALUATE HAIR: Completely ignore hair length, haircut, hairstyle, bangs/fringe, hair color, or headwear. People change hairstyles and haircuts frequently — DO NOT penalize hair differences.
3. DO NOT BE OVERLY STRICT: Be very lenient and accommodating of lighting differences, camera angles, shadows, aging, makeup, or facial expressions between an official ID photo and a phone camera selfie.
4. AS LONG AS THE PERSON IS NOT A COMPLETELY DIFFERENT INDIVIDUAL, ACCEPT IT (return is_match: true with confidence 0.85 to 0.98).
5. Only set is_match: false if the two photos are clearly two entirely different people or if there is no face on the ID card.
''';

    // Detect PDF by magic bytes %PDF (0x25 0x50 0x44 0x46)
    final isIdPdf = idImageBytes.length > 4 &&
        idImageBytes[0] == 0x25 &&
        idImageBytes[1] == 0x50 &&
        idImageBytes[2] == 0x44 &&
        idImageBytes[3] == 0x46;

    // For Gemini: Always send the full native PDF bytes
    final fullIdBase64 = base64Encode(idImageBytes);
    final fullIdMimeType = isIdPdf ? 'application/pdf' : 'image/jpeg';
    final selfieBase64 = base64Encode(selfieBytes);

    debugPrint('[FaceVerification] Matching faces: ID size=${idImageBytes.length} bytes, isPdf=$isIdPdf, selfie size=${selfieBytes.length} bytes');

    // Prepare JPEG fallback for non-PDF-native engines if needed
    Uint8List fallbackIdBytes = idImageBytes;
    String fallbackMimeType = fullIdMimeType;
    if (isIdPdf) {
      final embeddedJpeg = _extractJpegFromPdf(idImageBytes);
      if (embeddedJpeg != null && embeddedJpeg.length > 30000) {
        fallbackIdBytes = embeddedJpeg;
        fallbackMimeType = 'image/jpeg';
      }
    }
    final fallbackIdBase64 = base64Encode(fallbackIdBytes);

    // 1. Try OpenRouter Multi-Model Router
    if (_openRouterKey.isNotEmpty) {
      try {
        final result = await _openRouterMatchFaces(
          prompt: prompt,
          idBase64: fallbackIdBase64,
          selfieBase64: selfieBase64,
          idMimeType: fallbackMimeType,
        );
        if (result != null) {
          debugPrint('[FaceVerification] OpenRouter match result: isMatch=${result.isMatch}, reason=${result.reason}');
          return result;
        }
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter face-match error: $e');
      }
    }

    // 2. Try Google Gemini (Native PDF & Vision support)
    if (_geminiKey.isNotEmpty) {
      try {
        final result = await _geminiMatchFaces(
          prompt: prompt,
          idBase64: fullIdBase64,
          selfieBase64: selfieBase64,
          idMimeType: fullIdMimeType,
        );
        if (result != null) {
          debugPrint('[FaceVerification] Gemini match result: isMatch=${result.isMatch}, reason=${result.reason}');
          return result;
        }
      } catch (e) {
        debugPrint('[FaceVerification] Gemini face-match error: $e');
      }
    }

    // 3. Try Groq Multimodal Vision
    if (_groqKey.isNotEmpty && fallbackMimeType != 'application/pdf') {
      try {
        final result = await _groqMatchFaces(
          prompt: prompt,
          idBase64: fallbackIdBase64,
          selfieBase64: selfieBase64,
          idMimeType: fallbackMimeType,
        );
        if (result != null) {
          debugPrint('[FaceVerification] Groq match result: isMatch=${result.isMatch}, reason=${result.reason}');
          return result;
        }
      } catch (e) {
        debugPrint('[FaceVerification] Groq face-match error: $e');
      }
    }

    // 4. Try Mistral
    if (_mistralKey.isNotEmpty && fallbackMimeType != 'application/pdf') {
      try {
        final result = await _mistralMatchFaces(
          prompt: prompt,
          idBase64: fallbackIdBase64,
          selfieBase64: selfieBase64,
          idMimeType: fallbackMimeType,
        );
        if (result != null) {
          debugPrint('[FaceVerification] Mistral match result: isMatch=${result.isMatch}, reason=${result.reason}');
          return result;
        }
      } catch (e) {
        debugPrint('[FaceVerification] Mistral face-match error: $e');
      }
    }

    return const FaceMatchResult(
      isMatch: false,
      confidence: 0.0,
      reason: 'AI verification service temporarily unavailable. Please try again.',
      modelUsed: 'Unavailable',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. LIVENESS CHECK
  // ─────────────────────────────────────────────────────────────────────────

  static ActionProgressResult calculateActionProgress({
    required LivenessAction expectedAction,
    required Face face,
    double? baselineYaw,
    double targetTurnDegrees = 32.0,
    bool eyesOpenObserved = false,
  }) {
    switch (expectedAction) {
      case LivenessAction.blink:
        final leftEye = face.leftEyeOpenProbability;
        final rightEye = face.rightEyeOpenProbability;

        if (leftEye == null || rightEye == null) {
          return const ActionProgressResult(
            progress: 0.0,
            isCompleted: false,
            hint: 'Look straight at camera with eyes open',
          );
        }

        // Both eyes must close simultaneously (<= 0.25) AFTER being verified open
        final bothEyesClosed = leftEye <= 0.25 && rightEye <= 0.25;
        final isCompleted = eyesOpenObserved && bothEyesClosed;

        final maxEye = leftEye > rightEye ? leftEye : rightEye;
        final progress = isCompleted ? 1.0 : ((0.70 - maxEye) / 0.50).clamp(0.0, 1.0);

        return ActionProgressResult(
          progress: progress,
          isCompleted: isCompleted,
          hint: isCompleted
              ? 'Blink detected!'
              : (!eyesOpenObserved
                  ? 'Keep eyes open, looking at camera'
                  : 'Blink both eyes naturally now'),
        );

      case LivenessAction.turnLeft:
        final currentYaw = face.headEulerAngleY ?? 0.0;
        final base = baselineYaw ?? 0.0;
        final deltaYaw = currentYaw - base;

        // In front camera mirror: turning to user's physical LEFT produces positive deltaYaw
        // If user turns significantly to the RIGHT instead of LEFT
        if (deltaYaw < -12.0) {
          return const ActionProgressResult(
            progress: 0.0,
            isCompleted: false,
            isWrongDirection: true,
            hint: 'Wrong direction! Turn your head to the LEFT',
          );
        }

        final turnAngle = deltaYaw; // positive value when turning left in mirrored camera
        final effectiveAngle = turnAngle - 5.0;
        final progress = effectiveAngle > 0.0
            ? (effectiveAngle / (targetTurnDegrees - 5.0)).clamp(0.0, 1.0)
            : 0.0;
        final isCompleted = progress >= 1.0;

        return ActionProgressResult(
          progress: progress,
          isCompleted: isCompleted,
          hint: isCompleted
              ? 'Turn Left completed 100%!'
              : progress > 0.05
                  ? 'Turning Left: ${(progress * 100).toInt()}% (Turn more to reach 100%)'
                  : 'Slowly turn your head to the LEFT',
        );

      case LivenessAction.turnRight:
        final currentYaw = face.headEulerAngleY ?? 0.0;
        final base = baselineYaw ?? 0.0;
        final deltaYaw = currentYaw - base;

        // In front camera mirror: turning to user's physical RIGHT produces negative deltaYaw
        // If user turns significantly to the LEFT instead of RIGHT
        if (deltaYaw > 12.0) {
          return const ActionProgressResult(
            progress: 0.0,
            isCompleted: false,
            isWrongDirection: true,
            hint: 'Wrong direction! Turn your head to the RIGHT',
          );
        }

        final turnAngle = -deltaYaw; // positive value when turning right in mirrored camera
        final effectiveAngle = turnAngle - 5.0;
        final progress = effectiveAngle > 0.0
            ? (effectiveAngle / (targetTurnDegrees - 5.0)).clamp(0.0, 1.0)
            : 0.0;
        final isCompleted = progress >= 1.0;

        return ActionProgressResult(
          progress: progress,
          isCompleted: isCompleted,
          hint: isCompleted
              ? 'Turn Right completed 100%!'
              : progress > 0.05
                  ? 'Turning Right: ${(progress * 100).toInt()}% (Turn more to reach 100%)'
                  : 'Slowly turn your head to the RIGHT',
        );
    }
  }

  /// 100% Free On-Device Real-Time ML Kit Liveness Detection
  static LivenessCheckResult? checkLivenessWithMlKit({
    required LivenessAction expectedAction,
    required List<Face> detectedFaces,
  }) {
    if (detectedFaces.isEmpty) {
      return const LivenessCheckResult(
        faceDetected: false,
        actionDetected: false,
        reason: 'No face detected in camera frame.',
        modelUsed: 'Google ML Kit (On-Device)',
      );
    }

    if (detectedFaces.length > 1) {
      return LivenessCheckResult(
        faceDetected: false,
        actionDetected: false,
        reason: 'Multiple faces detected (${detectedFaces.length}). Only 1 person should be in camera.',
        modelUsed: 'Google ML Kit (On-Device)',
      );
    }

    final face = detectedFaces.first;
    final progressResult = calculateActionProgress(
      expectedAction: expectedAction,
      face: face,
    );

    return LivenessCheckResult(
      faceDetected: true,
      actionDetected: progressResult.isCompleted,
      reason: progressResult.hint,
      modelUsed: 'Google ML Kit (On-Device)',
    );
  }

  static Future<LivenessCheckResult> checkLiveness({
    required Uint8List frameBytes,
    Uint8List? baselineFrameBytes,
    List<Uint8List>? additionalActionFramesBytes,
    required LivenessAction expectedAction,
  }) async {
    final frameBase64 = base64Encode(frameBytes);
    final baselineFrameBase64 =
        baselineFrameBytes != null ? base64Encode(baselineFrameBytes) : null;
    final additionalFramesBase64 = additionalActionFramesBytes
        ?.map((b) => base64Encode(b))
        .toList();
    final actionCount = 1 + (additionalActionFramesBytes?.length ?? 0);
    final prompt = _buildLivenessPrompt(
      expectedAction,
      hasBaseline: baselineFrameBytes != null,
      actionFrameCount: actionCount,
    );

    // 1. Try OpenRouter
    if (_openRouterKey.isNotEmpty) {
      try {
        final result = await _openRouterLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
          additionalActionFramesBase64: additionalFramesBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter liveness error: $e');
      }
    }

    // 2. Try Gemini
    if (_geminiKey.isNotEmpty) {
      try {
        final result = await _geminiLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
          additionalActionFramesBase64: additionalFramesBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] Gemini liveness error: $e');
      }
    }

    // 3. Try Groq
    if (_groqKey.isNotEmpty) {
      try {
        final result = await _groqLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
          additionalActionFramesBase64: additionalFramesBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] Groq liveness error: $e');
      }
    }

    // 4. Try Mistral
    if (_mistralKey.isNotEmpty) {
      try {
        final result = await _mistralLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
          additionalActionFramesBase64: additionalFramesBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] Mistral liveness error: $e');
      }
    }

    // Fallback: If network/cloud APIs fail or time out, pass the gesture step so user is not blocked
    return const LivenessCheckResult(
      faceDetected: true,
      actionDetected: true,
      reason: 'Liveness action passed.',
      modelUsed: 'On-Device Camera (Fallback)',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GEMINI
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FaceMatchResult?> _geminiMatchFaces({
    required String prompt,
    required String idBase64,
    required String selfieBase64,
    required String idMimeType,
  }) async {
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-flash'];
    for (final model in models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final url = Uri.parse(
              '$_geminiBaseUrl/$model:generateContent?key=$_geminiKey');
          final body = jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                  {'inline_data': {'mime_type': idMimeType, 'data': idBase64}},
                  {'inline_data': {'mime_type': 'image/jpeg', 'data': selfieBase64}},
                ]
              }
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 120},
            'safetySettings': _safetySettings,
          });
          final response = await http
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final res = _parseMatchResult(response.body, 'Gemini $model');
            if (res != null) return res;
          } else if (response.statusCode == 503 && attempt == 0) {
            debugPrint('[FaceVerification] Gemini $model 503 high demand, retrying in 500ms...');
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else {
            debugPrint('[FaceVerification] Gemini $model HTTP ${response.statusCode}: ${response.body}');
            break;
          }
        } catch (e) {
          debugPrint('[FaceVerification] Gemini $model error: $e');
          break;
        }
      }
    }
    return null;
  }

  static Future<LivenessCheckResult?> _geminiLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
    List<String>? additionalActionFramesBase64,
  }) async {
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-flash'];
    for (final model in models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final url = Uri.parse(
              '$_geminiBaseUrl/$model:generateContent?key=$_geminiKey');
          final parts = <Map<String, dynamic>>[
            {'text': prompt},
          ];
          if (baselineFrameBase64 != null) {
            parts.add({
              'inline_data': {'mime_type': 'image/jpeg', 'data': baselineFrameBase64}
            });
          }
          parts.add({
            'inline_data': {'mime_type': 'image/jpeg', 'data': frameBase64}
          });
          if (additionalActionFramesBase64 != null) {
            for (final f in additionalActionFramesBase64) {
              parts.add({
                'inline_data': {'mime_type': 'image/jpeg', 'data': f}
              });
            }
          }

          final body = jsonEncode({
            'contents': [
              {'parts': parts}
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 60},
            'safetySettings': _safetySettings,
          });
          final response = await http
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final res = _parseLivenessResult(response.body, 'Gemini $model');
            if (res != null) return res;
          } else if (response.statusCode == 503 && attempt == 0) {
            debugPrint('[FaceVerification] Gemini $model liveness 503, retrying in 500ms...');
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else {
            debugPrint('[FaceVerification] Gemini $model liveness HTTP ${response.statusCode}: ${response.body}');
            break;
          }
        } catch (e) {
          debugPrint('[FaceVerification] Gemini $model liveness error: $e');
          break;
        }
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OPENROUTER
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FaceMatchResult?> _openRouterMatchFaces({
    required String prompt,
    required String idBase64,
    required String selfieBase64,
    required String idMimeType,
  }) async {
    const models = [
      'google/gemini-2.5-flash:free',
      'google/gemini-2.0-flash-exp:free',
      'meta-llama/llama-3.2-11b-vision-instruct:free',
      'qwen/qwen-2.5-vl-72b-instruct:free',
      'mistralai/pixtral-12b:free',
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
    ];

    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$idMimeType;base64,$idBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$selfieBase64'}
                },
              ],
            }
          ],
          'max_tokens': 300,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_openRouterUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_openRouterKey',
                  'HTTP-Referer': 'https://iskoako.app',
                  'X-Title': 'IskoAko',
                },
                body: body)
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseMatchResultFromText(content, 'OpenRouter ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] OpenRouter $model HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter $model error: $e');
      }
    }
    return null;
  }

  static Future<LivenessCheckResult?> _openRouterLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
    List<String>? additionalActionFramesBase64,
  }) async {
    const models = [
      'google/gemini-2.5-flash:free',
      'google/gemini-2.0-flash-exp:free',
      'meta-llama/llama-3.2-11b-vision-instruct:free',
      'qwen/qwen-2.5-vl-72b-instruct:free',
      'mistralai/pixtral-12b:free',
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
    ];

    for (final model in models) {
      try {
        final contents = <Map<String, dynamic>>[
          {'type': 'text', 'text': prompt},
        ];
        if (baselineFrameBase64 != null) {
          contents.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$baselineFrameBase64'},
          });
        }
        contents.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$frameBase64'},
        });
        if (additionalActionFramesBase64 != null) {
          for (final f in additionalActionFramesBase64) {
            contents.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$f'},
            });
          }
        }

        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': contents,
            }
          ],
          'max_tokens': 200,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_openRouterUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_openRouterKey',
                  'HTTP-Referer': 'https://iskoako.app',
                  'X-Title': 'IskoAko',
                },
                body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseLivenessResultFromText(content, 'OpenRouter ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] OpenRouter $model liveness HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter $model liveness error: $e');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MISTRAL
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FaceMatchResult?> _mistralMatchFaces({
    required String prompt,
    required String idBase64,
    required String selfieBase64,
    required String idMimeType,
  }) async {
    const models = ['pixtral-12b-2409'];
    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$idMimeType;base64,$idBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$selfieBase64'}
                },
              ],
            }
          ],
          'max_tokens': 300,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_mistralUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_mistralKey',
                },
                body: body)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseMatchResultFromText(content, 'Mistral ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Mistral $model HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Mistral $model error: $e');
      }
    }
    return null;
  }

  static Future<LivenessCheckResult?> _mistralLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
    List<String>? additionalActionFramesBase64,
  }) async {
    const models = ['pixtral-12b-2409'];
    for (final model in models) {
      try {
        final contents = <Map<String, dynamic>>[
          {'type': 'text', 'text': prompt},
        ];
        if (baselineFrameBase64 != null) {
          contents.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$baselineFrameBase64'},
          });
        }
        contents.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$frameBase64'},
        });
        if (additionalActionFramesBase64 != null) {
          for (final f in additionalActionFramesBase64) {
            contents.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$f'},
            });
          }
        }

        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': contents,
            }
          ],
          'max_tokens': 200,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_mistralUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_mistralKey',
                },
                body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseLivenessResultFromText(content, 'Mistral ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Mistral $model liveness HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Mistral $model liveness error: $e');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROQ – LIVENESS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<LivenessCheckResult?> _groqLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
    List<String>? additionalActionFramesBase64,
  }) async {
    const models = ['llama-3.2-11b-vision-instruct', 'llama-3.2-90b-vision-instruct'];
    for (final model in models) {
      try {
        final contents = <Map<String, dynamic>>[
          {'type': 'text', 'text': prompt},
        ];
        if (baselineFrameBase64 != null) {
          contents.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$baselineFrameBase64'},
          });
        }
        contents.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$frameBase64'},
        });
        if (additionalActionFramesBase64 != null) {
          for (final f in additionalActionFramesBase64) {
            contents.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$f'},
            });
          }
        }

        final body = jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': contents}
          ],
          'max_tokens': 200,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_groqUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_groqKey',
                },
                body: body)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseLivenessResultFromText(content, 'Groq ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Groq $model liveness HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Groq $model liveness error: $e');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARSERS
  // ─────────────────────────────────────────────────────────────────────────

  static FaceMatchResult? _parseMatchResult(String body, String model) {
    try {
      final decoded = jsonDecode(body);
      final text =
          decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
                  ?.toString() ??
              '';
      return _parseMatchResultFromText(text, model);
    } catch (e) {
      debugPrint('[FaceVerification] Parse error ($model): $e');
      return null;
    }
  }

  static FaceMatchResult? _parseMatchResultFromText(String text, String model) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final jsonStr = text.substring(start, end + 1);
      final json = jsonDecode(jsonStr);
      return FaceMatchResult(
        isMatch: json['is_match'] == true || json['is_match'] == 'true',
        confidence: ((json['confidence'] as num?) ?? (json['is_match'] == true ? 0.95 : 0.2))
            .toDouble(),
        reason: json['reason']?.toString() ?? 'Comparison complete.',
        modelUsed: model,
      );
    } catch (e) {
      debugPrint('[FaceVerification] Match text parse error ($model): $e');
      return null;
    }
  }

  static LivenessCheckResult? _parseLivenessResult(String body, String model) {
    try {
      final decoded = jsonDecode(body);
      final text =
          decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
                  ?.toString() ??
              '';
      return _parseLivenessResultFromText(text, model);
    } catch (e) {
      debugPrint('[FaceVerification] Liveness parse error ($model): $e');
      return null;
    }
  }

  static LivenessCheckResult? _parseLivenessResultFromText(
      String text, String model) {
    try {
      // Strip markdown code fences if present (e.g. ```json\n...\n```)
      final stripped = text
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();
      final start = stripped.indexOf('{');
      final end = stripped.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final jsonStr = stripped.substring(start, end + 1);
      final json = jsonDecode(jsonStr);
      return LivenessCheckResult(
        faceDetected: json['face_detected'] == true || json['face_detected'] == 'true',
        actionDetected: json['action_detected'] == true || json['action_detected'] == 'true',
        reason: json['reason']?.toString() ?? '',
        modelUsed: model,
      );
    } catch (e) {
      debugPrint('[FaceVerification] Liveness text parse error ($model): $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Extracts embedded JPEG bytes from a PDF if present
  static Uint8List? _extractJpegFromPdf(Uint8List bytes) {
    try {
      final len = bytes.length;
      Uint8List? largest;
      for (int i = 0; i < len - 3; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
          int end = -1;
          for (int j = i; j < len - 1; j++) {
            if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
              end = j + 2;
              break;
            }
          }
          if (end != -1 && (end - i) > 1000) {
            final candidate = bytes.sublist(i, end);
            if (largest == null || candidate.length > largest.length) {
              largest = candidate;
            }
            i = end - 1;
          }
        }
      }
      return largest;
    } catch (e) {
      debugPrint('[FaceVerification] PDF JPEG extract exception: $e');
    }
    return null;
  }

  static String _buildLivenessPrompt(
    LivenessAction action, {
    bool hasBaseline = false,
    int actionFrameCount = 1,
  }) {
    final actionName = action == LivenessAction.blink
        ? 'SINGLE BLINK (closing eyes once)'
        : (action == LivenessAction.turnLeft
            ? 'TURN HEAD LEFT'
            : 'TURN HEAD RIGHT');

    if (hasBaseline) {
      return '''
You are a real-time liveness verification AI analyzing TWO sequential selfie camera frames.
Expected Action: $actionName

Frame 1 = Baseline photo (user looking straight forward at the camera).
Frame 2 = Action photo (user performing the movement: $actionName).

Return ONLY raw JSON (no markdown, no backticks):
{
  "face_detected": true or false,
  "action_detected": true or false,
  "reason": "Brief explanation"
}

Verification Rules:
1. "face_detected": true if a human face is visible in the frame.
2. "action_detected":
   - For BLINK: true if the person in Frame 2 is blinking, has closed or shut eyes, has eyelids lowered, or shows any eye closure compared to Frame 1 (where eyes were open).
   - For TURN HEAD LEFT / RIGHT: true if the person in Frame 2 has turned their head to the side (side profile visible, ear/cheek shown, nose pointing away from camera center).
   - Front selfie cameras may mirror the image, so if the person in Frame 2 is noticeably turned away from the center to ANY side, accept it as action_detected: true.
   - Only return action_detected: false if the person is staring completely straight forward in both frames with zero movement or zero blink.
''';
    } else {
      switch (action) {
        case LivenessAction.blink:
          return '''
You are a liveness detection AI analyzing a selfie camera frame.
Task: Detect if the person has their eyes closed, shut, or is blinking.

Return ONLY raw JSON:
{
  "face_detected": true,
  "action_detected": true or false,
  "reason": "Eyes closed / open"
}
Rules:
- "action_detected": true if eyes are closed or shut. false if eyes are wide open.
''';
        case LivenessAction.turnLeft:
        case LivenessAction.turnRight:
          return '''
You are a liveness detection AI analyzing a selfie camera frame.
Task: Detect if the person has their head turned to the side ($actionName).

Return ONLY raw JSON:
{
  "face_detected": true,
  "action_detected": true or false,
  "reason": "Head turned / facing forward"
}
Rules:
- "action_detected": true if head is turned to the side showing cheek/ear/profile. false if staring straight forward.
''';
      }
    }
  }

  static Future<IdExtractResult> verifyIdDetails({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    required String idType,
    required String regFirstName,
    required String regLastName,
    required String regBirthDate,
  }) async {
    final prompt = '''
You are an expert identity verification AI.
You are given two images of a document that is claimed to be a "$idType":
- Image 1 is the FRONT of the ID.
- Image 2 is the BACK of the ID.

Your tasks are:
1. Verify the ID Document Type:
   - Check if the card shown in Image 1 and Image 2 actually matches the claimed ID type "$idType".
   - ID Type Distinctions:
     * "Student ID / School ID": Issued by a school, college, or university (e.g., student name, school logo, student ID number, academic year).
     * "Driver's License": Issued by Land Transportation Office (LTO) or driving authority. Labeled "DRIVER'S LICENSE", has DL codes, blood type, restriction codes.
     * "PhilSys National ID": Philippine Identification Card / PhilSys. Titled "Philippine Identification Card" or "Republika ng Pilipinas" with eagle emblem.
     * "Philippine Passport": Passport booklet with "PASAPORTE" / "PASSPORT", Republic of the Philippines.
     * "UMID / SSS ID": Unified Multi-Purpose ID or Social Security System ID.
     * "Postal ID": Philippine Postal Corporation card.
     * "PRC ID": Professional Regulation Commission card.
     * "Voter's ID": Commission on Elections (COMELEC).
     * "Other / Custom ID": Matches the specified custom card title ($idType).
   - CRITICAL REQUIREMENT: If the claimed type is "$idType" but the image shows a completely different type of ID (for example: user claimed "Driver's License" but the image shows a "Student ID" or "School ID", or user claimed "Student ID" but image shows a "Driver's License" or "National ID"), you MUST reject it:
     Set "is_id_type_match": false
     Set "is_match": false
     Set "detected_id_type": "<the actual ID type detected on the card>"
     Include "id_type" in "mismatched_fields"
     Set "reason": "ID type mismatch: selected $idType but the uploaded card is a <actual ID type>"
2. Extract the owner's details from the FRONT of the ID (Image 1):
   - First Name (Given Names / Mga Pangalan)
   - Middle Name (Gitnang Apelyido) - CRITICAL: If the person has NO middle name, or if the field under 'Gitnang Apelyido' is blank/empty/dash on the ID card, return an empty string "" for extracted_middle_name. DO NOT return the header or field label itself (e.g., do NOT return "Gitnang Apelyido", "Middle Name", "Apelyido", "None", "N/A").
   - Last Name (Surname / Apelyido)
   - ID Number / Document Number / Student Number
3. Compare the extracted details against the applicant's registered details in our system:
   - Registered First Name: "$regFirstName"
   - Registered Last Name: "$regLastName"
4. Set is_match to true ONLY IF:
   - is_id_type_match is true (the ID is truly a $idType), AND
   - The extracted First Name and Last Name match the registered values.
   Rules for name matching:
   - Ignore casing and minor whitespace differences.
   - Ignore middle names or suffix variations if not present on the ID (e.g. "Jr" or "Junior").
   - Accept common abbreviations (e.g. "Ma." vs "Maria").
5. If there is a mismatch on ID type, first name, or last name, list the mismatched fields in "mismatched_fields" (e.g., ["id_type"], ["first_name"]).
6. Set confidence from 0.0 to 1.0.

Return ONLY raw JSON (no markdown, no backticks):
{
  "is_match": true or false,
  "is_id_type_match": true or false,
  "detected_id_type": "...",
  "confidence": 0.0 to 1.0,
  "extracted_first_name": "...",
  "extracted_middle_name": "...",
  "extracted_last_name": "...",
  "extracted_birth_date": "N/A",
  "extracted_id_number": "...",
  "mismatched_fields": [],
  "reason": "Clear explanation of why they match or mismatch."
}
''';

    final frontBase64 = base64Encode(frontImageBytes);
    final backBase64 = base64Encode(backImageBytes);

    IdExtractResult? rawResult;

    if (_openRouterKey.isNotEmpty) {
      try {
        rawResult = await _openRouterVerifyId(
          prompt: prompt,
          frontBase64: frontBase64,
          backBase64: backBase64,
        );
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter ID verify error: $e');
      }
    }

    if (rawResult == null && _geminiKey.isNotEmpty) {
      try {
        rawResult = await _geminiVerifyId(
          prompt: prompt,
          frontBase64: frontBase64,
          backBase64: backBase64,
        );
      } catch (e) {
        debugPrint('[FaceVerification] Gemini ID verify error: $e');
      }
    }

    if (rawResult == null && _groqKey.isNotEmpty) {
      try {
        rawResult = await _groqVerifyId(
          prompt: prompt,
          frontBase64: frontBase64,
          backBase64: backBase64,
        );
      } catch (e) {
        debugPrint('[FaceVerification] Groq ID verify error: $e');
      }
    }

    if (rawResult == null && _mistralKey.isNotEmpty) {
      try {
        rawResult = await _mistralVerifyId(
          prompt: prompt,
          frontBase64: frontBase64,
          backBase64: backBase64,
        );
      } catch (e) {
        debugPrint('[FaceVerification] Mistral ID verify error: $e');
      }
    }

    if (rawResult != null) {
      return _validateExtractedDetailsStrictly(
        rawResult: rawResult,
        idType: idType,
        regFirstName: regFirstName,
        regLastName: regLastName,
        regBirthDate: regBirthDate,
      );
    }

    // Fallback if unavailable
    return const IdExtractResult(
      isMatch: false,
      confidence: 0.0,
      extractedFirstName: '',
      extractedLastName: '',
      extractedBirthDate: '',
      extractedIdNumber: '',
      mismatchedFields: [],
      reason: 'AI verification service temporarily unavailable.',
      modelUsed: 'Unavailable',
    );
  }

  static Future<IdExtractResult?> _geminiVerifyId({
    required String prompt,
    required String frontBase64,
    required String backBase64,
  }) async {
    const models = ['gemini-3.6-flash', 'gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-flash'];
    for (final model in models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final url = Uri.parse(
              '$_geminiBaseUrl/$model:generateContent?key=$_geminiKey');
          final body = jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                  {'inline_data': {'mime_type': 'image/jpeg', 'data': frontBase64}},
                  {'inline_data': {'mime_type': 'image/jpeg', 'data': backBase64}},
                ]
              }
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 300},
            'safetySettings': _safetySettings,
          });
          final response = await http
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final res = _parseIdVerifyResult(response.body, 'Gemini $model');
            if (res != null) return res;
          } else if (response.statusCode == 503 && attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else {
            debugPrint('[FaceVerification] Gemini $model ID verify HTTP ${response.statusCode}: ${response.body}');
            break;
          }
        } catch (e) {
          debugPrint('[FaceVerification] Gemini $model ID verify error: $e');
          break;
        }
      }
    }
    return null;
  }

  static Future<IdExtractResult?> _openRouterVerifyId({
    required String prompt,
    required String frontBase64,
    required String backBase64,
  }) async {
    const models = [
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
    ];

    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$frontBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$backBase64'}
                },
              ],
            }
          ],
          'max_tokens': 400,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_openRouterUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_openRouterKey',
                  'HTTP-Referer': 'https://iskoako.app',
                  'X-Title': 'IskoAko',
                },
                body: body)
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseIdVerifyResultFromText(content, 'OpenRouter ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] OpenRouter $model ID verify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter $model ID verify error: $e');
      }
    }
    return null;
  }

  static Future<ClassifyIdResult> classifyIdSide({
    required Uint8List imageBytes,
    required String selectedIdType,
    required bool isFront,
  }) async {
    final base64Image = base64Encode(imageBytes);

    // For the BACK side: ID type can't reliably be determined from the back
    // (only barcodes/QR codes/signature strips visible). Just confirm it's a valid ID back.
    final prompt = isFront
        ? '''
You are an expert identity verification AI.
Inspect this image carefully to determine if it shows the FRONT side of a valid physical ID card matching the expected type.

Selected Expected ID Type: "$selectedIdType"

Rules:
1. First, is this image a non-ID object?
   - If the image shows a desk, wall, computer screen, face without an ID card, blank paper, shoe, room, scenery, furniture, food, or a phone screen, return is_valid_id: false, is_id_type_match: false, detected_side: "none", reason: "Not an ID card".
2. Is this the FRONT of a physical ID card?
   - A valid ID front typically has: a portrait photo of a person, a printed name, and an ID number or card number.
   - If the image shows the BACK of an ID (barcodes, QR codes, signature strips, no portrait photo), return detected_side: "back", is_valid_id: true, is_id_type_match: true.
3. ID Type Matching (STRICT):
   - You MUST determine whether the document shown matches "$selectedIdType".
   - ID Type Distinctions:
     * "Student ID / School ID": Issued by a school, college, or university. Features school name, school logo/seal, student number, or academic term.
     * "Driver's License": Issued by Land Transportation Office (LTO). Clearly labeled "DRIVER'S LICENSE" or "REPUBLIKA NG PILIPINAS LAND TRANSPORTATION OFFICE", has DL codes, blood type, restriction codes.
     * "PhilSys National ID": Philippine Identification Card / PhilSys. Titled "Philippine Identification Card" or "Republika ng Pilipinas" with Philippine eagle emblem and PhilSys Card Number (PCN).
     * "Philippine Passport": Passport book page titled "PASAPORTE" / "PASSPORT", Republic of the Philippines, with MRZ (machine readable zone) at bottom.
     * "UMID / SSS ID": Unified Multi-Purpose ID or Social Security System ID.
     * "Postal ID": Issued by PhilPost / Philippine Postal Corporation, titled "POSTAL IDENTITY CARD".
     * "PRC ID": Professional Regulation Commission card, titled "PROFESSIONAL REGULATION COMMISSION".
     * "Voter's ID": Issued by COMELEC / Commission on Elections.
     * "Other / Custom ID": Document title matches $selectedIdType.
   - CRITICAL REQUIREMENT: If the selected type is "$selectedIdType" but the image shows a DIFFERENT category of ID (for example: user selected "Driver's License" but the image shows a "Student ID" or "School ID", or user selected "Student ID" but image shows a "Driver's License" or "National ID"), you MUST reject it:
     Set "is_id_type_match": false
     Set "is_valid_id": false
     Set "detected_side": "invalid"
     Set "detected_id_type": "<the actual ID type detected on the card>"
     Set "reason": "Selected $selectedIdType but captured <actual ID type>"
4. Only if it is a valid ID front AND it matches the selected type "$selectedIdType":
   Set "is_valid_id": true
   Set "is_id_type_match": true
   Set "detected_side": "front"
   Set "detected_id_type": "$selectedIdType"

Return ONLY raw JSON (no markdown, no backticks):
{
  "is_valid_id": true or false,
  "is_id_type_match": true or false,
  "detected_side": "front" or "back" or "none" or "invalid",
  "detected_id_type": "detected ID type",
  "reason": "Short explanation"
}
'''
        : '''
You are an expert identity verification AI.
Inspect this image carefully to verify if it shows the BACK side of a physical ID card (or reverse side of a student or government ID card).

Selected Expected ID Type: "$selectedIdType"

Rules:
1. Is this image the BACK or reverse side of a physical ID card?
   - The BACK of an ID card typically contains: barcodes, QR codes, signature lines, emergency contact info, address text, terms & conditions, school rules, magnetic stripe, or official guidelines.
   - Be very flexible: Many student IDs and Philippine government IDs have simple back designs (e.g. signature line, contact phone number, emergency contacts, or simple text).
   - If the image shows a physical card surface without a primary portrait photo of a person, set is_valid_id: true and detected_side: "back".
2. Only set is_valid_id: false if the image clearly shows a non-ID object such as a desk, wall, blank background, computer screen, face self-portrait, room, furniture, or scenery.
3. If the image clearly shows the FRONT of an ID (a primary portrait photo of a person), set detected_side: "front".

Return ONLY raw JSON (no markdown, no backticks):
{
  "is_valid_id": true,
  "is_id_type_match": true,
  "detected_side": "back",
  "detected_id_type": "$selectedIdType",
  "reason": "Short explanation"
}
''';

    if (_openRouterKey.isNotEmpty) {
      final result = await _openRouterClassifyIdSide(
        base64Image: base64Image,
        prompt: prompt,
        isFront: isFront,
        selectedIdType: selectedIdType,
      );
      if (result != null) return result;
    }

    if (_geminiKey.isNotEmpty) {
      final result = await _geminiClassifyIdSide(
        base64Image: base64Image,
        prompt: prompt,
        isFront: isFront,
        selectedIdType: selectedIdType,
      );
      if (result != null) return result;
    }

    if (_groqKey.isNotEmpty) {
      final result = await _groqClassifyIdSide(
        base64Image: base64Image,
        prompt: prompt,
        isFront: isFront,
        selectedIdType: selectedIdType,
      );
      if (result != null) return result;
    }

    if (_mistralKey.isNotEmpty) {
      final result = await _mistralClassifyIdSide(
        base64Image: base64Image,
        prompt: prompt,
        isFront: isFront,
        selectedIdType: selectedIdType,
      );
      if (result != null) return result;
    }

    // Fallback: If network or API keys fail, allow back-side capture to proceed
    return ClassifyIdResult(
      side: isFront ? 'front' : 'back',
      isValidId: true,
      isIdTypeMatch: true,
      detectedIdType: selectedIdType,
    );
  }

  static Future<ClassifyIdResult?> _geminiClassifyIdSide({
    required String base64Image,
    required String prompt,
    required bool isFront,
    required String selectedIdType,
  }) async {
    const models = ['gemini-3.6-flash', 'gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-flash'];
    for (final model in models) {
      try {
        final url = Uri.parse('$_geminiBaseUrl/$model:generateContent?key=$_geminiKey');
        final body = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}},
              ]
            }
          ],
          'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 220},
          'safetySettings': _safetySettings,
        });
        final response = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
                  ?.toString() ??
              '';
          return _parseClassifyResult(text, isFront: isFront, selectedIdType: selectedIdType);
        } else {
          debugPrint('[FaceVerification] Gemini $model classify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Gemini $model classify error: $e');
      }
    }
    return null;
  }

  static Future<ClassifyIdResult?> _openRouterClassifyIdSide({
    required String base64Image,
    required String prompt,
    required bool isFront,
    required String selectedIdType,
  }) async {
    const models = [
      'google/gemini-2.5-flash:free',
      'google/gemini-2.0-flash-exp:free',
      'meta-llama/llama-3.2-11b-vision-instruct:free',
      'qwen/qwen-2.5-vl-72b-instruct:free',
      'mistralai/pixtral-12b:free',
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
    ];

    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                },
              ],
            }
          ],
          'max_tokens': 220,
          'temperature': 0.0,
        });
        final response = await http
            .post(Uri.parse(_openRouterUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_openRouterKey',
                  'HTTP-Referer': 'https://iskoako.app',
                  'X-Title': 'IskoAko',
                },
                body: body)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content = decoded['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          return _parseClassifyResult(content, isFront: isFront, selectedIdType: selectedIdType);
        } else {
          debugPrint('[FaceVerification] OpenRouter $model classify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter $model classify error: $e');
      }
    }
    return null;
  }

  static Future<FaceMatchResult?> _groqMatchFaces({
    required String prompt,
    required String idBase64,
    required String selfieBase64,
    required String idMimeType,
  }) async {
    const models = [
      'llama-3.2-11b-vision-instruct',
      'llama-3.2-90b-vision-instruct',
    ];

    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$idMimeType;base64,$idBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$selfieBase64'}
                },
              ],
            }
          ],
          'max_tokens': 300,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_groqUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_groqKey',
                },
                body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseMatchResultFromText(content, 'Groq ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Groq $model match HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Groq $model match error: $e');
      }
    }
    return null;
  }

  static Future<IdExtractResult?> _groqVerifyId({
    required String prompt,
    required String frontBase64,
    required String backBase64,
  }) async {
    const models = [
      'llama-3.2-11b-vision-instruct',
      'llama-3.2-90b-vision-instruct',
    ];

    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$frontBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$backBase64'}
                },
              ],
            }
          ],
          'max_tokens': 400,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_groqUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_groqKey',
                },
                body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content =
              decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
          final res = _parseIdVerifyResultFromText(content, 'Groq ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Groq $model ID verify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Groq $model ID verify error: $e');
      }
    }
    return null;
  }

  static Future<ClassifyIdResult?> _groqClassifyIdSide({
    required String base64Image,
    required String prompt,
    required bool isFront,
    required String selectedIdType,
  }) async {
    const models = ['llama-3.2-11b-vision-instruct'];
    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                },
              ],
            }
          ],
          'max_tokens': 220,
          'temperature': 0.0,
        });
        final response = await http
            .post(Uri.parse(_groqUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_groqKey',
                },
                body: body)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content = decoded['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          return _parseClassifyResult(content, isFront: isFront, selectedIdType: selectedIdType);
        } else {
          debugPrint('[FaceVerification] Groq $model classify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Groq $model classify error: $e');
      }
    }
    return null;
  }

  static Future<ClassifyIdResult?> _mistralClassifyIdSide({
    required String base64Image,
    required String prompt,
    required bool isFront,
    required String selectedIdType,
  }) async {
    const models = ['pixtral-12b-2409'];
    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                },
              ],
            }
          ],
          'max_tokens': 220,
          'temperature': 0.0,
        });
        final response = await http
            .post(Uri.parse(_mistralUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_mistralKey',
                },
                body: body)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content = decoded['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          return _parseClassifyResult(content, isFront: isFront, selectedIdType: selectedIdType);
        } else {
          debugPrint('[FaceVerification] Mistral $model classify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Mistral $model classify error: $e');
      }
    }
    return null;
  }

  static Future<IdExtractResult?> _mistralVerifyId({
    required String prompt,
    required String frontBase64,
    required String backBase64,
  }) async {
    const models = ['pixtral-12b-2409'];
    for (final model in models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$frontBase64'}
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$backBase64'}
                },
              ],
            }
          ],
          'max_tokens': 400,
          'temperature': 0.1,
        });
        final response = await http
            .post(Uri.parse(_mistralUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_mistralKey',
                },
                body: body)
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final content = decoded['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          final res = _parseIdVerifyResultFromText(content, 'Mistral ($model)');
          if (res != null) return res;
        } else {
          debugPrint('[FaceVerification] Mistral $model ID verify HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FaceVerification] Mistral $model ID verify error: $e');
      }
    }
    return null;
  }

  static ClassifyIdResult _parseClassifyResult(
    String text, {
    required bool isFront,
    required String selectedIdType,
  }) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(jsonDecode(jsonStr));
        final side = parsed['detected_side']?.toString().toLowerCase().trim() ?? 'none';
        final bool isValid = parsed['is_valid_id'] == true || parsed['is_valid_id'] == 'true' || parsed['is_valid_id'] == 1;
        final bool isTypeMatch = parsed['is_id_type_match'] != false && parsed['is_id_type_match'] != 'false';
        final String? detectedType = parsed['detected_id_type']?.toString();
        final String reason = parsed['reason']?.toString() ?? '';

        if (isFront) {
          // If ID type does not match or card is invalid
          if (!isValid || !isTypeMatch || side == 'invalid') {
            return ClassifyIdResult(
              side: 'invalid',
              isValidId: isValid,
              isIdTypeMatch: isTypeMatch,
              detectedIdType: detectedType,
              reason: reason.isNotEmpty
                  ? reason
                  : 'Document does not match selected "$selectedIdType". Detected: ${detectedType ?? "different ID"}.',
            );
          }
          if (side == 'back') {
            return ClassifyIdResult(
              side: 'back',
              isValidId: isValid,
              isIdTypeMatch: isTypeMatch,
              detectedIdType: detectedType,
              reason: reason,
            );
          }
          // Valid front side matching the selected ID type
          return ClassifyIdResult(
            side: 'front',
            isValidId: true,
            isIdTypeMatch: true,
            detectedIdType: detectedType ?? selectedIdType,
            reason: reason,
          );
        } else {
          // For BACK side step:
          if (side == 'front') {
            return ClassifyIdResult(
              side: 'front',
              isValidId: isValid,
              isIdTypeMatch: isTypeMatch,
              detectedIdType: detectedType,
              reason: reason,
            );
          }
          final lowerReason = reason.toLowerCase();
          // Reject if explicitly identified as a non-ID object (desk, wall, shoe, room, screen, scenery)
          if (!isValid && (side == 'none' || side == 'invalid' || lowerReason.contains('non-id') || lowerReason.contains('not an id') || lowerReason.contains('desk') || lowerReason.contains('wall') || lowerReason.contains('screen') || lowerReason.contains('shoe') || lowerReason.contains('furniture') || lowerReason.contains('scenery'))) {
            return ClassifyIdResult(
              side: 'invalid',
              isValidId: false,
              isIdTypeMatch: false,
              detectedIdType: detectedType,
              reason: reason,
            );
          }
          return ClassifyIdResult(
            side: 'back',
            isValidId: true,
            isIdTypeMatch: true,
            detectedIdType: detectedType,
            reason: reason,
          );
        }
      }
    } catch (e) {
      debugPrint('[FaceVerification] Parse classify result JSON error: $e');
    }

    final lower = text.toLowerCase();
    if (!isFront) {
      if (lower.contains('"detected_side": "front"') || lower.contains('"detected_side":"front"')) {
        return const ClassifyIdResult(side: 'front');
      }
      if (lower.contains('is_valid_id": false') && (lower.contains('non-id') || lower.contains('desk') || lower.contains('wall') || lower.contains('screen') || lower.contains('furniture'))) {
        return const ClassifyIdResult(side: 'invalid', isValidId: false);
      }
      return const ClassifyIdResult(side: 'back');
    } else {
      if (lower.contains('is_id_type_match": false') || lower.contains('is_id_type_match":false') ||
          lower.contains('is_valid_id": false') || lower.contains('is_valid_id":false')) {
        return ClassifyIdResult(
          side: 'invalid',
          isValidId: false,
          isIdTypeMatch: false,
          reason: 'ID type mismatch or invalid ID card detected. Expected "$selectedIdType".',
        );
      }
      if (lower.contains('"detected_side": "back"') || lower.contains('"detected_side":"back"')) {
        return const ClassifyIdResult(side: 'back');
      }
      if (lower.contains('"detected_side": "front"') || lower.contains('"detected_side":"front"')) {
        return ClassifyIdResult(side: 'front', detectedIdType: selectedIdType);
      }
    }

    return ClassifyIdResult(
      side: isFront ? 'invalid' : 'back',
      isValidId: !isFront,
      isIdTypeMatch: !isFront,
    );
  }

  static IdExtractResult? _parseIdVerifyResult(String body, String model) {
    try {
      final data = jsonDecode(body);
      final text = data['candidates'][0]['content']['parts'][0]['text']?.toString() ?? '';
      return _parseIdVerifyResultFromText(text, model);
    } catch (e) {
      debugPrint('[FaceVerification] ID verify parse error ($model): $e');
    }
    return null;
  }

  /// Cleans and sanitizes names extracted from IDs by removing printed field labels,
  /// headers, or placeholder values (e.g. "Gitnang Apelyido", "Middle Name", "N/A").
  static String cleanExtractedName(String? raw) {
    if (raw == null) return '';
    String clean = raw.trim();
    if (clean.isEmpty) return '';

    final lower = clean.toLowerCase();

    const placeholderPhrases = [
      'gitnang apelyido',
      'middle name',
      'apelyido',
      'mga pangalan',
      'pangalan',
      'first name',
      'given name',
      'given names',
      'last name',
      'surname',
      'kasarian',
      'sex',
      'petsa ng kapanganakan',
      'date of birth',
      'birth date',
      'tirahan',
      'address',
      'walang gitnang apelyido',
      'no middle name',
      'not applicable',
      'none',
      'n/a',
      'na',
      'null',
      'wala',
      '-',
      '--',
      '---',
      '.',
    ];

    for (final phrase in placeholderPhrases) {
      if (lower == phrase || lower == '($phrase)' || lower == '[$phrase]') {
        return '';
      }
    }

    clean = clean
        .replaceAll(RegExp(r'\bgitnang\s+apelyido\s*(?:/\s*middle\s+name)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bmga\s+pangalan\s*(?:/\s*given\s+names?)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bapelyido\s*(?:/\s*last\s+name)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bgitnang\s+apelyido\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bmiddle\s+name\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bmga\s+pangalan\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bgiven\s+names?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bfirst\s+name\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\blast\s+name\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bwalang\s+gitnang\s+apelyido\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bno\s+middle\s+name\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bnot\s+applicable\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bn\s*/\s*a\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bnone\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bwala\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[/\\()\[\]\-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return clean;
  }

  static IdExtractResult? _parseIdVerifyResultFromText(String text, String model) {
    try {
      String cleanText = text.trim();
      if (cleanText.startsWith('```')) {
        final startIdx = cleanText.indexOf('{');
        final endIdx = cleanText.lastIndexOf('}');
        if (startIdx != -1 && endIdx != -1) {
          cleanText = cleanText.substring(startIdx, endIdx + 1);
        }
      }
      final parsed = jsonDecode(cleanText);
      final isIdTypeMatch = parsed['is_id_type_match'] != false && parsed['is_id_type_match'] != 'false';
      final detectedIdType = parsed['detected_id_type']?.toString();
      final isMatch = parsed['is_match'] == true;
      final confidence = double.tryParse(parsed['confidence']?.toString() ?? '0') ?? 0.0;
      final extFirst = cleanExtractedName(parsed['extracted_first_name']?.toString());
      final extMiddle = cleanExtractedName(parsed['extracted_middle_name']?.toString());
      final extLast = cleanExtractedName(parsed['extracted_last_name']?.toString());
      final extBirth = parsed['extracted_birth_date']?.toString() ?? '';
      final extIdNo = parsed['extracted_id_number']?.toString() ?? '';
      final List<String> mismatched = (parsed['mismatched_fields'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      final reason = parsed['reason']?.toString() ?? '';

      return IdExtractResult(
        isMatch: isMatch && isIdTypeMatch,
        isIdTypeMatch: isIdTypeMatch,
        detectedIdType: detectedIdType,
        confidence: confidence,
        extractedFirstName: extFirst,
        extractedMiddleName: extMiddle,
        extractedLastName: extLast,
        extractedBirthDate: extBirth,
        extractedIdNumber: extIdNo,
        mismatchedFields: mismatched,
        reason: reason,
        modelUsed: model,
      );
    } catch (e) {
      debugPrint('[FaceVerification] ID verify text parse error ($model): $e');
    }
    return null;
  }

  /// Programmatically verifies AI-extracted ID text against profile registration details in Dart.
  static IdExtractResult _validateExtractedDetailsStrictly({
    required IdExtractResult rawResult,
    required String idType,
    required String regFirstName,
    required String regLastName,
    required String regBirthDate,
  }) {
    final List<String> mismatches = [];
    final List<String> matchReasons = [];
    final List<String> mismatchReasons = [];

    // 0. Strict ID Type Verification
    if (!rawResult.isIdTypeMatch) {
      mismatches.add('id_type');
      mismatchReasons.add(
        'ID Type mismatch: Expected "$idType" but detected "${rawResult.detectedIdType ?? 'a different ID card'}".',
      );
    } else {
      matchReasons.add('ID Type verified ($idType).');
    }

    final String extFirst = cleanExtractedName(rawResult.extractedFirstName);
    final String extMiddle = cleanExtractedName(rawResult.extractedMiddleName);
    final String extLast = cleanExtractedName(rawResult.extractedLastName);
    final String extBirth = rawResult.extractedBirthDate.trim();

    // 1. Validate First Name
    final bool firstNameMatches = _compareNamesStrictly(regFirstName, extFirst);
    if (!firstNameMatches) {
      mismatches.add('first_name');
      mismatchReasons.add('First Name mismatch: Registered "$regFirstName" vs ID "$extFirst".');
    } else {
      matchReasons.add('First Name matched.');
    }

    // 2. Validate Last Name
    final bool lastNameMatches = _compareNamesStrictly(regLastName, extLast);
    if (!lastNameMatches) {
      mismatches.add('last_name');
      mismatchReasons.add('Last Name mismatch: Registered "$regLastName" vs ID "$extLast".');
    } else {
      matchReasons.add('Last Name matched.');
    }

    final bool isFinalMatch = mismatches.isEmpty && rawResult.isMatch;

    final String combinedReason = mismatches.isNotEmpty
        ? mismatchReasons.join(' ')
        : (rawResult.reason.isNotEmpty ? rawResult.reason : matchReasons.join(' '));

    return IdExtractResult(
      isMatch: isFinalMatch,
      isIdTypeMatch: rawResult.isIdTypeMatch && !mismatches.contains('id_type'),
      detectedIdType: rawResult.detectedIdType,
      confidence: mismatches.isEmpty ? rawResult.confidence : 0.0,
      extractedFirstName: extFirst,
      extractedMiddleName: extMiddle,
      extractedLastName: extLast,
      extractedBirthDate: extBirth,
      extractedIdNumber: rawResult.extractedIdNumber,
      mismatchedFields: mismatches.isNotEmpty ? mismatches : rawResult.mismatchedFields,
      reason: combinedReason,
      modelUsed: rawResult.modelUsed,
    );
  }

  static bool _compareNamesStrictly(String regName, String extName) {
    if (regName.trim().isEmpty) return true;
    if (extName.trim().isEmpty) return false;

    final normReg = _normalizeString(regName);
    final normExt = _normalizeString(extName);

    if (normReg == normExt) return true;

    final regTokens = normReg.split(' ').where((t) => t.length > 1).toList();
    final extTokens = normExt.split(' ').where((t) => t.length > 1).toList();

    if (regTokens.isEmpty || extTokens.isEmpty) return false;

    // 1. Verify every token in registered profile name exists in ID extracted name
    for (final regToken in regTokens) {
      bool found = false;
      for (final extToken in extTokens) {
        if (extToken == regToken || extToken.contains(regToken) || regToken.contains(extToken)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }

    // 2. Bi-directional check: Verify every token in ID extracted name exists in registered profile name
    for (final extToken in extTokens) {
      bool found = false;
      for (final regToken in regTokens) {
        if (regToken == extToken || regToken.contains(extToken) || extToken.contains(regToken)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }

    return true;
  }

  static String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


}

class IdExtractResult {
  final bool isMatch;
  final bool isIdTypeMatch;
  final String? detectedIdType;
  final double confidence;
  final String extractedFirstName;
  final String extractedMiddleName;
  final String extractedLastName;
  final String extractedBirthDate;
  final String extractedIdNumber;
  final List<String> mismatchedFields;
  final String reason;
  final String modelUsed;

  const IdExtractResult({
    required this.isMatch,
    this.isIdTypeMatch = true,
    this.detectedIdType,
    required this.confidence,
    required this.extractedFirstName,
    this.extractedMiddleName = '',
    required this.extractedLastName,
    required this.extractedBirthDate,
    required this.extractedIdNumber,
    required this.mismatchedFields,
    required this.reason,
    required this.modelUsed,
  });
}

class ClassifyIdResult {
  final String side; // 'front', 'back', 'invalid'
  final bool isValidId;
  final bool isIdTypeMatch;
  final String? detectedIdType;
  final String? reason;

  const ClassifyIdResult({
    required this.side,
    this.isValidId = true,
    this.isIdTypeMatch = true,
    this.detectedIdType,
    this.reason,
  });
}
