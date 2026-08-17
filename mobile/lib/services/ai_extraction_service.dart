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
Carefully read the printed or embossed account/card number and the account holder name, even if the document is
slightly blurry, skewed, low-resolution, or has glare. Transcribe the FULL account/card number digit by digit.
If you can confidently identify some fields but not others, return what you found with an empty string for unknown fields.
Return ONLY valid, raw JSON without markdown backticks or commentary in this exact format:
{
  "bank_name": "Exact Bank Name (e.g. Landbank of the Philippines, BDO, BPI, UnionBank, SeaBank, Metrobank, etc.)",
  "account_holder_name": "Full Name of Account Holder / Scholar as printed on the card",
  "account_number": "Account or Card Number as digits only (no dashes, spaces, or letters). Include the full number even if partially visible.",
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
    Uint8List visionBytes = actualBytes;
    String visionMime = mimeType;
    if (isPdf) {
      final embeddedJpeg = _extractJpegFromPdf(actualBytes);
      if (embeddedJpeg != null && embeddedJpeg.isNotEmpty) {
        visionBytes = await _prepareImageForOcr(embeddedJpeg) ?? embeddedJpeg;
        visionMime = 'image/jpeg';
        debugPrint('Found embedded JPEG in PDF, prepared for OCR (${visionBytes.length} bytes)');
      } else {
        debugPrint('No embedded JPEG found; keeping native PDF payload (${visionBytes.length} bytes)');
      }
    } else {
      visionBytes = await _prepareImageForOcr(actualBytes) ?? actualBytes;
    }

    // 1. Google Gemini (native PDF + vision). Model name auto-falls back
    //    because Google retires older model versions over time.
    if (geminiKey.isNotEmpty) {
      try {
        debugPrint('Attempting extraction with Gemini...');
        final res = await _extractWithGemini(
          bytes: actualBytes,
          mimeType: mimeType,
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
          bytes: visionBytes,
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
          bytes: visionBytes,
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

  /// Extracts the largest embedded JPEG stream from a scanned PDF.
  /// PDFs often embed a small thumbnail before the actual photo, so we scan
  /// for every JPEG block and return the biggest one (best OCR source).
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
      debugPrint('PDF JPEG extract exception: $e');
    }
    return null;
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
    for (final b in _knownBanks) {
      if (lower.contains(b.toLowerCase())) {
        bank = b;
        break;
      }
    }
    if (bank.isEmpty) bank = 'Landbank of the Philippines';

    String number = '';
    for (final match in RegExp(r'\d[\d ]{5,18}\d').allMatches(text)) {
      final clean = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
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
          l.contains('name')) {
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
    required Uint8List bytes,
    required String mimeType,
    required String apiKey,
  }) async {
    const models = ['gemini-3.6-flash', 'gemini-2.5-flash', 'gemini-2.0-flash'];
    final base64Data = base64Encode(bytes);

    for (final model in models) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': _systemPrompt},
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Data,
                        },
                      },
                    ],
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
    required Uint8List bytes,
    required String mimeType,
    required String apiKey,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final base64Data = base64Encode(bytes);

    // gpt-4o-mini is the only model usable with a $0 balance; the others are
    // kept as fallbacks in case credits are added later.
    final models = [
      'openai/gpt-4o-mini',
      'openai/gpt-4.1-mini',
      'openai/gpt-4o',
      'google/gemini-2.5-flash',
    ];

    for (final model in models) {
      try {
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
                    'content': [
                      {'type': 'text', 'text': _systemPrompt},
                      {
                        'type': 'image_url',
                        'image_url': {'url': 'data:$mimeType;base64,$base64Data'},
                      },
                    ],
                  },
                ],
                'temperature': 0.1,
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
              data['card_number'] ??
              data['card_no'] ??
              data['accountNumber'] ??
              data['cardNumber'] ??
              data['number'] ??
              '')
          .toString();

      // Scan all keys if not standard
      if (accNum.isEmpty || accNum.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
        for (final entry in data.entries) {
          final k = entry.key.toLowerCase();
          final v = entry.value?.toString() ?? '';
          final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
          if ((k.contains('num') || k.contains('acc') || k.contains('card') || k.contains('id') || k.contains('bank')) &&
              digitsOnly.length >= 6) {
            accNum = digitsOnly;
            break;
          }
        }
      }

      // Scan raw text with regex
      if (accNum.isEmpty || accNum.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
        String best = '';
        for (final match in RegExp(r'\d[0-9 ]{5,}\d').allMatches(raw)) {
          final clean = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
          if (clean.length >= 6 && clean.length <= 19 && clean.length > best.length) {
            best = clean;
          }
        }
        if (best.isNotEmpty) accNum = best;
      }

      final conf = double.tryParse(data['confidence_score']?.toString() ?? '0.95') ?? 0.95;

      return ExtractedBankInfo(
        bankName: bank,
        accountName: accName,
        accountNumber: accNum.replaceAll(RegExp(r'[^0-9]'), ''),
        confidenceScore: conf,
        aiModelUsed: modelName,
      );
    } catch (e) {
      debugPrint('JSON parse error in AI extraction: $e');
      return null;
    }
  }
}
