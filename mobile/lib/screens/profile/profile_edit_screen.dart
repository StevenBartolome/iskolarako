import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Independent Section Edit Controls
  bool _editingAcademic = false;
  bool _editingPersonal = false;
  bool _editingAddress = false;

  bool get _isAnyEditing => _editingAcademic || _editingPersonal || _editingAddress;

  String _userEmail = '';
  String? _avatarUrl;
  bool _isUploadingPhoto = false;

  // Personal Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _phoneController = TextEditingController();
  final _citizenshipController = TextEditingController(text: 'Filipino');
  DateTime? _selectedBirthDate;
  String? _selectedGender;

  // Location / Address (PSGC API)
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _municipalities = [];
  List<Map<String, dynamic>> _barangays = [];

  String? _selectedRegionCode;
  String? _selectedRegionName;
  String? _selectedProvinceCode;
  String? _selectedProvinceName;
  String? _selectedMunicipalityCode;
  String? _selectedMunicipalityName;
  String? _selectedBarangayName;

  // Academic Info
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  final _gpaController = TextEditingController();
  int? _selectedYearLevel;
  String _educationLevel = 'college'; // college, graduate, senior_high, vocational, incoming_college
  String _gpaScale = 'scale_5';       // scale_5, scale_4, percentage

  static const Map<String, String> _eduLabels = {
    'college': 'Undergraduate / College',
    'graduate': 'Graduate Studies (MA/PhD)',
    'senior_high': 'Senior High School (SHS)',
    'vocational': 'Vocational / TVET',
    'incoming_college': 'Incoming College (Graduating SHS)',
  };

  static const Map<String, String> _scaleLabels = {
    'scale_5': '1.0–5.0 Scale (1.0 = Highest)',
    'scale_4': '4.0 Scale (4.0 = Highest)',
    'percentage': 'Percentage Scale (60–100%)',
  };

  static const Map<String, String> _scaleExplanations = {
    'scale_5': '1.0 is Highest / Excellent • Lower score = Better performance',
    'scale_4': '4.0 is Highest / Outstanding • Higher score = Better performance',
    'percentage': '100% is Highest • Percentage average grade system',
  };

  String? _getSafeGenderValue() {
    if (_selectedGender == null) return null;
    final val = _selectedGender!.trim().toLowerCase();
    if (val == 'male') return 'Male';
    if (val == 'female') return 'Female';
    if (val.contains('non')) return 'Non-binary';
    if (val.contains('prefer')) return 'Prefer not to say';
    return null;
  }

  String _getSafeEducationLevel() {
    if (_eduLabels.containsKey(_educationLevel)) return _educationLevel;
    final val = _educationLevel.toLowerCase().trim();
    if (val.contains('undergrad') || val.contains('college')) return 'college';
    if (val.contains('grad')) return 'graduate';
    if (val.contains('high') || val.contains('shs')) return 'senior_high';
    if (val.contains('vocational') || val.contains('tvet')) return 'vocational';
    return 'college';
  }

  String _getSafeGpaScale() {
    if (_scaleLabels.containsKey(_gpaScale)) return _gpaScale;
    final val = _gpaScale.toLowerCase().trim();
    if (val.contains('5')) return 'scale_5';
    if (val.contains('4')) return 'scale_4';
    if (val.contains('percent') || val.contains('100')) return 'percentage';
    return 'scale_5';
  }

  int? _getSafeYearLevel() {
    if (_selectedYearLevel != null && _selectedYearLevel! >= 1 && _selectedYearLevel! <= 5) {
      return _selectedYearLevel;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _phoneController.dispose();
    _citizenshipController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  // ── PSGC API Calls ─────────────────────────────────────────────────────────

  Future<void> _fetchRegions() async {
    try {
      final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _regions = data.map((r) => {'code': r['code'], 'name': r['name']}).toList();
            _regions.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching regions: $e');
    }
  }

  Future<void> _fetchProvinces(String regionCode) async {
    try {
      final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/$regionCode/provinces/'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _provinces = data.map((p) => {'code': p['code'], 'name': p['name']}).toList();
            _provinces.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    }
  }

  Future<void> _fetchMunicipalities(String provinceCode) async {
    try {
      final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/provinces/$provinceCode/cities-municipalities/'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _municipalities = data.map((m) => {'code': m['code'], 'name': m['name']}).toList();
            _municipalities.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching municipalities: $e');
    }
  }

  Future<void> _fetchBarangays(String municipalityCode) async {
    try {
      final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/cities-municipalities/$municipalityCode/barangays/'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _barangays = data.map((b) => {'name': b['name']}).toList();
            _barangays.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching barangays: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _userEmail = user.email ?? '';
      });
    }

    try {
      final dataList = await Supabase.instance.client
          .from('scholar')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (dataList != null) {
        _firstNameController.text = dataList['first_name'] ?? '';
        _lastNameController.text = dataList['last_name'] ?? '';
        _middleNameController.text = dataList['middle_name'] ?? '';
        _suffixController.text = dataList['suffix'] ?? '';
        _phoneController.text = dataList['phone'] ?? '';
        _citizenshipController.text = dataList['citizenship'] ?? 'Filipino';
        _schoolController.text = dataList['school'] ?? '';
        _courseController.text = dataList['course'] ?? '';
        _selectedYearLevel = dataList['year_level'];
        _gpaController.text = dataList['gpa'] != null ? dataList['gpa'].toString() : '';
        _selectedGender = dataList['gender'];
        _educationLevel = dataList['education_level'] ?? 'college';
        final scholarAvatar = dataList['avatar_url']?.toString().trim();
        final metaAvatar = user.userMetadata?['avatar_url']?.toString().trim();
        if (scholarAvatar != null && scholarAvatar.isNotEmpty && scholarAvatar != 'null') {
          _avatarUrl = scholarAvatar;
        } else if (metaAvatar != null && metaAvatar.isNotEmpty && metaAvatar != 'null') {
          _avatarUrl = metaAvatar;
        } else {
          _avatarUrl = null;
        }

        _selectedRegionName = dataList['region']?.toString();
        _selectedProvinceName = dataList['province']?.toString();
        _selectedMunicipalityName = dataList['municipality']?.toString();
        _selectedBarangayName = dataList['barangay']?.toString();

        if (dataList['birth_date'] != null) {
          _selectedBirthDate = DateTime.tryParse(dataList['birth_date']);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Populate PSGC dropdowns in background without blocking UI render
    _populatePsgcDropdowns();
  }

  Future<void> _populatePsgcDropdowns() async {
    try {
      await _fetchRegions();
      if (_selectedRegionName != null && _selectedRegionName!.isNotEmpty && _regions.isNotEmpty) {
        final regionMatch = _regions.firstWhere(
          (r) => r['name'].toString().toLowerCase().trim() == _selectedRegionName!.toLowerCase().trim(),
          orElse: () => <String, dynamic>{},
        );
        if (regionMatch.isNotEmpty) {
          _selectedRegionCode = regionMatch['code'];
          await _fetchProvinces(_selectedRegionCode!);

          if (_selectedProvinceName != null && _selectedProvinceName!.isNotEmpty && _provinces.isNotEmpty) {
            final provinceMatch = _provinces.firstWhere(
              (p) => p['name'].toString().toLowerCase().trim() == _selectedProvinceName!.toLowerCase().trim(),
              orElse: () => <String, dynamic>{},
            );
            if (provinceMatch.isNotEmpty) {
              _selectedProvinceCode = provinceMatch['code'];
              await _fetchMunicipalities(_selectedProvinceCode!);

              if (_selectedMunicipalityName != null && _selectedMunicipalityName!.isNotEmpty && _municipalities.isNotEmpty) {
                final muniMatch = _municipalities.firstWhere(
                  (m) => m['name'].toString().toLowerCase().trim() == _selectedMunicipalityName!.toLowerCase().trim(),
                  orElse: () => <String, dynamic>{},
                );
                if (muniMatch.isNotEmpty) {
                  _selectedMunicipalityCode = muniMatch['code'];
                  await _fetchBarangays(_selectedMunicipalityCode!);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error populating PSGC dropdowns in background: $e');
    }
  }

  // ── Section Save Actions ───────────────────────────────────────────────────

  Future<void> _saveAcademicSection() async {
    if (_schoolController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _gpaController.text.trim().isEmpty ||
        double.tryParse(_gpaController.text.trim()) == null) {
      _showSnackBar('Please fill out all required academic fields.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('scholar').upsert({
          'user_id': user.id,
          'first_name': _firstNameController.text.trim().isNotEmpty ? _firstNameController.text.trim() : 'Scholar',
          'last_name': _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : 'Student',
          'school': _schoolController.text.trim(),
          'course': _courseController.text.trim(),
          'year_level': _selectedYearLevel,
          'education_level': _educationLevel,
          'gpa': double.tryParse(_gpaController.text.trim()),
          'gpa_scale': _gpaScale,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (mounted) {
          _showSnackBar('Academic details updated successfully!', isError: false);
          setState(() => _editingAcademic = false);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Failed to save academic details: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _savePersonalSection() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _citizenshipController.text.trim().isEmpty) {
      _showSnackBar('Please fill out all required personal fields.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('scholar').upsert({
          'user_id': user.id,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'middle_name': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          'suffix': _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim(),
          'phone': _phoneController.text.trim(),
          'citizenship': _citizenshipController.text.trim(),
          'birth_date': _selectedBirthDate?.toIso8601String().split('T')[0],
          'gender': _selectedGender,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (mounted) {
          _showSnackBar('Personal details updated successfully!', isError: false);
          setState(() => _editingPersonal = false);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Failed to save personal details: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAddressSection() async {
    if (_selectedRegionName == null ||
        _selectedProvinceName == null ||
        _selectedMunicipalityName == null ||
        _selectedBarangayName == null) {
      _showSnackBar('Please select all address/location dropdowns.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('scholar').upsert({
          'user_id': user.id,
          'first_name': _firstNameController.text.trim().isNotEmpty ? _firstNameController.text.trim() : 'Scholar',
          'last_name': _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : 'Student',
          'region': _selectedRegionName,
          'province': _selectedProvinceName,
          'municipality': _selectedMunicipalityName,
          'barangay': _selectedBarangayName,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (mounted) {
          _showSnackBar('Location & address updated successfully!', isError: false);
          setState(() => _editingAddress = false);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Failed to save address details: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(1950);
    final lastDate = DateTime(now.year - 12, now.month, now.day);
    final initial = _selectedBirthDate ?? DateTime(now.year - 18, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Modals: Security & Credentials ─────────────────────────────────────────

  void _showChangePasswordDialog() {
    final pwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Change Password', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pwdController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password', hintText: 'At least 6 characters'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPwdController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm New Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          final pwd = pwdController.text.trim();
                          final confirmPwd = confirmPwdController.text.trim();
                          if (pwd.length < 6) {
                            _showSnackBar('Password must be at least 6 characters.', isError: true);
                            return;
                          }
                          if (pwd != confirmPwd) {
                            _showSnackBar('Passwords do not match.', isError: true);
                            return;
                          }

                          setDialogState(() => isUpdating = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: pwd),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            _showSnackBar('Password updated successfully!', isError: false);
                          } catch (e) {
                            _showSnackBar('Failed to update password: $e', isError: true);
                          } finally {
                            setDialogState(() => isUpdating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController(text: _userEmail);
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Change Email Address', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter your new email address. A confirmation email will be sent to verify your change.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'New Email Address', hintText: 'scholar@example.com'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          final newMail = emailController.text.trim();
                          if (newMail.isEmpty || !newMail.contains('@')) {
                            _showSnackBar('Please enter a valid email address.', isError: true);
                            return;
                          }

                          setDialogState(() => isUpdating = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(email: newMail),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              setState(() {
                                _userEmail = newMail;
                              });
                            }
                            _showSnackBar('Email update request sent! Check your new email inbox to verify.', isError: false);
                          } catch (e) {
                            _showSnackBar('Failed to update email: $e', isError: true);
                          } finally {
                            setDialogState(() => isUpdating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Verification', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPhotoOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Photo Options',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take a photo now or select an image from your gallery',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Take Photo with Camera',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Use your camera to capture a new profile picture',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 16, color: AppColors.rule),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.image, color: AppColors.amberDeep, size: 20),
                  ),
                  title: Text(
                    'Upload Photo from Gallery',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Choose an existing photo from device storage',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      Uint8List? bytes;
      String extension = 'jpg';

      if (source == ImageSource.camera) {
        try {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            bytes = await pickedFile.readAsBytes();
            final nameParts = pickedFile.name.split('.');
            if (nameParts.length > 1) extension = nameParts.last;
          }
        } catch (e) {
          if (e.toString().contains('channel-error') || e.toString().contains('MissingPlugin')) {
            _showSnackBar(
              'Camera plugin requires restarting the app after installation. Please restart flutter run or pick from gallery.',
              isError: true,
            );
            return;
          }
          rethrow;
        }
      } else {
        try {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            bytes = await pickedFile.readAsBytes();
            final nameParts = pickedFile.name.split('.');
            if (nameParts.length > 1) extension = nameParts.last;
          }
        } catch (_) {
          final result = await FilePicker.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result != null && result.files.isNotEmpty) {
            final file = result.files.first;
            bytes = file.bytes;
            if (file.extension != null) extension = file.extension!;
          }
        }
      }

      if (bytes == null) return;

      setState(() => _isUploadingPhoto = true);

      String uploadedUrl = '';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'avatars/avatar_${user.id}_$timestamp.$extension';

      try {
        await Supabase.instance.client.storage.from('scholar-documents').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        uploadedUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(path);
      } catch (e1) {
        debugPrint('[ProfileEdit] Upload to scholar-documents failed: $e1. Trying avatars bucket...');
        try {
          await Supabase.instance.client.storage.from('avatars').uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          uploadedUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
        } catch (e2) {
          debugPrint('[ProfileEdit] Upload to avatars failed: $e2');
          final base64Str = base64Encode(bytes);
          uploadedUrl = 'data:image/$extension;base64,$base64Str';
        }
      }

      try {
        await Supabase.instance.client
            .from('scholar')
            .update({'avatar_url': uploadedUrl})
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('[ProfileEdit] Failed updating scholar table avatar_url: $e');
      }

      try {
        await Supabase.instance.client
            .from('users')
            .update({'avatar_url': uploadedUrl})
            .eq('id', user.id);
      } catch (_) {}

      try {
        if (uploadedUrl.startsWith('http')) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'avatar_url': uploadedUrl}),
          );
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _avatarUrl = uploadedUrl;
          _isUploadingPhoto = false;
        });
        _showSnackBar('Profile photo updated successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackBar('Failed to update photo: $e', isError: true);
      }
    }
  }

  Widget _buildAvatarImage(String initials) {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('data:image')) {
        try {
          final base64Bytes = base64Decode(_avatarUrl!.split(',').last);
          return ClipOval(
            child: Image.memory(
              base64Bytes,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else if (_avatarUrl!.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            _avatarUrl!,
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsWidget(initials),
          ),
        );
      }
    }
    return _buildInitialsWidget(initials);
  }

  Widget _buildInitialsWidget(String initials) {
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : 'IS',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Header Card ─────────────────────────────────────────────────────────────

  Widget _buildProfileHeaderCard() {
    final first = _firstNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final last = _lastNameController.text.trim();
    final suffix = _suffixController.text.trim();
    final nameParts = [first, middle, last, suffix].where((s) => s.isNotEmpty).join(' ');
    final fullName = nameParts.trim().isNotEmpty ? nameParts : 'Scholar Student';
    final initials = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();

    final bool isComplete = _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _selectedBirthDate != null &&
        _selectedGender != null &&
        _phoneController.text.trim().isNotEmpty &&
        _schoolController.text.trim().isNotEmpty &&
        _courseController.text.trim().isNotEmpty &&
        _selectedYearLevel != null &&
        _gpaController.text.trim().isNotEmpty &&
        _citizenshipController.text.trim().isNotEmpty &&
        _selectedRegionName != null &&
        _selectedProvinceName != null &&
        _selectedMunicipalityName != null &&
        _selectedBarangayName != null;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptionsModal,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: AppColors.signatureGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isUploadingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : _buildAvatarImage(initials),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showPhotoOptionsModal,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isComplete)
                      const VerifiedBadge(label: 'Verified Scholar')
                    else
                      const StatusChip(label: 'Incomplete Profile', type: StatusType.pending),
                    const SizedBox(height: 6),
                    Text(
                      _userEmail.isNotEmpty ? _userEmail : 'scholar@iskolarako.ph',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eduLabels[_educationLevel] ?? 'Scholar Student',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amberDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.rule),
          const SizedBox(height: 14),

          // Prominent Scholar Full Name (Uncut, multiline support)
          Text(
            fullName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header with Independent Edit Toggle ────────────────────────────

  Widget _buildSectionHeaderWithAction({
    required String title,
    required bool isEditing,
    required VoidCallback onToggleEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          GestureDetector(
            onTap: onToggleEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isEditing ? AppColors.amber.withAlpha(30) : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isEditing ? AppColors.amber : AppColors.rule),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditing ? LucideIcons.xCircle : LucideIcons.pencil,
                    size: 14,
                    color: isEditing ? AppColors.amberDeep : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEditing ? 'Cancel Edit' : 'Edit Section',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isEditing ? AppColors.amberDeep : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION BUILDERS (ACADEMIC, PERSONAL, ADDRESS, SECURITY) ──────────────

  Widget _buildAcademicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithAction(
          title: 'Academic Information',
          isEditing: _editingAcademic,
          onToggleEdit: () => setState(() => _editingAcademic = !_editingAcademic),
        ),
        if (_editingAcademic)
          _buildEditAcademicSection()
        else
          _buildViewAcademicSection(),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithAction(
          title: 'Personal Information',
          isEditing: _editingPersonal,
          onToggleEdit: () => setState(() => _editingPersonal = !_editingPersonal),
        ),
        if (_editingPersonal)
          _buildEditPersonalSection()
        else
          _buildViewPersonalSection(),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderWithAction(
          title: 'Location / Address',
          isEditing: _editingAddress,
          onToggleEdit: () => setState(() => _editingAddress = !_editingAddress),
        ),
        if (_editingAddress)
          _buildEditAddressSection()
        else
          _buildViewAddressSection(),
      ],
    );
  }

  // ── VIEW MODE SECTIONS ─────────────────────────────────────────────────────

  Widget _buildViewAcademicSection() {
    final school = _schoolController.text.trim().isNotEmpty ? _schoolController.text.trim() : 'Not specified';
    final course = _courseController.text.trim().isNotEmpty ? _courseController.text.trim() : 'Not specified';
    final year = _selectedYearLevel != null ? 'Year $_selectedYearLevel' : 'Not specified';
    final gpa = _gpaController.text.trim().isNotEmpty ? _gpaController.text.trim() : 'Not set';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildViewDetailRow(
            icon: LucideIcons.graduationCap,
            label: 'Education Level',
            value: _eduLabels[_educationLevel] ?? 'Undergraduate / College',
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.building,
            label: 'School / University',
            value: school,
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.bookOpen,
            label: 'Course / Degree Program',
            value: course,
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.calendar,
            label: 'Year Level',
            value: year,
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.award,
            label: 'GPA / GWA',
            value: gpa,
            subtitle: _scaleLabels[_gpaScale],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scaleExplanations[_gpaScale] ?? 'Grading system scale configured.',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewPersonalSection() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final suffix = _suffixController.text.trim();
    final fullName = '$first ${middle.isNotEmpty ? "$middle " : ""}$last ${suffix.isNotEmpty ? suffix : ""}'.trim();
    final phone = _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : 'Not provided';
    final citizenship = _citizenshipController.text.trim().isNotEmpty ? _citizenshipController.text.trim() : 'Filipino';
    final dob = _selectedBirthDate != null
        ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
        : 'Not set';
    final gender = _selectedGender ?? 'Not set';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildViewDetailRow(
            icon: LucideIcons.user,
            label: 'Full Name',
            value: fullName.isNotEmpty ? fullName : 'Not set',
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.phone,
            label: 'Phone Number',
            value: phone,
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.calendar,
            label: 'Birth Date & Gender',
            value: '$dob • $gender',
          ),
          const Divider(height: 20, color: AppColors.rule),
          _buildViewDetailRow(
            icon: LucideIcons.flag,
            label: 'Citizenship',
            value: citizenship,
          ),
        ],
      ),
    );
  }

  Widget _buildViewAddressSection() {
    final addressParts = <String>[];
    if (_selectedBarangayName != null) addressParts.add(_selectedBarangayName!);
    if (_selectedMunicipalityName != null) addressParts.add(_selectedMunicipalityName!);
    if (_selectedProvinceName != null) addressParts.add(_selectedProvinceName!);
    if (_selectedRegionName != null) addressParts.add(_selectedRegionName!);
    final fullAddress = addressParts.isNotEmpty ? addressParts.join(', ') : 'Location not set';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: _buildViewDetailRow(
        icon: LucideIcons.mapPin,
        label: 'Residential Address',
        value: fullAddress,
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Security & Credentials',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.mail, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Email', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        Text(_userEmail.isNotEmpty ? _userEmail : 'scholar@iskolarako.ph',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showChangeEmailDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Change Email', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.rule),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.lock, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        Text('••••••••••••', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showChangePasswordDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.key, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('Change Password', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── EDIT MODE SECTIONS ─────────────────────────────────────────────────────

  Widget _buildEditPersonalSection() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField(
            controller: _firstNameController,
            label: 'First Name *',
            hint: 'e.g. Juan',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _lastNameController,
            label: 'Last Name *',
            hint: 'e.g. Dela Cruz',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name',
                  hint: 'e.g. Santos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _suffixController,
                  label: 'Suffix',
                  hint: 'e.g. Jr.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: 'e.g. 09123456789',
            keyboardType: TextInputType.phone,
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _citizenshipController,
            label: 'Citizenship *',
            hint: 'e.g. Filipino',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Birth Date *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _selectBirthDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.rule),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedBirthDate != null
                                  ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select Date',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _selectedBirthDate != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                            const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gender *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _getSafeGenderValue(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                      ),
                      hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
                        DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingPersonal = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.rule),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Save Personal Details',
                  icon: LucideIcons.check,
                  isLoading: _isSaving,
                  onPressed: _savePersonalSection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditAddressSection() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownField(
            label: 'Region *',
            value: _selectedRegionCode,
            hint: 'Select Region',
            items: _regions.map((r) => DropdownMenuItem(value: r['code'].toString(), child: Text(r['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (val) {
              if (val != null) {
                final region = _regions.firstWhere((r) => r['code'].toString() == val);
                setState(() {
                  _selectedRegionCode = val;
                  _selectedRegionName = region['name'];
                  _selectedProvinceCode = null;
                  _selectedProvinceName = null;
                  _selectedMunicipalityCode = null;
                  _selectedMunicipalityName = null;
                  _selectedBarangayName = null;
                  _provinces = [];
                  _municipalities = [];
                  _barangays = [];
                });
                _fetchProvinces(val);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Province *',
            value: _selectedProvinceCode,
            hint: _selectedRegionCode == null ? 'Select Region First' : 'Select Province',
            items: _provinces.map((p) => DropdownMenuItem(value: p['code'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _selectedRegionCode == null ? null : (val) {
              if (val != null) {
                final prov = _provinces.firstWhere((p) => p['code'].toString() == val);
                setState(() {
                  _selectedProvinceCode = val;
                  _selectedProvinceName = prov['name'];
                  _selectedMunicipalityCode = null;
                  _selectedMunicipalityName = null;
                  _selectedBarangayName = null;
                  _municipalities = [];
                  _barangays = [];
                });
                _fetchMunicipalities(val);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Municipality / City *',
            value: _selectedMunicipalityCode,
            hint: _selectedProvinceCode == null ? 'Select Province First' : 'Select City/Municipality',
            items: _municipalities.map((m) => DropdownMenuItem(value: m['code'].toString(), child: Text(m['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _selectedProvinceCode == null ? null : (val) {
              if (val != null) {
                final muni = _municipalities.firstWhere((m) => m['code'].toString() == val);
                setState(() {
                  _selectedMunicipalityCode = val;
                  _selectedMunicipalityName = muni['name'];
                  _selectedBarangayName = null;
                  _barangays = [];
                });
                _fetchBarangays(val);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Barangay *',
            value: _selectedBarangayName,
            hint: _selectedMunicipalityCode == null ? 'Select Municipality First' : 'Select Barangay',
            items: _barangays.map((b) => DropdownMenuItem(value: b['name'].toString(), child: Text(b['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _selectedMunicipalityCode == null ? null : (val) {
              if (val != null) {
                setState(() {
                  _selectedBarangayName = val;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingAddress = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.rule),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Save Address Details',
                  icon: LucideIcons.check,
                  isLoading: _isSaving,
                  onPressed: _saveAddressSection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditAcademicSection() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Education Level Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Education Level *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _getSafeEducationLevel(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                ),
                items: _eduLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _educationLevel = val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _schoolController,
            label: 'School / University Name *',
            hint: 'e.g. University of the Philippines',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _courseController,
            label: 'Course / Degree Program *',
            hint: 'e.g. BS Computer Science',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Year Level *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _getSafeYearLevel(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                      ),
                      hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1st Year')),
                        DropdownMenuItem(value: 2, child: Text('2nd Year')),
                        DropdownMenuItem(value: 3, child: Text('3rd Year')),
                        DropdownMenuItem(value: 4, child: Text('4th Year')),
                        DropdownMenuItem(value: 5, child: Text('5th Year')),
                      ],
                      onChanged: (val) => setState(() => _selectedYearLevel = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _gpaController,
                  label: 'GPA / GWA *',
                  hint: 'e.g. 1.25 or 90.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    if (double.tryParse(val.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GPA Scale Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grading System / GPA Scale *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _getSafeGpaScale(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
                ),
                items: _scaleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _gpaScale = val);
                  }
                },
              ),
              const SizedBox(height: 6),
              Text(
                _scaleExplanations[_gpaScale] ?? 'Grading system scale configured.',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.amberDeep),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingAcademic = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.rule),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Save Academic Details',
                  icon: LucideIcons.check,
                  isLoading: _isSaving,
                  onPressed: _saveAcademicSection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final bool hasMatch = value != null && items.any((item) => item.value == value);
    final String? safeValue = hasMatch ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: safeValue,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rule)),
          ),
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : Column(
                children: [
                  // Consistent Top Bar Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.rule),
                            ),
                            child: const Icon(LucideIcons.chevronLeft,
                                color: AppColors.primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _isAnyEditing ? 'Edit Profile Details' : 'Student Profile',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_isAnyEditing) {
                                _editingAcademic = false;
                                _editingPersonal = false;
                                _editingAddress = false;
                              } else {
                                _editingAcademic = true;
                                _editingPersonal = true;
                                _editingAddress = true;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isAnyEditing ? AppColors.amberDeep : AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAnyEditing ? LucideIcons.eye : LucideIcons.pencil,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isAnyEditing ? 'View Mode' : 'Edit All',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Avatar Summary Header
                            _buildProfileHeaderCard(),
                            const SizedBox(height: 20),

                            // Academic Section (Independent Edit/View)
                            _buildAcademicSection(),
                            const SizedBox(height: 20),

                            // Personal Section (Independent Edit/View)
                            _buildPersonalSection(),
                            const SizedBox(height: 20),

                            // Address Section (Independent Edit/View)
                            _buildAddressSection(),
                            const SizedBox(height: 20),

                            // Security & Credentials
                            _buildSecuritySection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
