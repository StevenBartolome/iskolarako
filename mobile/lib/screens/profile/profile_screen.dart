import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iskoako/services/blockchain_service.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _fullName = 'Loading...';
  String _initials = '';
  String _academicDetails = '...';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isProfileComplete = false;
  bool _isProfileInfoComplete = false;
  // Face verification
  String _faceVerificationStatus = 'unverified'; // unverified | verified | failed
  DateTime? _faceVerifiedAt;
  // Blockchain profile anchor & tamper detection
  bool _isBlockchainVerified = false;
  String? _blockchainTxHash;
  bool _isProfileTampered = false;
  String? _tamperTitle;
  String? _tamperDescription;
  RealtimeChannel? _realtimeChannel;

  // Original vs Tampered data inspection
  Map<String, dynamic>? _tamperedProfileData;
  Map<String, dynamic>? _originalProfileData;
  String? _storedBlockchainHash;
  String? _computedBlockchainHash;

  static const Map<String, String> _eduLabels = {
    'college': 'Undergraduate / College',
    'graduate': 'Graduate Studies (MA/PhD)',
    'senior_high': 'Senior High School (SHS)',
    'vocational': 'Vocational / TVET',
    'incoming_college': 'Incoming College (Graduating SHS)',
  };

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('profile-screen-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar',
          callback: (payload) {
            if (mounted) _loadProfileData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            if (mounted) _loadProfileData();
          },
        );
    _realtimeChannel?.subscribe();
  }

  bool _hasCompletedProfileInfo(Map<String, dynamic>? scholar) {
    if (scholar == null) return false;
    final requiredFields = [
      'first_name',
      'last_name',
      'birth_date',
      'gender',
      'phone',
      'school',
      'course',
      'year_level',
      'citizenship',
      'region',
      'province',
      'municipality',
      'barangay',
    ];
    for (final field in requiredFields) {
      if (scholar[field] == null || scholar[field].toString().trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('scholar')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        Map<String, dynamic>? userRow;
        try {
          userRow = await Supabase.instance.client
              .from('users')
              .select('first_name, last_name')
              .eq('id', user.id)
              .maybeSingle();
        } catch (_) {}

        if (mounted) {
          setState(() {
            if (data != null) {
              _isProfileInfoComplete = _hasCompletedProfileInfo(data);
              _isProfileComplete = EligibilityHelper.isProfileComplete(data);
              final first = data['first_name'] ?? '';
              final last = data['last_name'] ?? '';
              final middle = data['middle_name'] ?? '';
              final suffix = data['suffix'] ?? '';
              final scholarAvatar = data['avatar_url']?.toString().trim();
              final metaAvatar = user.userMetadata?['avatar_url']?.toString().trim();
              if (scholarAvatar != null && scholarAvatar.isNotEmpty && scholarAvatar != 'null') {
                _avatarUrl = scholarAvatar;
              } else if (metaAvatar != null && metaAvatar.isNotEmpty && metaAvatar != 'null') {
                _avatarUrl = metaAvatar;
              } else {
                _avatarUrl = null;
              }

              final eduLevel = _eduLabels[data['education_level']?.toString()] ?? 'Undergraduate / College';
              final course = data['course'] ?? '';
              final school = data['school'] ?? '';

              final nameParts = [first, middle, last, suffix].where((s) => s.toString().trim().isNotEmpty).join(' ');
              _fullName = nameParts.trim().isNotEmpty ? nameParts : 'Scholar Student';
              _initials = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
              _academicDetails = '$eduLevel • $course\n$school';
              _faceVerificationStatus = data['face_verification_status']?.toString() ?? 'unverified';
              final verifiedAtRaw = data['face_verified_at']?.toString();
              _faceVerifiedAt = verifiedAtRaw != null ? DateTime.tryParse(verifiedAtRaw) : null;
              _isBlockchainVerified = data['profile_blockchain_verified'] == true;
              _blockchainTxHash = data['profile_blockchain_tx_hash']?.toString();

              // Check for tampering or missing blockchain anchor
              _isProfileTampered = false;
              _tamperTitle = null;
              _tamperDescription = null;

              _tamperedProfileData = Map<String, dynamic>.from(data);
              _storedBlockchainHash = data['profile_blockchain_hash']?.toString();
              _computedBlockchainHash = BlockchainService.computeProfileHash(data);

              final snapshot = user.userMetadata?['verified_profile_snapshot'] as Map<String, dynamic>?;

              String origFirst = snapshot?['first_name']?.toString().trim() ?? '';
              String origLast = snapshot?['last_name']?.toString().trim() ?? '';
              String origMiddle = snapshot?['middle_name']?.toString().trim() ?? '';
              String origSuffix = snapshot?['suffix']?.toString().trim() ?? '';
              String origBirth = snapshot?['birth_date']?.toString().trim() ?? '';
              String origGender = snapshot?['gender']?.toString().trim() ?? '';

              // Fallback to original registered scholar details in users table or auth metadata
              if (origFirst.isEmpty) {
                origFirst = (userRow?['first_name'] ?? user.userMetadata?['first_name'] ?? '').toString().trim();
              }
              if (origLast.isEmpty) {
                origLast = (userRow?['last_name'] ?? user.userMetadata?['last_name'] ?? '').toString().trim();
              }

              _originalProfileData = {
                'first_name': origFirst,
                'middle_name': origMiddle,
                'last_name': origLast,
                'suffix': origSuffix,
                'birth_date': origBirth,
                'gender': origGender,
                'face_verification_status': 'verified',
                'profile_blockchain_hash': _storedBlockchainHash ?? '',
                'profile_blockchain_tx_hash': _blockchainTxHash ?? '',
              };

              if (_faceVerificationStatus == 'verified') {
                if (!_isBlockchainVerified) {
                  _isProfileTampered = true;
                  _tamperTitle = 'Unanchored Verification Status';
                  _tamperDescription =
                      'Your face verification is marked verified in the database, but lacks a valid blockchain anchor. Direct database alteration detected. Please re-verify to unlock scholarship applications.';
                } else {
                  final storedHash = data['profile_blockchain_hash']?.toString();
                  if (storedHash == null || storedHash.isEmpty) {
                    _isProfileTampered = true;
                    _tamperTitle = 'Missing Security Fingerprint';
                    _tamperDescription =
                        'The cryptographic blockchain anchor for your profile is missing. Please complete face re-verification.';
                  } else {
                    final currentHash = BlockchainService.computeProfileHash(data);
                    if (currentHash.toLowerCase() != storedHash.toLowerCase()) {
                      _isProfileTampered = true;
                      _tamperTitle = 'Identity Data Tampered';
                      _tamperDescription =
                          'Critical profile attributes in the scholars table (Name, Birthdate, or Gender) do not match the immutable blockchain fingerprint created during verification. Applications are locked.';
                    }
                  }
                }
              }

              // Auto-refresh snapshot when profile is clean and verified
              if (_faceVerificationStatus == 'verified' && _isBlockchainVerified && !_isProfileTampered) {
                if (snapshot == null || snapshot['first_name'] != data['first_name'] || snapshot['last_name'] != data['last_name']) {
                  try {
                    Supabase.instance.client.auth.updateUser(
                      UserAttributes(data: {
                        'verified_profile_snapshot': {
                          'first_name': data['first_name'] ?? '',
                          'middle_name': data['middle_name'] ?? '',
                          'last_name': data['last_name'] ?? '',
                          'suffix': data['suffix'] ?? '',
                          'birth_date': data['birth_date'] ?? '',
                          'gender': data['gender'] ?? '',
                          'face_verification_status': 'verified',
                          'face_verified_at': data['face_verified_at'] ?? '',
                          'profile_blockchain_hash': _storedBlockchainHash ?? '',
                          'profile_blockchain_tx_hash': _blockchainTxHash ?? '',
                        },
                      }),
                    );
                  } catch (_) {}
                }
              }
            } else {
              _isProfileInfoComplete = false;
              _isProfileComplete = false;
              _fullName = user.email ?? 'Scholar Student';
              _initials = 'IS';
              _academicDetails = 'Complete profile details';
            }
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _fullName = 'Student Profile';
            _isLoading = false;
          });
        }
      }
    }
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Camera requires restarting the app. Please pick from gallery.'),
                  backgroundColor: Color(0xFFB91C1C),
                ),
              );
            }
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
        debugPrint('[Profile] Upload to scholar-documents failed: $e1. Trying avatars bucket...');
        try {
          await Supabase.instance.client.storage.from('avatars').uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          uploadedUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
        } catch (e2) {
          debugPrint('[Profile] Upload to avatars failed: $e2');
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
        debugPrint('[Profile] Failed updating scholar table avatar_url: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    }
  }

  Widget _buildAvatarImage() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('data:image')) {
        try {
          final base64Bytes = base64Decode(_avatarUrl!.split(',').last);
          return ClipOval(
            child: Image.memory(
              base64Bytes,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else if (_avatarUrl!.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            _avatarUrl!,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsWidget(),
          ),
        );
      }
    }
    return _buildInitialsWidget();
  }

  Widget _buildInitialsWidget() {
    return Center(
      child: Text(
        _initials.isNotEmpty ? _initials : 'IS',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ─── Face Verification Card ────────────────────────────────────────────────
  Widget _buildFaceVerificationCard() {
    if (_isProfileTampered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.shieldAlert,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tamperTitle ?? 'Data Tampering Detected',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Blockchain Security Mismatch',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'TAMPERED',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _tamperDescription ??
                    'Profile data does not match the cryptographic blockchain anchor. Applications are locked until you re-verify.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF7F1D1D),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showTamperDiscrepancyModal,
                icon: const Icon(LucideIcons.fileSearch, size: 15, color: Colors.white),
                label: Text(
                  'View Original vs Tampered Data',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_faceVerificationStatus == 'verified') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: Color(0xFF16A34A),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identity Verified',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (_faceVerifiedAt != null)
                    Text(
                      'Verified on ${_faceVerifiedAt!.day}/${_faceVerifiedAt!.month}/${_faceVerifiedAt!.year}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  if (_isBlockchainVerified && _blockchainTxHash != null)
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse(BlockchainService.getExplorerUrl(_blockchainTxHash!));
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.link, size: 11, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              'Secured on Blockchain',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7C3AED),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ],
        ),
      );
    } else if (_faceVerificationStatus == 'failed') {
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.pushNamed(context, AppRouter.faceVerification);
          if (result == true) _loadProfileData();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldOff,
                  color: Color(0xFFB91C1C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Failed',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                    Text(
                      'Tap to retry identity verification',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: Color(0xFFB91C1C), size: 18),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.pushNamed(context, AppRouter.faceVerification);
          if (result == true) _loadProfileData();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE8D0), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldAlert,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Your Identity',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Upload your ID + face check to get verified',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Verify Now',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ─── Tampered Data Discrepancy Modal ──────────────────────────────────────
  void _showTamperDiscrepancyModal() {
    final original = _originalProfileData ?? {};
    final current = _tamperedProfileData ?? {};

    final origFirst = (original['first_name'] ?? '').toString().trim();
    final currFirst = (current['first_name'] ?? '').toString().trim();

    final origMiddle = (original['middle_name'] ?? '').toString().trim();
    final currMiddle = (current['middle_name'] ?? '').toString().trim();

    final origLast = (original['last_name'] ?? '').toString().trim();
    final currLast = (current['last_name'] ?? '').toString().trim();

    final origSuffix = (original['suffix'] ?? '').toString().trim();
    final currSuffix = (current['suffix'] ?? '').toString().trim();

    final origBirth = (original['birth_date'] ?? '').toString().trim();
    final currBirth = (current['birth_date'] ?? '').toString().trim();

    final origGender = (original['gender'] ?? '').toString().trim();
    final currGender = (current['gender'] ?? '').toString().trim();

    final origStatus = (original['face_verification_status'] ?? 'verified').toString();
    final currStatus = (current['face_verification_status'] ?? 'unverified').toString();

    final storedHash = _storedBlockchainHash ?? '';
    final currentHash = _computedBlockchainHash ?? '';
    final txHash = _blockchainTxHash ?? '';

    // Collect ONLY fields that are actually tampered / modified
    final List<Widget> tamperedRows = [];

    if (origFirst.isNotEmpty && currFirst.isNotEmpty && origFirst.toLowerCase().trim() != currFirst.toLowerCase().trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'First Name',
        originalVal: origFirst,
        currentVal: currFirst,
      ));
    }

    if ((origMiddle.isNotEmpty || currMiddle.isNotEmpty) &&
        origMiddle.toLowerCase().trim() != currMiddle.toLowerCase().trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Middle Name',
        originalVal: origMiddle.isNotEmpty ? origMiddle : '(None)',
        currentVal: currMiddle.isNotEmpty ? currMiddle : '(None)',
      ));
    }

    if (origLast.isNotEmpty && currLast.isNotEmpty && origLast.toLowerCase().trim() != currLast.toLowerCase().trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Last Name',
        originalVal: origLast,
        currentVal: currLast,
      ));
    }

    if ((origSuffix.isNotEmpty || currSuffix.isNotEmpty) &&
        origSuffix.toLowerCase().trim() != currSuffix.toLowerCase().trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Suffix',
        originalVal: origSuffix.isNotEmpty ? origSuffix : '(None)',
        currentVal: currSuffix.isNotEmpty ? currSuffix : '(None)',
      ));
    }

    if (origBirth.isNotEmpty && currBirth.isNotEmpty && origBirth.trim() != currBirth.trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Birth Date',
        originalVal: origBirth,
        currentVal: currBirth,
      ));
    }

    if (origGender.isNotEmpty && currGender.isNotEmpty && origGender.toLowerCase().trim() != currGender.toLowerCase().trim()) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Gender',
        originalVal: origGender,
        currentVal: currGender,
      ));
    }

    if (currStatus != 'verified' || !_isBlockchainVerified) {
      tamperedRows.add(_buildDiscrepancyRow(
        label: 'Verification Status',
        originalVal: origStatus == 'verified' ? 'verified (Anchored on Blockchain)' : origStatus,
        currentVal: currStatus == 'verified' ? 'verified (Direct DB Change / Unanchored)' : currStatus,
      ));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.shieldAlert,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Identity Tampering Audit',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Original Database Record vs Modified Values',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tamperTitle ?? 'Data Tampering Detected',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _tamperDescription ??
                                        'Unauthorized changes were detected in the scholars database table. The altered record does not match the immutable cryptographic blockchain anchor.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF7F1D1D),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Tampered Fields',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF374151),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only the database fields that were modified after verification and differ from the blockchain anchor are shown below:',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (tamperedRows.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.shieldAlert, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                '${tamperedRows.length} Tampered ${tamperedRows.length == 1 ? 'Field' : 'Fields'} Detected',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...tamperedRows,
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.fingerprint, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Direct database alteration detected. The cryptographic identity hash no longer matches the anchor in the Polygon blockchain block.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF991B1B),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.blocks, size: 14, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 6),
                                Text(
                                  'Cryptographic Proof (Polygon Amoy)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildHashBox(
                              label: 'On-Chain Anchored Hash (keccak256)',
                              hash: storedHash,
                              isError: storedHash.isEmpty,
                              badgeText: 'ANCHORED',
                              badgeColor: const Color(0xFF15803D),
                            ),
                            const SizedBox(height: 8),
                            _buildHashBox(
                              label: 'Current Database Hash (keccak256)',
                              hash: currentHash,
                              isError: storedHash.toLowerCase() != currentHash.toLowerCase(),
                              badgeText: storedHash.toLowerCase() != currentHash.toLowerCase()
                                  ? 'MISMATCH'
                                  : 'MATCHED',
                              badgeColor: storedHash.toLowerCase() != currentHash.toLowerCase()
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF15803D),
                            ),
                            if (txHash.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () async {
                                  final url = Uri.parse(BlockchainService.getExplorerUrl(txHash));
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.externalLink, size: 12, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'View Transaction on Polygonscan',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Re-verifying will update your cryptographic proof with your live biometric and ID check.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final result = await Navigator.pushNamed(context, AppRouter.faceVerification);
                            if (result == true) {
                              _loadProfileData();
                            }
                          },
                          icon: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
                          label: Text(
                            'Re-verify Face & Identity',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscrepancyRow({
    required String label,
    required String originalVal,
    required String currentVal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFCA5A5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF991B1B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TAMPERED',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, size: 11, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            'Original (Scholar DB)',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        originalVal,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF166534),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 11, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(
                            'Tampered in Database',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentVal,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF991B1B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHashBox({
    required String label,
    required String hash,
    required bool isError,
    required String badgeText,
    required Color badgeColor,
  }) {
    final displayHash = hash.isEmpty
        ? 'Not Available'
        : (hash.length > 24 ? '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}' : hash);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  displayHash,
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isError ? const Color(0xFFB91C1C) : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (hash.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hash copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(LucideIcons.copy, size: 13, color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Complete Profile Details Card ──────────────────────────────────────────
  Widget _buildCompleteProfileCard() {
    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
        if (updated == true) {
          _loadProfileData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileText,
                color: Color(0xFF16A34A),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Profile Details',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fill in personal, academic, location & family info',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3D2F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fill Info',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.arrowRight,
                    color: Colors.white,
                    size: 13,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Scholar Profile Hero Card
                        Container(
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
                                children: [
                                  Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: _showPhotoOptionsModal,
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF1E3D2F), Color(0xFF162E23)],
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 3),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF1E3D2F).withValues(alpha: 0.2),
                                                blurRadius: 12,
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
                                              : _buildAvatarImage(),
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
                                              color: const Color(0xFF1E3D2F),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _isProfileTampered
                                                ? const Color(0xFFFEE2E2)
                                                : (_isProfileComplete && _faceVerificationStatus == 'verified')
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _isProfileTampered
                                                ? '⚠️ Tampered Profile'
                                                : (_isProfileComplete && _faceVerificationStatus == 'verified')
                                                    ? 'Verified Scholar'
                                                    : (!_isProfileInfoComplete)
                                                        ? 'Incomplete Profile'
                                                        : 'Unverified Identity',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: _isProfileTampered
                                                  ? const Color(0xFFDC2626)
                                                  : (_isProfileComplete && _faceVerificationStatus == 'verified')
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap photo to change profile picture',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF9CA3AF),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              const SizedBox(height: 14),

                              Text(
                                _fullName,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Academic Details Card
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.graduationCap, size: 20, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _academicDetails,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E3D2F),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              GestureDetector(
                                onTap: () async {
                                  final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                                  if (updated == true) {
                                    _loadProfileData();
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF1E3D2F), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.pencil, size: 14, color: Color(0xFF1E3D2F)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Edit Profile & Information',
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Face Verification Banner
                        _buildFaceVerificationCard(),

                        // Complete Profile Details Banner (shown when profile info is incomplete)
                        if (!_isProfileInfoComplete) ...[
                          const SizedBox(height: 12),
                          _buildCompleteProfileCard(),
                        ],
                        const SizedBox(height: 20),

                        // Menu Settings Section
                        Text(
                          'ACCOUNT SETTINGS',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E3D2F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                          ),
                          child: Column(
                            children: [
                              _buildProfileItem(
                                icon: LucideIcons.userCheck,
                                title: 'Personal & Academic Information',
                                subtitle: 'Education level, location & details',
                                onTap: () async {
                                  final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                                  if (updated == true) {
                                    _loadProfileData();
                                  }
                                },
                              ),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              _buildProfileItem(
                                icon: LucideIcons.users,
                                title: 'Parents & Guardian Background',
                                subtitle: 'Family details, occupation & siblings',
                                onTap: () async {
                                  final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                                  if (updated == true) {
                                    _loadProfileData();
                                  }
                                },
                              ),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              _buildProfileItem(
                                icon: LucideIcons.shieldCheck,
                                title: 'Security Credentials',
                                subtitle: 'Change email address & account password',
                                onTap: () async {
                                  final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                                  if (updated == true) {
                                    _loadProfileData();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Log Out Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(LucideIcons.logOut, size: 16, color: Color(0xFFB91C1C)),
                            label: Text(
                              'Log Out',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDF2F2),
                              foregroundColor: const Color(0xFFB91C1C),
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFFEE2E2), width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
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

  // ─── Header Top Bar ────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        'STUDENT PROFILE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student\nprofile.',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage education info, location details & security credentials',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/books-hats-icon.png',
              width: 85,
              height: 75,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF16A34A), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}
