import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ExtractedBankInfo {
  final String bankName;
  final String accountName;
  final String accountNumber;
  final double confidenceScore;
  final String aiModelUsed;

  const ExtractedBankInfo({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.confidenceScore = 0.95,
    this.aiModelUsed = 'AI OCR',
  });
}

class AiExtractionService {
  static const String _systemPrompt = '''
You are a specialized Philippine banking document OCR and data extraction assistant.
Extract banking details from the provided bank card / ATM card / bank certificate / deposit slip image or PDF page.
Carefully read the printed or embossed actual bank account number (typically 10-12 digits) and the account holder name, even if the document is
slightly blurry, skewed, low-resolution, or has glare. Transcribe the FULL account number digit by digit.
CRITICAL: Do NOT extract the 16-digit ATM/Debit/Credit card number (often printed/embossed across the middle of the card, grouped in 4s).
If only a 16-digit card number is visible, do not extract it; return empty string for "account_number" instead.
If you can confidently identify some fields but not others, return what you found with an empty string for unknown fields.
Return ONLY valid, raw JSON without markdown backticks or commentary in this exact format:
{
  "bank_name": "Exact Bank Name (e.g. Landbank of the Philippines, BDO, BPI, UnionBank, SeaBank, Metrobank, etc.)",
  "account_holder_name": "Full Name of Account Holder / Scholar as printed on the card",
  "account_number": "Account number as digits only (no dashes, spaces, or letters). Do NOT use 16-digit card numbers here.",
  "confidence_score": 0.95
}
If the document truly contains no banking information at all, return exactly:
{"bank_name":"","account_holder_name":"","account_number":"","confidence_score":0}
''';

  /// Main extraction entry point
  static Future<ExtractedBankInfo?> extractBankDetails({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
  }) async {
    Uint8List actualBytes = fileBytes;
    if (actualBytes.isEmpty && filePath != null && filePath.isNotEmpty) {
      try {
        actualBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading file from path: $e');
      }
    }

    if (actualBytes.isEmpty) {
      debugPrint('Error: Document bytes are completely empty');
      return null;
    }

    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isPng = fileName.toLowerCase().endsWith('.png');
    final mimeType = isPdf ? 'application/pdf' : (isPng ? 'image/png' : 'image/jpeg');

    final mistralKey = dotenv.env['MISTRAL_API_KEY'] ?? '';
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final openRouterKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';

    // Build the best payload for vision models:
    //  - For scanned PDFs with an embedded JPEG, extract and preprocess that image.
    //  - For images, downscale so they fit the model's image-token budget
    //    (huge photos are otherwise truncated/blurred, causing "no data found").
    //  - If a PDF has no embedded JPEG we can pull out, keep the native PDF
    //    payload so Gemini-based models can OCR it directly.
    List<Uint8List> visionImages = [];
    String visionMime = mimeType;

    if (isPdf) {
      final embeddedJpegs = _extractJpegsFromPdf(actualBytes);
      if (embeddedJpegs.isNotEmpty) {
        for (final img in embeddedJpegs) {
          final prepped = await _prepareImageForOcr(img);
          if (prepped != null) {
            visionImages.add(prepped);
          }
        }
        visionMime = 'image/jpeg';
        debugPrint('Found ${visionImages.length} embedded images in PDF, prepared for vision models.');
      } else {
        debugPrint('No embedded JPEG found; keeping native PDF payload (${actualBytes.length} bytes)');
        visionImages.add(actualBytes);
      }
    } else {
      final prepped = await _prepareImageForOcr(actualBytes);
      visionImages.add(prepped ?? actualBytes);
    }

    // 1. Google Gemini (native PDF + vision). Model name auto-falls back
    //    because Google retires older model versions over time.
    if (geminiKey.isNotEmpty) {
      try {
        debugPrint('Attempting extraction with Gemini...');
        final res = await _extractWithGemini(
          images: visionImages,
          mimeType: visionMime,
          apiKey: geminiKey,
        );
        if (res != null && res.confidenceScore > 0.1 && res.accountNumber.isNotEmpty) {
          return res;
        }
      } catch (e) {
        debugPrint('Gemini extraction error: $e');
      }
    }

    // 2. OpenRouter Vision (multi-model fallback)
    if (openRouterKey.isNotEmpty) {
      try {
        debugPrint('Attempting extraction with OpenRouter...');
        final res = await _extractWithOpenRouter(
          images: visionImages,
          mimeType: visionMime,
          apiKey: openRouterKey,
        );
        if (res != null && res.confidenceScore > 0.1 && res.accountNumber.isNotEmpty) {
          return res;
        }
      } catch (e) {
        debugPrint('OpenRouter extraction error: $e');
      }
    }

    // 3. Mistral OCR (dedicated document OCR engine). It returns raw text,
    //    which we structure into fields with Groq (or a local parser).
    if (mistralKey.isNotEmpty) {
      try {
        debugPrint('Attempting extraction with Mistral OCR...');
        final ocrText = await _extractWithMistralOcr(
          bytes: visionImages.first,
          mimeType: visionMime,
          apiKey: mistralKey,
        );
        if (ocrText != null && ocrText.trim().length > 5) {
          if (groqKey.isNotEmpty) {
            final structured = await _extractWithGroqText(textOnly: ocrText, apiKey: groqKey);
            if (structured != null && structured.accountNumber.isNotEmpty) {
              return structured;
            }
          }
          final parsed = _parseOcrText(ocrText);
          if (parsed != null && parsed.accountNumber.isNotEmpty) {
            return parsed;
          }
        }
      } catch (e) {
        debugPrint('Mistral OCR extraction error: $e');
      }
    }

    // 4. Try Text Extraction from PDF with Groq (text-based PDFs)
    if (isPdf && groqKey.isNotEmpty) {
      final text = _extractTextFromPdf(actualBytes);
      if (text != null && text.length > 10) {
        try {
          debugPrint('Attempting extraction with Groq text...');
          final res = await _extractWithGroqText(textOnly: text, apiKey: groqKey);
          if (res != null && res.accountNumber.isNotEmpty) {
            return res;
          }
        } catch (e) {
          debugPrint('Groq extraction error: $e');
        }
      }
    }

    return null;
  }

  /// Decodes an image and downscales it to fit inside the model's
  /// image-token budget. Huge phone photos are otherwise truncated or
  /// downsampled so aggressively by the API that text becomes unreadable.
  static Future<Uint8List?> _prepareImageForOcr(Uint8List bytes, {int maxDim = 1400}) async {
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
      debugPrint('Image prep exception: $e');
      return bytes;
    }
  }

  /// Extracts all embedded JPEG streams from a scanned PDF.
  /// PDFs often embed a photo for each scanned page. We return all JPEG blocks
  /// found in order (Page 1 front, Page 2 back, etc.).
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
          if (end != -1 && (end - i) > 5000) { // minimum 5KB for real page images
            list.add(bytes.sublist(i, end));
            i = end - 1;
          }
        }
      }
    } catch (e) {
      debugPrint('PDF JPEG extract exception: $e');
    }
    return list;
  }

  /// Extracts visible text from PDF streams
  static String? _extractTextFromPdf(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes, allowInvalid: true);
      final buffer = StringBuffer();
      final regExp = RegExp(r'\(([^)]+)\)\s*Tj|\[([^\]]+)\]\s*TJ', multiLine: true);
      final matches = regExp.allMatches(raw);

      for (final match in matches) {
        final str = match.group(1) ?? match.group(2) ?? '';
        if (str.isNotEmpty) {
          buffer.write('$str ');
        }
      }

      final res = buffer.toString().trim();
      return res.isNotEmpty ? res : null;
    } catch (e) {
      debugPrint('PDF Text extract exception: $e');
      return null;
    }
  }

  static const List<String> _knownBanks = [
    'Landbank of the Philippines',
    'BDO Unibank',
    'BPI',
    'UnionBank',
    'Metrobank',
    'SeaBank',
    'RCBC',
    'Security Bank',
    'Philippine National Bank',
    'PNB',
    'Development Bank of the Philippines',
    'DBP',
    'Maya Bank',
    'GoTyme',
    'GCash',
  ];

  /// Mistral dedicated OCR endpoint (returns raw text, not chat JSON).
  /// Mistral retired their Pixtral vision chat models, but `mistral-ocr-*`
  /// reads documents extremely well (including embossed card numbers).
  static Future<String?> _extractWithMistralOcr({
    required Uint8List bytes,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://api.mistral.ai/v1/ocr');
    final base64Data = base64Encode(bytes);

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'mistral-ocr-latest',
            'document': {
              'type': 'document_url',
              'document_url': 'data:$mimeType;base64,$base64Data',
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final pages = data['pages'];
      if (pages is List && pages.isNotEmpty) {
        final md = pages[0]['markdown']?.toString() ?? pages[0]['text']?.toString() ?? '';
        debugPrint('Mistral OCR text: $md');
        return md.isNotEmpty ? md : null;
      }
    } else {
      debugPrint('Mistral OCR HTTP ${response.statusCode}: ${response.body}');
    }
    return null;
  }

  /// Local fallback: pull structured fields straight out of OCR text.
  static ExtractedBankInfo? _parseOcrText(String text) {
    if (text.trim().isEmpty) return null;

    String bank = '';
    final lower = text.toLowerCase();
    if (lower.contains('unionbank') || lower.contains('union bank') || lower.contains('ubp')) {
      bank = 'UnionBank of the Philippines';
    } else if (lower.contains('landbank') || lower.contains('land bank') || lower.contains('lbp')) {
      bank = 'Landbank of the Philippines';
    } else if (lower.contains('bdo') || lower.contains('bancodeoro') || lower.contains('unibank')) {
      bank = 'BDO Unibank';
    } else if (lower.contains('bpi') || lower.contains('philippine islands')) {
      bank = 'BPI (Bank of the Philippine Islands)';
    } else if (lower.contains('gcash')) {
      bank = 'GCash / GCash Card';
    } else if (lower.contains('maya')) {
      bank = 'Maya Bank';
    } else if (lower.contains('seabank')) {
      bank = 'SeaBank Philippines';
    } else if (lower.contains('metrobank')) {
      bank = 'Metrobank';
    }

    if (bank.isEmpty) {
      for (final b in _knownBanks) {
        if (lower.contains(b.toLowerCase())) {
          bank = b;
          break;
        }
      }
    }
    if (bank.isEmpty) bank = 'Landbank of the Philippines';

    String number = '';
    for (final match in RegExp(r'\d[\d ]{5,18}\d').allMatches(text)) {
      final clean = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length == 16) continue; // Skip 16-digit card numbers
      if (clean.length >= 6 && clean.length <= 19 && clean.length > number.length) {
        number = clean;
      }
    }
    if (number.isEmpty) return null;

    String name = '';
    for (final line in text.split('\n')) {
      final t = line.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (t.isEmpty) continue;
      final l = t.toLowerCase();
      if (l.contains('account') ||
          l.contains('number') ||
          l.contains('card') ||
          l.contains('valid') ||
          l.contains('thru') ||
          l.contains('expir') ||
          l.contains('bank') ||
          l.contains('holder') ||
          l.contains('name') ||
          l.contains('authorized') ||
          l.contains('signature') ||
          l.contains('non-transferable') ||
          l.contains('property of')) {
        continue;
      }
      if (RegExp(r'[A-Za-z]{2,}').hasMatch(t) && !RegExp(r'\d').hasMatch(t)) {
        if (t.length > name.length) name = t;
      }
    }

    return ExtractedBankInfo(
      bankName: bank,
      accountName: name,
      accountNumber: number,
      confidenceScore: 0.9,
      aiModelUsed: 'Mistral OCR',
    );
  }

  /// Google Gemini (native PDF & Vision support).
  /// Google retires model versions over time, so we try the newest first and
  /// fall back through older ones until one answers successfully.
  static Future<ExtractedBankInfo?> _extractWithGemini({
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-flash'];

    for (final model in models) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final parts = <Map<String, dynamic>>[
          {'text': _systemPrompt},
        ];

        for (final img in images) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType,
              'data': base64Encode(img),
            },
          });
        }

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': parts,
                  },
                ],
                'generationConfig': {
                  'response_mime_type': 'application/json',
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
          final parsed = _parseJsonResponse(rawText, 'Gemini $model');
          if (parsed != null && parsed.accountNumber.isNotEmpty) return parsed;
        } else {
          debugPrint('Gemini $model HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Gemini $model error: $e');
      }
    }
    return null;
  }

  /// OpenRouter Vision
  static Future<ExtractedBankInfo?> _extractWithOpenRouter({
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    const models = [
      'google/gemini-2.5-pro',
      'openai/gpt-4o',
      'anthropic/claude-3.5-sonnet',
      'qwen/qwen-2.5-vl-72b-instruct',
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
      'google/gemini-2.5-flash:free',
      'meta-llama/llama-3.2-11b-vision-instruct:free',
    ];

    for (final model in models) {
      try {
        final contentList = <Map<String, dynamic>>[
          {'type': 'text', 'text': _systemPrompt},
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
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://iskoako.app',
                'X-Title': 'IskoAko Scholarship App',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'user',
                    'content': contentList,
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['choices']?[0]?['message']?['content']?.toString() ?? '';
          final parsed = _parseJsonResponse(rawText, model);
          if (parsed != null && parsed.confidenceScore > 0.1) return parsed;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Groq Text LLM
  static Future<ExtractedBankInfo?> _extractWithGroqText({
    required String textOnly,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'llama-3.3-70b-versatile',
            'messages': [
              {'role': 'user', 'content': '$_systemPrompt\n\nDocument Text:\n$textOnly'},
            ],
            'temperature': 0.1,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawText = data['choices']?[0]?['message']?['content']?.toString() ?? '';
      return _parseJsonResponse(rawText, 'Groq Llama 3.3');
    }
    return null;
  }

  /// Parses JSON output from LLMs
  static ExtractedBankInfo? _parseJsonResponse(String raw, String modelName) {
    try {
      debugPrint('AI Raw OCR Output ($modelName): $raw');
      String cleaned = raw.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.replaceFirst('```json', '').replaceFirst(RegExp(r'```$'), '').trim();
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst('```', '').replaceFirst(RegExp(r'```$'), '').trim();
      }

      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final Map<String, dynamic> data = jsonDecode(cleaned);

      // Check if AI explicitly returned an error or insufficient data
      if (data.containsKey('error') && !data.containsKey('account_number')) {
        return null;
      }

      final bank = data['bank_name']?.toString() ??
          data['bank']?.toString() ??
          data['bankName']?.toString() ??
          'Landbank of the Philippines';

      final accName = data['account_holder_name']?.toString() ??
          data['account_name']?.toString() ??
          data['account_holder']?.toString() ??
          data['name']?.toString() ??
          '';

      String accNum = (data['account_number'] ??
              data['account_no'] ??
              data['account_num'] ??
              data['accountNumber'] ??
              data['number'] ??
              '')
          .toString();

      // Scan all keys if not standard
      if (accNum.isEmpty || accNum.replaceAll(RegExp(r'[^0-9]'), '').length < 6 || accNum.replaceAll(RegExp(r'[^0-9]'), '').length == 16) {
        for (final entry in data.entries) {
          final k = entry.key.toLowerCase();
          final v = entry.value?.toString() ?? '';
          final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
          if ((k.contains('num') || k.contains('acc') || k.contains('bank')) &&
              digitsOnly.length >= 6 &&
              digitsOnly.length != 16) {
            accNum = digitsOnly;
            break;
          }
        }
      }

      // Scan raw text with regex
      if (accNum.isEmpty || accNum.replaceAll(RegExp(r'[^0-9]'), '').length < 6 || accNum.replaceAll(RegExp(r'[^0-9]'), '').length == 16) {
        String best = '';
        for (final match in RegExp(r'\d[0-9 ]{5,}\d').allMatches(raw)) {
          final clean = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
          if (clean.length == 16) continue; // Skip 16-digit card numbers
          if (clean.length >= 6 && clean.length <= 19 && clean.length > best.length) {
            best = clean;
          }
        }
        if (best.isNotEmpty) accNum = best;
      }

      final conf = double.tryParse(data['confidence_score']?.toString() ?? '0.95') ?? 0.95;

      final finalAccNum = accNum.replaceAll(RegExp(r'[^0-9]'), '');
      return ExtractedBankInfo(
        bankName: bank,
        accountName: accName,
        accountNumber: finalAccNum.length == 16 ? '' : finalAccNum,
        confidenceScore: conf,
        aiModelUsed: modelName,
      );
    } catch (e) {
      debugPrint('JSON parse error in AI extraction: $e');
      return null;
    }
  }

  static const String _academicPrompt = '''
You are a specialized Philippine academic document auditor, tuition fee extraction assistant, and OCR parser.
Extract details from the provided Transcript of Records (TOR), Report Card, True Copy of Grades, Certificate of Registration (COR), Statement of Account (SOA), Assessment Form, or Billing Statement.

Your tasks are:
1. Extract the overall GWA / GPA / General Average of the student if printed on the document (return null if no grade is printed on this document).
2. Determine the grading scale used by the school ("scale_5", "scale_4", or "percentage").
3. Identify the school name if visible.
4. If this document is a Certificate of Registration (COR), Statement of Account (SOA), Assessment Form, Billing Statement, or Enrollment Receipt, extract the total tuition amount or total matriculation fees (look for labels like "Total Assessment", "Total Tuition", "Gross Assessment", "Total Fees", "Net Payable", "Amount Due", "Amount Payable", "Tuition Fee", "Total Assessment Amount", "Assessment Balance").

Return ONLY valid, raw JSON without markdown backticks or commentary in this exact format:
{
  "gpa": 1.75,
  "gpa_scale": "scale_5",
  "school_name": "University of the Philippines",
  "extracted_tuition_amount": 24500.00,
  "confidence_score": 0.95
}
If a field is not present on the document, return null for that field. If neither grade nor tuition amount is found, return confidence_score of 0.3.
''';

  static Future<ExtractedAcademicInfo?> extractAcademicDetails({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    String? expectedScale,
  }) async {
    Uint8List actualBytes = fileBytes;
    if (actualBytes.isEmpty && filePath != null && filePath.isNotEmpty) {
      try {
        actualBytes = await File(filePath).readAsBytes();
      } catch (e) {
        debugPrint('Error reading file from path: $e');
      }
    }

    if (actualBytes.isEmpty) {
      debugPrint('Error: Document bytes are completely empty');
      return null;
    }

    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isPng = fileName.toLowerCase().endsWith('.png');
    final mimeType = isPdf ? 'application/pdf' : (isPng ? 'image/png' : 'image/jpeg');

    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final openRouterKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';

    List<Uint8List> visionImages = [];
    String visionMime = mimeType;

    if (isPdf) {
      final embeddedJpegs = _extractJpegsFromPdf(actualBytes);
      if (embeddedJpegs.isNotEmpty) {
        for (final img in embeddedJpegs) {
          final prepped = await _prepareImageForOcr(img);
          if (prepped != null) visionImages.add(prepped);
        }
        visionMime = 'image/jpeg';
      } else {
        visionImages.add(actualBytes);
      }
    } else {
      final prepped = await _prepareImageForOcr(actualBytes);
      visionImages.add(prepped ?? actualBytes);
    }

    if (visionImages.isEmpty) return null;

    final customPrompt = _academicPrompt + (expectedScale != null
        ? '\nADDITIONAL CONTEXT: The student\'s expected grading scale format is "$expectedScale". Please prioritize matching and extracting grades according to this scale format if applicable.'
        : '');

    if (geminiKey.isNotEmpty) {
      final result = await _extractAcademicWithGemini(
        images: visionImages,
        mimeType: visionMime,
        apiKey: geminiKey,
        prompt: customPrompt,
        expectedScale: expectedScale,
      );
      if (result != null && result.gpa != null) return result;
    }

    if (openRouterKey.isNotEmpty) {
      final result = await _extractAcademicWithOpenRouter(
        images: visionImages,
        mimeType: visionMime,
        apiKey: openRouterKey,
        prompt: customPrompt,
        expectedScale: expectedScale,
      );
      if (result != null && result.gpa != null) return result;
    }

    return null;
  }

  static Future<ExtractedAcademicInfo?> _extractAcademicWithGemini({
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
    required String prompt,
    String? expectedScale,
  }) async {
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-flash'];

    for (final model in models) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final parts = <Map<String, dynamic>>[
          {'text': prompt},
        ];

        for (final img in images) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType,
              'data': base64Encode(img),
            },
          });
        }

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': parts,
                  },
                ],
                'generationConfig': {
                  'response_mime_type': 'application/json',
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
          final parsed = _parseAcademicJsonResponse(rawText, 'Gemini $model', expectedScale);
          if (parsed != null && parsed.gpa != null) return parsed;
        }
      } catch (e) {
        debugPrint('Gemini $model academic error: $e');
      }
    }
    return null;
  }

  static Future<ExtractedAcademicInfo?> _extractAcademicWithOpenRouter({
    required List<Uint8List> images,
    required String mimeType,
    required String apiKey,
    required String prompt,
    String? expectedScale,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    const models = [
      'google/gemini-2.5-pro',
      'openai/gpt-4o',
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
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
                'HTTP-Referer': 'https://iskoako.app',
                'X-Title': 'IskoAko',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'user', 'content': contentList}
                ],
                'response_format': {'type': 'json_object'},
                'temperature': 0.1,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawText = data['choices']?[0]?['message']?['content']?.toString() ?? '';
          final parsed = _parseAcademicJsonResponse(rawText, 'OpenRouter $model', expectedScale);
          if (parsed != null && parsed.gpa != null) return parsed;
        }
      } catch (e) {
        debugPrint('OpenRouter $model academic error: $e');
      }
    }
    return null;
  }

  static ExtractedAcademicInfo? _parseAcademicJsonResponse(String raw, String modelName, [String? expectedScale]) {
    try {
      String clean = raw.trim();
      if (clean.startsWith('```')) {
        final start = clean.indexOf('{');
        final end = clean.lastIndexOf('}');
        if (start != -1 && end != -1) {
          clean = clean.substring(start, end + 1);
        }
      }
      final data = jsonDecode(clean);
      final gpaVal = double.tryParse(data['gpa']?.toString() ?? '');
      final rawScaleFromAi = data['gpa_scale']?.toString();
      final scale = (expectedScale != null && expectedScale.isNotEmpty && expectedScale != 'unknown')
          ? expectedScale
          : (rawScaleFromAi ?? 'scale_5');
      final school = data['school_name']?.toString() ?? '';
      final tuitionVal = double.tryParse(
        data['extracted_tuition_amount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? ''
      );
      final conf = double.tryParse(data['confidence_score']?.toString() ?? '0.95') ?? 0.95;

      return ExtractedAcademicInfo(
        gpa: gpaVal,
        gpaScale: scale,
        schoolName: school,
        extractedTuitionAmount: tuitionVal,
        confidenceScore: conf,
        aiModelUsed: modelName,
      );
    } catch (e) {
      debugPrint('JSON parse error in AI academic extraction: $e');
      return null;
    }
  }
}

class ExtractedAcademicInfo {
  final double? gpa;
  final String? gpaScale;
  final String? schoolName;
  final double? extractedTuitionAmount;
  final double confidenceScore;
  final String aiModelUsed;

  const ExtractedAcademicInfo({
    required this.gpa,
    required this.gpaScale,
    this.schoolName,
    this.extractedTuitionAmount,
    this.confidenceScore = 0.95,
    this.aiModelUsed = 'AI OCR',
  });
}
