import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/widgets/custom_button.dart';
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
  String _gpaText = '...';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isProfileComplete = false;
  // Face verification
  String _faceVerificationStatus = 'unverified'; // unverified | verified | failed
  DateTime? _faceVerifiedAt;

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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
              final gpa = data['gpa'] != null ? data['gpa'].toString() : 'N/A';
              final scale = _scaleLabels[data['gpa_scale']?.toString()] ?? '1.0–5.0 Scale';

              final nameParts = [first, middle, last, suffix].where((s) => s.toString().trim().isNotEmpty).join(' ');
              _fullName = nameParts.trim().isNotEmpty ? nameParts : 'Scholar Student';
              _initials = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
              _academicDetails = '$eduLevel • $course\n$school';
              _gpaText = 'GWA: $gpa ($scale)';
              // Face verification
              _faceVerificationStatus =
                  data['face_verification_status']?.toString() ?? 'unverified';
              final verifiedAtRaw = data['face_verified_at']?.toString();
              _faceVerifiedAt = verifiedAtRaw != null
                  ? DateTime.tryParse(verifiedAtRaw)
                  : null;
            } else {
              _isProfileComplete = false;
              _fullName = user.email ?? 'Scholar Student';
              _initials = 'IS';
              _academicDetails = 'Complete profile details';
              _gpaText = 'GWA: Not set';
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Camera plugin requires restarting the app after installation. Please restart flutter run or pick from gallery.'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 5),
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.login);
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

  // ─────────────────────────────────────────────────────────────────────────
  // FACE VERIFICATION CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFaceVerificationCard() {
    if (_faceVerificationStatus == 'verified') {
      // Green verified card
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: AppColors.primary,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_faceVerifiedAt != null)
                    Text(
                      'Verified on ${_faceVerifiedAt!.day}/${_faceVerifiedAt!.month}/${_faceVerifiedAt!.year}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(LucideIcons.checkCircle,
                color: AppColors.primary, size: 20),
          ],
        ),
      );
    } else if (_faceVerificationStatus == 'failed') {
      // Red failed card with retry
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.pushNamed(
              context, AppRouter.faceVerification);
          if (result == true) _loadProfileData();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldOff,
                  color: AppColors.error,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                    Text(
                      'Tap to retry identity verification',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight,
                  color: AppColors.error, size: 18),
            ],
          ),
        ),
      );
    } else {
      // Unverified — amber CTA banner
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.pushNamed(
              context, AppRouter.faceVerification);
          if (result == true) _loadProfileData();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8EE), Color(0xFFFFF0D4)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.amber.withAlpha(80)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.amber.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldAlert,
                  color: AppColors.amberDeep,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberDeep,
                      ),
                    ),
                    Text(
                      'Upload your ID + face check to get verified',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.amberDeep,
                  borderRadius: BorderRadius.circular(8),
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
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Consistent Top Bar Header
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
                              'STUDENT PROFILE',
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
                          onTap: () async {
                            final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                            if (updated == true) {
                              _loadProfileData();
                            }
                          },
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
                                LucideIcons.pencil,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Student\nprofile.',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage education info, GPA, location details & security credentials',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Redesigned Scholar Profile Hero Card
                    AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Avatar with Photo Upload Trigger + Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _showPhotoOptionsModal,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.signatureGradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryDark.withAlpha(35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: _isUploadingPhoto
                                          ? const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
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
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          LucideIcons.camera,
                                          size: 14,
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
                                    if (_isProfileComplete && _faceVerificationStatus == 'verified')
                                      const VerifiedBadge(label: 'Verified Scholar')
                                    else
                                      const StatusChip(label: 'Incomplete Profile', type: StatusType.pending),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap photo to change profile picture',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: AppColors.rule),
                          const SizedBox(height: 16),

                          // Prominent Scholar Full Name (Uncut, multiline support)
                          Text(
                            _fullName,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Academic Summary & GPA Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.rule, width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.graduationCap, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _academicDetails,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.award, size: 16, color: AppColors.amberDeep),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _gpaText,
                                        style: GoogleFonts.dmMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          GestureDetector(
                            onTap: () async {
                              final updated = await Navigator.pushNamed(context, AppRouter.profileEdit);
                              if (updated == true) {
                                _loadProfileData();
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.pencil, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit Profile & Information',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
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

                    // ── Face Verification Banner ────────────────────────────
                    _buildFaceVerificationCard(),
                    const SizedBox(height: 24),

                    // Menu Sections
                    const SectionHeading(title: 'Account Settings'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildProfileItem(
                            icon: LucideIcons.userCheck,
                            title: 'Personal & Academic Information',
                            subtitle: 'Education level, GPA scale, location & details',
                            onTap: () async {
                              final updated = await Navigator.pushNamed(
                                  context, AppRouter.profileEdit);
                              if (updated == true) {
                                _loadProfileData();
                              }
                            },
                          ),
                          const Divider(height: 1, color: AppColors.rule),
                          _buildProfileItem(
                            icon: LucideIcons.shieldCheck,
                            title: 'Security Credentials',
                            subtitle: 'Change email address & account password',
                            onTap: () async {
                              final updated = await Navigator.pushNamed(
                                  context, AppRouter.profileEdit);
                              if (updated == true) {
                                _loadProfileData();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    CustomButton(
                      text: 'Log Out',
                      isOutlined: true,
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
