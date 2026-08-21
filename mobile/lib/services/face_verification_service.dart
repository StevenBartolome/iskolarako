import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

// ─── Service ─────────────────────────────────────────────────────────────────

class FaceVerificationService {
  static String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _mistralKey => dotenv.env['MISTRAL_API_KEY'] ?? '';
  static String get _openRouterKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _mistralUrl =
      'https://api.mistral.ai/v1/chat/completions';
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

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

Rules:
- Search the entire ID card/document for the student's face photo.
- If the ID contains a photo and the facial features (eyes, nose, mouth, face shape) match the person in the selfie, return is_match: true.
- Account for normal variations in lighting, expression, hairstyle, age, or glasses between an ID photo and a phone camera selfie.
- If the faces belong to different people, return is_match: false.
- If the document contains no photo of a person at all, return is_match: false with reason "No face found on ID".
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

    // 1. Try Google Gemini (Native PDF & Vision support)
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

    // 2. Try OpenRouter Multi-Model Router
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

    // 3. Try Mistral
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

  static Future<LivenessCheckResult> checkLiveness({
    required Uint8List frameBytes,
    Uint8List? baselineFrameBytes,
    required LivenessAction expectedAction,
  }) async {
    final frameBase64 = base64Encode(frameBytes);
    final baselineFrameBase64 =
        baselineFrameBytes != null ? base64Encode(baselineFrameBytes) : null;
    final prompt = _buildLivenessPrompt(expectedAction,
        hasBaseline: baselineFrameBytes != null);

    // 1. Try Gemini
    if (_geminiKey.isNotEmpty) {
      try {
        final result = await _geminiLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] Gemini liveness error: $e');
      }
    }

    // 2. Try OpenRouter
    if (_openRouterKey.isNotEmpty) {
      try {
        final result = await _openRouterLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] OpenRouter liveness error: $e');
      }
    }

    // 3. Try Mistral
    if (_mistralKey.isNotEmpty) {
      try {
        final result = await _mistralLiveness(
          prompt: prompt,
          frameBase64: frameBase64,
          baselineFrameBase64: baselineFrameBase64,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[FaceVerification] Mistral liveness error: $e');
      }
    }

    return const LivenessCheckResult(
      faceDetected: false,
      actionDetected: false,
      reason: 'AI service temporarily unavailable.',
      modelUsed: 'Unavailable',
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
    const models = ['gemini-3.6-flash', 'gemini-2.5-flash'];
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
  }) async {
    const models = ['gemini-3.6-flash', 'gemini-2.5-flash'];
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

          final body = jsonEncode({
            'contents': [
              {'parts': parts}
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 40},
          });
          final response = await http
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 6));

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
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
      'qwen/qwen-2.5-vl-72b-instruct',
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
  }) async {
    const models = [
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
      'qwen/qwen-2.5-vl-72b-instruct',
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
    const models = ['pixtral-12b-2409', 'pixtral-large-latest'];
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
  }) async {
    const models = ['pixtral-12b-2409', 'pixtral-large-latest'];
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
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final json = jsonDecode(cleaned.substring(start, end + 1));
      return FaceMatchResult(
        isMatch: json['is_match'] == true,
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
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final json = jsonDecode(cleaned.substring(start, end + 1));
      return LivenessCheckResult(
        faceDetected: json['face_detected'] == true,
        actionDetected: json['action_detected'] == true,
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

  static String _buildLivenessPrompt(LivenessAction action,
      {bool hasBaseline = false}) {
    final actionName = action == LivenessAction.blink
        ? 'BLINK (closing or shut eyes)'
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
   - For BLINK: true if the eyes in Frame 2 are closed, squinting, or shutting compared to Frame 1.
   - For TURN HEAD LEFT / RIGHT: true if the person in Frame 2 has turned their head to the side (side profile visible, ear/cheek shown, nose pointing away from camera center).
   - Front selfie cameras may mirror the image, so if the person in Frame 2 is noticeably turned away from the center to ANY side, accept it as action_detected: true.
   - Only return action_detected: false if the person is staring completely straight forward in both frames with zero movement.
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
}
