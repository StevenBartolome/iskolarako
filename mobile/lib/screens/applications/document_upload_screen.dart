import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/services/audit_log_service.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final int _step = 2; // Step 2 is document upload (after details / before review)
  static const int _totalSteps = 3;

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
      _isInitialized = true;
    }
  }

  void _initializeRequirements() {
    final reqs = _program?['application_requirements'];
    if (reqs == null) {
      // Fallback default requirements
      _docs = [
        const _DocItem(
          name: 'PSA Birth Certificate',
          hint: 'Required · Not yet uploaded',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'Form 138 / Report Card',
          hint: 'Required · Not yet uploaded',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'ITR or Cert. of Indigency',
          hint: 'Required · Not yet uploaded',
          status: _DocStatus.notUploaded,
        ),
        const _DocItem(
          name: 'Valid Government ID',
          hint: 'Required · Not yet uploaded',
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
        final isRequired = r['required'] == true;
        if (name.isNotEmpty) {
          loadedDocs.add(_DocItem(
            name: name,
            hint: isRequired ? 'Required · Not yet uploaded' : 'Optional',
            status: isRequired ? _DocStatus.notUploaded : _DocStatus.optional,
          ));
        }
      }
    }

    if (loadedDocs.isEmpty) {
      loadedDocs.add(const _DocItem(
        name: 'Scholarship Application Form',
        hint: 'Required · Not yet uploaded',
        status: _DocStatus.notUploaded,
      ));
    }

    setState(() {
      _docs = loadedDocs;
    });
  }

  String get _scholarFullName {
    if (_scholar == null) return 'N/A';
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
  int get _uploadedCount => _docs.where((d) => d.status == _DocStatus.uploaded).length;

  bool get _canSubmit {
    return _docs.where((d) => d.status != _DocStatus.optional).every((d) => d.status == _DocStatus.uploaded);
  }

  Future<Map<String, dynamic>?> _ensureScholarProfile() async {
    if (_scholar != null && _scholar!['id'] != null) return _scholar;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Ensure user row exists in public.users table
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

      // 2. Fetch or insert scholar row in public.scholar table
      final existingScholar = await Supabase.instance.client
          .from('scholar')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingScholar != null) {
        _scholar = existingScholar;
        return existingScholar;
      }

      // If no scholar row exists, insert one
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
    if (doc.status == _DocStatus.uploaded) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                  title: Text(
                    'Remove ${doc.name}',
                    style: GoogleFonts.inter(
                        color: AppColors.error, fontWeight: FontWeight.w600),
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
                              ? 'Required · Not yet uploaded'
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
                  leading: const Icon(LucideIcons.eye),
                  title: Text('View File', style: GoogleFonts.inter()),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening ${doc.filename}...')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
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
      final messenger = ScaffoldMessenger.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UploadProgressDialog(
          docName: doc.name,
          pickedFileName: fileName,
          onComplete: () async {
            String? uploadedUrl;
            try {
              final bytes = pickedFile.bytes;
              if (bytes != null) {
                final scholar = await _ensureScholarProfile();
                final scholarId = scholar?['id'] ?? 'guest';
                final cycleId = _cycle?['id'] ?? 'cycle';
                final timeStamp = DateTime.now().millisecondsSinceEpoch;
                final storagePath = '$scholarId/${cycleId}_${timeStamp}_$fileName';

                // 1. Try Supabase storage upload & ensure bucket exists
                try {
                  try {
                    await Supabase.instance.client.storage.createBucket(
                      'scholar-documents',
                      const BucketOptions(public: true),
                    );
                  } catch (bErr) {
                    debugPrint('Bucket auto-create info: $bErr');
                  }

                  await Supabase.instance.client.storage
                      .from('scholar-documents')
                      .uploadBinary(storagePath, bytes);

                  uploadedUrl = Supabase.instance.client.storage
                      .from('scholar-documents')
                      .getPublicUrl(storagePath);
                } catch (_) {
                  // Fallback: convert bytes to Data URL if storage bucket doesn't exist
                  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
                  String mimeType = 'application/pdf';
                  if (ext == 'jpg' || ext == 'jpeg') {
                    mimeType = 'image/jpeg';
                  } else if (ext == 'png') {
                    mimeType = 'image/png';
                  } else if (ext == 'doc' || ext == 'docx') {
                    mimeType = 'application/msword';
                  }

                  final base64Content = base64Encode(bytes);
                  uploadedUrl = 'data:$mimeType;base64,$base64Content';
                }

                if (scholarId != null && scholarId != 'guest') {
                  try {
                    await Supabase.instance.client.from('scholar_documents').insert({
                      'scholar_id': scholarId,
                      'document_name': doc.name,
                      'document_url': uploadedUrl,
                      'verification_status': 'pending',
                    });
                  } catch (docErr) {
                    debugPrint('Scholar documents table insert note: $docErr');
                  }
                }
              }
            } catch (e) {
              debugPrint('Upload processing error: $e');
            }

            if (!mounted) return;
            setState(() {
              final idx = _docs.indexOf(doc);
              if (idx != -1) {
                _docs[idx] = doc.copyWith(
                  status: _DocStatus.uploaded,
                  filename: fileName,
                  filesize: sizeStr,
                  fileUrl: uploadedUrl,
                );
              }
            });

            messenger.showSnackBar(
              SnackBar(
                content: Text('Successfully uploaded $fileName for ${doc.name}!'),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('File picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file picker: $e')),
      );
    }
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
              const Icon(LucideIcons.alertTriangle, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'No Active Cycle',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'This scholarship program currently has no active application cycle open.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
              const Icon(LucideIcons.alertTriangle, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                'Incomplete Uploads',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'Please upload all required documents before submitting your application.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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

    if (scholarId == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to resolve scholar profile. Please complete your profile first.'),
            backgroundColor: AppColors.error,
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
          .where((d) => d.status == _DocStatus.uploaded)
          .map((d) => {
                'name': d.name,
                'document_name': d.name,
                'filename': d.filename,
                'filesize': d.filesize,
                'document_url': d.fileUrl ?? '',
                'submitted_at': DateTime.now().toIso8601String(),
              })
          .toList();

      final payload = {
        'cycle_id': cycleId,
        'scholar_id': scholarId,
        'status': 'pending', // Per DB CHECK constraint (pending, under_review, for_exam, approved, rejected, withdrawn)
        'submitted_documents': {
          'reference_number': refNum,
          'documents': uploadedDocsList,
        },
        'remarks': 'Submitted via mobile app',
      };

      await Supabase.instance.client.from('scholarship_applications').insert(payload);
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
              const Icon(LucideIcons.alertTriangle, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Submission Error',
                  style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              errorMessage ?? 'An error occurred while submitting your application.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Application Submitted!',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ref #: $refNum',
              style: GoogleFonts.dmMono(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your application for ${_program?['title'] ?? 'this scholarship'} has been submitted successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Back to Dashboard',
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context); // Pop upload screen
                Navigator.pop(context); // Pop detail screen
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildUploadZone(),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Required Documents'),
                  const SizedBox(height: 12),
                  ..._docs.map((d) => _DocTile(
                        doc: d,
                        onTap: () => _handleUpload(d),
                      )),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Personal Information'),
                  const SizedBox(height: 12),
                  _buildField('Full Name', _scholarFullName),
                  const SizedBox(height: 10),
                  _buildField('Course & Year', _scholarCourseAndYear),
                  const SizedBox(height: 10),
                  _buildField('School / University', _scholarSchool),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.rule)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Save Draft',
                      isOutlined: true,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Draft saved successfully!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: 'Submit Application',
                      icon: LucideIcons.send,
                      isLoading: _isSubmitting,
                      onPressed: _submitApplication,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$_uploadedCount of $_requiredCount documents uploaded · Complete all required files to submit',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      size: 14,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DOCUMENT REPOSITORY',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amberDeep,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.rule, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.chevronLeft,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Upload\ndocuments.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    height: 1.15,
                  ),
                ),
                Row(
                  children: List.generate(_totalSteps, (i) {
                    final active = i == _step - 1;
                    final done = i < _step - 1;
                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.primary
                            : active
                                ? AppColors.amber
                                : AppColors.rule,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Step $_step of $_totalSteps — Upload requirements for verification',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: () {
        final firstPending = _docs.firstWhere(
          (d) => d.status == _DocStatus.notUploaded || d.status == _DocStatus.optional || d.status == _DocStatus.pending,
          orElse: () => _docs.first,
        );
        _handleUpload(firstPending);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withAlpha(80),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.uploadCloud,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to upload or pick a file',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, JPG, PNG, DOC · Max 10 MB per file',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rule),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Doc tile ────────────────────────────────────────────────────────────────

enum _DocStatus { uploaded, pending, notUploaded, optional }

class _DocItem {
  final String name;
  final String hint;
  final _DocStatus status;
  final String? filename;
  final String? filesize;
  final String? fileUrl;

  const _DocItem({
    required this.name,
    required this.hint,
    required this.status,
    this.filename,
    this.filesize,
    this.fileUrl,
  });

  _DocItem copyWith({
    String? name,
    String? hint,
    _DocStatus? status,
    String? filename,
    String? filesize,
    String? fileUrl,
  }) {
    return _DocItem(
      name: name ?? this.name,
      hint: hint ?? this.hint,
      status: status ?? this.status,
      filename: filename ?? this.filename,
      filesize: filesize ?? this.filesize,
      fileUrl: fileUrl ?? this.fileUrl,
    );
  }
}

class _DocTile extends StatelessWidget {
  final _DocItem doc;
  final VoidCallback? onTap;

  const _DocTile({required this.doc, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color iconBg;
    Color iconColor;
    Widget trailing;
    Widget leadingIcon;

    switch (doc.status) {
      case _DocStatus.uploaded:
        borderColor = AppColors.primary.withAlpha(60);
        iconBg = AppColors.successBg;
        iconColor = AppColors.primary;
        leadingIcon = const Icon(LucideIcons.check, size: 18);
        trailing = StatusChip(label: 'Uploaded', type: StatusType.approved);
        break;
      case _DocStatus.pending:
        borderColor = AppColors.amber.withAlpha(80);
        iconBg = AppColors.pendingBg;
        iconColor = AppColors.amber;
        leadingIcon = const Icon(LucideIcons.uploadCloud, size: 18);
        trailing = StatusChip(label: 'Pending', type: StatusType.pending);
        break;
      case _DocStatus.notUploaded:
        borderColor = AppColors.rule;
        iconBg = AppColors.surfaceAlt;
        iconColor = AppColors.textMuted;
        leadingIcon = const Icon(LucideIcons.fileText, size: 18);
        trailing = StatusChip(label: 'Upload', type: StatusType.info);
        break;
      case _DocStatus.optional:
        borderColor = AppColors.rule;
        iconBg = AppColors.surfaceAlt;
        iconColor = AppColors.textMuted;
        leadingIcon = const Icon(LucideIcons.fileText, size: 18);
        trailing = StatusChip(label: 'Optional', type: StatusType.info);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: doc.status == _DocStatus.pending
                ? AppColors.pendingBg
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ColoredBox(
                  color: Colors.transparent,
                  child: IconTheme(
                    data: IconThemeData(color: iconColor),
                    child: Center(child: leadingIcon),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.filename != null
                          ? '${doc.filename} · ${doc.filesize}'
                          : doc.hint,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

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
    _startProgress();
  }

  void _startProgress() {
    const steps = 10;
    const duration = Duration(milliseconds: 100);
    int currentStep = 0;

    void updateProgress() {
      Future.delayed(duration, () async {
        if (!mounted) return;
        currentStep++;
        setState(() {
          _progress = currentStep / steps;
        });
        if (currentStep < steps) {
          updateProgress();
        } else {
          Navigator.pop(context); // Close progress dialog
          await widget.onComplete();
        }
      });
    }
    updateProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Uploading ${widget.pickedFileName}...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              widget.docName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.rule,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}% uploaded',
              style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
