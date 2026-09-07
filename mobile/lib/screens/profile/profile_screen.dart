import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  RealtimeChannel? _realtimeChannel;

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
    if (_faceVerificationStatus == 'verified') {
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
                                            color: (_isProfileComplete && _faceVerificationStatus == 'verified')
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (_isProfileComplete && _faceVerificationStatus == 'verified')
                                                ? '✓ Verified Scholar'
                                                : (!_isProfileInfoComplete)
                                                    ? '● Incomplete Profile'
                                                    : '● Unverified Identity',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: (_isProfileComplete && _faceVerificationStatus == 'verified')
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
