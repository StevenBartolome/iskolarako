import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iskoako/services/audit_log_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/utils/school_catalog.dart';

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
  int? _selectedYearLevel;
  String _educationLevel = 'college'; // college, graduate, senior_high, vocational, incoming_college
  String _gradingScale = 'scale_5';
  List<String> _schoolOptions = [];
  bool _isScaleLocked = false;

  static const Map<String, String> _eduLabels = {
    'college': 'Undergraduate / College',
    'graduate': 'Graduate Studies (MA/PhD)',
    'senior_high': 'Senior High School (SHS)',
    'vocational': 'Vocational / TVET',
    'incoming_college': 'Incoming College (Graduating SHS)',
  };

  String? _getSafeGenderValue() {
    if (_selectedGender == null) return null;
    final val = _selectedGender!.trim().toLowerCase();
    if (val == 'male') return 'male';
    if (val == 'female') return 'female';
    if (val == 'other' || val.contains('non')) return 'other';
    if (val.contains('prefer')) return 'prefer_not_to_say';
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

  int? _getSafeYearLevel() {
    if (_selectedYearLevel != null && _selectedYearLevel! >= 1 && _selectedYearLevel! <= 5) {
      return _selectedYearLevel;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _schoolOptions = philippineSchools.map((s) => s.name).toList();
    _schoolOptions.sort((a, b) => a.compareTo(b));
    _fetchSchoolsFromApi();
    _loadProfileData();
  }

  Future<void> _fetchSchoolsFromApi() async {
    try {
      final response = await http
          .get(Uri.parse('http://universities.hipolabs.com/search?country=philippines'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> remoteSchools = data
            .map((item) => item['name'].toString().trim())
            .where((name) => name.isNotEmpty)
            .toList();

        if (mounted) {
          setState(() {
            final Set<String> allSchoolsSet = {};
            for (final localSchool in philippineSchools) {
              allSchoolsSet.add(localSchool.name);
            }
            allSchoolsSet.addAll(remoteSchools);

            _schoolOptions = allSchoolsSet.toList();
            _schoolOptions.sort((a, b) => a.compareTo(b));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading remote schools from HipoLabs: $e');
    }
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
        _selectedGender = dataList['gender'];
        _educationLevel = dataList['education_level'] ?? 'college';
        _gradingScale = dataList['gpa_scale'] ?? 'scale_5';

        final loadedSchool = dataList['school']?.toString() ?? '';
        final matchedIndex = philippineSchools.indexWhere(
          (s) => s.name.toLowerCase().trim() == loadedSchool.toLowerCase().trim(),
        );
        _isScaleLocked = (matchedIndex != -1) ? philippineSchools[matchedIndex].isAccurate : false;
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
        _courseController.text.trim().isEmpty) {
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
          'gpa_scale': _gradingScale,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (mounted) {
          _showSnackBar('Academic details updated successfully!', isError: false);
          AuditLogService.createAuditLog(action: 'UPDATED ACADEMIC DETAILS', target: 'Scholar Profile');
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
          AuditLogService.createAuditLog(action: 'UPDATED PERSONAL DETAILS', target: 'Scholar Profile');
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
          AuditLogService.createAuditLog(action: 'UPDATED ADDRESS DETAILS', target: 'Scholar Profile');
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
            Icon(isError ? LucideIcons.alertCircle : Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF1E3D2F),
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
              title: Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
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
                    backgroundColor: const Color(0xFF1E3D2F),
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
              title: Text('Change Email Address', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter your new email address. A confirmation email will be sent to verify your change.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                    backgroundColor: const Color(0xFF1E3D2F),
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
      backgroundColor: Colors.white,
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
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take a photo now or select an image from your gallery',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.camera, color: Color(0xFF15803D), size: 20),
                  ),
                  title: Text(
                    'Take Photo with Camera',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                  ),
                  subtitle: Text(
                    'Use your camera to capture a new profile picture',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 16, color: Color(0xFFE5E7EB)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.image, color: Color(0xFFD97706), size: 20),
                  ),
                  title: Text(
                    'Upload Photo from Gallery',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                  ),
                  subtitle: Text(
                    'Choose an existing photo from device storage',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
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
              'Camera plugin requires restarting the app. Please pick from gallery.',
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

  // ── Profile Header Card ──────────────────────────────────────────────────────

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
        _citizenshipController.text.trim().isNotEmpty &&
        _selectedRegionName != null &&
        _selectedProvinceName != null &&
        _selectedMunicipalityName != null &&
        _selectedBarangayName != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3D2F), Color(0xFF162E23)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3D2F).withValues(alpha: 0.2),
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3D2F),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 12,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isComplete ? '✓ Verified Scholar' : '● Incomplete Profile',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isComplete ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _userEmail.isNotEmpty ? _userEmail : 'scholar@iskolarako.ph',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eduLabels[_educationLevel] ?? 'Scholar Student',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          Text(
            fullName,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
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
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          GestureDetector(
            onTap: onToggleEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isEditing ? const Color(0xFFFEF3C7) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isEditing ? const Color(0xFFD97706) : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditing ? LucideIcons.xCircle : LucideIcons.pencil,
                    size: 13,
                    color: isEditing ? const Color(0xFFD97706) : const Color(0xFF1E3D2F),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEditing ? 'Cancel Edit' : 'Edit Section',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isEditing ? const Color(0xFFD97706) : const Color(0xFF1E3D2F),
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

  // ── SECTION BUILDERS ──────────────────────────────────────────────────────

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          _buildViewDetailRow(
            icon: LucideIcons.graduationCap,
            label: 'Education Level',
            value: _eduLabels[_educationLevel] ?? 'Undergraduate / College',
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _buildViewDetailRow(
            icon: LucideIcons.building,
            label: 'School / University',
            value: school,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _buildViewDetailRow(
            icon: LucideIcons.bookOpen,
            label: 'Course / Degree Program',
            value: course,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _buildViewDetailRow(
            icon: LucideIcons.calendar,
            label: 'Year Level',
            value: year,
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
    final String gender;
    if (_selectedGender == null) {
      gender = 'Not set';
    } else {
      final gVal = _selectedGender!.toLowerCase();
      if (gVal == 'male') {
        gender = 'Male';
      } else if (gVal == 'female') {
        gender = 'Female';
      } else if (gVal == 'other') {
        gender = 'Other';
      } else if (gVal == 'prefer_not_to_say') {
        gender = 'Prefer not to say';
      } else {
        gender = _selectedGender!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          _buildViewDetailRow(
            icon: LucideIcons.user,
            label: 'Full Name',
            value: fullName.isNotEmpty ? fullName : 'Not set',
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _buildViewDetailRow(
            icon: LucideIcons.phone,
            label: 'Phone Number',
            value: phone,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _buildViewDetailRow(
            icon: LucideIcons.calendar,
            label: 'Birth Date & Gender',
            value: '$dob • $gender',
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
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
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.mail, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Email', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
                        Text(_userEmail.isNotEmpty ? _userEmail : 'scholar@iskolarako.ph',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showChangeEmailDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1E3D2F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Change Email', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E3D2F))),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF3F4F6)),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.lock, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
                        Text('••••••••••••', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showChangePasswordDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3D2F),
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
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF16A34A), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF1E3D2F)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
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
                    Text('Birth Date *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _selectBirthDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFCFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                color: _selectedBirthDate != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF1E3D2F)),
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
                    Text('Gender *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _getSafeGenderValue(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFFAFCFA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                        DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
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
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePersonalSection,
                  icon: const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  label: Text('Save Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
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
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAddressSection,
                  icon: const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  label: Text('Save Address', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditAcademicSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Education Level *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _getSafeEducationLevel(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
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

          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _schoolOptions
                  .where((school) => school.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              _schoolController.text = selection;
              final matchedIndex = philippineSchools.indexWhere(
                (s) => s.name.toLowerCase() == selection.toLowerCase(),
              );
              setState(() {
                if (matchedIndex != -1) {
                  final matched = philippineSchools[matchedIndex];
                  _gradingScale = matched.defaultScale;
                  _isScaleLocked = matched.isAccurate;
                } else {
                  _isScaleLocked = false;
                }
              });
            },
            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
              if (textController.text != _schoolController.text) {
                textController.text = _schoolController.text;
              }
              textController.addListener(() {
                _schoolController.text = textController.text;
                
                final typed = textController.text.trim();
                final matchedIndex = philippineSchools.indexWhere(
                  (s) => s.name.toLowerCase().trim() == typed.toLowerCase().trim(),
                );
                
                setState(() {
                  if (matchedIndex != -1) {
                    final matched = philippineSchools[matchedIndex];
                    _gradingScale = matched.defaultScale;
                    _isScaleLocked = matched.isAccurate;
                  } else {
                    _isScaleLocked = false;
                  }
                });
              });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('School / University Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    onFieldSubmitted: (val) => onFieldSubmitted(),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      hintText: 'e.g. University of the Philippines',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFFAFCFA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grading System *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _gradingScale,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                ),
                items: const [
                  DropdownMenuItem(value: 'scale_5', child: Text('1.00 - 5.00 Scale (PH State Univ / UP / PUP / UST)', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'scale_4', child: Text('4.00 - 1.00 Scale (ADMU / DLSU / FEU / NU)', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage Scale (DepEd K-12 / 65 - 100%)', style: TextStyle(fontSize: 13))),
                ],
                onChanged: _isScaleLocked
                    ? null
                    : (val) => setState(() {
                          if (val != null) _gradingScale = val;
                        }),
              ),
            ],
          ),
          if (_isScaleLocked)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12, left: 2),
              child: Text(
                '🔒 Grading system verified for this school and locked.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _courseController,
            label: 'Course / Degree Program *',
            hint: 'e.g. BS Computer Science',
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Year Level *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _getSafeYearLevel(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                ),
                hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingAcademic = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAcademicSection,
                  icon: const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  label: Text('Save Academic', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
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
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFFAFCFA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
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
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: safeValue,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFFAFCFA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          ),
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3D2F)),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildProfileHeaderCard(),
                          const SizedBox(height: 20),

                          _buildAcademicSection(),
                          const SizedBox(height: 20),

                          _buildPersonalSection(),
                          const SizedBox(height: 20),

                          _buildAddressSection(),
                          const SizedBox(height: 20),

                          _buildSecuritySection(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header Top Bar ────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
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
                        LucideIcons.userCheck,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'EDIT PROFILE',
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
                    'Edit Profile',
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
                    'Update education, location & personal info',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAnyEditing ? const Color(0xFFD97706) : const Color(0xFF1E3D2F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isAnyEditing ? 'View Mode' : 'Edit All',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Image.asset(
                  'assets/books-hats-icon.png',
                  width: 70,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
