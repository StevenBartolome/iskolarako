import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/widgets/custom_header.dart';
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
    final providerName = provider?['name'] ?? 'Provider';
    final title = program?['title'] ?? 'Scholarship';
    final description = program?['description'] ?? '';
    
    final coversTuition = program?['covers_tuition'] == true;
    final coversStipend = program?['covers_stipend'] == true;
    final coversAllowance = program?['covers_allowance'] == true;

    final stipendAmt = program?['stipend_amount'] != null ? '₱${program?['stipend_amount']}' : '₱0';
    final amountText = coversStipend ? stipendAmt : (coversTuition ? 'Tuition Covered' : 'Varies');
    final periodText = coversStipend ? 'per semester' : '';
    final budgetStr = amountText;
    final slotsStr = program?['total_slots']?.toString() ?? 'Unlimited';

    final benefitsList = <String>[];
    if (coversTuition) benefitsList.add('Full tuition and miscellaneous fees coverage');
    if (coversStipend) {
      benefitsList.add('$stipendAmt monthly living stipend');
    }
    if (coversAllowance) {
      final allowance = program?['allowance_amount'] != null ? '₱${program?['allowance_amount']}' : '₱0';
      benefitsList.add('Additional book/living allowance of $allowance');
    }
    if (program?['other_benefits'] != null && program?['other_benefits'] is List) {
      for (final b in (program?['other_benefits'] as List)) {
        benefitsList.add(b.toString());
      }
    }
    if (benefitsList.isEmpty) {
      benefitsList.add('Refer to program coordinator for full benefits listing');
    }

    final eligibilityList = <String>[];
    if (program?['target_education_level'] != null) {
      const eduLabels = {
        'college': 'College / Undergraduate',
        'graduate': 'Graduate Studies (MA/PhD)',
        'senior_high': 'Senior High School (SHS)',
        'high_school': 'High School (JHS)',
        'elementary': 'Elementary',
        'vocational': 'Vocational / TVET',
        'incoming_college': 'Incoming College (Graduating SHS)',
      };
      final level = program?['target_education_level']?.toString() ?? '';
      final levelLabel = eduLabels[level] ?? level;
      eligibilityList.add('🎓 Education Level: $levelLabel');
    }
    if (program?['citizenship_required'] != null) {
      eligibilityList.add('${program?['citizenship_required']} citizenship required');
    }
    if (program?['course_eligibility'] != null && (program?['course_eligibility'] as List).isNotEmpty) {
      eligibilityList.add('Open to: ${(program?['course_eligibility'] as List).join(', ')}');
    }
    if (program?['year_level_eligibility'] != null && (program?['year_level_eligibility'] as List).isNotEmpty) {
      eligibilityList.add('Year/Grade levels: ${(program?['year_level_eligibility'] as List).join(', ')}');
    }
    if (program?['minimum_gwa'] != null) {
      const gsLabels = {
        'scale_5': '(1–5 Scale, lower = better)',
        'scale_4': '(4.0 Scale, higher = better)',
        'percentage': '(Percentage, 60–100)',
      };
      final gs = program?['grading_system']?.toString() ?? 'scale_5';
      final gsNote = gsLabels[gs] ?? '';
      eligibilityList.add('Minimum Grade: ${program?['minimum_gwa']} $gsNote');
    }
    if (eligibilityList.isEmpty) {
      eligibilityList.add('Open to all eligible students');
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
          debugPrint('Error decoding requirements: $e');
        }
      }
      for (final r in parsedReqs) {
        if (r is Map) {
          final name = r['name']?.toString() ?? '';
          final req = r['required'] == true ? ' (Required)' : ' (Optional)';
          if (name.isNotEmpty) {
            docList.add('$name$req');
          }
        }
      }
    }
    if (docList.isEmpty) {
      docList.add('No specific document requirements configured.');
    }

    final hasApplied = _existingApp != null;
    final buttonText = hasApplied
        ? 'View Application Tracker (${_existingApp!['status']?.toString().toUpperCase()})'
        : 'Apply for this Scholarship';

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, title, providerName, program),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBar(slotsStr, budgetStr, periodText, program),
                  const SizedBox(height: 16),
                  _buildDeadlineAlert(daysLeft, formattedEndDate),
                  const SizedBox(height: 22),
                  _buildSection(
                    title: 'About this Scholarship',
                    content: description,
                  ),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Coverage & Benefits'),
                  const SizedBox(height: 12),
                  _buildBulletList(benefitsList),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Eligibility Requirements'),
                  const SizedBox(height: 12),
                  _buildCheckList(eligibilityList),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Documents to Prepare'),
                  const SizedBox(height: 12),
                  _buildDocList(docList),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasApplied && !EligibilityHelper.isProfileComplete(scholar))
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: AppColors.amberDeep, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your profile is incomplete. Complete it to unlock application.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.profileEdit);
                        },
                        child: Text(
                          'Complete Now',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              CustomButton(
                text: hasApplied
                    ? buttonText
                    : (!EligibilityHelper.isProfileComplete(scholar) ? 'Complete Profile to Apply' : buttonText),
                icon: hasApplied
                    ? LucideIcons.clipboardList
                    : (!EligibilityHelper.isProfileComplete(scholar) ? LucideIcons.userCheck : LucideIcons.send),
                onPressed: () {
                  if (hasApplied) {
                    Navigator.pushNamed(context, AppRouter.applicationTracker);
                    return;
                  }

                  final isComplete = EligibilityHelper.isProfileComplete(scholar);
                  if (!isComplete) {
                    final missingFields = EligibilityHelper.getMissingFields(scholar);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              'Profile Incomplete',
                              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Before you can apply for this scholarship, you must complete your profile. The following fields are missing:',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              ...missingFields.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.dot, size: 16, color: AppColors.error),
                                    const SizedBox(width: 6),
                                    Text(
                                      f,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 12),
                              Text(
                                'Please update your profile details to proceed.',
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, AppRouter.profileEdit);
                            },
                            icon: const Icon(LucideIcons.userCheck, size: 16, color: Colors.white),
                            label: Text(
                              'Complete Profile Now',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    );
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
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildHeader(BuildContext context, String title, String providerName, Map<String, dynamic>? program) {
    final typeLabel = program?['scholarship_type']?.toString().toUpperCase() ?? 'MERIT-BASED';
    final providerShort = providerName.length > 20 ? '${providerName.substring(0, 20)}...' : providerName;

    return CustomHeader(
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.chevronLeft,
                        color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.share2,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(
                      label: providerShort,
                      type: StatusType.approved,
                    ),
                    StatusChip(
                      label: typeLabel,
                      type: StatusType.info,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  providerName,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(160),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(String slotsStr, String budgetStr, String periodText, Map<String, dynamic>? program) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            _InfoBarItem(value: budgetStr, label: periodText.isNotEmpty ? periodText : 'Total Allowance', isMono: true),
            VerticalDivider(width: 1, color: AppColors.rule),
            const _InfoBarItem(value: 'Variable', label: 'Duration'),
            VerticalDivider(width: 1, color: AppColors.rule),
            _InfoBarItem(value: slotsStr, label: 'Slots Available'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineAlert(int daysLeft, String formattedEndDate) {
    final showUrgent = daysLeft > 0 && daysLeft <= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: showUrgent ? AppColors.errorBg : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (showUrgent ? AppColors.error : AppColors.primary).withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(
            showUrgent ? LucideIcons.alertCircle : LucideIcons.calendar,
            color: showUrgent ? AppColors.error : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                daysLeft > 0
                    ? 'Application closes in $daysLeft day${daysLeft > 1 ? "s" : ""}'
                    : 'Application Open',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: showUrgent ? AppColors.error : AppColors.primaryDark,
                ),
              ),
              Text(
                daysLeft > 0
                    ? '$formattedEndDate · 11:59 PM'
                    : 'Ongoing Cycle',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: (showUrgent ? AppColors.error : AppColors.textSecondary).withAlpha(180),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: title),
        const SizedBox(height: 10),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.check,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rule),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pendingBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(LucideIcons.fileText,
                    size: 18, color: AppColors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(LucideIcons.upload,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Info bar item ──────────────────────────────────────────────────────────

class _InfoBarItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isMono;

  const _InfoBarItem({
    required this.value,
    required this.label,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: isMono
                  ? GoogleFonts.dmMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    )
                  : GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
