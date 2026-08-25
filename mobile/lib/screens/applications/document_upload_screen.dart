import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/services/audit_log_service.dart';

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
      _isInitialized = true;
    }
  }

  void _initializeRequirements() {
    final reqs = _program?['application_requirements'];
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
        final isRequired = r['required'] == true;
        if (name.isNotEmpty) {
          loadedDocs.add(_DocItem(
            name: name,
            hint: isRequired ? 'Required · PDF or Image' : 'Optional',
            status: isRequired ? _DocStatus.notUploaded : _DocStatus.optional,
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
  int get _uploadedCount => _docs.where((d) => d.status == _DocStatus.uploaded).length;

  bool get _canSubmit {
    return _docs.where((d) => d.status != _DocStatus.optional).every((d) => d.status == _DocStatus.uploaded);
  }

  Future<Map<String, dynamic>?> _ensureScholarProfile() async {
    if (_scholar != null && _scholar!['id'] != null) return _scholar;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

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
        _scholar = existingScholar;
        return existingScholar;
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
    if (doc.status == _DocStatus.uploaded) {
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
                content: Text('Successfully attached $fileName for ${doc.name}!'),
                backgroundColor: const Color(0xFF1E3D2F),
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
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Text(
                'No Active Cycle',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
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

    if (!_canSubmit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(
                'Incomplete Requirements',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
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
        'status': 'pending',
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
                      : const Icon(LucideIcons.send, size: 16),
                  label: Text(
                    _isSubmitting ? 'Submitting Application...' : 'Submit Application',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Attach documents for $programTitle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    final isUploaded = doc.status == _DocStatus.uploaded;
    final isOptional = doc.status == _DocStatus.optional;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUploaded ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB),
          width: 1,
        ),
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
                  color: isUploaded ? const Color(0xFFDCFCE7) : (isOptional ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUploaded ? LucideIcons.checkCircle2 : (isOptional ? LucideIcons.fileText : LucideIcons.fileUp),
                  size: 18,
                  color: isUploaded ? const Color(0xFF16A34A) : (isOptional ? const Color(0xFF6B7280) : const Color(0xFFD97706)),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      isUploaded ? '${doc.filename} · ${doc.filesize}' : doc.hint,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isUploaded ? const Color(0xFF15803D) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUploaded ? const Color(0xFFDCFCE7) : (isOptional ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUploaded ? 'Attached' : (isOptional ? 'Optional' : 'Required'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isUploaded ? const Color(0xFF15803D) : (isOptional ? const Color(0xFF6B7280) : const Color(0xFFD97706)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _handleUpload(doc),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isUploaded ? Colors.white : const Color(0xFFFAFCFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUploaded ? const Color(0xFFDCFCE7) : const Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUploaded ? LucideIcons.rotateCcw : LucideIcons.plusCircle,
                      size: 14,
                      color: const Color(0xFF1E3D2F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUploaded ? 'Change Document File' : 'Select & Attach File (PDF / Image)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3D2F),
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
enum _DocStatus { notUploaded, uploaded, optional }

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
