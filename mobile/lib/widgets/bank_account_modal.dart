import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  final String? requiredBankName;
  final VoidCallback? onSuccess;

  const BankAccountModal({
    super.key,
    required this.scholarId,
    required this.scholarName,
    this.requiredBankName,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String scholarId,
    required String scholarName,
    String? requiredBankName,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: BankAccountModal(
          scholarId: scholarId,
          scholarName: scholarName,
          requiredBankName: requiredBankName,
          onSuccess: onSuccess,
        ),
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
  late final TextStyle _titleStyle = GoogleFonts.merriweather(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A3C2E));
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

  @override
  void initState() {
    super.initState();
    _selectedBank = widget.requiredBankName ?? 'Landbank of the Philippines';
    if (!kPhilippineBanks.contains(_selectedBank)) {
      _selectedBank = 'Landbank of the Philippines';
    }
    _accountNameController = TextEditingController(text: widget.scholarName);
    _accountNumberController = TextEditingController();
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
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to pick file. Please try again.';
      });
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

      final payload = {
        'scholar_id': widget.scholarId,
        'account_type': 'bank_transfer',
        'bank_name': _selectedBank,
        'account_name': accName,
        'account_number': accNum.replaceAll(RegExp(r'\s+'), ''),
        'document_proof_url': documentProofUrl,
        'ai_extracted_data': _extractedInfo != null
            ? {
                'bank_name': _extractedInfo!.bankName,
                'account_name': _extractedInfo!.accountName,
                'account_number': _extractedInfo!.accountNumber,
                'confidence_score': _extractedInfo!.confidenceScore,
              }
            : {},
        'ai_model_used': _extractedInfo?.aiModelUsed ?? 'Manual Input',
        'is_primary': true,
        'is_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('scholar_payment_accounts').upsert(
          payload,
          onConflict: 'scholar_id',
        );
      } catch (upsertErr) {
        try {
          await Supabase.instance.client.from('scholar_payment_accounts').insert(payload);
        } catch (_) {
          await Supabase.instance.client
              .from('scholar_payment_accounts')
              .update(payload)
              .eq('scholar_id', widget.scholarId);
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
              '✓ Bank details verified & saved! Payouts are now activated.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      debugPrint('Error saving payment account: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save bank details: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        : Text('Confirm & Activate Payouts 🚀', style: _buttonStyle),
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
