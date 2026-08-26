import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScholarshipDetailScreen extends StatefulWidget {
  const ScholarshipDetailScreen({super.key});

  @override
  State<ScholarshipDetailScreen> createState() => _ScholarshipDetailScreenState();
}

class _ScholarshipDetailScreenState extends State<ScholarshipDetailScreen> {
  bool _isCheckingApp = false;
  Map<String, dynamic>? _existingApp;
  bool _hasCheckedApp = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _subscribeRealtime(String scholarId, String cycleId) {
    if (_realtimeChannel != null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('scholarship-detail-$cycleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_applications',
          callback: (payload) {
            if (mounted) {
              _checkExistingApplication(scholarId, cycleId, force: true);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_programs',
          callback: (payload) {
            if (mounted) {
              setState(() {});
            }
          },
        );
    _realtimeChannel?.subscribe();
  }

  Future<void> _checkExistingApplication(String scholarId, String cycleId, {bool force = false}) async {
    if (_hasCheckedApp && !force) return;
    setState(() => _isCheckingApp = true);
    try {
      final res = await Supabase.instance.client
          .from('scholarship_applications')
          .select()
          .eq('scholar_id', scholarId)
          .eq('cycle_id', cycleId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _existingApp = res;
          _hasCheckedApp = true;
          _isCheckingApp = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking existing application: $e');
      if (mounted) {
        setState(() => _isCheckingApp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final program = args?['program'] as Map<String, dynamic>?;
    final scholar = args?['scholar'] as Map<String, dynamic>?;

    final provider = program?['provider'] as Map<String, dynamic>?;
    final providerName = provider?['name'] ?? 'Scholarship Provider';
    final title = program?['title'] ?? 'Scholarship Program';
    final description = program?['description'] ?? 'No detailed description provided for this scholarship program.';
    
    final coversTuition = program?['covers_tuition'] == true;
    final coversStipend = program?['covers_stipend'] == true;
    final coversAllowance = program?['covers_allowance'] == true;

    final stipendAmt = program?['stipend_amount'] != null ? '₱${program?['stipend_amount']}' : '₱0';
    final amountText = calculateGrantValueSummary(program);
    final fundingFreq = program?['funding_frequency']?.toString();
    final periodText = fundingFreq != null && fundingFreq.isNotEmpty ? fundingFreq.toLowerCase() : 'total benefit';
    final slotsStr = program?['total_slots']?.toString() ?? 'Unlimited';

    final benefitsList = <String>[];
    if (coversTuition) {
      final tuitionType = program?['tuition_coverage_type']?.toString();
      final tuitionMax = double.tryParse(program?['tuition_max_amount']?.toString() ?? '');
      if (tuitionType == 'fixed_cap' && tuitionMax != null && tuitionMax > 0) {
        benefitsList.add('Tuition subsidy cap up to ${_formatCurrency(tuitionMax)}');
      } else {
        benefitsList.add('Full tuition and miscellaneous academic fees coverage');
      }
    }
    if (coversStipend) {
      benefitsList.add('$stipendAmt stipend / allowance support');
    }
    if (coversAllowance) {
      final allowance = program?['allowance_amount'] != null ? '₱${program?['allowance_amount']}' : '₱0';
      benefitsList.add('Book, uniform & learning device allowance of $allowance');
    }
    if (program?['other_benefits'] != null && program?['other_benefits'] is List) {
      for (final b in (program?['other_benefits'] as List)) {
        if (b.toString().trim().isNotEmpty) {
          benefitsList.add(b.toString());
        }
      }
    }
    if (benefitsList.isEmpty) {
      benefitsList.add('Refer to scholarship program guidelines for complete benefit details');
    }

    final mode = program?['disbursement_mode']?.toString() ?? program?['disbursementMode']?.toString() ?? 'online_transfer';
    final onlineType = program?['online_bank_type']?.toString() ?? program?['onlineBankType']?.toString() ?? 'personal_bank';
    if (mode == 'in_person_cash') {
      benefitsList.add('Release Channel: Over-the-Counter Cash (On-Site Payout)');
    } else {
      if (onlineType == 'provider_issued_card') {
        benefitsList.add('Release Channel: Online via Provider-Issued ATM Cash Card');
      } else {
        benefitsList.add('Release Channel: Online via Scholar Personal Bank / E-Wallet (GCash, Maya, etc.)');
      }
    }

    final eligibilityList = <String>[];
    if (program?['target_education_level'] != null) {
      const eduLabels = {
        'college': 'College / Undergraduate Students',
        'graduate': 'Graduate Studies (Masteral / PhD)',
        'senior_high': 'Senior High School (SHS)',
        'high_school': 'Junior High School (JHS)',
        'elementary': 'Elementary Grade School',
        'vocational': 'Vocational / TVET Certificate',
        'incoming_college': 'Incoming Freshmen (Graduating SHS)',
      };
      final level = program?['target_education_level']?.toString() ?? '';
      final levelLabel = eduLabels[level] ?? level;
      eligibilityList.add('Education Level: $levelLabel');
    }
    if (program?['course_eligibility'] != null && (program?['course_eligibility'] as List).isNotEmpty) {
      eligibilityList.add('Eligible Programs: ${(program?['course_eligibility'] as List).join(', ')}');
    }
    if (program?['year_level_eligibility'] != null && (program?['year_level_eligibility'] as List).isNotEmpty) {
      eligibilityList.add('Year Levels: ${(program?['year_level_eligibility'] as List).join(', ')}');
    }
    if (program?['availability_scope'] != null) {
      final scope = program?['availability_scope']?.toString().toUpperCase() ?? 'NATIONWIDE';
      eligibilityList.add('Geographic Coverage: $scope');
    }
    if (eligibilityList.isEmpty) {
      eligibilityList.add('Open to all qualified Philippine students');
    }

    final docList = <String>[];
    final requirements = program?['application_requirements'];
    if (requirements != null) {
      List<dynamic> parsedReqs = [];
      if (requirements is List) {
        parsedReqs = requirements;
      } else if (requirements is String) {
        try {
          parsedReqs = jsonDecode(requirements);
        } catch (e) {
          debugPrint('Error parsing requirements JSON: $e');
        }
      }
      for (final r in parsedReqs) {
        if (r is Map) {
          final name = r['name']?.toString() ?? '';
          final req = r['required'] == true ? ' [Required]' : ' [Optional]';
          if (name.isNotEmpty) {
            docList.add('$name$req');
          }
        }
      }
    }

    if (program?['minimum_gwa'] != null && program?['minimum_gwa'].toString().isNotEmpty == true) {
      final minGwa = program?['minimum_gwa'];
      final gs = program?['grading_system']?.toString() ?? 'scale_5';
      const gsLabels = {
        'scale_5': '(1.0–5.0 Scale)',
        'scale_4': '(4.0 Scale)',
        'percentage': '(Percentage)',
      };
      final gsNote = gsLabels[gs] ?? '';
      docList.insert(0, 'Grade / GWA Proof Requirement: Minimum GWA of $minGwa $gsNote [Required]');
    }

    if (docList.isEmpty) {
      docList.add('No specific document requirements configured for this cycle.');
    }

    final cycles = program?['cycles'] as List<dynamic>?;
    Map<String, dynamic>? activeCycle;
    if (cycles != null && cycles.isNotEmpty) {
      activeCycle = cycles.firstWhere(
        (c) => c['status']?.toString().toLowerCase() == 'open',
        orElse: () => cycles.first,
      ) as Map<String, dynamic>?;
    }

    final scholarId = scholar?['id']?.toString();
    final cycleId = activeCycle?['id']?.toString();

    if (scholarId != null && cycleId != null) {
      if (!_hasCheckedApp && !_isCheckingApp) {
        _checkExistingApplication(scholarId, cycleId);
      }
      _subscribeRealtime(scholarId, cycleId);
    }

    int daysLeft = 0;
    String formattedEndDate = 'Open';
    if (activeCycle != null && activeCycle['application_end_date'] != null) {
      try {
        final endDate = DateTime.tryParse(activeCycle['application_end_date'].toString());
        if (endDate != null) {
          final diff = endDate.difference(DateTime.now());
          daysLeft = diff.inDays + 1;
          
          final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
          formattedEndDate = '${months[endDate.month - 1]} ${endDate.day}, ${endDate.year}';
        }
      } catch (e) {
        debugPrint('Error parsing end date: $e');
      }
    }

    final hasApplied = _existingApp != null;
    final isComplete = EligibilityHelper.isProfileComplete(scholar);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          _buildHeader(context, title, providerName),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Program Hero Banner Card
                  _buildProgramHeroCard(
                    title: title,
                    providerName: providerName,
                    amountText: amountText,
                    periodText: periodText,
                    slotsStr: slotsStr,
                    daysLeft: daysLeft,
                    formattedEndDate: formattedEndDate,
                    program: program,
                  ),
                  const SizedBox(height: 20),

                  // About Section
                  _buildSectionCard(
                    title: 'About this Scholarship',
                    icon: LucideIcons.info,
                    child: Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Coverage & Benefits Section
                  _buildSectionCard(
                    title: 'Coverage & Benefits',
                    icon: LucideIcons.gift,
                    child: Column(
                      children: benefitsList.map((benefit) => _buildCheckRow(benefit)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Eligibility Requirements Section
                  _buildSectionCard(
                    title: 'Eligibility Criteria',
                    icon: LucideIcons.userCheck,
                    child: Column(
                      children: eligibilityList.map((elig) => _buildCheckRow(elig)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Documents to Prepare Section
                  _buildSectionCard(
                    title: 'Documents & Requirements',
                    icon: LucideIcons.fileText,
                    child: Column(
                      children: docList.map((doc) => _buildDocRow(doc)).toList(),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasApplied && !isComplete)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE8D0), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Profile incomplete. Update your information to apply.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.profileEdit);
                        },
                        child: Text(
                          'Update',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E3D2F),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (hasApplied) {
                      Navigator.pushNamed(context, AppRouter.applicationTracker);
                      return;
                    }

                    if (!isComplete) {
                      final missingFields = EligibilityHelper.getMissingFields(scholar);
                      _showIncompleteProfileModal(context, missingFields);
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRouter.documentUpload,
                        arguments: {
                          'program': program,
                          'scholar': scholar,
                          'cycle': activeCycle,
                        },
                      );
                    }
                  },
                  icon: Icon(
                    hasApplied
                        ? LucideIcons.clipboardList
                        : (!isComplete ? LucideIcons.userCheck : LucideIcons.send),
                    size: 18,
                  ),
                  label: Text(
                    hasApplied
                        ? 'View Application Tracker (${_existingApp!['status']?.toString().toUpperCase()})'
                        : (!isComplete ? 'Complete Profile to Apply' : 'Apply for this Scholarship'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasApplied ? const Color(0xFF374151) : const Color(0xFF1E3D2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // ─── Header Component ───────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String title, String providerName) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
                        LucideIcons.shieldCheck,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SCHOLARSHIP DETAILS',
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
                    'Program Information',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    providerName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/books-hats-icon.png',
              width: 75,
              height: 65,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Program Card ──────────────────────────────────────────────────────
  Widget _buildProgramHeroCard({
    required String title,
    required String providerName,
    required String amountText,
    required String periodText,
    required String slotsStr,
    required int daysLeft,
    required String formattedEndDate,
    required Map<String, dynamic>? program,
  }) {
    final typeLabel = program?['scholarship_type']?.toString().toUpperCase() ?? 'MERIT-BASED';
    final showUrgent = daysLeft > 0 && daysLeft <= 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  typeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: showUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      showUrgent ? LucideIcons.alertCircle : LucideIcons.calendarCheck,
                      size: 12,
                      color: showUrgent ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      daysLeft > 0 ? '$daysLeft days left' : 'Open Cycle',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: showUrgent ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            providerName,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFDCFCE7)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  label: 'Grant Value',
                  value: amountText,
                  subLabel: periodText,
                  icon: LucideIcons.banknote,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFDCFCE7)),
              Expanded(
                child: _buildHeroStat(
                  label: 'Available Slots',
                  value: slotsStr,
                  subLabel: 'Applicants',
                  icon: LucideIcons.users,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
    required String subLabel,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF16A34A), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF6B7280)),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section Card Wrapper ──────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF16A34A), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String docText) {
    final isReq = docText.contains('[Required]');
    final isOpt = docText.contains('[Optional]');
    final cleanText = docText.replaceAll('[Required]', '').replaceAll('[Optional]', '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isReq ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReq ? LucideIcons.fileCheck : LucideIcons.fileText,
              size: 11,
              color: isReq ? const Color(0xFFD97706) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cleanText,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ),
          if (isReq || isOpt)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isReq ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isReq ? 'Required' : 'Optional',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isReq ? const Color(0xFFD97706) : const Color(0xFF6B7280),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showIncompleteProfileModal(BuildContext context, List<String> missingFields) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Profile Completion Required',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Before you can apply for this scholarship, you must complete your profile information:',
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 12),
            ...missingFields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.xCircle, size: 14, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppRouter.profileEdit);
                },
                icon: const Icon(LucideIcons.userCheck, size: 16),
                label: Text(
                  'Update Profile Information',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3D2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(num amount) {
  final str = amount.toStringAsFixed(0);
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return '₱${str.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
}

String calculateGrantValueSummary(Map<String, dynamic>? program) {
  if (program == null) return 'Grant Assistance';

  double totalMonetaryGrant = 0.0;

  // 1. Base program grant amount
  final amountVal = double.tryParse(program['amount']?.toString() ?? '') ??
      double.tryParse(program['grant_amount']?.toString() ?? '') ?? 0.0;
  totalMonetaryGrant += amountVal;

  // 2. Stipend / Allowance amount
  if (program['covers_stipend'] == true && program['stipend_amount'] != null) {
    totalMonetaryGrant += double.tryParse(program['stipend_amount'].toString()) ?? 0.0;
  }

  // 3. Book / Device Allowance amount
  if (program['covers_allowance'] == true && program['allowance_amount'] != null) {
    totalMonetaryGrant += double.tryParse(program['allowance_amount'].toString()) ?? 0.0;
  }

  // 4. Fixed Cap Tuition Subsidy
  final coversTuition = program['covers_tuition'] == true || program['coverstuition'] == true;
  final tuitionType = program['tuition_coverage_type']?.toString();
  final tuitionMax = double.tryParse(program['tuition_max_amount']?.toString() ?? '');
  if (coversTuition && tuitionType == 'fixed_cap' && tuitionMax != null) {
    totalMonetaryGrant += tuitionMax;
  }

  // 5. Custom Benefits List
  if (program['custom_benefits'] != null && program['custom_benefits'] is List) {
    for (final b in (program['custom_benefits'] as List)) {
      if (b is Map && b['amount'] != null) {
        totalMonetaryGrant += double.tryParse(b['amount'].toString()) ?? 0.0;
      }
    }
  }

  if (totalMonetaryGrant > 0) {
    return _formatCurrency(totalMonetaryGrant);
  }

  if (coversTuition) {
    if (tuitionType == 'fixed_cap' && tuitionMax != null && tuitionMax > 0) {
      return _formatCurrency(tuitionMax);
    }
    return 'Full Tuition Covered';
  }

  return 'Grant Assistance';
}
