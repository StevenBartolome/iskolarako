import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/utils/app_router.dart';

class ProfileIntegrityResult {
  final bool isTampered;
  final String? reason;
  final String? verifiedIdName;
  final String? currentProfileName;

  const ProfileIntegrityResult({
    required this.isTampered,
    this.reason,
    this.verifiedIdName,
    this.currentProfileName,
  });

  static const valid = ProfileIntegrityResult(isTampered: false);
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final bool isSameAccount;
  final String matchMethod;
  final String? existingApplicationId;
  final String? existingApplicationStatus;
  final String? matchedScholarId;
  final String? matchedApplicantName;
  final String? matchedEmail;
  final DateTime? submittedAt;
  final String message;

  const DuplicateCheckResult({
    required this.isDuplicate,
    this.isSameAccount = false,
    this.matchMethod = 'Personal Identity Matching',
    this.existingApplicationId,
    this.existingApplicationStatus,
    this.matchedScholarId,
    this.matchedApplicantName,
    this.matchedEmail,
    this.submittedAt,
    this.message = '',
  });

  static const DuplicateCheckResult notDuplicate = DuplicateCheckResult(
    isDuplicate: false,
  );
}

class DuplicateCheckService {
  /// Normalize text: lowercase, trimmed, collapsed whitespace
  static String _normalize(String? s) {
    if (s == null) return '';
    return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Normalize birth date to YYYY-MM-DD
  static String? _normalizeDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return '${raw.year.toString().padLeft(4, '0')}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
    }
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
    if (str.contains('T')) {
      return str.split('T').first.trim();
    }
    return str;
  }

  /// Normalize Philippine mobile phone number to standard 10 digits
  static String _normalizePhone(String? p) {
    if (p == null) return '';
    var clean = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('63') && clean.length == 12) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0') && clean.length == 11) {
      clean = clean.substring(1);
    }
    return clean;
  }

  /// Mask email address for privacy while providing clear recognition (e.g. j***n@gmail.com)
  static String _maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return 'another registered account';
    final parts = email.trim().split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  /// Format date for display in dialog
  static String _formatDisplayDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Compute Levenshtein similarity [0.0 to 1.0]
  static double _nameSimilarity(String s1, String s2) {
    final a = s1.trim().toLowerCase();
    final b = s2.trim().toLowerCase();
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((curr, next) => curr < next ? curr : next);
      }
    }

    final distance = dp[m][n];
    final maxLen = m > n ? m : n;
    return 1.0 - (distance / maxLen);
  }

  /// Advanced Philippine Identity Matching Rule Engine
  static bool _isIdentityDuplicate({
    required String candFirst,
    required String candMiddle,
    required String candLast,
    required String? candBirth,
    required String candPhone,
    required String normFirst,
    required String normMiddle,
    required String normLast,
    required String? normBirthDate,
    required String normPhone,
  }) {
    final hasBirthMatch = (normBirthDate != null && candBirth != null && normBirthDate == candBirth);
    final hasPhoneMatch = (normPhone.isNotEmpty && candPhone.isNotEmpty && normPhone == candPhone);

    // Tokenize names
    final candFirstTokens = candFirst.split(' ').where((t) => t.isNotEmpty).toSet();
    final normFirstTokens = normFirst.split(' ').where((t) => t.isNotEmpty).toSet();

    final candAllTokens = {...candFirstTokens, ...candMiddle.split(' '), ...candLast.split(' ')}
        .where((t) => t.length > 1)
        .toSet();
    final normAllTokens = {...normFirstTokens, ...normMiddle.split(' '), ...normLast.split(' ')}
        .where((t) => t.length > 1)
        .toSet();

    final sharedAllTokens = candAllTokens.intersection(normAllTokens);
    final sharedFirstTokens = candFirstTokens.intersection(normFirstTokens);

    // Check if First Names overlap (e.g. "mark steven" vs "mark", or similarity >= 75%)
    final hasSharedFirst = sharedFirstTokens.isNotEmpty ||
        (candFirst.isNotEmpty && normFirst.isNotEmpty && (candFirst.contains(normFirst) || normFirst.contains(candFirst))) ||
        _nameSimilarity(candFirst, normFirst) >= 0.75;

    // Check Last / Middle Name links
    final hasLastMatch = candLast.isNotEmpty && normLast.isNotEmpty &&
        (candLast == normLast || _nameSimilarity(candLast, normLast) >= 0.75);
    final hasMiddleMatch = candMiddle.isNotEmpty && normMiddle.isNotEmpty &&
        (candMiddle == normMiddle || _nameSimilarity(candMiddle, normMiddle) >= 0.75);

    // Maiden Surname -> Married Middle Name / Surname link
    final hasMaidenOrMiddleLink = (candLast.isNotEmpty && (candLast == normMiddle || candMiddle == normLast)) ||
        (normLast.isNotEmpty && (normLast == candMiddle || normMiddle == candLast)) ||
        (candMiddle.isNotEmpty && candMiddle == normMiddle);

    // ─── RULE 1: SAME BIRTH DATE + SHARED FIRST NAME ───
    if (hasBirthMatch && hasSharedFirst) {
      // 1A: Last name matches OR Middle name matches OR Maiden link OR 2+ shared name tokens
      if (hasLastMatch || hasMiddleMatch || hasMaidenOrMiddleLink || sharedAllTokens.length >= 2) {
        return true;
      }
      // 1B: Married woman validation (First name + Birth date match, and surname changed on marriage)
      if (sharedFirstTokens.isNotEmpty || candFirst == normFirst) {
        return true;
      }
    }

    // ─── RULE 2: SAME BIRTH DATE + MULTIPLE SHARED NAME TOKENS (e.g. Mark + Mendoza) ───
    if (hasBirthMatch && sharedAllTokens.length >= 2) {
      return true;
    }

    // ─── RULE 3: SAME PHONE + SHARED FIRST NAME + (Last Match OR Middle Match OR Shared Tokens) ───
    if (hasPhoneMatch && hasSharedFirst && (hasLastMatch || hasMiddleMatch || sharedAllTokens.length >= 2)) {
      return true;
    }

    // ─── RULE 4: EXACT FULL NAME MATCH (First + Last) + (Same Birth OR Same Phone OR Same Middle OR Null Date) ───
    if (hasLastMatch && (candFirst == normFirst || _nameSimilarity(candFirst, normFirst) >= 0.85)) {
      if (hasBirthMatch || hasPhoneMatch || hasMiddleMatch || normBirthDate == null || candBirth == null) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the scholar's current profile name differs significantly from the name on their verified ID.
  /// Applies considerations for minimal changes (middle names, suffixes, typos, married maiden names).
  static ProfileIntegrityResult checkProfileIntegrity({
    required Map<String, dynamic>? scholar,
  }) {
    if (scholar == null) return ProfileIntegrityResult.valid;

    final faceStatus = scholar['face_verification_status']?.toString().toLowerCase().trim();
    if (faceStatus != 'verified') {
      // If face is not verified yet, profile tampering check is not applicable
      return ProfileIntegrityResult.valid;
    }

    final currFirst = _normalize(scholar['first_name']?.toString());
    final currMiddle = _normalize(scholar['middle_name']?.toString());
    final currLast = _normalize(scholar['last_name']?.toString());
    final currentFullName = [currFirst, currMiddle, currLast].where((s) => s.isNotEmpty).join(' ');

    // Extract verified ID name recorded during Face & ID Verification
    String? verifiedIdName = scholar['verified_id_name']?.toString() ??
        scholar['verified_id_full_name']?.toString() ??
        scholar['id_name']?.toString();

    // If verified_id_name is not stored in top-level, check requirements_submitted / metadata / auth user metadata
    if (verifiedIdName == null || verifiedIdName.trim().isEmpty) {
      final reqs = scholar['requirements_submitted'];
      if (reqs is Map) {
        verifiedIdName = reqs['verified_id_name']?.toString() ??
            reqs['verified_id_data']?['id_full_name']?.toString() ??
            reqs['verified_id_data']?['name']?.toString();
      }
    }

    if (verifiedIdName == null || verifiedIdName.trim().isEmpty) {
      try {
        final uMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
        final idData = uMeta?['verified_id_data'];
        if (idData is Map) {
          verifiedIdName = idData['id_full_name']?.toString() ??
              '${idData['id_first_name'] ?? ''} ${idData['id_last_name'] ?? ''}'.trim();
        }
      } catch (_) {}
    }

    if (verifiedIdName == null || verifiedIdName.trim().isEmpty) {
      return ProfileIntegrityResult.valid;
    }

    final idNorm = _normalize(verifiedIdName);
    if (idNorm.isEmpty) return ProfileIntegrityResult.valid;

    final idTokens = idNorm.replaceAll(RegExp(r'[^a-z\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
    if (idTokens.isEmpty) return ProfileIntegrityResult.valid;

    final idSurname = idTokens.last;
    final idGivenTokens = idTokens.sublist(0, idTokens.length - 1);
    final idGiven = idGivenTokens.join(' ');

    final firstTokens = currFirst.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
    final lastTokens = currLast.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();

    // 1. Check Legal Surname Match:
    bool surnameMatches = false;
    for (final l in lastTokens) {
      if (l == idSurname || idSurname.contains(l)) {
        surnameMatches = true;
        break;
      }
    }

    // 2. Check Married Woman Surname Transition:
    // Maiden surname on ID becomes middle name in profile AND first name must be identical
    bool marriedMaidenMatches = false;
    if (!surnameMatches && currMiddle.isNotEmpty) {
      if (currMiddle.contains(idSurname) || idSurname.contains(currMiddle)) {
        if (currFirst == idGiven || _nameSimilarity(currFirst, idGiven) >= 0.85 || (idGivenTokens.isNotEmpty && firstTokens.contains(idGivenTokens.first))) {
          marriedMaidenMatches = true;
        }
      }
    }

    // 3. Check First Name Match:
    bool firstMatches = false;
    if (idGiven.isEmpty) {
      firstMatches = true;
    } else {
      for (final f in firstTokens) {
        if (idGivenTokens.contains(f) || idGiven.contains(f) || _nameSimilarity(currFirst, idGiven) >= 0.80) {
          firstMatches = true;
          break;
        }
      }
    }

    // If surname does not match and is not a legitimate married woman transition:
    if (!surnameMatches && !marriedMaidenMatches) {
      final reason = 'Profile changing detected: Declared surname ($currLast) differs from verified ID ($verifiedIdName).';
      return ProfileIntegrityResult(
        isTampered: true,
        reason: reason,
        verifiedIdName: verifiedIdName,
        currentProfileName: currentFullName,
      );
    }

    // If first name does not match at all:
    if (!firstMatches) {
      final reason = 'Profile changing detected: Declared first name ($currFirst) differs from verified ID ($verifiedIdName).';
      return ProfileIntegrityResult(
        isTampered: true,
        reason: reason,
        verifiedIdName: verifiedIdName,
        currentProfileName: currentFullName,
      );
    }

    return ProfileIntegrityResult.valid;
  }

  /// Display Profile Modification Discrepancy Dialog
  static Future<void> showProfileTamperedDialog(
    BuildContext context,
    ProfileIntegrityResult integrity, {
    VoidCallback? onReverify,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.shieldAlert, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Discrepancy',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Application Blocked',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A significant difference was detected between your current profile name and your verified Government/Student ID.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF374151), height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    icon: LucideIcons.fileCheck2,
                    label: 'Name on Verified ID',
                    value: integrity.verifiedIdName ?? 'Verified ID',
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: LucideIcons.userX,
                    label: 'Current Profile Name',
                    value: integrity.currentProfileName ?? 'Profile Name',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security Rule: To prevent account evasion and identity mismatch, profile names cannot be changed to a different person after ID verification. Please complete identity re-verification or revert your profile details.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRouter.profileEdit);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Edit Profile', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRouter.faceVerification);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text('Re-verify ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Check whether an application already exists for this scholarship cycle
  /// under either the current account OR a different account with matching personal identifiers (name + birth date).
  static Future<DuplicateCheckResult> checkForDuplicate({
    required String cycleId,
    String? currentScholarId,
    required String firstName,
    String? middleName,
    required String lastName,
    dynamic birthDate,
    String? phone,
    String? programTitle,
  }) async {
    try {
      final cleanCycleId = cycleId.trim();
      if (cleanCycleId.isEmpty) return DuplicateCheckResult.notDuplicate;

      final normFirst = _normalize(firstName);
      final normMiddle = _normalize(middleName);
      final normLast = _normalize(lastName);
      final normBirthDate = _normalizeDate(birthDate);
      final normPhone = _normalizePhone(phone);

      if (normFirst.isEmpty && normLast.isEmpty) {
        return DuplicateCheckResult.notDuplicate;
      }

      final supabase = Supabase.instance.client;

      // ─── STEP 1: Direct Self-Check ──────────────────────────────────────────
      // Check if the current scholar record already has an application in this cycle
      if (currentScholarId != null && currentScholarId.isNotEmpty) {
        final existingSelf = await supabase
            .from('scholarship_applications')
            .select('id, status, created_at')
            .eq('cycle_id', cleanCycleId)
            .eq('scholar_id', currentScholarId)
            .neq('status', 'withdrawn')
            .maybeSingle();

        if (existingSelf != null) {
          final status = existingSelf['status']?.toString().toUpperCase() ?? 'PENDING';
          return DuplicateCheckResult(
            isDuplicate: true,
            isSameAccount: true,
            existingApplicationId: existingSelf['id']?.toString(),
            existingApplicationStatus: status,
            matchedScholarId: currentScholarId,
            matchedApplicantName: '$firstName $lastName'.trim(),
            submittedAt: DateTime.tryParse(existingSelf['created_at']?.toString() ?? ''),
            message: 'You have already submitted an application for this scholarship cycle (Status: $status).',
          );
        }
      }

      // ─── STEP 2: Cross-Account Identifier Matching ─────────────────────────
      // Query applications for this cycle with joined scholar details
      try {
        final List<dynamic> apps = await supabase
            .from('scholarship_applications')
            .select('''
              id,
              cycle_id,
              scholar_id,
              status,
              created_at,
              scholar:scholar_id (
                id,
                user_id,
                first_name,
                middle_name,
                last_name,
                suffix,
                birth_date,
                phone
              )
            ''')
            .eq('cycle_id', cleanCycleId)
            .neq('status', 'withdrawn');

        for (final app in apps) {
          final sId = app['scholar_id']?.toString();
          // If this is the current scholar, we already checked it in Step 1
          if (currentScholarId != null && sId == currentScholarId) continue;

          final scholarData = app['scholar'] as Map<String, dynamic>?;
          if (scholarData == null) continue;

          final candFirst = _normalize(scholarData['first_name']?.toString());
          final candMiddle = _normalize(scholarData['middle_name']?.toString());
          final candLast = _normalize(scholarData['last_name']?.toString());
          final candBirth = _normalizeDate(scholarData['birth_date']);
          final candPhone = _normalizePhone(scholarData['phone']?.toString());

          final isMatch = _isIdentityDuplicate(
            candFirst: candFirst,
            candMiddle: candMiddle,
            candLast: candLast,
            candBirth: candBirth,
            candPhone: candPhone,
            normFirst: normFirst,
            normMiddle: normMiddle,
            normLast: normLast,
            normBirthDate: normBirthDate,
            normPhone: normPhone,
          );

          if (isMatch) {
            final status = app['status']?.toString().toUpperCase() ?? 'PENDING';
            String? rawEmail;
            final uId = scholarData['user_id']?.toString();
            if (uId != null && uId.isNotEmpty) {
              try {
                final uRes = await supabase.from('users').select('email').eq('id', uId).maybeSingle();
                rawEmail = uRes?['email']?.toString();
              } catch (_) {}
            }
            final maskedEmail = _maskEmail(rawEmail);
            final matchedFullName =
                '${scholarData['first_name'] ?? ''} ${scholarData['last_name'] ?? ''}'
                    .trim();
            final createdAt = DateTime.tryParse(app['created_at']?.toString() ?? '');

            return DuplicateCheckResult(
              isDuplicate: true,
              isSameAccount: false,
              matchMethod: 'Personal Identity (Name & Date of Birth)',
              existingApplicationId: app['id']?.toString(),
              existingApplicationStatus: status,
              matchedScholarId: sId,
              matchedApplicantName: matchedFullName.isNotEmpty
                  ? matchedFullName
                  : '$firstName $lastName'.trim(),
              matchedEmail: maskedEmail,
              submittedAt: createdAt,
              message:
                  'A duplicate application was detected. An application for this scholarship cycle has already been submitted under another account ($maskedEmail) for applicant $matchedFullName.',
            );
          }
        }
      } catch (queryErr) {
        debugPrint('[DuplicateCheckService] Join query exception: $queryErr');
        // Fallback to separate scholar table search if relational join was blocked
        return await _fallbackCheck(
          supabase: supabase,
          cleanCycleId: cleanCycleId,
          currentScholarId: currentScholarId,
          normFirst: normFirst,
          normMiddle: normMiddle,
          normLast: normLast,
          normBirthDate: normBirthDate,
          normPhone: normPhone,
          firstName: firstName,
          lastName: lastName,
        );
      }

      return DuplicateCheckResult.notDuplicate;
    } catch (e) {
      debugPrint('[DuplicateCheckService] General error during duplicate check: $e');
      // In case of unexpected network error, fail open so legitimate scholars are not stuck
      return DuplicateCheckResult.notDuplicate;
    }
  }

  /// Fallback matching when PostgREST nested select is unavailable or restricted
  static Future<DuplicateCheckResult> _fallbackCheck({
    required SupabaseClient supabase,
    required String cleanCycleId,
    required String? currentScholarId,
    required String normFirst,
    required String normMiddle,
    required String normLast,
    required String? normBirthDate,
    required String normPhone,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final matchingScholars = await supabase
          .from('scholar')
          .select('id, user_id, first_name, middle_name, last_name, birth_date, phone');

      final List<String> candidateScholarIds = [];
      final Map<String, Map<String, dynamic>> scholarMap = {};

      for (final s in (matchingScholars as List<dynamic>)) {
        final sId = s['id']?.toString();
        if (sId == null || (currentScholarId != null && sId == currentScholarId)) {
          continue;
        }

        final candFirst = _normalize(s['first_name']?.toString());
        final candMiddle = _normalize(s['middle_name']?.toString());
        final candLast = _normalize(s['last_name']?.toString());
        final candBirth = _normalizeDate(s['birth_date']);
        final candPhone = _normalizePhone(s['phone']?.toString());

        final isMatch = _isIdentityDuplicate(
          candFirst: candFirst,
          candMiddle: candMiddle,
          candLast: candLast,
          candBirth: candBirth,
          candPhone: candPhone,
          normFirst: normFirst,
          normMiddle: normMiddle,
          normLast: normLast,
          normBirthDate: normBirthDate,
          normPhone: normPhone,
        );

        if (isMatch) {
          candidateScholarIds.add(sId);
          scholarMap[sId] = s as Map<String, dynamic>;
        }
      }

      if (candidateScholarIds.isNotEmpty) {
        final apps = await supabase
            .from('scholarship_applications')
            .select('id, scholar_id, cycle_id, status, created_at')
            .eq('cycle_id', cleanCycleId)
            .filter('scholar_id', 'in', candidateScholarIds)
            .neq('status', 'withdrawn');

        if ((apps as List<dynamic>).isNotEmpty) {
          final matchedApp = apps.first;
          final sId = matchedApp['scholar_id']?.toString() ?? '';
          final sData = scholarMap[sId];
          String? rawEmail;
          final uId = sData?['user_id']?.toString();
          if (uId != null && uId.isNotEmpty) {
            try {
              final uRes = await supabase.from('users').select('email').eq('id', uId).maybeSingle();
              rawEmail = uRes?['email']?.toString();
            } catch (_) {}
          }
          final maskedEmail = _maskEmail(rawEmail);
          final status = matchedApp['status']?.toString().toUpperCase() ?? 'PENDING';
          final matchedName =
              '${sData?['first_name'] ?? firstName} ${sData?['last_name'] ?? lastName}'
                  .trim();
          final createdAt = DateTime.tryParse(matchedApp['created_at']?.toString() ?? '');

          return DuplicateCheckResult(
            isDuplicate: true,
            isSameAccount: false,
            matchMethod: 'Personal Identity (Name & Date of Birth)',
            existingApplicationId: matchedApp['id']?.toString(),
            existingApplicationStatus: status,
            matchedScholarId: sId,
            matchedApplicantName: matchedName,
            matchedEmail: maskedEmail,
            submittedAt: createdAt,
            message:
                'A duplicate application was detected. An application for this scholarship cycle has already been submitted under another account ($maskedEmail) for applicant $matchedName.',
          );
        }
      }
    } catch (e) {
      debugPrint('[DuplicateCheckService] Fallback check notice: $e');
    }

    return DuplicateCheckResult.notDuplicate;
  }

  /// Display a modal dialog alerting the user about duplicate application
  static Future<void> showDuplicateWarningDialog(
    BuildContext context,
    DuplicateCheckResult result, {
    String? programTitle,
  }) async {
    final title = programTitle ?? 'this scholarship program';
    final isSame = result.isSameAccount;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFEE2E2), width: 1.5),
              ),
              child: const Icon(
                LucideIcons.shieldAlert,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duplicate Application',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Submission Blocked',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              isSame
                  ? 'You have already submitted an active application for $title in this application cycle.'
                  : 'An application for $title in this cycle has already been submitted using these applicant details under another registered account.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF374151),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            // Details Container Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    icon: LucideIcons.user,
                    label: 'Applicant Name',
                    value: result.matchedApplicantName ?? 'Applicant',
                  ),
                  if (!isSame && result.matchedEmail != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: LucideIcons.mail,
                      label: 'Registered Account',
                      value: result.matchedEmail!,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: LucideIcons.shieldCheck,
                    label: 'Detection Method',
                    value: result.matchMethod,
                  ),
                  if (result.existingApplicationStatus != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: LucideIcons.fileCheck2,
                      label: 'Application Status',
                      value: result.existingApplicationStatus!,
                      isStatus: true,
                    ),
                  ],
                  if (result.submittedAt != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: LucideIcons.calendar,
                      label: 'Date Submitted',
                      value: _formatDisplayDate(result.submittedAt),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Policy Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Policy Rule: To ensure fairness, each student is allowed only one application per scholarship cycle.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF92400E),
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'I Understand',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isStatus = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              isStatus
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @visibleForTesting
  static bool isIdentityDuplicateForTesting({
    required String candFirst,
    required String candMiddle,
    required String candLast,
    required String? candBirth,
    required String candPhone,
    required String normFirst,
    required String normMiddle,
    required String normLast,
    required String? normBirthDate,
    required String normPhone,
  }) {
    return _isIdentityDuplicate(
      candFirst: _normalize(candFirst),
      candMiddle: _normalize(candMiddle),
      candLast: _normalize(candLast),
      candBirth: _normalizeDate(candBirth),
      candPhone: _normalizePhone(candPhone),
      normFirst: _normalize(normFirst),
      normMiddle: _normalize(normMiddle),
      normLast: _normalize(normLast),
      normBirthDate: _normalizeDate(normBirthDate),
      normPhone: _normalizePhone(normPhone),
    );
  }
}
