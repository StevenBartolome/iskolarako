import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ─── Result Types ────────────────────────────────────────────────────────────

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
  static const String _geminiModel = 'gemini-2.0-flash';
  static const String _mistralUrl =
      'https://api.mistral.ai/v1/chat/completions';
  static const String _mistralVisionModel = 'pixtral-12b-2409';
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _openRouterModel = 'google/gemma-3-27b-it:free';

  // ─────────────────────────────────────────────────────────────────────────
  // 1. FACE MATCH
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FaceMatchResult> matchFaces({
    required Uint8List idImageBytes,
    required Uint8List selfieBytes,
  }) async {
    final idBase64 = base64Encode(idImageBytes);
    final selfieBase64 = base64Encode(selfieBytes);

    const prompt = '''
You are a strict face verification AI assistant.
You are given TWO images:
  Image 1 = a photo of a valid ID / school ID card (may contain a small face photo embedded in the card).
  Image 2 = a live selfie of the person claiming to own this ID.

Your task:
1. Locate the face/photo on the ID card (Image 1).
2. Compare that face with the selfie face in Image 2.
3. Determine if they are the SAME person.

Return ONLY raw JSON (no markdown, no backticks):
{
  "is_match": true or false,
  "confidence": 0.0 to 1.0,
  "reason": "Brief explanation of the comparison result."
}

Be strict: only return is_match=true if you are reasonably confident (>=0.70) it is the same person.
If the ID has no visible face photo, return is_match=false with reason "No face found on ID".
''';

    // Detect PDF by magic bytes %PDF (0x25 0x50 0x44 0x46)
    final isIdPdf = idImageBytes.length > 4 &&
        idImageBytes[0] == 0x25 &&
        idImageBytes[1] == 0x50 &&
        idImageBytes[2] == 0x44 &&
        idImageBytes[3] == 0x46;
    final idMimeType = isIdPdf ? 'application/pdf' : 'image/jpeg';

    try {
      final result = await _geminiMatchFaces(
        prompt: prompt,
        idBase64: idBase64,
        selfieBase64: selfieBase64,
        idMimeType: idMimeType,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] Gemini face-match failed: $e');
    }
    try {
      final result = await _mistralMatchFaces(
        prompt: prompt,
        idBase64: idBase64,
        selfieBase64: selfieBase64,
        idMimeType: idMimeType,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] Mistral face-match failed: $e');
    }
    try {
      final result = await _openRouterMatchFaces(
        prompt: prompt,
        idBase64: idBase64,
        selfieBase64: selfieBase64,
        idMimeType: idMimeType,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] OpenRouter face-match failed: $e');
    }

    return const FaceMatchResult(
      isMatch: false,
      confidence: 0.0,
      reason: 'AI service temporarily unavailable. Please try again.',
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

    try {
      final result = await _geminiLiveness(
        prompt: prompt,
        frameBase64: frameBase64,
        baselineFrameBase64: baselineFrameBase64,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] Gemini liveness failed: $e');
    }
    try {
      final result = await _mistralLiveness(
        prompt: prompt,
        frameBase64: frameBase64,
        baselineFrameBase64: baselineFrameBase64,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] Mistral liveness failed: $e');
    }
    try {
      final result = await _openRouterLiveness(
        prompt: prompt,
        frameBase64: frameBase64,
        baselineFrameBase64: baselineFrameBase64,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('[FaceVerification] OpenRouter liveness failed: $e');
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
    final url = Uri.parse(
        '$_geminiBaseUrl/$_geminiModel:generateContent?key=$_geminiKey');
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
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 300},
    });
    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));
    return _parseMatchResult(response.body, 'Gemini Flash');
  }

  static Future<LivenessCheckResult?> _geminiLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
  }) async {
    final url = Uri.parse(
        '$_geminiBaseUrl/$_geminiModel:generateContent?key=$_geminiKey');
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
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 200},
    });
    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));
    return _parseLivenessResult(response.body, 'Gemini Flash');
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
    final body = jsonEncode({
      'model': _mistralVisionModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {'type': 'image_url', 'image_url': 'data:$idMimeType;base64,$idBase64'},
            {'type': 'image_url', 'image_url': 'data:image/jpeg;base64,$selfieBase64'},
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
    final decoded = jsonDecode(response.body);
    final content =
        decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _parseMatchResultFromText(content, 'Mistral Pixtral');
  }

  static Future<LivenessCheckResult?> _mistralLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
  }) async {
    final contents = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    if (baselineFrameBase64 != null) {
      contents.add({
        'type': 'image_url',
        'image_url': 'data:image/jpeg;base64,$baselineFrameBase64',
      });
    }
    contents.add({
      'type': 'image_url',
      'image_url': 'data:image/jpeg;base64,$frameBase64',
    });

    final body = jsonEncode({
      'model': _mistralVisionModel,
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
    final decoded = jsonDecode(response.body);
    final content =
        decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _parseLivenessResultFromText(content, 'Mistral Pixtral');
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
    final body = jsonEncode({
      'model': _openRouterModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {'type': 'image_url', 'image_url': {'url': 'data:$idMimeType;base64,$idBase64'}},
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$selfieBase64'}},
          ],
        }
      ],
      'max_tokens': 300,
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
        .timeout(const Duration(seconds: 40));
    final decoded = jsonDecode(response.body);
    final content =
        decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _parseMatchResultFromText(content, 'OpenRouter (Gemma-3)');
  }

  static Future<LivenessCheckResult?> _openRouterLiveness({
    required String prompt,
    required String frameBase64,
    String? baselineFrameBase64,
  }) async {
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
      'model': _openRouterModel,
      'messages': [
        {
          'role': 'user',
          'content': contents,
        }
      ],
      'max_tokens': 200,
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
    final decoded = jsonDecode(response.body);
    final content =
        decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _parseLivenessResultFromText(content, 'OpenRouter (Gemma-3)');
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
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        reason: json['reason']?.toString() ?? '',
        modelUsed: model,
      );
    } catch (e) {
      debugPrint('[FaceVerification] JSON parse error ($model): $e\n$text');
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
      debugPrint(
          '[FaceVerification] Liveness JSON parse error ($model): $e\n$text');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static String _buildLivenessPrompt(LivenessAction action,
      {bool hasBaseline = false}) {
    final actionName = action == LivenessAction.blink
        ? 'BLINK (eyes closed / shut)'
        : (action == LivenessAction.turnLeft
            ? 'TURN HEAD LEFT (side profile / looking left)'
            : 'TURN HEAD RIGHT (side profile / looking right)');

    if (hasBaseline) {
      return '''
You are a precise liveness verification AI analyzing TWO sequential camera frames:
- Frame 1: Baseline photo of the person starting by looking straight forward at the camera.
- Frame 2: The person performing the requested action: $actionName.

Return ONLY raw JSON (no markdown, no backticks):
{
  "face_detected": true or false,
  "action_detected": true or false,
  "reason": "Short feedback (e.g. eyes closed in frame 2, head turned in frame 2, no movement)"
}

Rules:
1. "face_detected": true if a human face is clearly visible in the frames.
2. "action_detected":
   - For BLINK: true if eyes are open in Frame 1 and CLOSED/shut in Frame 2.
   - For TURN HEAD LEFT: true if the person was facing forward in Frame 1 and visibly turned/rotated their head to the LEFT in Frame 2.
   - For TURN HEAD RIGHT: true if the person was facing forward in Frame 1 and visibly turned/rotated their head to the RIGHT in Frame 2.
   - If the person in Frame 2 is still looking straight at the camera (no turn or blink), return action_detected: false.
''';
    } else {
      switch (action) {
        case LivenessAction.blink:
          return '''
You are a precise liveness detection AI analyzing a selfie camera frame.
Task: Detect if the person in the photo has their EYES CLOSED or is actively BLINKING.

Return ONLY raw JSON (no markdown, no backticks):
{
  "face_detected": true or false,
  "action_detected": true or false,
  "reason": "Short feedback (e.g. eyes closed, eyes open, facing forward)"
}

Rules:
1. "face_detected": true if a human face is clearly visible.
2. "action_detected": Set to TRUE ONLY if both eyes are CLOSED or SHUT. If eyes are open, return false.
''';

        case LivenessAction.turnLeft:
          return '''
You are a precise liveness detection AI analyzing a selfie camera frame.
Task: Detect if the person has actively TURNED THEIR HEAD TO THE LEFT.

Return ONLY raw JSON (no markdown, no backticks):
{
  "face_detected": true or false,
  "action_detected": true or false,
  "reason": "Short feedback (e.g. turned left, facing forward, turned right)"
}

Rules:
1. "face_detected": true if a human face is clearly visible.
2. "action_detected": Set to TRUE if the person has rotated/turned their head to the LEFT side. If facing forward, return false.
''';

        case LivenessAction.turnRight:
          return '''
You are a precise liveness detection AI analyzing a selfie camera frame.
Task: Detect if the person has actively TURNED THEIR HEAD TO THE RIGHT.

Return ONLY raw JSON (no markdown, no backticks):
{
  "face_detected": true or false,
  "action_detected": true or false,
  "reason": "Short feedback (e.g. turned right, facing forward, turned left)"
}

Rules:
1. "face_detected": true if a human face is clearly visible.
2. "action_detected": Set to TRUE if the person has rotated/turned their head to the RIGHT side. If facing forward, return false.
''';
      }
    }
  }
}
