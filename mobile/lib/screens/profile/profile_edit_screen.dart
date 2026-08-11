import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
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

  // Personal Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _phoneController = TextEditingController();
  final _citizenshipController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _selectedGender;

  // Address (fetched dynamically from PSGC API)
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

  // Academic
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  int? _selectedYearLevel;
  final _gpaController = TextEditingController();

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

  Future<void> _fetchRegions() async {
    try {
      final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _regions = data.map((r) => {'code': r['code'], 'name': r['name']}).toList();
          _regions.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        });
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
        setState(() {
          _provinces = data.map((p) => {'code': p['code'], 'name': p['name']}).toList();
          _provinces.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        });
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
        setState(() {
          _municipalities = data.map((m) => {'code': m['code'], 'name': m['name']}).toList();
          _municipalities.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        });
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
        setState(() {
          _barangays = data.map((b) => {'code': b['code'], 'name': b['name']}).toList();
          _barangays.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        });
      }
    } catch (e) {
      debugPrint('Error fetching barangays: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final userRecord = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      final dataList = await Supabase.instance.client
          .from('scholar')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      await _fetchRegions();

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
        if (dataList['birth_date'] != null) {
          _selectedBirthDate = DateTime.tryParse(dataList['birth_date']);
        }

        // Load cascade values based on saved names
        final savedRegionName = dataList['region']?.toString() ?? '';
        if (savedRegionName.isNotEmpty) {
          final regionMatch = _regions.firstWhere(
            (r) => r['name'].toString().toLowerCase().trim() == savedRegionName.toLowerCase().trim(),
            orElse: () => <String, dynamic>{},
          );
          if (regionMatch.isNotEmpty) {
            _selectedRegionCode = regionMatch['code'];
            _selectedRegionName = regionMatch['name'];
            await _fetchProvinces(_selectedRegionCode!);

            final savedProvinceName = dataList['province']?.toString() ?? '';
            if (savedProvinceName.isNotEmpty && _provinces.isNotEmpty) {
              final provinceMatch = _provinces.firstWhere(
                (p) => p['name'].toString().toLowerCase().trim() == savedProvinceName.toLowerCase().trim(),
                orElse: () => <String, dynamic>{},
              );
              if (provinceMatch.isNotEmpty) {
                _selectedProvinceCode = provinceMatch['code'];
                _selectedProvinceName = provinceMatch['name'];
                await _fetchMunicipalities(_selectedProvinceCode!);

                final savedMuniName = dataList['municipality']?.toString() ?? '';
                if (savedMuniName.isNotEmpty && _municipalities.isNotEmpty) {
                  final muniMatch = _municipalities.firstWhere(
                    (m) => m['name'].toString().toLowerCase().trim() == savedMuniName.toLowerCase().trim(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (muniMatch.isNotEmpty) {
                    _selectedMunicipalityCode = muniMatch['code'];
                    _selectedMunicipalityName = muniMatch['name'];
                    await _fetchBarangays(_selectedMunicipalityCode!);

                    final savedBrgyName = dataList['barangay']?.toString() ?? '';
                    if (savedBrgyName.isNotEmpty && _barangays.isNotEmpty) {
                      final brgyMatch = _barangays.firstWhere(
                        (b) => b['name'].toString().toLowerCase().trim() == savedBrgyName.toLowerCase().trim(),
                        orElse: () => <String, dynamic>{},
                      );
                      if (brgyMatch.isNotEmpty) {
                        _selectedBarangayName = brgyMatch['name'];
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        _firstNameController.text = userRecord['first_name'] ?? '';
        _lastNameController.text = userRecord['last_name'] ?? '';
        _citizenshipController.text = 'Filipino';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2005),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRegionName == null ||
        _selectedProvinceName == null ||
        _selectedMunicipalityName == null ||
        _selectedBarangayName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.alertCircle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Please select all address/location fields.', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profileData = {
      'user_id': user.id,
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'middle_name': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      'suffix': _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim(),
      'phone': _phoneController.text.trim(),
      'birth_date': _selectedBirthDate?.toIso8601String().split('T')[0],
      'gender': _selectedGender,
      'citizenship': _citizenshipController.text.trim(),
      'region': _selectedRegionName,
      'province': _selectedProvinceName,
      'municipality': _selectedMunicipalityName,
      'barangay': _selectedBarangayName,
      'school': _schoolController.text.trim(),
      'course': _courseController.text.trim(),
      'year_level': _selectedYearLevel,
      'gpa': double.tryParse(_gpaController.text.trim()),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await Supabase.instance.client
          .from('scholar')
          .upsert(profileData, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Profile updated successfully!', style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Failed to save profile: $e', style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
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
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable form
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete your details below so you can qualify for matching scholarships.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Personal Section
                            _buildSectionHeader('Personal Details'),
                            AppCard(
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
                                  // Birth date picker
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Birth Date *',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () => _selectBirthDate(context),
                                              child: Container(
                                                height: 48,
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceAlt,
                                                  borderRadius: BorderRadius.circular(10),
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
                                                        color: _selectedBirthDate != null
                                                            ? AppColors.textPrimary
                                                            : AppColors.textMuted,
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
                                      // Gender dropdown
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Gender *',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceAlt,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.rule),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _selectedGender,
                                                  hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                                  isExpanded: true,
                                                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                                                  items: ['male', 'female', 'other', 'prefer_not_to_say'].map((g) {
                                                    return DropdownMenuItem(
                                                      value: g,
                                                      child: Text(
                                                        g == 'prefer_not_to_say' ? 'Prefer not to say' : g[0].toUpperCase() + g.substring(1),
                                                        style: GoogleFonts.inter(fontSize: 13),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _selectedGender = val;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Address / Location Section
                            _buildSectionHeader('Address / Location Details'),
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Region dropdown
                                  _buildDropdownField(
                                    label: 'Region *',
                                    value: _selectedRegionName,
                                    items: _regions.map((r) => r['name'].toString()).toList(),
                                    onChanged: (val) async {
                                      final match = _regions.firstWhere((r) => r['name'] == val);
                                      setState(() {
                                        _selectedRegionName = val;
                                        _selectedRegionCode = match['code'];
                                        _selectedProvinceName = null;
                                        _selectedProvinceCode = null;
                                        _selectedMunicipalityName = null;
                                        _selectedMunicipalityCode = null;
                                        _selectedBarangayName = null;
                                        _provinces = [];
                                        _municipalities = [];
                                        _barangays = [];
                                      });
                                      if (_selectedRegionCode != null) {
                                        await _fetchProvinces(_selectedRegionCode!);
                                      }
                                    },
                                    hint: 'Select Region',
                                  ),
                                  const SizedBox(height: 12),
                                  // Province dropdown
                                  _buildDropdownField(
                                    label: 'Province *',
                                    value: _selectedProvinceName,
                                    items: _provinces.map((p) => p['name'].toString()).toList(),
                                    onChanged: (val) async {
                                      final match = _provinces.firstWhere((p) => p['name'] == val);
                                      setState(() {
                                        _selectedProvinceName = val;
                                        _selectedProvinceCode = match['code'];
                                        _selectedMunicipalityName = null;
                                        _selectedMunicipalityCode = null;
                                        _selectedBarangayName = null;
                                        _municipalities = [];
                                        _barangays = [];
                                      });
                                      if (_selectedProvinceCode != null) {
                                        await _fetchMunicipalities(_selectedProvinceCode!);
                                      }
                                    },
                                    hint: _selectedRegionName == null ? 'Select Region First' : 'Select Province',
                                    enabled: _selectedRegionName != null,
                                  ),
                                  const SizedBox(height: 12),
                                  // Municipality dropdown
                                  _buildDropdownField(
                                    label: 'Town / Municipality *',
                                    value: _selectedMunicipalityName,
                                    items: _municipalities.map((m) => m['name'].toString()).toList(),
                                    onChanged: (val) async {
                                      final match = _municipalities.firstWhere((m) => m['name'] == val);
                                      setState(() {
                                        _selectedMunicipalityName = val;
                                        _selectedMunicipalityCode = match['code'];
                                        _selectedBarangayName = null;
                                        _barangays = [];
                                      });
                                      if (_selectedMunicipalityCode != null) {
                                        await _fetchBarangays(_selectedMunicipalityCode!);
                                      }
                                    },
                                    hint: _selectedProvinceName == null ? 'Select Province First' : 'Select Municipality',
                                    enabled: _selectedProvinceName != null,
                                  ),
                                  const SizedBox(height: 12),
                                  // Barangay dropdown
                                  _buildDropdownField(
                                    label: 'Barangay *',
                                    value: _selectedBarangayName,
                                    items: _barangays.map((b) => b['name'].toString()).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedBarangayName = val;
                                      });
                                    },
                                    hint: _selectedMunicipalityName == null ? 'Select Municipality First' : 'Select Barangay',
                                    enabled: _selectedMunicipalityName != null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Academic Section
                            _buildSectionHeader('Academic Details'),
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: _schoolController,
                                    label: 'School / University *',
                                    hint: 'e.g. Bulacan State University',
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: _courseController,
                                    label: 'Course / Program *',
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
                                            Text(
                                              'Year Level *',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceAlt,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.rule),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<int>(
                                                  value: _selectedYearLevel,
                                                  hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                                  isExpanded: true,
                                                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                                                  items: [1, 2, 3, 4, 5].map((y) {
                                                    return DropdownMenuItem(
                                                      value: y,
                                                      child: Text('Year $y', style: GoogleFonts.inter(fontSize: 13)),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _selectedYearLevel = val;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _gpaController,
                                          label: 'GWA / GPA *',
                                          hint: 'e.g. 1.75 or 3.5',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) return 'Required';
                                            if (double.tryParse(val) == null) return 'Invalid number';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            CustomButton(
                              text: 'Save Details',
                              icon: LucideIcons.save,
                              isLoading: _isSaving,
                              onPressed: _saveProfile,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceAlt : AppColors.surfaceAlt.withAlpha(120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.rule),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (value != null && items.contains(value)) ? value : null,
              hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              isExpanded: true,
              disabledHint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted.withAlpha(120))),
              icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
              items: enabled
                  ? items.map((val) {
                      return DropdownMenuItem(
                        value: val,
                        child: Text(val, style: GoogleFonts.inter(fontSize: 13)),
                      );
                    }).toList()
                  : null,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

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
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            fillColor: AppColors.surfaceAlt,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.rule),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
