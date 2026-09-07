import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/services/ai_extraction_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/services/audit_log_service.dart';

const List<String> kPhilippineBanks = [
  'Landbank of the Philippines',
  'BDO Unibank',
  'BPI (Bank of the Philippine Islands)',
  'UnionBank of the Philippines',
  'Metrobank',
  'SeaBank Philippines',
  'RCBC',
  'Security Bank',
  'Philippine National Bank (PNB)',
  'Development Bank of the Philippines (DBP)',
  'Maya Bank',
  'GoTyme Bank',
  'GCash (GSave / E-Wallet)',
  'Other Bank',
];

class BankAccountModal extends StatefulWidget {
  final String scholarId;
  final String scholarName;
  final String? programId;
  final String? applicationId;
  final String? requiredBankName;
  final VoidCallback? onSuccess;

  const BankAccountModal({
    super.key,
    required this.scholarId,
    required this.scholarName,
    this.programId,
    this.applicationId,
    this.requiredBankName,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String scholarId,
    required String scholarName,
    String? programId,
    String? applicationId,
    String? requiredBankName,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankAccountModal(
        scholarId: scholarId,
        scholarName: scholarName,
        programId: programId,
        applicationId: applicationId,
        requiredBankName: requiredBankName,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BankAccountModal> createState() => _BankAccountModalState();
}

class _BankAccountModalState extends State<BankAccountModal> {
  late String _selectedBank;
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountNumberController;

  PlatformFile? _pickedFile;
  bool _isSaving = false;
  bool _isScanning = false;
  String _scanStatus = 'AI scanning document...';
  ExtractedBankInfo? _extractedInfo;
  String? _errorMessage;

  // GoogleFonts text-style resolution is expensive, and this sheet rebuilds on
  // every frame while the keyboard animates in/out. Cache the styles once so
  // the field taps don't lag when the keyboard opens.
  late final TextStyle _badgeStyle = GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8);
  late final TextStyle _titleStyle = GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A3C2E));
  late final TextStyle _subtitleStyle = GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6C6C70), height: 1.4);
  late final TextStyle _errorStyle = GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600);
  late final TextStyle _sectionLabelStyle = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF6C6C70));
  late final TextStyle _fileNameStyle = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E));
  late final TextStyle _fileSubStyle = GoogleFonts.inter(fontSize: 10, color: const Color(0xFF6C6C70));
  late final TextStyle _accentLinkStyle = GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary);
  late final TextStyle _dropdownItemStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E));
  late final TextStyle _fieldStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600);
  late final TextStyle _hintStyle = GoogleFonts.inter(fontSize: 12, color: Colors.grey);
  late final TextStyle _accNumStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.0);
  late final TextStyle _buttonStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white);

  Map<String, dynamic>? _existingAccount;

  @override
  void initState() {
    super.initState();
    _selectedBank = widget.requiredBankName ?? 'Landbank of the Philippines';
    if (!kPhilippineBanks.contains(_selectedBank)) {
      _selectedBank = 'Landbank of the Philippines';
    }
    _accountNameController = TextEditingController(text: widget.scholarName);
    _accountNumberController = TextEditingController();
    // Defer the async fetch until after the first frame so that setState()
    // is never called before the widget tree has been laid out. Calling it
    // directly in initState() causes "Cannot hit test a render box that has
    // never been laid out" when a second program's modal opens right after
    // the first one closes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExistingAccount();
    });
  }

  Future<void> _fetchExistingAccount() async {
    try {
      // 1. Try to find account specifically for this program first
      if (widget.programId != null) {
        final data = await Supabase.instance.client
            .from('scholar_payment_accounts')
            .select()
            .eq('scholar_id', widget.scholarId)
            .eq('program_id', widget.programId!)
            .maybeSingle();

        if (data != null) {
          if (mounted) {
            setState(() {
              _existingAccount = data;
            });
          }
          return;
        }
      }

      // 2. Otherwise load any other account as a saved template
      final list = await Supabase.instance.client
          .from('scholar_payment_accounts')
          .select()
          .eq('scholar_id', widget.scholarId);

      if (list.isNotEmpty && mounted) {
        setState(() {
          _existingAccount = list.first;
        });
      }
    } catch (e) {
      debugPrint('Note fetching existing account: $e');
    }
  }

  Future<void> _useExistingAccountForProgram() async {
    if (_existingAccount == null) return;
    setState(() => _isSaving = true);

    try {
      final bankName = _existingAccount!['bank_name']?.toString() ?? 'Bank';
      final accName = _existingAccount!['account_name']?.toString() ?? widget.scholarName;
      final accNum = _existingAccount!['account_number']?.toString() ?? '';
      final docUrl = _existingAccount!['document_proof_url']?.toString() ?? '';

      List<String> programIds = [];
      List<String> applicationIds = [];

      final aiDataRaw = _existingAccount!['ai_extracted_data'];
      Map<String, dynamic> aiData = aiDataRaw is Map ? Map<String, dynamic>.from(aiDataRaw) : {};

      if (aiData['program_ids'] is List) {
        programIds = List<String>.from((aiData['program_ids'] as List).map((e) => e.toString()));
      }
      if (aiData['application_ids'] is List) {
        applicationIds = List<String>.from((aiData['application_ids'] as List).map((e) => e.toString()));
      }

      if (widget.programId != null && !programIds.contains(widget.programId)) {
        programIds.add(widget.programId!);
      }
      if (widget.applicationId != null && !applicationIds.contains(widget.applicationId)) {
        applicationIds.add(widget.applicationId!);
      }

      aiData['program_ids'] = programIds;
      aiData['application_ids'] = applicationIds;

      // Determine is_primary dynamically:
      // - Preserve is_primary of an existing record for this program
      // - Only set to true if scholar has no other payment accounts yet
      final allAccounts = await Supabase.instance.client
          .from('scholar_payment_accounts')
          .select('id, program_id, is_primary')
          .eq('scholar_id', widget.scholarId);
      final accountsList = List<Map<String, dynamic>>.from(allAccounts as List);
      final hasAny = accountsList.isNotEmpty;
      final matchingForProgram = accountsList.where(
        (a) => a['program_id']?.toString() == widget.programId,
      );
      final existingForProgram = matchingForProgram.isNotEmpty ? matchingForProgram.first : null;
      final isPrimary = existingForProgram != null
          ? existingForProgram['is_primary'] == true
          : !hasAny;

      final payload = {
        'scholar_id': widget.scholarId,
        'program_id': widget.programId,
        'account_type': 'bank_transfer',
        'bank_name': bankName,
        'account_name': accName,
        'account_number': accNum,
        'document_proof_url': docUrl,
        'ai_extracted_data': aiData,
        'is_primary': isPrimary,
        'is_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('scholar_payment_accounts').upsert(
          payload,
          onConflict: 'scholar_id, program_id',
        );
      } catch (upsertErr) {
        try {
          await Supabase.instance.client.from('scholar_payment_accounts').insert(payload);
        } catch (insertErr) {
          debugPrint('Insert fallback failed, trying update: $insertErr');
          await Supabase.instance.client
              .from('scholar_payment_accounts')
              .update(payload)
              .eq('scholar_id', widget.scholarId)
              .eq('program_id', widget.programId!);
        }
      }

      if (widget.applicationId != null && widget.applicationId!.isNotEmpty) {
        try {
          final existingApp = await Supabase.instance.client
              .from('scholarship_applications')
              .select('submitted_documents')
              .eq('id', widget.applicationId!)
              .maybeSingle();

          Map<String, dynamic> submittedDocs = {};
          if (existingApp != null && existingApp['submitted_documents'] is Map) {
            submittedDocs = Map<String, dynamic>.from(existingApp['submitted_documents']);
          }

          submittedDocs['bank_details'] = {
            'bank_name': bankName,
            'account_name': accName,
            'account_number': accNum,
            'document_proof_url': docUrl,
            'updated_at': DateTime.now().toIso8601String(),
          };

          await Supabase.instance.client
              .from('scholarship_applications')
              .update({'submitted_documents': submittedDocs})
              .eq('id', widget.applicationId!);
        } catch (appErr) {
          debugPrint('Note updating application submitted_documents: $appErr');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attached $bankName account to this scholarship program!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      debugPrint('Error attaching saved bank account: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to attach bank account: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        if (!mounted) return;
        setState(() {
          _pickedFile = picked;
          _isScanning = true;
          _scanStatus = 'AI analyzing card scan & extracting details...';
          _errorMessage = null;
        });

        // Read bytes directly from memory or disk
        Uint8List? bytes = picked.bytes;
        if (bytes == null && picked.path != null) {
          try {
            bytes = await File(picked.path!).readAsBytes();
          } catch (readErr) {
            debugPrint('Error reading file bytes: $readErr');
          }
        }

        if (bytes != null || picked.path != null) {
          try {
            final extracted = await AiExtractionService.extractBankDetails(
              fileBytes: bytes ?? Uint8List(0),
              fileName: picked.name,
              filePath: picked.path,
            );

            if (mounted && extracted != null) {
              setState(() {
                _extractedInfo = extracted;

                // Auto-fill bank name
                for (final b in kPhilippineBanks) {
                  if (b.toLowerCase().contains(extracted.bankName.toLowerCase()) ||
                      extracted.bankName.toLowerCase().contains(b.toLowerCase())) {
                    _selectedBank = b;
                    break;
                  }
                }

                // Auto-fill account holder name
                if (extracted.accountName.isNotEmpty) {
                  _accountNameController.text = extracted.accountName;
                }

                // Auto-fill account number
                if (extracted.accountNumber.isNotEmpty) {
                  _accountNumberController.text = extracted.accountNumber;
                  _accountNumberController.selection = TextSelection.fromPosition(
                    TextPosition(offset: extracted.accountNumber.length),
                  );
                }
              });
            } else if (mounted) {
              setState(() {
                _errorMessage = 'AI finished scan. Please verify or complete your account details below.';
              });
            }
          } catch (scanErr) {
            debugPrint('AI Scan error: $scanErr');
          } finally {
            if (mounted) setState(() => _isScanning = false);
          }
        } else {
          if (mounted) setState(() => _isScanning = false);
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Failed to pick file. Please try again.';
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final accNum = _accountNumberController.text.trim();
    final accName = _accountNameController.text.trim();

    if (accNum.isEmpty) {
      setState(() => _errorMessage = 'Please enter your bank account number.');
      return;
    }
    if (accName.isEmpty) {
      setState(() => _errorMessage = 'Please enter the account holder name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String documentProofUrl = '';

      if (_pickedFile != null) {
        final ext = _pickedFile!.extension ?? 'jpg';
        final fileName = 'bank_proof_${widget.scholarId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = 'bank_documents/$fileName';

        try {
          if (kIsWeb && _pickedFile!.bytes != null) {
            await Supabase.instance.client.storage
                .from('bank-proofs')
                .uploadBinary(path, _pickedFile!.bytes!);
          } else if (_pickedFile!.path != null) {
            await Supabase.instance.client.storage
                .from('bank-proofs')
                .upload(path, File(_pickedFile!.path!));
          } else if (_pickedFile!.bytes != null) {
            await Supabase.instance.client.storage
                .from('bank-proofs')
                .uploadBinary(path, _pickedFile!.bytes!);
          }
          documentProofUrl = Supabase.instance.client.storage.from('bank-proofs').getPublicUrl(path);
        } catch (_) {
          try {
            if (kIsWeb && _pickedFile!.bytes != null) {
              await Supabase.instance.client.storage
                  .from('scholar-documents')
                  .uploadBinary(path, _pickedFile!.bytes!);
            } else if (_pickedFile!.path != null) {
              await Supabase.instance.client.storage
                  .from('scholar-documents')
                  .upload(path, File(_pickedFile!.path!));
            } else if (_pickedFile!.bytes != null) {
              await Supabase.instance.client.storage
                  .from('scholar-documents')
                  .uploadBinary(path, _pickedFile!.bytes!);
            }
            documentProofUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(path);
          } catch (e) {
            debugPrint('Storage upload note: $e');
          }
        }
      }

      List<String> programIds = [];
      List<String> applicationIds = [];

      if (_existingAccount != null && _existingAccount!['ai_extracted_data'] is Map) {
        final existingProgs = _existingAccount!['ai_extracted_data']['program_ids'];
        if (existingProgs is List) {
          programIds = List<String>.from(existingProgs.map((e) => e.toString()));
        }
        final existingApps = _existingAccount!['ai_extracted_data']['application_ids'];
        if (existingApps is List) {
          applicationIds = List<String>.from(existingApps.map((e) => e.toString()));
        }
      }

      if (widget.programId != null && !programIds.contains(widget.programId)) {
        programIds.add(widget.programId!);
      }
      if (widget.applicationId != null && !applicationIds.contains(widget.applicationId)) {
        applicationIds.add(widget.applicationId!);
      }

      final Map<String, dynamic> aiData = _extractedInfo != null
          ? {
              'bank_name': _extractedInfo!.bankName,
              'account_name': _extractedInfo!.accountName,
              'account_number': _extractedInfo!.accountNumber,
              'confidence_score': _extractedInfo!.confidenceScore,
            }
          : {};
      aiData['program_ids'] = programIds;
      aiData['application_ids'] = applicationIds;

      // Determine is_primary dynamically:
      // - Preserve is_primary of an existing record for this program
      // - Only set to true if scholar has no other payment accounts yet
      final allAccounts = await Supabase.instance.client
          .from('scholar_payment_accounts')
          .select('id, program_id, is_primary')
          .eq('scholar_id', widget.scholarId);
      final accountsList = List<Map<String, dynamic>>.from(allAccounts as List);
      final hasAny = accountsList.isNotEmpty;
      final matchingForProgram = accountsList.where(
        (a) => a['program_id']?.toString() == widget.programId,
      );
      final existingForProgram = matchingForProgram.isNotEmpty ? matchingForProgram.first : null;
      final isPrimary = existingForProgram != null
          ? existingForProgram['is_primary'] == true
          : !hasAny;

      final payload = {
        'scholar_id': widget.scholarId,
        'program_id': widget.programId,
        'account_type': 'bank_transfer',
        'bank_name': _selectedBank,
        'account_name': accName,
        'account_number': accNum.replaceAll(RegExp(r'\s+'), ''),
        'document_proof_url': documentProofUrl,
        'ai_extracted_data': aiData,
        'ai_model_used': _extractedInfo?.aiModelUsed ?? 'Manual Input',
        'is_primary': isPrimary,
        'is_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('scholar_payment_accounts').upsert(
          payload,
          onConflict: 'scholar_id, program_id',
        );
      } catch (upsertErr) {
        try {
          await Supabase.instance.client.from('scholar_payment_accounts').insert(payload);
        } catch (insertErr) {
          debugPrint('Insert fallback failed, trying update: $insertErr');
          await Supabase.instance.client
              .from('scholar_payment_accounts')
              .update(payload)
              .eq('scholar_id', widget.scholarId)
              .eq('program_id', widget.programId!);
        }
      }

      if (widget.applicationId != null && widget.applicationId!.isNotEmpty) {
        try {
          final existingApp = await Supabase.instance.client
              .from('scholarship_applications')
              .select('submitted_documents')
              .eq('id', widget.applicationId!)
              .maybeSingle();

          Map<String, dynamic> submittedDocs = {};
          if (existingApp != null && existingApp['submitted_documents'] is Map) {
            submittedDocs = Map<String, dynamic>.from(existingApp['submitted_documents']);
          }

          submittedDocs['bank_details'] = {
            'bank_name': _selectedBank,
            'account_name': accName,
            'account_number': accNum.replaceAll(RegExp(r'\s+'), ''),
            'document_proof_url': documentProofUrl,
            'updated_at': DateTime.now().toIso8601String(),
          };

          await Supabase.instance.client
              .from('scholarship_applications')
              .update({'submitted_documents': submittedDocs})
              .eq('id', widget.applicationId!);
        } catch (appErr) {
          debugPrint('Note updating application submitted_documents: $appErr');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        AuditLogService.createAuditLog(
          action: 'REGISTERED BANK DETAILS',
          target: 'Bank: $_selectedBank | Account: ${_accountNumberController.text}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bank details verified & saved! Payouts are now activated.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      debugPrint('Error saving payment account: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save bank details: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF5EE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                            child: Text(
                              'POST-APPROVAL REQUIREMENT',
                              style: _badgeStyle,
                            ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submit Bank Account Proof',
                          style: _titleStyle,
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your ATM card scan (PDF or Photo). The built-in AI will automatically scan and fill your account details.',
                  style: _subtitleStyle,
                ),
                const SizedBox(height: 16),

                if (_existingAccount != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                          child: const Center(child: Icon(LucideIcons.creditCard, size: 16, color: Color(0xFF15803D))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved Account Available',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A3C2E)),
                              ),
                              Text(
                                '${_existingAccount!['bank_name']} (${_existingAccount!['account_number']})',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF6C6C70)),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _useExistingAccountForProgram,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(60, 30), // Fix global infinite width theme constraint
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text('Attach Account', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: _errorStyle,
                    ),
                  ),

                // 1. Upload Button
                Text(
                  '1. SELECT ATM CARD / BANK PROOF (PDF OR PHOTO)',
                  style: _sectionLabelStyle,
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isScanning ? null : _pickDocument,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F5EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _pickedFile != null ? AppColors.primary : const Color(0xFFD9D2C5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _pickedFile != null ? const Color(0xFFEBF5EE) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : Icon(
                                  _pickedFile != null ? LucideIcons.fileCheck : LucideIcons.uploadCloud,
                                  color: _pickedFile != null ? AppColors.primary : Colors.grey,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning
                                    ? _scanStatus
                                    : (_pickedFile != null ? _pickedFile!.name : 'Choose ATM Card Scan (PDF / Image)'),
                                style: _fileNameStyle.copyWith(
                                  color: _pickedFile != null ? AppColors.primary : const Color(0xFF1C1C1E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isScanning
                                    ? 'Analyzing card scan & extracting details...'
                                    : (_pickedFile != null ? 'File ready • AI Auto-Scanned' : 'Tap to select PDF or image file'),
                                style: _fileSubStyle,
                              ),
                            ],
                          ),
                        ),
                        if (_pickedFile != null && !_isScanning)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF5EE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Change',
                              style: _accentLinkStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // AI Extraction Badge
                if (_extractedInfo != null && !_isScanning) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI Auto-Scanned (${_extractedInfo!.aiModelUsed}): Details extracted. Please verify below.',
                            style: _accentLinkStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // 2. Bank Name
                Text('2. BANK NAME', style: _sectionLabelStyle),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F5EF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9D2C5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBank,
                      isExpanded: true,
                      items: kPhilippineBanks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank,
                          child: Text(bank, style: _dropdownItemStyle),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBank = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Account Name
                Text('3. ACCOUNT HOLDER NAME', style: _sectionLabelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: _accountNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Full Name as printed on ATM Card',
                    hintStyle: _hintStyle,
                    filled: true,
                    fillColor: const Color(0xFFF9F5EF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9D2C5))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9D2C5))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                  style: _fieldStyle,
                ),
                const SizedBox(height: 16),

                // 4. Account Number
                Text('4. BANK ACCOUNT / ATM CARD NUMBER', style: _sectionLabelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1234-5678-90 (Auto-filled by AI)',
                    hintStyle: _hintStyle,
                    filled: true,
                    fillColor: const Color(0xFFF9F5EF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9D2C5))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9D2C5))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                  style: _accNumStyle,
                ),
                const SizedBox(height: 22),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Confirm & Activate Payouts', style: _buttonStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
