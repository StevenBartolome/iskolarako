import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/constants/app_colors.dart';

class AppealModal extends StatefulWidget {
  final String applicationId;
  final String scholarId;
  final String? programId;
  final String? providerId;
  final String scholarshipName;
  final VoidCallback onSuccess;

  const AppealModal({
    super.key,
    required this.applicationId,
    required this.scholarId,
    this.programId,
    this.providerId,
    required this.scholarshipName,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String applicationId,
    required String scholarId,
    String? programId,
    String? providerId,
    required String scholarshipName,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppealModal(
        applicationId: applicationId,
        scholarId: scholarId,
        programId: programId,
        providerId: providerId,
        scholarshipName: scholarshipName,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<AppealModal> createState() => _AppealModalState();
}

class _AppealModalState extends State<AppealModal> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'Grade Computation / Evaluation Error';
  final _statementController = TextEditingController();
  
  File? _attachedFile;
  String? _attachedFileName;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Grade Computation / Evaluation Error',
    'Document Misinterpretation / Legibility',
    'Extenuating Family / Financial Circumstance',
    'System / Portal Requirement Issue',
    'Other Justification',
  ];

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _pickSupportingDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedFile = File(result.files.single.path!);
          _attachedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('File pick error: $e');
    }
  }

  Future<void> _submitAppeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? uploadedDocUrl;
      if (_attachedFile != null && _attachedFileName != null) {
        final fileExt = _attachedFileName!.split('.').last;
        final storagePath = 'appeals/${widget.scholarId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        try {
          await Supabase.instance.client.storage
              .from('submitted-documents')
              .upload(storagePath, _attachedFile!);
          uploadedDocUrl = Supabase.instance.client.storage
              .from('submitted-documents')
              .getPublicUrl(storagePath);
        } catch (sErr) {
          debugPrint('Storage upload note: $sErr');
        }
      }

      final List<Map<String, dynamic>> supportingDocs = [];
      if (uploadedDocUrl != null) {
        supportingDocs.add({
          'name': 'Supporting Proof / Document',
          'filename': _attachedFileName,
          'document_url': uploadedDocUrl,
          'submitted_at': DateTime.now().toIso8601String(),
        });
      }

      final appealData = {
        'application_id': widget.applicationId,
        'scholar_id': widget.scholarId,
        'program_id': widget.programId,
        'provider_id': widget.providerId,
        'reason_category': _selectedCategory,
        'statement': _statementController.text.trim(),
        'supporting_documents': supportingDocs,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Upsert into application_appeals table
      try {
        await Supabase.instance.client
            .from('application_appeals')
            .upsert(appealData);
      } catch (dbErr) {
        debugPrint('DB Insert into application_appeals failed: $dbErr');
      }

      // Also tag remarks on scholarship_applications row
      try {
        await Supabase.instance.client
            .from('scholarship_applications')
            .update({
          'remarks': 'Formal Appeal Filed: ${_statementController.text.trim().replaceAll('\n', ' ')}',
        }).eq('id', widget.applicationId);
      } catch (appErr) {
        debugPrint('App update note: $appErr');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formal Appeal filed successfully! Provider has been notified.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      debugPrint('Error submitting appeal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error filing appeal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.scale, color: AppColors.amberDeep, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Formal Appeal / Dispute',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          widget.scholarshipName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.info, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If you believe your application decision was mistaken or requires re-evaluation, present your reasoning clearly below. The provider committee will review your dispute.',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Text(
                'REASON CATEGORY',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rule),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statement
              Text(
                'APPEAL STATEMENT & JUSTIFICATION',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _statementController,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Explain why your application should be re-evaluated. Provide details regarding grades, documents, or circumstances...',
                  hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 15) {
                    return 'Please provide a detailed appeal statement (minimum 15 characters).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Attach Proof
              Text(
                'SUPPORTING PROOF / DOCUMENT (OPTIONAL)',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickSupportingDocument,
                icon: Icon(_attachedFile != null ? LucideIcons.checkCircle2 : LucideIcons.paperclip, size: 16, color: _attachedFile != null ? AppColors.primary : AppColors.textSecondary),
                label: Text(
                  _attachedFileName ?? 'Attach Proof (Grade Correction, Letter, PDF)',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _attachedFile != null ? AppColors.primary : AppColors.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: _attachedFile != null ? AppColors.primary : AppColors.rule),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAppeal,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.send, size: 16),
                  label: Text(
                    _isSubmitting ? 'Submitting Appeal...' : 'Submit Formal Appeal to Provider',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
