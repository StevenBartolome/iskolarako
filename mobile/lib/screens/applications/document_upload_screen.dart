import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/services/audit_log_service.dart';
import 'package:iskoako/services/ai_extraction_service.dart';
import 'package:iskoako/services/document_validation_service.dart';
import 'package:iskoako/utils/eligibility_helper.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  List<_DocItem> _docs = [];
  Map<String, dynamic>? _scholar;
  Map<String, dynamic>? _program;
  Map<String, dynamic>? _cycle;
  bool _isInitialized = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _program = args?['program'] as Map<String, dynamic>?;
      _scholar = args?['scholar'] as Map<String, dynamic>?;
      _cycle = args?['cycle'] as Map<String, dynamic>?;

      if (_cycle == null && _program != null) {
        final cycles = _program!['cycles'] as List<dynamic>?;
        if (cycles != null && cycles.isNotEmpty) {
          _cycle = cycles.firstWhere(
            (c) => c['status']?.toString().toLowerCase() == 'open',
            orElse: () => cycles.first,
          ) as Map<String, dynamic>?;
        }
      }

      _initializeRequirements();
      _ensureScholarProfile();
      _isInitialized = true;
    }
  }

  void _initializeRequirements() {
    final renewalReqs = _cycle?['renewal_requirements'] ?? _cycle?['renewalRequirements'];
    final isRenewal = renewalReqs != null;
    final reqs = renewalReqs ?? _program?['application_requirements'];

    if (reqs == null) {
      _docs = [
        const _DocItem(
          name: 'PSA Birth Certificate',
          hint: 'Required · PDF or Image',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'Form 138 / Report Card or TOR',
          hint: 'Required · PDF or Image',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'ITR or Certificate of Indigency',
          hint: 'Required · PDF or Image',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'Valid Government or Student ID',
          hint: 'Required · PDF or Image',
          status: _DocStatus.notUploaded,
        ),
      ];
      return;
    }

    List<dynamic> parsedReqs = [];
    if (reqs is List) {
      parsedReqs = reqs;
    } else if (reqs is String) {
      try {
        parsedReqs = jsonDecode(reqs);
      } catch (e) {
        debugPrint('Error parsing requirements JSON: $e');
      }
    }

    final List<_DocItem> loadedDocs = [];
    for (final r in parsedReqs) {
      if (r is Map) {
        final name = r['name']?.toString() ?? '';
        final desc = r['description']?.toString() ?? r['instructions']?.toString() ?? r['remarks']?.toString() ?? '';
        final isRequired = isRenewal || r['required'] == true;
        if (name.isNotEmpty) {
          loadedDocs.add(_DocItem(
            name: name,
            description: desc.isNotEmpty ? desc : null,
            hint: isRequired ? 'Required · PDF or Image' : 'Optional',
            status: isRequired ? _DocStatus.notUploaded : _DocStatus.optional,
          ));
        }
      } else if (r is String) {
        final name = r.trim();
        if (name.isNotEmpty) {
          loadedDocs.add(_DocItem(
            name: name,
            hint: 'Required · PDF or Image',
            status: _DocStatus.notUploaded,
          ));
        }
      }
    }

    if (loadedDocs.isEmpty) {
      loadedDocs.add(const _DocItem(
        name: 'Scholarship Application Form',
        hint: 'Required · PDF or Image',
        status: _DocStatus.notUploaded,
      ));
    }

    setState(() {
      _docs = loadedDocs;
    });
  }

  String get _scholarFullName {
    if (_scholar == null) return 'Scholar Applicant';
    final first = _scholar!['first_name'] ?? '';
    final middle = _scholar!['middle_name'] ?? '';
    final last = _scholar!['last_name'] ?? '';
    final suffix = _scholar!['suffix'] ?? '';

    final parts = [first];
    if (middle.toString().isNotEmpty) {
      parts.add(middle);
    }
    parts.add(last);
    if (suffix.toString().isNotEmpty) {
      parts.add(suffix);
    }

    return parts.join(' ').trim();
  }

  String get _scholarCourseAndYear {
    if (_scholar == null) return 'N/A';
    final course = _scholar!['course'] ?? '';
    final year = _scholar!['year_level'] ?? '';

    String yearStr = '';
    if (year != null) {
      final y = year.toString();
      if (y == '1') {
        yearStr = '1st Year';
      } else if (y == '2') {
        yearStr = '2nd Year';
      } else if (y == '3') {
        yearStr = '3rd Year';
      } else if (y == '4') {
        yearStr = '4th Year';
      } else {
        yearStr = '$y Year';
      }
    }

    if (course.toString().isNotEmpty && yearStr.isNotEmpty) {
      return '$course · $yearStr';
    }
    return course.toString().isNotEmpty ? course.toString() : yearStr;
  }

  String get _scholarSchool {
    return _scholar?['school'] ?? 'N/A';
  }

  int get _requiredCount => _docs.where((d) => d.status != _DocStatus.optional).length;
  int get _uploadedCount => _docs.where((d) =>
      d.status == _DocStatus.valid ||
      d.status == _DocStatus.flagged ||
      d.isDisputeSubmitted).length;

  bool get _hasRejectedDoc => _docs.any((d) => d.status == _DocStatus.rejected && !d.isDisputeSubmitted);
  bool get _hasDisputedDoc => _docs.any((d) => d.isDisputeSubmitted);
  bool get _hasMaxRejections => _docs.any((d) => d.status == _DocStatus.rejected && d.attemptCount >= 3);
  bool get _isForAppeal => _hasDisputedDoc || _hasMaxRejections;

  bool get _canSubmit {
    if (_hasRejectedDoc) return false;
    return _docs.where((d) => d.status != _DocStatus.optional).every((d) =>
        d.status == _DocStatus.valid ||
        d.status == _DocStatus.flagged ||
        d.isDisputeSubmitted);
  }

  Future<Map<String, dynamic>?> _ensureScholarProfile() async {
    if (_scholar != null &&
        _scholar!['id'] != null &&
        _scholar!['gpa_scale'] != null &&
        _scholar!['gpa_scale'].toString().isNotEmpty &&
        _scholar!['gpa_scale'].toString() != 'null') {
      return _scholar;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _scholar;

    try {
      try {
        final existingUser = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (existingUser == null) {
          final firstName = user.userMetadata?['first_name']?.toString() ?? 'Scholar';
          final lastName = user.userMetadata?['last_name']?.toString() ?? 'Student';
          final email = user.email ?? '${user.id}@iskolarako.app';

          await Supabase.instance.client.from('users').upsert({
            'id': user.id,
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'role': 'scholar',
          });
        }
      } catch (uErr) {
        debugPrint('Note checking public.users table: $uErr');
      }

      final existingScholar = await Supabase.instance.client
          .from('scholar')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingScholar != null) {
        if (mounted) {
          setState(() {
            _scholar = {...(_scholar ?? {}), ...existingScholar};
          });
        } else {
          _scholar = {...(_scholar ?? {}), ...existingScholar};
        }
        debugPrint('[DocumentUploadScreen] Resolved complete scholar profile: id=${_scholar!['id']}, gpa_scale=${_scholar!['gpa_scale']}');
        return _scholar;
      }

      final firstName = user.userMetadata?['first_name']?.toString() ?? 'Scholar';
      final lastName = user.userMetadata?['last_name']?.toString() ?? 'Student';
      final school = user.userMetadata?['school']?.toString();
      final course = user.userMetadata?['course']?.toString();
      final phone = user.userMetadata?['phone']?.toString();
      final yearLevel = int.tryParse(user.userMetadata?['year_level']?.toString() ?? '');
      final gpa = double.tryParse(user.userMetadata?['gpa']?.toString() ?? '');

      final Map<String, dynamic> insertPayload = {
        'user_id': user.id,
        'first_name': firstName,
        'last_name': lastName,
        'citizenship': 'Filipino',
      };
      if (school != null && school.isNotEmpty) insertPayload['school'] = school;
      if (course != null && course.isNotEmpty) insertPayload['course'] = course;
      if (phone != null && phone.isNotEmpty) insertPayload['phone'] = phone;
      if (yearLevel != null) insertPayload['year_level'] = yearLevel;
      if (gpa != null) insertPayload['gpa'] = gpa;

      final newScholar = await Supabase.instance.client.from('scholar').insert(insertPayload).select().maybeSingle();

      if (newScholar != null) {
        _scholar = newScholar;
        return newScholar;
      }
    } catch (e) {
      debugPrint('Error ensuring scholar profile: $e');
    }

    return _scholar;
  }

  Future<void> _handleUpload(_DocItem doc) async {
    // If already uploaded cleanly or flagged, allow removing or viewing
    if (doc.status == _DocStatus.valid || doc.status == _DocStatus.flagged) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: Color(0xFFB91C1C)),
                    title: Text(
                      'Remove ${doc.name}',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFB91C1C), fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        final idx = _docs.indexOf(doc);
                        if (idx != -1) {
                          final isRequired = doc.hint.toLowerCase().contains('required') ||
                              doc.status == _DocStatus.notUploaded;
                          _docs[idx] = _DocItem(
                            name: doc.name,
                            hint: isRequired
                                ? 'Required · PDF or Image'
                                : 'Optional',
                            status: isRequired
                                ? _DocStatus.notUploaded
                                : _DocStatus.optional,
                          );
                        }
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.fileText, color: Color(0xFF1E3D2F)),
                    title: Text('View File (${doc.filename})', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Viewing ${doc.filename}...'),
                          backgroundColor: const Color(0xFF1E3D2F),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // Check attempts & cooldowns first!
    final scholar = await _ensureScholarProfile();
    final scholarId = scholar?['id'] ?? '';
    final cycleId = _cycle?['id']?.toString();

    final attemptStatus = await DocumentValidationService.checkAttemptStatus(
      scholarId: scholarId,
      cycleId: cycleId,
      docSlotName: doc.name,
    );

    if (attemptStatus.isDisputeEligible && !doc.isDisputeSubmitted) {
      _showDisputeDialog(doc, attemptStatus.attemptCount);
      return;
    }

    if (attemptStatus.isCooldownActive) {
      _showCooldownDialog(doc, attemptStatus.remainingCooldownSeconds);
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final fileName = pickedFile.name;
      final sizeInKb = (pickedFile.size / 1024);
      final sizeStr = sizeInKb > 1024
          ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB'
          : '${sizeInKb.toStringAsFixed(0)} KB';

      if (!mounted) return;

      // Update UI state to scanning
      setState(() {
        final idx = _docs.indexOf(doc);
        if (idx != -1) {
          _docs[idx] = doc.copyWith(
            status: _DocStatus.scanning,
            filename: fileName,
            filesize: sizeStr,
          );
        }
      });

      final messenger = ScaffoldMessenger.of(context);
      final bytes = pickedFile.bytes;
      String? uploadedUrl;

      if (bytes != null) {
        final sId = scholarId.isNotEmpty ? scholarId : 'guest';
        final cId = cycleId ?? 'cycle';
        final timeStamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$sId/${cId}_${timeStamp}_$fileName';

        try {
          try {
            await Supabase.instance.client.storage.createBucket(
              'scholar-documents',
              const BucketOptions(public: true),
            );
          } catch (_) {}

          await Supabase.instance.client.storage
              .from('scholar-documents')
              .uploadBinary(storagePath, bytes);

          uploadedUrl = Supabase.instance.client.storage
              .from('scholar-documents')
              .getPublicUrl(storagePath);
        } catch (_) {
          final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
          String mimeType = 'application/pdf';
          if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
          if (ext == 'png') mimeType = 'image/png';
          if (ext == 'doc' || ext == 'docx') mimeType = 'application/msword';
          uploadedUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        }

        final scholarFirstName = scholar?['first_name']?.toString() ?? '';
        final scholarLastName = scholar?['last_name']?.toString() ?? '';
        final scholarFullName = '$scholarFirstName $scholarLastName'.trim();

        // Extract Minimum GWA and Grading System from scholarship program
        final minGwaRaw = _program?['minimum_gwa'] ?? _program?['minimumGwa'] ?? _program?['renewal_gwa_requirement'];
        double? minimumGwa;
        if (minGwaRaw != null) {
          minimumGwa = double.tryParse(minGwaRaw.toString());
        }
        final scholarScaleRaw = scholar?['gpa_scale']?.toString() ?? _scholar?['gpa_scale']?.toString() ?? '';
        final scholarGpaScale = (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown')
            ? scholarScaleRaw
            : 'scale_5';
        final gradingSystem = scholarGpaScale;

        // STEP 1: FAST PRE-CHECK — Run AI Document Validation for Document Type, Name Match & Remarks Instructions FIRST!
        final validationRes = await DocumentValidationService.validateDocument(
          fileBytes: bytes,
          fileName: fileName,
          requiredDocName: doc.name,
          requirementDescription: doc.description,
          scholarName: scholarFullName,
          minimumGwa: minimumGwa,
          gradingSystem: gradingSystem,
        );

        if (!mounted) return;

        // If Step 1 fails (<40%), REJECT IMMEDIATELY and stop (do not waste time extracting/converting grades)!
        if (validationRes.confidenceScore < 0.40) {
          final newAttemptCount = attemptStatus.attemptCount + 1;
          final reason = validationRes.rejectionReason.isNotEmpty
              ? validationRes.rejectionReason
              : 'Uploaded document does not match ${doc.name}. Detected: ${validationRes.documentDetected}.';

          await DocumentValidationService.logRejection(
            scholarId: scholarId,
            cycleId: cycleId,
            docSlotName: doc.name,
            filename: fileName,
            confidenceScore: validationRes.confidenceScore,
            rejectionReason: reason,
            attemptNumber: newAttemptCount,
          );

          setState(() {
            final idx = _docs.indexWhere((d) => d.name == doc.name);
            if (idx != -1) {
              _docs[idx] = doc.copyWith(
                status: _DocStatus.rejected,
                filename: fileName,
                filesize: sizeStr,
                fileUrl: uploadedUrl,
                fileBytes: bytes,
                aiConfidence: validationRes.confidenceScore,
                aiRejectionReason: reason,
                aiDocumentDetected: validationRes.documentDetected,
                aiFlags: validationRes.flags,
                attemptCount: newAttemptCount,
              );
            }
          });

          _showRejectionDialog(doc.name, reason, newAttemptCount);
          return; // Stop immediately, do not proceed to grade extraction!
        }

        // STEP 2: IF STEP 1 PASSED — Check if document is about grades, then proceed to grade extraction & minimum GWA check!
        final docNameLower = doc.name.toLowerCase();
        final isAcademicDoc = docNameLower.contains('tor') ||
            docNameLower.contains('transcript') ||
            docNameLower.contains('grade') ||
            docNameLower.contains('report card') ||
            docNameLower.contains('card') ||
            docNameLower.contains('cor') ||
            docNameLower.contains('enrollment') ||
            docNameLower.contains('registration') ||
            docNameLower.contains('assessment') ||
            docNameLower.contains('billing') ||
            docNameLower.contains('soa') ||
            docNameLower.contains('tcg');

        final extraGradeFlags = <String>[];
        double? tempExtractedGpa;
        String? tempExtractedScale;
        double? tempExtractedTuition;

        if (isAcademicDoc) {
          try {
            final scholarScaleRaw = scholar?['gpa_scale']?.toString() ?? _scholar?['gpa_scale']?.toString() ?? '';
            final scholarGpaScale = (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown')
                ? scholarScaleRaw
                : 'scale_5';

            debugPrint('[AiExtraction] Step 1 Passed. Extracting academic details for ${doc.name}... scholar scale: "$scholarGpaScale"');

            final extracted = await AiExtractionService.extractAcademicDetails(
              fileBytes: bytes,
              fileName: fileName,
              expectedScale: scholarGpaScale,
            );

            if (extracted != null) {
              if (extracted.extractedTuitionAmount != null && extracted.extractedTuitionAmount! > 0) {
                tempExtractedTuition = extracted.extractedTuitionAmount;
                extraGradeFlags.add('Extracted Matriculation Fee: ₱${tempExtractedTuition!.toStringAsFixed(2)}');
              }

              if (extracted.gpa != null) {
                tempExtractedGpa = extracted.gpa!;

                // PRIORITIZE scale from scholars table if present!
                if (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown') {
                  tempExtractedScale = scholarScaleRaw;
                } else {
                  tempExtractedScale = extracted.gpaScale ?? scholarGpaScale;
                }

                final scholarPercent = EligibilityHelper.normalizeGpa(tempExtractedGpa, tempExtractedScale);

                debugPrint('[Eligibility Check] Scholar GWA: $tempExtractedGpa, Scale: $tempExtractedScale, Equivalent Percent: ${scholarPercent.toStringAsFixed(1)}%');

                if (minimumGwa != null) {
                  final programScaleRaw = _program?['gpa_scale']?.toString() ?? _program?['grading_system']?.toString() ?? '';
                  final programScale = (minimumGwa > 5.0)
                      ? 'percentage'
                      : (programScaleRaw.isNotEmpty && programScaleRaw != 'null' ? programScaleRaw : scholarGpaScale);

                  final requiredPercent = EligibilityHelper.normalizeGpa(minimumGwa, programScale);

                  debugPrint('[Eligibility Check] Scholar GWA: ${scholarPercent.toStringAsFixed(1)}%, Required: ${requiredPercent.toStringAsFixed(1)}% (min: $minimumGwa, scale: $programScale)');

                  if (scholarPercent < requiredPercent - 0.001) {
                    // REJECT IMMEDIATELY (below program grade requirement)
                    final newAttemptCount = attemptStatus.attemptCount + 1;
                    final reason = 'Extracted GWA $tempExtractedGpa (${scholarPercent.toStringAsFixed(1)}%) does not meet the minimum required grade of ${minimumGwa > 5.0 ? "${minimumGwa.toStringAsFixed(0)}%" : minimumGwa.toStringAsFixed(2)} for this scholarship program.';

                    await DocumentValidationService.logRejection(
                      scholarId: scholarId,
                      cycleId: cycleId,
                      docSlotName: doc.name,
                      filename: fileName,
                      confidenceScore: 0.30,
                      rejectionReason: reason,
                      attemptNumber: newAttemptCount,
                    );

                    if (mounted) {
                      setState(() {
                        final idx = _docs.indexWhere((d) => d.name == doc.name);
                        if (idx != -1) {
                          _docs[idx] = doc.copyWith(
                            status: _DocStatus.rejected,
                            filename: fileName,
                            filesize: sizeStr,
                            fileUrl: uploadedUrl,
                            fileBytes: bytes,
                            aiConfidence: 0.30,
                            aiRejectionReason: reason,
                            aiDocumentDetected: 'Grade Document',
                            aiFlags: [...extraGradeFlags, ...validationRes.flags],
                            extractedGpa: tempExtractedGpa,
                            extractedGpaScale: tempExtractedScale,
                            extractedTuitionAmount: tempExtractedTuition,
                            attemptCount: newAttemptCount,
                          );
                        }
                      });
                      _showRejectionDialog(doc.name, reason, newAttemptCount);
                    }
                    return; // Stop execution, document is rejected due to below minimum grade!
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[AiExtraction] Error extracting academic details during upload: $e');
          }
        }

        // STEP 3: SAVE DOCUMENT STATE (Clean Pass >=80% or Flagged 40-79%)
        final cleanValidationFlags = validationRes.flags
            .where((f) => !f.toLowerCase().startsWith('extracted gwa:'))
            .toList();
        final combinedFlags = <String>[...extraGradeFlags, ...cleanValidationFlags];

        if (validationRes.confidenceScore < 0.80) {
          // Flagged / Under Review (40% to 79%)
          setState(() {
            final idx = _docs.indexWhere((d) => d.name == doc.name);
            if (idx != -1) {
              _docs[idx] = doc.copyWith(
                status: _DocStatus.flagged,
                filename: fileName,
                filesize: sizeStr,
                fileUrl: uploadedUrl,
                fileBytes: bytes,
                aiConfidence: validationRes.confidenceScore,
                aiDocumentDetected: validationRes.documentDetected,
                aiFlags: combinedFlags,
                extractedGpa: tempExtractedGpa,
                extractedGpaScale: tempExtractedScale,
                extractedTuitionAmount: tempExtractedTuition,
              );
            }
          });

          messenger.showSnackBar(
            SnackBar(
              content: Text('Attached $fileName for ${doc.name} (Flagged for Review).'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
        } else {
          // Clean Pass (>=80%)
          setState(() {
            final idx = _docs.indexWhere((d) => d.name == doc.name);
            if (idx != -1) {
              _docs[idx] = doc.copyWith(
                status: _DocStatus.valid,
                filename: fileName,
                filesize: sizeStr,
                fileUrl: uploadedUrl,
                fileBytes: bytes,
                aiConfidence: validationRes.confidenceScore,
                aiDocumentDetected: validationRes.documentDetected,
                aiFlags: combinedFlags,
                extractedGpa: tempExtractedGpa,
                extractedGpaScale: tempExtractedScale,
                extractedTuitionAmount: tempExtractedTuition,
              );
            }
          });

          messenger.showSnackBar(
            SnackBar(
              content: Text('Successfully verified and attached $fileName!'),
              backgroundColor: const Color(0xFF1E3D2F),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('File picker or validation error: $e');
      if (mounted) {
        setState(() {
          final idx = _docs.indexOf(doc);
          if (idx != -1) {
            _docs[idx] = doc.copyWith(status: _DocStatus.notUploaded);
          }
        });
      }
    }
  }

  void _showCooldownDialog(_DocItem doc, int remainingSeconds) {
    final minutes = (remainingSeconds / 60).ceil();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.clock, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cooldown Active',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'You have had 2 consecutive AI rejections for "${doc.name}". To prevent submission spam, please wait ~$minutes minute(s) before attempting your 3rd upload.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF374151), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3D2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Got It', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(String docName, String reason, int attemptCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.xCircle, color: Color(0xFFB91C1C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Validation Failed',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The uploaded file for "$docName" was rejected by AI verification.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF374151), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                reason,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              attemptCount >= 3
                  ? '⚠️ Maximum 3 attempts reached. You may now submit an Appeal / Dispute to the scholarship provider.'
                  : (attemptCount == 2
                      ? '⚠️ Attempt $attemptCount of 3 used. Next attempt will trigger a 15-minute cooldown if rejected.'
                      : 'Attempt $attemptCount of 3 used. Please upload a valid copy of $docName.'),
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3D2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(_DocItem doc, int attemptCount) {
    final textController = TextEditingController();
    String? currentFileName = doc.filename;
    String? currentFileSize = doc.filesize;
    String? currentFileUrl = doc.fileUrl;
    Uint8List? currentFileBytes = doc.fileBytes;
    bool isPickingFile = false;
    bool isScanningFile = false;
    double? newAiConfidence = doc.aiConfidence;
    List<String>? newAiFlags = doc.aiFlags;
    String? newAiDetected = doc.aiDocumentDetected;
    double? newExtractedGpa = doc.extractedGpa;
    String? newExtractedGpaScale = doc.extractedGpaScale;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(LucideIcons.helpCircle, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dispute AI Rejection',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have reached the 3-attempt limit for "${doc.name}". If you believe your document is authentic and the AI made an error, you can submit an appeal directly to the provider.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF4B5563), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Attached Document Card
                    Text(
                      'Attached Appeal Document File:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          isScanningFile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
                                )
                              : const Icon(LucideIcons.fileText, color: Color(0xFF7C3AED), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isScanningFile ? 'AI Scanning Document...' : (currentFileName ?? 'No file attached'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: currentFileName != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentFileSize != null)
                                  Text(
                                    currentFileSize!,
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF6B7280)),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: (isPickingFile || isScanningFile)
                                ? null
                                : () async {
                                    setModalState(() {
                                      isPickingFile = true;
                                      isScanningFile = true;
                                    });
                                    try {
                                      final result = await FilePicker.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                                        withData: true,
                                      );
                                      if (result != null && result.files.isNotEmpty) {
                                        final picked = result.files.first;
                                        final name = picked.name;
                                        final sizeKb = picked.size / 1024;
                                        final sizeText = sizeKb > 1024
                                            ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
                                            : '${sizeKb.toStringAsFixed(0)} KB';

                                        String? url;
                                        if (picked.bytes != null) {
                                          final sId = _scholar?['id'] ?? 'guest';
                                          final cId = _cycle?['id']?.toString() ?? 'cycle';
                                          final timeStamp = DateTime.now().millisecondsSinceEpoch;
                                          final path = '$sId/${cId}_dispute_${timeStamp}_$name';
                                          try {
                                            await Supabase.instance.client.storage
                                                .from('scholar-documents')
                                                .uploadBinary(path, picked.bytes!);
                                            url = Supabase.instance.client.storage
                                                .from('scholar-documents')
                                                .getPublicUrl(path);
                                          } catch (_) {}

                                          // Run 2-step AI Scan on newly attached file!
                                          final scholarFirstName = _scholar?['first_name']?.toString() ?? '';
                                          final scholarLastName = _scholar?['last_name']?.toString() ?? '';
                                          final scholarFullName = '$scholarFirstName $scholarLastName'.trim();
                                          final minGwaRaw = _program?['minimum_gwa'] ?? _program?['minimumGwa'] ?? _program?['renewal_gwa_requirement'];
                                          double? minimumGwa;
                                          if (minGwaRaw != null) minimumGwa = double.tryParse(minGwaRaw.toString());
                                          
                                          final scholarScaleRaw = _scholar?['gpa_scale']?.toString() ?? '';
                                          final scholarGpaScale = (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown')
                                              ? scholarScaleRaw
                                              : 'scale_5';
                                          final gradingSystem = scholarGpaScale;

                                          final vRes = await DocumentValidationService.validateDocument(
                                            fileBytes: picked.bytes!,
                                            fileName: name,
                                            requiredDocName: doc.name,
                                            requirementDescription: doc.description,
                                            scholarName: scholarFullName,
                                            minimumGwa: minimumGwa,
                                            gradingSystem: gradingSystem,
                                          );

                                          double? extractedGpaVal;
                                          String? extractedScaleVal;
                                          final modalFlags = <String>[...vRes.flags];

                                          final docNameLower = doc.name.toLowerCase();
                                          final isAcademicDoc = docNameLower.contains('tor') ||
                                              docNameLower.contains('transcript') ||
                                              docNameLower.contains('grade') ||
                                              docNameLower.contains('report card') ||
                                              docNameLower.contains('card') ||
                                              docNameLower.contains('tcg');

                                          if (isAcademicDoc) {
                                            final scholarScaleRaw = _scholar?['gpa_scale']?.toString() ?? '';
                                            final scholarGpaScale = (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown')
                                                ? scholarScaleRaw
                                                : 'scale_5';
                                            final ex = await AiExtractionService.extractAcademicDetails(
                                              fileBytes: picked.bytes!,
                                              fileName: name,
                                              expectedScale: scholarGpaScale,
                                            );
                                            if (ex != null && ex.gpa != null) {
                                              extractedGpaVal = ex.gpa!;
                                              extractedScaleVal = (scholarScaleRaw.isNotEmpty && scholarScaleRaw != 'null' && scholarScaleRaw != 'unknown')
                                                  ? scholarScaleRaw
                                                  : (ex.gpaScale ?? scholarGpaScale);
                                            }
                                          }

                                          setModalState(() {
                                            currentFileName = name;
                                            currentFileSize = sizeText;
                                            currentFileBytes = picked.bytes;
                                            currentFileUrl = url;
                                            newAiConfidence = vRes.confidenceScore;
                                            newAiFlags = modalFlags;
                                            newAiDetected = vRes.documentDetected;
                                            newExtractedGpa = extractedGpaVal;
                                            newExtractedGpaScale = extractedScaleVal;
                                          });
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking dispute file: $e');
                                    } finally {
                                      setModalState(() {
                                        isPickingFile = false;
                                        isScanningFile = false;
                                      });
                                    }
                                  },
                            icon: const Icon(LucideIcons.paperclip, size: 14, color: Color(0xFF7C3AED)),
                            label: Text(
                              currentFileName != null ? 'Change' : 'Attach File',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (newAiFlags != null && newAiFlags!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'AI Note: ${newAiFlags!.join(', ')}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    Text(
                      'Reason for Appeal / Statement:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'e.g. This is an official document signed with Dean signature and school dry seal...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final note = textController.text.trim();
                    if (note.isEmpty) return;
                    if (currentFileName == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please attach a document file for your appeal.'),
                          backgroundColor: Color(0xFFB91C1C),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    setState(() {
                      final idx = _docs.indexWhere((d) => d.name == doc.name);
                      if (idx != -1) {
                        _docs[idx] = _docs[idx].copyWith(
                          filename: currentFileName,
                          filesize: currentFileSize,
                          fileUrl: currentFileUrl ?? _docs[idx].fileUrl,
                          fileBytes: currentFileBytes ?? _docs[idx].fileBytes,
                          aiConfidence: newAiConfidence ?? _docs[idx].aiConfidence,
                          aiFlags: newAiFlags ?? _docs[idx].aiFlags,
                          aiDocumentDetected: newAiDetected ?? _docs[idx].aiDocumentDetected,
                          extractedGpa: newExtractedGpa ?? _docs[idx].extractedGpa,
                          extractedGpaScale: newExtractedGpaScale ?? _docs[idx].extractedGpaScale,
                          isDisputeSubmitted: true,
                          disputeNote: note,
                          status: _DocStatus.flagged,
                        );
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appeal recorded for this document! You can now submit your application.'),
                        backgroundColor: Color(0xFF7C3AED),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Submit Dispute', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitApplication() async {
    final cycleId = _cycle?['id'];

    if (cycleId == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No Active Cycle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'This scholarship program currently has no active application cycle open.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D2F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    if (_hasRejectedDoc) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.xCircle, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rejected Document',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'One or more uploaded documents were rejected by AI document validation. Please replace the rejected document file or submit an appeal before submitting your application.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF374151), height: 1.45),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D2F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    if (!_canSubmit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Incomplete Requirements',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            'Please upload all required documents before submitting your application.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D2F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final scholar = await _ensureScholarProfile();
    final scholarId = scholar?['id'];
    final scholarGpaScale = scholar?['gpa_scale']?.toString() ?? 'scale_5';

    if (scholarId == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to resolve scholar profile. Please complete your profile first.'),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
      }
      return;
    }

    final refNum = 'ISK-${DateTime.now().year}-${1000 + Random().nextInt(8999)}';
    bool submitSuccess = false;
    String? errorMessage;

    try {
      final uploadedDocsList = _docs
          .where((d) => d.status == _DocStatus.valid || d.status == _DocStatus.flagged || d.isDisputeSubmitted)
          .map((d) => {
                'name': d.name,
                'document_name': d.name,
                'filename': d.filename,
                'filesize': d.filesize,
                'document_url': d.fileUrl ?? '',
                'submitted_at': DateTime.now().toIso8601String(),
                'ai_confidence': d.aiConfidence,
                'ai_flags': d.aiFlags,
                'is_disputed': d.isDisputeSubmitted,
                'extractedGwa': d.extractedGpa,
                'extractedGwaScale': d.extractedGpaScale,
                'extractedTuitionAmount': d.extractedTuitionAmount,
                'extracted_tuition_amount': d.extractedTuitionAmount,
                'aiVerification': {
                  'extractedGwa': d.extractedGpa,
                  'extractedGwaScale': d.extractedGpaScale,
                  'extractedTuitionAmount': d.extractedTuitionAmount,
                  'extracted_tuition_amount': d.extractedTuitionAmount,
                },
              })
          .toList();

      String appStatus = 'pending';
      final underReviewReasons = <String, dynamic>{};
      final aiScanSummary = <String, dynamic>{};
      bool hasDispute = false;
      String? disputeNoteText;

      for (final doc in _docs) {
        if (doc.status == _DocStatus.valid || doc.status == _DocStatus.flagged || doc.status == _DocStatus.rejected) {
          aiScanSummary[doc.name] = {
            'status': doc.status.name,
            'confidence': doc.aiConfidence,
            'document_detected': doc.aiDocumentDetected,
            'flags': doc.aiFlags,
            'rejection_reason': doc.aiRejectionReason,
          };
        }

        if (doc.status == _DocStatus.flagged && appStatus != 'appealed') {
          appStatus = 'under_review';
          underReviewReasons[doc.name] = doc.aiFlags ?? ['Flagged by AI verification'];
        }

        if (doc.isDisputeSubmitted) {
          appStatus = 'appealed';
          hasDispute = true;
          disputeNoteText = doc.disputeNote;
        }
      }

      double? finalExtractedGpa;
      String finalExtractedScale = scholarGpaScale;

      for (final doc in _docs) {
        if (doc.extractedGpa != null) {
          finalExtractedGpa = doc.extractedGpa;
          if (doc.extractedGpaScale != null) {
            finalExtractedScale = doc.extractedGpaScale!;
          }
        }
      }

      final payload = {
        'cycle_id': cycleId,
        'scholar_id': scholarId,
        'status': appStatus,
        'submitted_documents': {
          'reference_number': refNum,
          'documents': uploadedDocsList,
        },
        'ai_scan_summary': aiScanSummary,
        'under_review_reasons': underReviewReasons,
        if (hasDispute && disputeNoteText != null) 'dispute_note': disputeNoteText,
        if (hasDispute) 'dispute_submitted_at': DateTime.now().toUtc().toIso8601String(),
        'remarks': appStatus == 'under_review'
            ? 'Under review due to AI document flags'
            : (appStatus == 'appealed' ? 'Dispute submitted by scholar' : 'Submitted via mobile app'),
        if (finalExtractedGpa != null) 'grade': finalExtractedGpa,
        'gpa_scale': finalExtractedScale,
      };

      await Supabase.instance.client.from('scholarship_applications').insert(payload);

      // Update scholar profile GWA and scale in the scholar table to stay in sync
      if (finalExtractedGpa != null) {
        try {
          await Supabase.instance.client.from('scholar').update({
            'gpa': finalExtractedGpa,
            'gpa_scale': finalExtractedScale,
          }).eq('id', scholarId);
          debugPrint('[AiExtraction] Updated scholar profile table with GWA: $finalExtractedGpa ($finalExtractedScale)');
        } catch (sUpdateErr) {
          debugPrint('[AiExtraction] Scholar profile update error: $sUpdateErr');
        }
      }

      submitSuccess = true;
      AuditLogService.createAuditLog(
        action: 'SUBMITTED SCHOLARSHIP APPLICATION',
        target: 'Program: ${_program?['title'] ?? 'Unknown'} | Ref: $refNum',
      );
    } on PostgrestException catch (pe) {
      debugPrint('PostgrestException submitting application: ${pe.code} - ${pe.message}');
      if (pe.code == '42501') {
        errorMessage = 'Row-Level Security Policy Error (42501):\n\nSupabase RLS is blocking inserts on table "scholarship_applications".\n\nFix: Open Supabase Dashboard -> SQL Editor and execute:\nCREATE POLICY "Allow scholar insert" ON public.scholarship_applications FOR INSERT WITH CHECK (true);';
      } else {
        errorMessage = 'Database Error (${pe.code}): ${pe.message}';
      }
    } catch (e) {
      debugPrint('Submission handler error: $e');
      errorMessage = 'Submission failed: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;

    if (!submitSuccess) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Submission Error',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              errorMessage ?? 'An error occurred while submitting your application.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D2F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(LucideIcons.checkCheck, color: Color(0xFF16A34A), size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Application Submitted!',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reference #: $refNum',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your application for ${_program?['title'] ?? 'this scholarship'} has been submitted successfully to the scholarship provider.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Pop dialog
                    Navigator.pop(context); // Pop upload screen
                    Navigator.pop(context); // Pop detail screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Return to Dashboard',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final programTitle = _program?['title'] ?? 'Scholarship Program';
    final providerName = (_program?['provider'] as Map<String, dynamic>?)?['name'] ?? 'Provider';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          _buildHeader(context, programTitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Application Summary Hero Card
                  _buildUploadHeroCard(programTitle, providerName),
                  const SizedBox(height: 20),

                  // Required Documents Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'REQUIRED DOCUMENTS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E3D2F),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _canSubmit ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_uploadedCount of $_requiredCount Uploaded',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _canSubmit ? const Color(0xFF15803D) : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Document Tiles List
                  ..._docs.map((d) => _buildDocTile(d)),
                  const SizedBox(height: 20),

                  // Scholar Verification Card
                  _buildScholarInfoCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isForAppeal
                              ? LucideIcons.helpCircle
                              : (_hasRejectedDoc ? LucideIcons.xCircle : LucideIcons.send),
                          size: 16,
                        ),
                  label: Text(
                    _isSubmitting
                        ? (_isForAppeal ? 'Submitting Appeal...' : 'Submitting Application...')
                        : (_isForAppeal
                            ? 'Submit Appeal'
                            : (_hasRejectedDoc
                                ? 'Fix Rejected Document to Submit'
                                : 'Submit Application')),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isForAppeal
                        ? const Color(0xFF7C3AED)
                        : (_hasRejectedDoc ? const Color(0xFFDC2626) : const Color(0xFF1E3D2F)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_uploadedCount of $_requiredCount required documents uploaded · All files encrypted',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String programTitle) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.chevronLeft,
                    color: Color(0xFF111827),
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SUBMIT APPLICATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload Requirements',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Attach documents for $programTitle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                    softWrap: true,
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
      ),
    );
  }

  // ─── Hero Progress Card ─────────────────────────────────────────────────────
  Widget _buildUploadHeroCard(String programTitle, String providerName) {
    final progress = _requiredCount > 0 ? _uploadedCount / _requiredCount : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.fileUp, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programTitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                      softWrap: true,
                    ),
                    Text(
                      providerName,
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upload Progress',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF15803D)),
              ),
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFDCFCE7),
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Document Tile Component ───────────────────────────────────────────────
  Widget _buildDocTile(_DocItem doc) {
    final isValid = doc.status == _DocStatus.valid;
    final isFlagged = doc.status == _DocStatus.flagged;
    final isRejected = doc.status == _DocStatus.rejected;
    final isScanning = doc.status == _DocStatus.scanning;
    final isOptional = doc.status == _DocStatus.optional;
    final isDisputed = doc.isDisputeSubmitted;

    Color tileBg = Colors.white;
    Color tileBorder = const Color(0xFFE5E7EB);
    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeText = const Color(0xFFD97706);
    String badgeLabel = 'Required';
    IconData leadingIcon = LucideIcons.fileUp;

    if (isScanning) {
      tileBg = const Color(0xFFF0F9FF);
      tileBorder = const Color(0xFFBAE6FD);
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = const Color(0xFF0284C7);
      badgeLabel = 'AI Scanning...';
      leadingIcon = LucideIcons.search;
    } else if (isDisputed) {
      tileBg = const Color(0xFFF5F3FF);
      tileBorder = const Color(0xFFDDD6FE);
      badgeBg = const Color(0xFFEDE9FE);
      badgeText = const Color(0xFF7C3AED);
      badgeLabel = 'Dispute Recorded';
      leadingIcon = LucideIcons.helpCircle;
    } else if (isValid) {
      tileBg = const Color(0xFFF0FDF4);
      tileBorder = const Color(0xFFDCFCE7);
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF15803D);
      final scoreStr = doc.aiConfidence != null ? ' (${(doc.aiConfidence! * 100).toInt()}%)' : '';
      badgeLabel = 'AI Verified$scoreStr';
      leadingIcon = LucideIcons.checkCircle2;
    } else if (isFlagged) {
      tileBg = const Color(0xFFFFFBEB);
      tileBorder = const Color(0xFFFDE68A);
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      badgeLabel = 'Needs Review';
      leadingIcon = LucideIcons.alertTriangle;
    } else if (isRejected) {
      tileBg = const Color(0xFFFEF2F2);
      tileBorder = const Color(0xFFFCA5A5);
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFB91C1C);
      badgeLabel = 'AI Rejected (${doc.attemptCount}/3)';
      leadingIcon = LucideIcons.xCircle;
    } else if (isOptional) {
      badgeBg = const Color(0xFFF3F4F6);
      badgeText = const Color(0xFF6B7280);
      badgeLabel = 'Optional';
      leadingIcon = LucideIcons.fileText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tileBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isScanning
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                      )
                    : Icon(leadingIcon, size: 18, color: badgeText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      (isValid || isFlagged || isRejected) && doc.filename != null
                          ? '${doc.filename} · ${doc.filesize}'
                          : doc.hint,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isValid ? const Color(0xFF15803D) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          if (isRejected && doc.aiRejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                'Reason: ${doc.aiRejectionReason}',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF991B1B), height: 1.3),
              ),
            ),
          ],
          if (doc.aiFlags != null && doc.aiFlags!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'AI Note: ${doc.aiFlags!.join(', ')}',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E), height: 1.3),
              ),
            ),
          ],
          if (isDisputed && doc.disputeNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                'Dispute Reason: ${doc.disputeNote}',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF5B21B6), height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isScanning ? null : () => _handleUpload(doc),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isRejected && doc.attemptCount >= 3 && !isDisputed
                    ? const Color(0xFFF5F3FF)
                    : ((isValid || isFlagged) ? Colors.white : const Color(0xFFFAFCFA)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRejected && doc.attemptCount >= 3 && !isDisputed
                      ? const Color(0xFF7C3AED)
                      : ((isValid || isFlagged) ? const Color(0xFFDCFCE7) : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRejected && doc.attemptCount >= 3 && !isDisputed
                          ? LucideIcons.helpCircle
                          : ((isValid || isFlagged) ? LucideIcons.rotateCcw : LucideIcons.plusCircle),
                      size: 14,
                      color: isRejected && doc.attemptCount >= 3 && !isDisputed
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF1E3D2F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isScanning
                          ? 'AI Verifying...'
                          : (isRejected && doc.attemptCount >= 3 && !isDisputed
                              ? 'Submit Appeal / Dispute'
                              : (isRejected
                                  ? 'Try Upload Again (Attempt ${doc.attemptCount}/3)'
                                  : ((isValid || isFlagged) ? 'Change Document File' : 'Select & Attach File (PDF / Image)'))),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isRejected && doc.attemptCount >= 3 && !isDisputed
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF1E3D2F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Scholar Info Card ──────────────────────────────────────────────────────
  Widget _buildScholarInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.userCheck, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text(
                'APPLICANT VERIFICATION DETAILS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16A34A),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Full Name', _scholarFullName),
          const SizedBox(height: 6),
          _buildInfoRow('School / University', _scholarSchool),
          const SizedBox(height: 6),
          _buildInfoRow('Course & Year Level', _scholarCourseAndYear),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280))),
        Flexible(
          child: Text(
            val,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─── Doc Item Model ───────────────────────────────────────────────────────────
enum _DocStatus { notUploaded, scanning, valid, flagged, rejected, optional }

class _DocItem {
  final String name;
  final String? description;
  final String hint;
  final _DocStatus status;
  final String? filename;
  final String? filesize;
  final String? fileUrl;
  final Uint8List? fileBytes;
  final double? aiConfidence;
  final String? aiRejectionReason;
  final String? aiDocumentDetected;
  final List<String>? aiFlags;
  final double? extractedGpa;
  final String? extractedGpaScale;
  final double? extractedTuitionAmount;
  final int attemptCount;
  final bool isDisputeSubmitted;
  final String? disputeNote;

  const _DocItem({
    required this.name,
    this.description,
    required this.hint,
    required this.status,
    this.filename,
    this.filesize,
    this.fileUrl,
    this.fileBytes,
    this.aiConfidence,
    this.aiRejectionReason,
    this.aiDocumentDetected,
    this.aiFlags,
    this.extractedGpa,
    this.extractedGpaScale,
    this.extractedTuitionAmount,
    this.attemptCount = 0,
    this.isDisputeSubmitted = false,
    this.disputeNote,
  });

  _DocItem copyWith({
    String? name,
    String? description,
    String? hint,
    _DocStatus? status,
    String? filename,
    String? filesize,
    String? fileUrl,
    Uint8List? fileBytes,
    double? aiConfidence,
    String? aiRejectionReason,
    String? aiDocumentDetected,
    List<String>? aiFlags,
    double? extractedGpa,
    String? extractedGpaScale,
    double? extractedTuitionAmount,
    int? attemptCount,
    bool? isDisputeSubmitted,
    String? disputeNote,
  }) {
    return _DocItem(
      name: name ?? this.name,
      description: description ?? this.description,
      hint: hint ?? this.hint,
      status: status ?? this.status,
      filename: filename ?? this.filename,
      filesize: filesize ?? this.filesize,
      fileUrl: fileUrl ?? this.fileUrl,
      fileBytes: fileBytes ?? this.fileBytes,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiRejectionReason: aiRejectionReason ?? this.aiRejectionReason,
      aiDocumentDetected: aiDocumentDetected ?? this.aiDocumentDetected,
      aiFlags: aiFlags ?? this.aiFlags,
      extractedGpa: extractedGpa ?? this.extractedGpa,
      extractedGpaScale: extractedGpaScale ?? this.extractedGpaScale,
      extractedTuitionAmount: extractedTuitionAmount ?? this.extractedTuitionAmount,
      attemptCount: attemptCount ?? this.attemptCount,
      isDisputeSubmitted: isDisputeSubmitted ?? this.isDisputeSubmitted,
      disputeNote: disputeNote ?? this.disputeNote,
    );
  }
}

// ─── Upload Progress Dialog ───────────────────────────────────────────────────
class _UploadProgressDialog extends StatefulWidget {
  final String docName;
  final String pickedFileName;
  final Future<void> Function() onComplete;

  const _UploadProgressDialog({
    required this.docName,
    required this.pickedFileName,
    required this.onComplete,
  });

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startSimulatedProgress();
  }

  void _startSimulatedProgress() async {
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) {
        setState(() {
          _progress = i / 10;
        });
      }
    }
    await widget.onComplete();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: Color(0xFF1E3D2F),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Encrypting & Uploading...',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.pickedFileName} for ${widget.docName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
