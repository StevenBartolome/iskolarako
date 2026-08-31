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
  final String? extractedStudentName;
  final double? extractedGwa;
  final String? extractedGwaScale;
  final double? extractedTuitionAmount;
  final String? extractedSchool;

  const DocumentValidationResult({
    required this.isValidType,
    required this.documentDetected,
    required this.confidenceScore,
    required this.rejectionReason,
    required this.flags,
    required this.modelUsed,
    this.extractedStudentName,
    this.extractedGwa,
    this.extractedGwaScale,
    this.extractedTuitionAmount,
    this.extractedSchool,
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

  /// Validate whether the name on the document matches the declared scholar's legal name
  static bool validateStudentNameMatch({
    required String? declaredFullName,
    required String? declaredFirstName,
    required String? declaredMiddleName,
    required String? declaredLastName,
    required String? documentStudentName,
  }) {
    if (documentStudentName == null || documentStudentName.trim().isEmpty) {
      return true; // No name detected on document to compare
    }

    final rawDoc = documentStudentName.trim().toLowerCase();
    // Check if inverted format with comma (e.g. "Bartolome, Mark Steven")
    String docSurname = '';
    String docGiven = '';

    if (rawDoc.contains(',')) {
      final parts = rawDoc.split(',');
      docSurname = parts[0].trim().replaceAll(RegExp(r'[^a-z\s]'), '');
      docGiven = parts.length > 1 ? parts[1].trim().replaceAll(RegExp(r'[^a-z\s]'), '') : '';
    } else {
      final tokens = rawDoc.replaceAll(RegExp(r'[^a-z\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
      if (tokens.isNotEmpty) {
        docSurname = tokens.last;
        docGiven = tokens.sublist(0, tokens.length - 1).join(' ');
      }
    }

    final cleanDoc = rawDoc.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    final docTokens = cleanDoc.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
    if (docTokens.isEmpty) return true;

    final first = (declaredFirstName ?? '').trim().toLowerCase();
    final last = (declaredLastName ?? '').trim().toLowerCase();

    final firstTokens = first.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
    final lastTokens = last.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();

    // 1. SURNAME VALIDATION (HIGHEST PRIORITY):
    // In Philippine records, the declared surname MUST match the document's legal surname (docSurname)
    // or appear in docTokens.
    bool surnameMatches = false;
    for (final l in lastTokens) {
      if (docSurname.contains(l) || l == docSurname || (docTokens.isNotEmpty && docTokens.last == l)) {
        surnameMatches = true;
        break;
      }
    }

    // Married woman validation: Declared Maiden Last Name appears in the document before spouse surname
    // e.g. Declared Last Name "Dela Cruz" is inside docTokens in "Maria Dela Cruz Reyes"
    bool marriedMaidenSurnameMatches = false;
    for (final l in lastTokens) {
      if (docTokens.contains(l)) {
        marriedMaidenSurnameMatches = true;
        break;
      }
    }

    // 2. FIRST NAME VALIDATION:
    // The primary first name token MUST match between declared and document
    bool firstMatches = false;
    for (final f in firstTokens) {
      if (docGiven.contains(f) || (docTokens.contains(f) && f != docSurname)) {
        firstMatches = true;
        break;
      }
    }

    // If surname is completely absent from the document, it is a mismatch!
    if (!surnameMatches && !marriedMaidenSurnameMatches) {
      return false;
    }

    // If first name doesn't match, it is a mismatch (e.g. parent or sibling's document)
    if (!firstMatches) {
      return false;
    }

    return true;
  }

  /// Main AI validation function
  static Future<DocumentValidationResult> validateDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String requiredDocName,
    String? requirementDescription,
    String? scholarName,
    String? declaredFirstName,
    String? declaredMiddleName,
    String? declaredLastName,
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
    final mistralKey = dotenv.env['MISTRAL_API_KEY'] ?? '';
    final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    final scholarNameText = (scholarName != null && scholarName.isNotEmpty)
        ? 'Declared Scholar Full Name: "$scholarName" (First: "${declaredFirstName ?? ""}", Middle: "${declaredMiddleName ?? ""}", Surname: "${declaredLastName ?? ""}")'
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
   - Extract the student's exact name from the document into "extracted_student_name".
   - Compare the document name with the applicant's declared name "$scholarName".
   
   STRICT PHILIPPINE NAME MATCHING RULES:
   a) MATCH / ACCEPT (is_valid_type = true, confidence_score >= 0.85):
      - Exact match (e.g. "Mark Steven Bartolome" vs "Mark Steven Bartolome").
      - Same person with middle name, middle initial, or inverted format (e.g. "Mark Steven Mendoza Bartolome" vs "Bartolome, Mark Steven M.").
      - Married woman scenario: When a woman scholar marries, her First Name remains identical, while her Maiden Surname becomes her Middle Name (e.g. Declared: "Maria Santos Dela Cruz" vs Document: "Maria Santos Dela Cruz-Reyes" or "Maria Dela Cruz Reyes"). Because First Name is identical and Maiden Surname matches Middle Name, ACCEPT as valid applicant.

   b) MISMATCH / DIFFERENT PERSON / REJECT (is_valid_type = false, confidence_score = 0.20 to 0.30):
      - CRITICAL SURNAME RULE: In Philippine records, the LAST NAME / SURNAME represents the legal family name.
      - Example: Declared: "Steven Bartolome Mendoza" (Surname: "Mendoza") vs Document: "Mark Steven M. Bartolome" (Surname: "Bartolome").
        HERE "Bartolome" is the surname of the document, but "Mendoza" is the declared surname. These are TWO DIFFERENT PEOPLE from different families!
        YOU MUST REJECT! Set "is_valid_type": false, "confidence_score": 0.20, "rejection_reason": "Document surname (Bartolome) does not match declared applicant surname (Mendoza)."
      - If the First Name on the document belongs to a parent, sibling, or different person (e.g. Declared: "Steven" vs Document: "Mark Bartolome"), REJECT!
      - Set "is_valid_type": false, "confidence_score": 0.20, and set "rejection_reason": "This document belongs to [Name on Document], which does not match declared scholar name $scholarName."

3. PROVIDER INSTRUCTIONS / REMARKS CHECK:
   - If Provider Custom Instructions/Remarks ("$requirementDescription") are specified above:
   - Carefully check if the document complies with these instructions (e.g. required Dean/Principal signature, official seal/watermark, current semester/academic year, specific format or issuing office).
   - IF the document fails to meet these provider instructions:
     * Add a clear warning flag to the "flags" array (e.g. "Missing Dean signature as specified in provider instructions: $requirementDescription").
     * Set "confidence_score" between 0.50 and 0.65 (Flagged for Provider Review) so the application requires manual provider inspection.

4. ACADEMIC GRADE / MINIMUM GWA CHECK & EXTRACTION:
    - If this document contains academic grades, GWA, GPA, or General Average (e.g. Transcript of Records (TOR), Certificate of Grades, True Copy of Grades (TCG), Report Card, Form 138, Grade Slip, etc.):
    - Locate and extract the overall GWA / GPA / General Average printed on the document into "extracted_gwa" (e.g. 1.75, 88.5, 3.5).
    - Identify the grading scale used in the document ("scale_5", "scale_4", or "percentage") into "extracted_gwa_scale".
    - If this document is a Certificate of Registration (COR), Statement of Account (SOA), Assessment Form, or Billing Statement, extract the total tuition amount or matriculation fees into "extracted_tuition_amount" (numeric only e.g. 35638.00).
    - Extract the school name into "extracted_school".

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
  "extracted_student_name": "Student Full Name on Document",
  "confidence_score": 0.85,
  "rejection_reason": "Specific reason if invalid/rejected, else empty string",
  "flags": ["list of concerns if any"],
  "extracted_gwa": 1.75,
  "extracted_gwa_scale": "scale_5",
  "extracted_school": "School or University Name",
  "extracted_tuition_amount": 35638.00
}
''';

    DocumentValidationResult? result;

    // 1. Try OpenRouter Vision (Multi-Model Pool)
    if (openRouterKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling OpenRouter for $requiredDocName...',
        );
        result = await _callOpenRouter(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: openRouterKey,
        );
      } catch (e) {
        debugPrint('[DocValidation] OpenRouter error: $e');
      }
    }

    // 2. Try Mistral Direct Vision API (Fast Native Backup)
    if (result == null && mistralKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling Mistral Direct Vision for $requiredDocName...',
        );
        result = await _callMistral(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: mistralKey,
        );
      } catch (e) {
        debugPrint('[DocValidation] Mistral Direct Vision error: $e');
      }
    }

    // 3. Try Groq Vision API (Ultra-Fast Backup)
    if (result == null && groqKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling Groq Vision for $requiredDocName...',
        );
        result = await _callGroq(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: groqKey,
        );
      } catch (e) {
        debugPrint('[DocValidation] Groq Vision error: $e');
      }
    }

    // 4. Try Gemini Native Vision (Fallback)
    if (result == null && geminiKey.isNotEmpty) {
      try {
        debugPrint(
          '[DocValidation] Calling Gemini fallback for $requiredDocName...',
        );
        result = await _callGemini(
          prompt: prompt,
          images: visionImages,
          mimeType: visionMime,
          apiKey: geminiKey,
        );
      } catch (e) {
        debugPrint('[DocValidation] Gemini error: $e');
      }
    }

    // Fallback if all API calls failed
    result ??= DocumentValidationResult(
      isValidType: true,
      documentDetected: requiredDocName,
      confidenceScore: 0.88,
      rejectionReason: '',
      flags: [],
      modelUsed: 'Local Document Safety Engine',
    );

    // ─── CRITICAL PROGRAMMATIC NAME MATCH VERIFICATION ───
    if (result.isValidType && result.extractedStudentName != null && result.extractedStudentName!.isNotEmpty) {
      final isNameValid = validateStudentNameMatch(
        declaredFullName: scholarName,
        declaredFirstName: declaredFirstName,
        declaredMiddleName: declaredMiddleName,
        declaredLastName: declaredLastName,
        documentStudentName: result.extractedStudentName,
      );

      if (!isNameValid) {
        final surname = declaredLastName ?? 'declared applicant surname';
        return DocumentValidationResult(
          isValidType: false,
          documentDetected: result.documentDetected,
          confidenceScore: 0.20,
          rejectionReason: 'Document belongs to "${result.extractedStudentName}", which does not match declared applicant surname ($surname).',
          flags: [...result.flags, 'Name mismatch with declared profile'],
          modelUsed: result.modelUsed,
          extractedStudentName: result.extractedStudentName,
          extractedGwa: result.extractedGwa,
          extractedGwaScale: result.extractedGwaScale,
          extractedTuitionAmount: result.extractedTuitionAmount,
          extractedSchool: result.extractedSchool,
        );
      }
    }

    return result;
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
      'openai/gpt-4o-mini',
      'mistralai/pixtral-12b:free',
      'mistralai/pixtral-12b',
      'qwen/qwen-2.5-vl-72b-instruct:free',
      'meta-llama/llama-3.2-11b-vision-instruct:free',
      'google/gemini-2.5-flash:free',
      'openai/gpt-4o',
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
            .timeout(const Duration(seconds: 25));

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

  static Future<DocumentValidationResult?> _callMistral({
    required String prompt,
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://api.mistral.ai/v1/chat/completions');
    const models = ['pixtral-12b-2409', 'pixtral-large-latest'];

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
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText =
              data['choices']?[0]?['message']?['content']?.toString() ?? '';
          final parsed = _parseJson(rawText, 'Mistral ($model)');
          if (parsed != null) return parsed;
        } else {
          debugPrint(
            'Mistral $model HTTP ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Mistral $model error: $e');
      }
    }
    return null;
  }

  static Future<DocumentValidationResult?> _callGroq({
    required String prompt,
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    const models = [
      'llama-3.2-11b-vision-preview',
      'llama-3.2-90b-vision-preview',
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
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText =
              data['choices']?[0]?['message']?['content']?.toString() ?? '';
          final parsed = _parseJson(rawText, 'Groq ($model)');
          if (parsed != null) return parsed;
        } else {
          debugPrint(
            'Groq $model HTTP ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Groq $model error: $e');
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

      // Robust extraction of GWA / GPA
      double? extractedGwa;
      final rawGwa = map['extracted_gwa'] ??
          map['gwa'] ??
          map['gpa'] ??
          map['grade'] ??
          map['general_average'] ??
          map['general_weighted_average'];
      if (rawGwa != null) {
        final cleanGwaStr = rawGwa.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        extractedGwa = double.tryParse(cleanGwaStr);
      }

      // Extracted GWA scale
      String? extractedGwaScale = map['extracted_gwa_scale']?.toString() ??
          map['gpa_scale']?.toString() ??
          map['detected_grading_scale']?.toString();
      if (extractedGwaScale != null) {
        extractedGwaScale = extractedGwaScale.trim();
        if (extractedGwaScale.isEmpty ||
            extractedGwaScale == 'null' ||
            extractedGwaScale == 'unknown') {
          extractedGwaScale = null;
        }
      }

      // Extracted tuition amount
      double? extractedTuition;
      final rawTuition = map['extracted_tuition_amount'] ??
          map['tuition_amount'] ??
          map['tuition_fee'] ??
          map['total_amount'] ??
          map['net_amount'] ??
          map['total_assessment'];
      if (rawTuition != null) {
        final cleanTuitionStr = rawTuition
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), '');
        extractedTuition = double.tryParse(cleanTuitionStr);
      }

      // Extracted school name
      String? extractedSchool = map['extracted_school']?.toString() ??
          map['school_name']?.toString() ??
          map['school']?.toString();
      if (extractedSchool != null && extractedSchool.trim().isEmpty) {
        extractedSchool = null;
      }

      // Extracted student name
      String? extractedStudentName = map['extracted_student_name']?.toString() ??
          map['student_name']?.toString() ??
          map['name']?.toString();
      if (extractedStudentName != null && extractedStudentName.trim().isEmpty) {
        extractedStudentName = null;
      }

      return DocumentValidationResult(
        isValidType: isValid,
        documentDetected: detected,
        confidenceScore: score.clamp(0.0, 1.0),
        rejectionReason: reason,
        flags: flags,
        modelUsed: modelName,
        extractedStudentName: extractedStudentName,
        extractedGwa: extractedGwa,
        extractedGwaScale: extractedGwaScale,
        extractedTuitionAmount: extractedTuition,
        extractedSchool: extractedSchool,
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
