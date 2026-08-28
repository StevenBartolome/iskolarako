import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentValidationResult {
  final bool isValidType;
  final String documentDetected;
  final double confidenceScore;
  final String rejectionReason;
  final List<String> flags;
  final String modelUsed;

  const DocumentValidationResult({
    required this.isValidType,
    required this.documentDetected,
    required this.confidenceScore,
    required this.rejectionReason,
    required this.flags,
    required this.modelUsed,
  });
}

class AttemptStatus {
  final int attemptCount;
  final bool isCooldownActive;
  final int remainingCooldownSeconds;
  final bool isDisputeEligible;

  const AttemptStatus({
    required this.attemptCount,
    required this.isCooldownActive,
    required this.remainingCooldownSeconds,
    required this.isDisputeEligible,
  });
}

class DocumentValidationService {
  static const int maxAttempts = 3;
  static const int cooldownMinutes = 1;

  static String? _sanitizeUuid(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final clean = raw.trim();
    if (clean == 'guest' || clean == 'cycle') return null;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(clean)) return null;
    return clean;
  }

  /// Check attempt count and cooldown status from `document_ai_rejections` table
  static Future<AttemptStatus> checkAttemptStatus({
    required String scholarId,
    required String? cycleId,
    required String docSlotName,
  }) async {
    try {
      final validScholarId = _sanitizeUuid(scholarId);
      final validCycleId = _sanitizeUuid(cycleId);

      if (validScholarId == null) {
        debugPrint(
          '[DocValidation] checkAttemptStatus: invalid scholarId "$scholarId"',
        );
        return const AttemptStatus(
          attemptCount: 0,
          isCooldownActive: false,
          remainingCooldownSeconds: 0,
          isDisputeEligible: false,
        );
      }

      final supabase = Supabase.instance.client;
      var query = supabase
          .from('document_ai_rejections')
          .select()
          .eq('scholar_id', validScholarId)
          .eq('document_slot_name', docSlotName);

      if (validCycleId != null) {
        query = query.eq('cycle_id', validCycleId);
      }

      final List<dynamic> rows = await query.order(
        'created_at',
        ascending: false,
      );

      final count = rows.length;
      if (count == 0) {
        return const AttemptStatus(
          attemptCount: 0,
          isCooldownActive: false,
          remainingCooldownSeconds: 0,
          isDisputeEligible: false,
        );
      }

      final lastRejection = rows.first;
      final createdAtStr = lastRejection['created_at']?.toString();
      bool inCooldown = false;
      int remainingSecs = 0;

      if (count == 2 && createdAtStr != null) {
        final lastTime = DateTime.parse(createdAtStr).toUtc();
        final now = DateTime.now().toUtc();
        final diff = now.difference(lastTime);
        final cooldownDuration = const Duration(minutes: cooldownMinutes);

        if (diff < cooldownDuration) {
          inCooldown = true;
          remainingSecs = cooldownDuration.inSeconds - diff.inSeconds;
        }
      }

      return AttemptStatus(
        attemptCount: count,
        isCooldownActive: inCooldown,
        remainingCooldownSeconds: remainingSecs,
        isDisputeEligible: count >= maxAttempts,
      );
    } catch (e) {
      debugPrint('Error checking attempt status: $e');
      return const AttemptStatus(
        attemptCount: 0,
        isCooldownActive: false,
        remainingCooldownSeconds: 0,
        isDisputeEligible: false,
      );
    }
  }

  /// Log AI rejection to `document_ai_rejections` audit table
  static Future<void> logRejection({
    required String scholarId,
    required String? cycleId,
    required String docSlotName,
    required String? filename,
    required double confidenceScore,
    required String rejectionReason,
    required int attemptNumber,
  }) async {
    try {
      final validScholarId = _sanitizeUuid(scholarId);
      final validCycleId = _sanitizeUuid(cycleId);

      if (validScholarId == null) {
        debugPrint(
          '⚠️ [DocValidation Log Error]: Cannot log rejection because scholarId "$scholarId" is not a valid UUID or user is not logged in.',
        );
        return;
      }

      final supabase = Supabase.instance.client;
      final payload = {
        'scholar_id': validScholarId,
        'cycle_id': validCycleId,
        'document_slot_name': docSlotName,
        'filename': filename,
        'ai_confidence_score': confidenceScore,
        'ai_rejection_reason': rejectionReason,
        'attempt_number': attemptNumber,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await supabase
          .from('document_ai_rejections')
          .insert(payload)
          .select();
      debugPrint(
        '✅ Logged AI rejection (Attempt $attemptNumber) for $docSlotName: $response',
      );
    } catch (e) {
      debugPrint(
        '❌ Error logging AI rejection into document_ai_rejections table: $e',
      );
    }
  }

  /// Main AI validation function
  static Future<DocumentValidationResult> validateDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String requiredDocName,
    String? requirementDescription,
    String? scholarName,
    double? minimumGwa,
    String? gradingSystem,
    String? filePath,
  }) async {
    Uint8List actualBytes = fileBytes;
    if (actualBytes.isEmpty && filePath != null && filePath.isNotEmpty) {
      try {
        actualBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading file for validation: $e');
      }
    }

    if (actualBytes.isEmpty) {
      return const DocumentValidationResult(
        isValidType: false,
        documentDetected: 'Empty file',
        confidenceScore: 0.0,
        rejectionReason: 'The uploaded file is empty or corrupted.',
        flags: ['Empty or unreadable file'],
        modelUsed: 'Local Check',
      );
    }

    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isPng = fileName.toLowerCase().endsWith('.png');
    final mimeType = isPdf
        ? 'application/pdf'
        : (isPng ? 'image/png' : 'image/jpeg');

    List<Uint8List> visionImages = [];
    String visionMime = mimeType;

    if (isPdf) {
      final embedded = _extractJpegsFromPdf(actualBytes);
      if (embedded.isNotEmpty) {
        for (final img in embedded) {
          final prepped = await _prepareImage(img);
          if (prepped != null) visionImages.add(prepped);
        }
        visionMime = 'image/jpeg';
      } else {
        visionImages.add(actualBytes);
      }
    } else {
      final prepped = await _prepareImage(actualBytes);
      visionImages.add(prepped ?? actualBytes);
    }

    final openRouterKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    final scholarNameText = (scholarName != null && scholarName.isNotEmpty)
        ? 'Declared Scholar Name: "$scholarName"'
        : 'Declared Scholar Name: Not provided';

    final reqDescText =
        (requirementDescription != null &&
            requirementDescription.trim().isNotEmpty)
        ? 'Provider Custom Instructions/Remarks: "$requirementDescription"'
        : 'Provider Custom Instructions/Remarks: None specified';

    final gwaCheckText = (minimumGwa != null && minimumGwa > 0)
        ? 'Program Minimum GWA Required: $minimumGwa (Grading System: ${gradingSystem ?? "scale_5 where 1.00 is top, 3.00 passing, 5.00 failing"})'
        : 'Program Minimum GWA Required: Not applicable';

    final prompt =
        '''
You are an expert Philippine scholarship application document verifier.
Required Document Category: "$requiredDocName".
$scholarNameText.
$reqDescText.
$gwaCheckText.

Carefully read and analyze the document image/PDF to perform four critical checks:

1. DOCUMENT CATEGORY CHECK:
   - What type of document is this file actually? (e.g. Transcript of Records (TOR), Report Card / Grade Slip, Certificate of Grades, Certificate of Enrollment (COR), Certificate of Indigency, PSA Birth Certificate, Government ID, Student ID, School Assignment / Homework, Unrelated Document, etc.)
   - Does this document match the required category "$requiredDocName"?
   - CRITICAL: If the document is an assignment, homework, essay, random paper, or a wrong document type (e.g. Indigency uploaded under TOR), set "is_valid_type": false, "confidence_score": 0.15 to 0.35, and set "rejection_reason": "The uploaded document is [document type], not a valid $requiredDocName."

2. STUDENT / INDIVIDUAL NAME CHECK:
   - Search the document for the student's name (e.g. "Name:", "Student Name:", "Student:", "Issued to:").
   - Compare the document name with the applicant's declared name "$scholarName".
   
   NAME MATCHING RULES:
   a) MATCH / ACCEPT (is_valid_type = true, confidence_score >= 0.80):
      - Exact match (e.g. "Mark Steven Bartolome" vs "Mark Steven Bartolome").
      - Name variations including middle names, middle initials, or title order (e.g. Declared: "Mark Steven Bartolome" vs Document: "Mark Steven Mendoza Bartolome" or "Bartolome, Mark Steven M.").
      - DO NOT REJECT OR PENALIZE for extra middle names, middle initials, or inverted Last-Name-First formatting! Treat this as a clean match (confidence_score >= 0.85).

   b) COMPLETELY DIFFERENT PERSON (confidence_score = 0.25 to 0.35):
      - If the document clearly belongs to a completely different person (e.g. Declared: "$scholarName" vs Document: "Juan Dela Cruz" or "Maria Santos"), this MUST BE REJECTED.
      - Set "is_valid_type": false, "confidence_score": 0.25 to 0.35, and set "rejection_reason": "This document belongs to [Name on Document], which does not match declared scholar name $scholarName."

3. PROVIDER INSTRUCTIONS / REMARKS CHECK:
   - If Provider Custom Instructions/Remarks ("$requirementDescription") are specified above:
   - Carefully check if the document complies with these instructions (e.g. required Dean/Principal signature, official seal/watermark, current semester/academic year, specific format or issuing office).
   - IF the document fails to meet these provider instructions:
     * Add a clear warning flag to the "flags" array (e.g. "Missing Dean signature as specified in provider instructions: $requirementDescription").
     * Set "confidence_score" between 0.50 and 0.65 (Flagged for Provider Review) so the application requires manual provider inspection.

4. ACADEMIC GRADE / MINIMUM GWA CHECK:
    - If this document contains academic grades, GWA, GPA, or General Average (e.g. Transcript of Records (TOR), Certificate of Grades, True Copy of Grades (TCG), Report Card, Form 138, Grade Slip, etc.):
    - Locate and extract the overall GWA / GPA / General Average printed on the document.

    STEP A — DETERMINE EQUIVALENT PERCENTAGE (compute ONCE, store as [equiv_pct], use everywhere below):
    Use ONLY the official lookup table below. DO NOT use a formula. DO NOT re-derive at any other step.

    scale_5 Lookup Table (Philippine Standard — LOWER GWA = BETTER grade):
    | GWA  | Equivalent % range | Use midpoint |
    |------|--------------------|--------------|
    | 1.00 | 97 – 100%          | 98.5%        |
    | 1.25 | 94 – 96%           | 95.0%        |
    | 1.50 | 91 – 93%           | 92.0%        |
    | 1.75 | 88 – 90%           | 89.0%        |
    | 2.00 | 85 – 87%           | 86.0%        |
    | 2.25 | 82 – 84%           | 83.0%        |
    | 2.50 | 79 – 81%           | 80.0%        |
    | 2.75 | 76 – 78%           | 77.0%        |
    | 3.00 | 75%                | 75.0%        |
    | 5.00 | < 60%              | 55.0%        |

    For GWA values BETWEEN table rows, interpolate linearly between the two bounding rows.
    Example: GWA 1.61 is between 1.50 (92.0%) and 1.75 (89.0%).
      fraction = (1.61 - 1.50) / (1.75 - 1.50) = 0.44
      [equiv_pct] = 92.0% - (0.44 × (92.0% - 89.0%)) = 92.0% - 1.32% ≈ 90.7%

    scale_4 Lookup Table (NU / DLSU / Ateneo system — HIGHER grade point = BETTER):
    | Grade Point | Equivalent % range | Use midpoint |
    |-------------|--------------------|--------------|
    | 4.0         | 96 – 100%          | 98.0%        |
    | 3.5         | 90 – 95%           | 92.5%        |
    | 3.0         | 84 – 89%           | 86.5%        |
    | 2.5         | 78 – 83%           | 80.5%        |
    | 2.0         | 72 – 77%           | 74.5%        |
    | 1.5         | 66 – 71%           | 68.5%        |
    | 1.0         | 60 – 65%           | 62.5%        |
    | 0.0 / R / F | < 60%              | 55.0%        |

    For grade points BETWEEN table rows, interpolate linearly between the two bounding rows.

    percentage system: [equiv_pct] = the grade value itself (e.g. 85 → 85.0%).

    STEP B — GRADE REJECTION CHECK:
    If a Minimum GWA ($minimumGwa) is specified above and [equiv_pct] from Step A is LOWER than
    the equivalent percentage of the minimum required GWA (also looked up from the same table):
      * YOU MUST REJECT THIS DOCUMENT SUBMISSION IMMEDIATELY.
      * Set "is_valid_type": false
      * Set "confidence_score": 0.25 to 0.35
      * Add to "flags": "Extracted GWA [extracted_grade] ([equiv_pct]%) is below required minimum $minimumGwa"
      * Set "rejection_reason": "Extracted GWA [extracted_grade] ([equiv_pct]%) does not meet the minimum required grade of $minimumGwa for this scholarship program."
      CRITICAL: Use the SAME [equiv_pct] from Step A in the flag and the rejection_reason. DO NOT compute a different percentage here.

Return ONLY valid JSON with no markdown backticks, commentary, or extra text:
{
  "is_valid_type": true,
  "document_detected": "Name of document seen",
  "confidence_score": 0.85,
  "rejection_reason": "Specific reason if invalid/rejected, else empty string",
  "flags": ["list of concerns if any"]
}
''';

    // 1. Try OpenRouter Vision (Primary)
    if (openRouterKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling OpenRouter for $requiredDocName...',
        );
        final res = await _callOpenRouter(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: openRouterKey,
        );
        if (res != null) return res;
      } catch (e) {
        debugPrint('[DocValidation] OpenRouter error: $e');
      }
    }

    // 2. Try Gemini Native Vision (Fallback)
    if (geminiKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling Gemini fallback for $requiredDocName...',
        );
        final res = await _callGemini(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: geminiKey,
        );
        if (res != null) return res;
      } catch (e) {
        debugPrint('[DocValidation] Gemini error: $e');
      }
    }

    // Default fallback if AI service fails/unreachable: default to basic flag
    return DocumentValidationResult(
      isValidType: true,
      documentDetected: requiredDocName,
      confidenceScore: 0.75, // Flagged for review
      rejectionReason: '',
      flags: [
        'AI service verification offline - flagged for manual provider review',
      ],
      modelUsed: 'Fallback Local Safety',
    );
  }

  static Future<DocumentValidationResult?> _callOpenRouter({
    required String prompt,
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    const models = [
      'google/gemini-2.5-flash',
      'google/gemini-2.0-flash',
      'anthropic/claude-3.5-haiku',
      'openai/gpt-4o-mini',
      'google/gemini-2.5-flash:free',
    ];

    for (final model in models) {
      try {
        final contentList = <Map<String, dynamic>>[
          {'type': 'text', 'text': prompt},
        ];

        for (final img in images) {
          contentList.add({
            'type': 'image_url',
            'image_url': {'url': 'data:$mimeType;base64,${base64Encode(img)}'},
          });
        }

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
                'HTTP-Referer': 'https://iskolarako.app',
                'X-Title': 'IskoAko Scholarship App',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'user', 'content': contentList},
                ],
                'response_format': {'type': 'json_object'},
                'temperature': 0.1,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText =
              data['choices']?[0]?['message']?['content']?.toString() ?? '';
          final parsed = _parseJson(rawText, 'OpenRouter ($model)');
          if (parsed != null) return parsed;
        } else {
          debugPrint(
            'OpenRouter $model HTTP ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('OpenRouter $model error: $e');
      }
    }
    return null;
  }

  static Future<DocumentValidationResult?> _callGemini({
    required String prompt,
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final parts = <Map<String, dynamic>>[
          {'text': prompt},
        ];

        for (final img in images) {
          parts.add({
            'inline_data': {'mime_type': mimeType, 'data': base64Encode(img)},
          });
        }

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts},
                ],
                'generationConfig': {
                  'response_mime_type': 'application/json',
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText =
              data['candidates']?[0]?['content']?['parts']?[0]?['text']
                  ?.toString() ??
              '';
          final parsed = _parseJson(rawText, 'Gemini ($model)');
          if (parsed != null) return parsed;
        }
      } catch (e) {
        debugPrint('Gemini $model error: $e');
      }
    }
    return null;
  }

  static DocumentValidationResult? _parseJson(
    String rawText,
    String modelName,
  ) {
    try {
      String clean = rawText.trim();
      if (clean.startsWith('```json')) clean = clean.substring(7);
      if (clean.startsWith('```')) clean = clean.substring(3);
      if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
      clean = clean.trim();

      final map = jsonDecode(clean) as Map<String, dynamic>;
      final isValid = map['is_valid_type'] == true;
      final detected = map['document_detected']?.toString() ?? 'Document';
      final score =
          double.tryParse(map['confidence_score']?.toString() ?? '') ??
          (isValid ? 0.85 : 0.20);
      final reason = map['rejection_reason']?.toString() ?? '';
      final rawFlags = map['flags'];
      List<String> flags = [];
      if (rawFlags is List) {
        flags = rawFlags
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return DocumentValidationResult(
        isValidType: isValid,
        documentDetected: detected,
        confidenceScore: score.clamp(0.0, 1.0),
        rejectionReason: reason,
        flags: flags,
        modelUsed: modelName,
      );
    } catch (e) {
      debugPrint('Failed to parse AI JSON response: $e\nRaw: $rawText');
      return null;
    }
  }

  static Future<Uint8List?> _prepareImage(
    Uint8List bytes, {
    int maxDim = 1200,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      final longest = w > h ? w : h;
      if (longest <= maxDim) return bytes;

      final scale = maxDim / longest;
      final targetW = (w * scale).round();
      final targetH = (h * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final resized = await picture.toImage(targetW, targetH);
      final data = await resized.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      return bytes;
    }
  }

  static List<Uint8List> _extractJpegsFromPdf(Uint8List bytes) {
    final list = <Uint8List>[];
    try {
      final len = bytes.length;
      for (int i = 0; i < len - 3; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
          int end = -1;
          for (int j = i; j < len - 1; j++) {
            if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
              end = j + 2;
              break;
            }
          }
          if (end != -1 && (end - i) > 5000) {
            list.add(bytes.sublist(i, end));
            i = end - 1;
          }
        }
      }
    } catch (_) {}
    return list;
  }
}
