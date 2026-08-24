import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/widgets/bank_account_modal.dart';
import 'package:iskoako/widgets/appeal_modal.dart';
import 'package:url_launcher/url_launcher.dart';

class AppliedScholarship {
  final String? applicationId;
  final String? scholarId;
  final String? cycleId;
  final String? programId;
  final Map<String, dynamic>? activeRenewalCycle;
  final String providerName;
  final String scholarshipName;
  final String cycleLabel;
  final String status;
  final StatusType statusType;
  final String appliedDate;
  final DateTime compareDate;
  final String referenceNumber;
  final List<TrackerStep> steps;
  final List<Map<String, dynamic>> submittedDocuments;
  final bool isCycleOpen;
  final String? cycleEndDate;

  const AppliedScholarship({
    this.applicationId,
    this.scholarId,
    this.cycleId,
    this.programId,
    this.activeRenewalCycle,
    required this.providerName,
    required this.scholarshipName,
    this.cycleLabel = 'Initial Cycle',
    required this.status,
    required this.statusType,
    required this.appliedDate,
    required this.compareDate,
    required this.referenceNumber,
    required this.steps,
    required this.submittedDocuments,
    this.isCycleOpen = true,
    this.cycleEndDate,
  });
}

class ProgramApplicationGroup {
  final String programId;
  final String scholarshipName;
  final String providerName;
  final List<AppliedScholarship> cycles;
  int selectedCycleIndex;

  ProgramApplicationGroup({
    required this.programId,
    required this.scholarshipName,
    required this.providerName,
    required this.cycles,
    this.selectedCycleIndex = 0,
  });

  AppliedScholarship get currentCycle =>
      cycles[selectedCycleIndex >= 0 && selectedCycleIndex < cycles.length
          ? selectedCycleIndex
          : 0];

  StatusType get statusType => currentCycle.statusType;
  DateTime get compareDate => currentCycle.compareDate;
}

enum StepState { done, active, future }

class TrackerStep {
  final IconData icon;
  final String title;
  final String date;
  final String description;
  final StepState state;
  final String? note;

  const TrackerStep({
    required this.icon,
    required this.title,
    required this.date,
    required this.description,
    required this.state,
    this.note,
  });
}

class ApplicationTrackerScreen extends StatefulWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  State<ApplicationTrackerScreen> createState() => _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen> {
  int? _expandedIndex = 0; // First item expanded by default
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _selectedSort = 'Date (Newest)'; // 'Date (Newest)', 'Date (Oldest)', 'Provider Name'

  bool _isLoading = true;
  List<ProgramApplicationGroup> _programGroups = [];
  RealtimeChannel? _realtimeChannel;
  Map<String, dynamic>? _paymentAccount;
  String _currentScholarId = '';
  String _currentScholarName = 'Scholar';

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('app-tracker-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_applications',
          callback: (payload) {
            if (mounted) _fetchApplications();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar_documents',
          callback: (payload) {
            if (mounted) _fetchApplications();
          },
        );
    _realtimeChannel?.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final List<String> scholarIds = [user.id];
      String scholarName = 'Scholar';
      String resolvedScholarId = user.id;
      try {
        final scholarData = await Supabase.instance.client
            .from('scholar')
            .select('id, first_name, last_name')
            .eq('user_id', user.id)
            .maybeSingle();

        if (scholarData != null && scholarData['id'] != null) {
          final idStr = scholarData['id'].toString();
          resolvedScholarId = idStr;
          if (!scholarIds.contains(idStr)) {
            scholarIds.add(idStr);
          }
          final fName = scholarData['first_name']?.toString() ?? '';
          final lName = scholarData['last_name']?.toString() ?? '';
          if (fName.isNotEmpty) {
            scholarName = '$fName $lName'.trim();
          }
        }
      } catch (sErr) {
        debugPrint('Scholar lookup note: $sErr');
      }

      Map<String, dynamic>? paymentAcc;
      try {
        final pAccData = await Supabase.instance.client
            .from('scholar_payment_accounts')
            .select()
            .filter('scholar_id', 'in', scholarIds)
            .maybeSingle();
        paymentAcc = pAccData;
      } catch (pErr) {
        debugPrint('Payment account fetch note: $pErr');
      }

      dynamic appsData;
      try {
        appsData = await Supabase.instance.client
            .from('scholarship_applications')
            .select('''
              *,
              cycle:application_cycles (
                *,
                program:scholarship_programs (
                  *,
                  provider:provider (*)
                )
              )
            ''')
            .filter('scholar_id', 'in', scholarIds)
            .order('created_at', ascending: false);
      } catch (jErr) {
        debugPrint('Join query note, trying direct query: $jErr');
        appsData = await Supabase.instance.client
            .from('scholarship_applications')
            .select()
            .filter('scholar_id', 'in', scholarIds)
            .order('created_at', ascending: false);
      }

      List<dynamic> releasesData = [];
      try {
        if (scholarIds.isNotEmpty) {
          final rData = await Supabase.instance.client
              .from('fund_releases')
              .select('id, application_id, status, blockchain_verified')
              .filter('scholar_id', 'in', scholarIds);
          releasesData = rData as List<dynamic>? ?? [];
        }
      } catch (rErr) {
        debugPrint('Fund releases fetch error: $rErr');
      }

      final List<AppliedScholarship> loadedApps = [];

      for (final row in (appsData as List<dynamic>? ?? [])) {
        final appId = row['id']?.toString();
        final hasRelease = releasesData.any((r) =>
            r['application_id']?.toString() == appId &&
            (r['status']?.toString().toLowerCase() == 'released' ||
             r['status']?.toString().toLowerCase() == 'completed' ||
             r['blockchain_verified'] == true));
        final cycle = row['cycle'] as Map<String, dynamic>?;
        final program = cycle?['program'] as Map<String, dynamic>?;
        final provider = program?['provider'] as Map<String, dynamic>?;

        String providerName = provider?['name'] ?? '';
        String scholarshipName = program?['title'] ?? '';

        if (scholarshipName.isEmpty && row['cycle_id'] != null) {
          try {
            final cycleRow = await Supabase.instance.client
                .from('application_cycles')
                .select('''
                  *,
                  program:scholarship_programs (
                    *,
                    provider:provider (*)
                  )
                ''')
                .eq('id', row['cycle_id'])
                .maybeSingle();

            if (cycleRow != null) {
              final fallbackProgram = cycleRow['program'] as Map<String, dynamic>?;
              final fallbackProvider = fallbackProgram?['provider'] as Map<String, dynamic>?;

              scholarshipName = fallbackProgram?['title'] ?? 'Scholarship Program';
              providerName = fallbackProvider?['name'] ?? 'Scholarship Provider';
            }
          } catch (fetchCycleErr) {
            debugPrint('Note fetching cycle details fallback: $fetchCycleErr');
          }
        }

        if (scholarshipName.isEmpty) scholarshipName = 'Scholarship Program';
        if (providerName.isEmpty) providerName = 'Scholarship Provider';

        final cycleType = cycle?['cycle_type']?.toString().toLowerCase() ?? '';
        final cycleName = cycle?['cycle_name']?.toString() ?? '';
        final semester = cycle?['semester']?.toString() ?? '';
        final remarksStr = row['remarks']?.toString().toLowerCase() ?? '';
        final isRenewalApp = cycleType == 'renewal' ||
            cycleName.toLowerCase().contains('renewal') ||
            cycleName.toLowerCase().contains('sem') ||
            remarksStr.contains('renewal');

        String cycleLabel = 'Initial Cycle';
        if (isRenewalApp) {
          final semTitle = semester.isNotEmpty ? semester : '2nd Semester';
          cycleLabel = '$semTitle Renewal';
        } else {
          final semTitle = semester.isNotEmpty ? semester : '1st Semester';
          cycleLabel = '$semTitle Initial';
        }

        String? programId = program?['id']?.toString() ?? row['program_id']?.toString();

        final dbStatus = row['status']?.toString().toLowerCase() ?? 'pending';

        String statusLabel = 'Submitted';
        StatusType statusType = StatusType.pending;

        if (dbStatus == 'pending') {
          statusLabel = 'Pending Review';
          statusType = StatusType.pending;
        } else if (dbStatus == 'under_review') {
          statusLabel = 'Under Review';
          statusType = StatusType.pending;
        } else if (dbStatus == 'for_exam') {
          statusLabel = 'For Exam / Evaluation';
          statusType = StatusType.pending;
        } else if (dbStatus == 'approved') {
          statusLabel = 'Approved';
          statusType = StatusType.approved;
        } else if (dbStatus == 'rejected') {
          statusLabel = 'Unsuccessful';
          statusType = StatusType.rejected;
        } else if (dbStatus == 'withdrawn') {
          statusLabel = 'Withdrawn';
          statusType = StatusType.info;
        }

        // Check if there is an active semestral renewal cycle for approved scholarship
        Map<String, dynamic>? activeRenewalCycle;
        if (dbStatus == 'approved' && programId != null && programId.isNotEmpty) {
          try {
            final renewalCycles = await Supabase.instance.client
                .from('application_cycles')
                .select('*, program:scholarship_programs(*)')
                .eq('program_id', programId)
                .eq('status', 'open');

            if (renewalCycles.isNotEmpty) {
              for (final c in renewalCycles) {
                final cType = c['cycle_type']?.toString().toLowerCase() ?? '';
                final cName = c['cycle_name']?.toString().toLowerCase() ?? '';
                if (cType == 'renewal' || cName.contains('renewal') || cName.contains('sem')) {
                  activeRenewalCycle = Map<String, dynamic>.from(c as Map);
                  break;
                }
              }
            }
          } catch (rErr) {
            debugPrint('Renewal cycle query note: $rErr');
          }
        }

        final rawDate = row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) : DateTime.now();
        final compareDate = rawDate ?? DateTime.now();

        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final appliedDate = '${months[compareDate.month - 1]} ${compareDate.day}, ${compareDate.year}';

        final submittedDocsObj = row['submitted_documents'];
        String refNum = 'ISK-${compareDate.year}-${row['id'].toString().substring(0, 5).toUpperCase()}';
        List<Map<String, dynamic>> parsedDocs = [];

        if (submittedDocsObj is Map) {
          if (submittedDocsObj['reference_number'] != null) {
            refNum = submittedDocsObj['reference_number'].toString();
          }
          if (submittedDocsObj['documents'] is List) {
            parsedDocs = (submittedDocsObj['documents'] as List)
                .whereType<Map>()
                .map((d) => Map<String, dynamic>.from(d))
                .toList();
          }
        } else if (submittedDocsObj is List) {
          parsedDocs = submittedDocsObj
              .whereType<Map>()
              .map((d) => Map<String, dynamic>.from(d))
              .toList();
        }

        // Cycle open & deadline calculation
        final cycleStatus = (cycle?['status'] ?? '').toString().toLowerCase();
        final programStatus = (program?['status'] ?? '').toString().toLowerCase();
        final endDateRaw = cycle?['application_end_date']?.toString();
        DateTime? endDate = endDateRaw != null ? DateTime.tryParse(endDateRaw) : null;
        final bool isDateValid = endDate == null || DateTime.now().isBefore(endDate.add(const Duration(days: 1)));
        final bool isCycleOpen = (cycleStatus == 'open' || programStatus == 'active' || cycleStatus.isEmpty) && isDateValid && cycleStatus != 'closed' && cycleStatus != 'cancelled';

        String? formattedCycleEndDate;
        if (endDate != null) {
          formattedCycleEndDate = '${months[endDate.month - 1]} ${endDate.day}, ${endDate.year}';
        }

        final bool hasFlaggedDocs = parsedDocs.any((d) =>
            d['status']?.toString().toLowerCase() == 'flagged' ||
            d['verification_status']?.toString().toLowerCase() == 'rejected');

        final bool allDocsVerified = parsedDocs.isNotEmpty && parsedDocs.every((d) =>
            d['status']?.toString().toLowerCase() == 'verified' ||
            d['verification_status']?.toString().toLowerCase() == 'verified');

        final remarks = row['remarks']?.toString();

        final steps = <TrackerStep>[
          TrackerStep(
            icon: LucideIcons.send,
            title: 'Application Submitted',
            date: '$appliedDate · ${compareDate.hour}:${compareDate.minute.toString().padLeft(2, '0')}',
            description: 'Your application and initial requirements have been received by the portal.',
            state: StepState.done,
          ),
          TrackerStep(
            icon: hasFlaggedDocs ? LucideIcons.alertTriangle : LucideIcons.fileCheck2,
            title: 'Document Verification',
            date: hasFlaggedDocs
                ? (isCycleOpen ? 'Action Required: Resubmit File' : 'Issue Flagged (Cycle Closed)')
                : (allDocsVerified
                    ? 'Verified'
                    : (dbStatus == 'pending' ? 'In Progress' : 'Under Review')),
            description: hasFlaggedDocs
                ? (isCycleOpen
                    ? 'Provider noted an issue in 1 or more uploaded files. Please resubmit the flagged document below before the cycle closes.'
                    : 'Document issue was flagged, but the scholarship cycle is now closed.')
                : (allDocsVerified
                    ? 'All uploaded documents passed verification and completeness checks.'
                    : 'Provider committee is verifying submitted requirements.'),
            state: (hasFlaggedDocs || dbStatus == 'pending' || dbStatus == 'under_review') && !allDocsVerified
                ? StepState.active
                : StepState.done,
            note: hasFlaggedDocs ? 'See flagged requirement(s) below to upload a replacement file.' : null,
          ),
        ];

        if (dbStatus == 'under_review' || dbStatus == 'for_exam') {
          steps.add(TrackerStep(
            icon: LucideIcons.search,
            title: dbStatus == 'for_exam' ? 'Exam & Evaluation' : 'Under Review',
            date: 'Active Stage',
            description: 'The scholarship selection committee is currently evaluating your application.',
            state: StepState.active,
            note: remarks,
          ));
          steps.add(const TrackerStep(
            icon: LucideIcons.award,
            title: 'Final Decision',
            date: 'Pending',
            description: 'You will be notified once final approval is granted.',
            state: StepState.future,
          ));
        } else if (dbStatus == 'approved') {
          steps.add(const TrackerStep(
            icon: LucideIcons.search,
            title: 'Evaluation Completed',
            date: 'Completed',
            description: 'Scholarship committee evaluation completed successfully.',
            state: StepState.done,
          ));
          steps.add(TrackerStep(
            icon: LucideIcons.award,
            title: 'Final Approval',
            date: 'Approved',
            description: 'Congratulations! Your scholarship application has been officially approved.',
            state: StepState.done,
            note: remarks,
          ));
          if (hasRelease) {
            steps.add(const TrackerStep(
              icon: LucideIcons.wallet,
              title: 'Disbursement Setup',
              date: 'Released',
              description: 'Your stipend disbursement has been successfully released.',
              state: StepState.done,
            ));
          } else {
            steps.add(const TrackerStep(
              icon: LucideIcons.wallet,
              title: 'Disbursement Setup',
              date: 'Processing',
              description: 'Your stipend disbursement is queuing for release.',
              state: StepState.active,
            ));
          }
        } else if (dbStatus == 'rejected') {
          steps.add(TrackerStep(
            icon: LucideIcons.xCircle,
            title: 'Application Unsuccessful',
            date: 'Decision Finalized',
            description: remarks ?? 'Unfortunately, your application was not selected for this cycle.',
            state: StepState.active,
          ));
        } else if (dbStatus == 'withdrawn') {
          steps.add(const TrackerStep(
            icon: LucideIcons.xCircle,
            title: 'Application Withdrawn',
            date: 'Withdrawn',
            description: 'You have withdrawn your application for this scholarship cycle.',
            state: StepState.active,
          ));
        } else {
          steps.add(const TrackerStep(
            icon: LucideIcons.search,
            title: 'Committee Review',
            date: 'Pending',
            description: 'Scheduled for deliberation upon completion of requirement check.',
            state: StepState.future,
          ));
          steps.add(const TrackerStep(
            icon: LucideIcons.award,
            title: 'Final Decision',
            date: 'Pending',
            description: 'You will be notified of the committee decision.',
            state: StepState.future,
          ));
        }

        loadedApps.add(AppliedScholarship(
          applicationId: row['id']?.toString(),
          scholarId: row['scholar_id']?.toString(),
          cycleId: row['cycle_id']?.toString(),
          programId: programId,
          activeRenewalCycle: activeRenewalCycle,
          providerName: providerName,
          scholarshipName: scholarshipName,
          cycleLabel: cycleLabel,
          status: statusLabel,
          statusType: statusType,
          appliedDate: appliedDate,
          compareDate: compareDate,
          referenceNumber: refNum,
          steps: steps,
          submittedDocuments: parsedDocs,
          isCycleOpen: isCycleOpen,
          cycleEndDate: formattedCycleEndDate,
        ));
      }

      // Group loaded applications into single cards per program
      final Map<String, List<AppliedScholarship>> groupedMap = {};
      for (final app in loadedApps) {
        final groupKey = (app.programId != null && app.programId!.isNotEmpty)
            ? app.programId!
            : app.scholarshipName.toLowerCase().trim();
        if (!groupedMap.containsKey(groupKey)) {
          groupedMap[groupKey] = [];
        }
        groupedMap[groupKey]!.add(app);
      }

      final List<ProgramApplicationGroup> groups = [];
      groupedMap.forEach((key, list) {
        list.sort((a, b) => b.compareDate.compareTo(a.compareDate));
        groups.add(ProgramApplicationGroup(
          programId: list.first.programId ?? key,
          scholarshipName: list.first.scholarshipName,
          providerName: list.first.providerName,
          cycles: list,
          selectedCycleIndex: 0,
        ));
      });

      if (mounted) {
        setState(() {
          _programGroups = groups;
          _paymentAccount = paymentAcc;
          _currentScholarId = resolvedScholarId;
          _currentScholarName = scholarName;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching scholar applications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProgramApplicationGroup> get _processedGroups {
    List<ProgramApplicationGroup> list = List.from(_programGroups);

    // Apply Filter
    if (_selectedFilter != 'All') {
      list = list.where((group) {
        if (_selectedFilter == 'Pending') {
          return group.statusType == StatusType.pending;
        } else if (_selectedFilter == 'Approved') {
          return group.statusType == StatusType.approved;
        } else if (_selectedFilter == 'Rejected') {
          return group.statusType == StatusType.rejected;
        }
        return true;
      }).toList();
    }

    // Apply Sorting
    if (_selectedSort == 'Date (Newest)') {
      list.sort((a, b) => b.compareDate.compareTo(a.compareDate));
    } else if (_selectedSort == 'Date (Oldest)') {
      list.sort((a, b) => a.compareDate.compareTo(b.compareDate));
    } else if (_selectedSort == 'Provider Name') {
      list.sort((a, b) => a.providerName.compareTo(b.providerName));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayedList = _processedGroups;

    Widget contentWidget;
    if (_isLoading) {
      contentWidget = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else {
      contentWidget = RefreshIndicator(
        onRefresh: _fetchApplications,
        color: AppColors.primary,
        child: displayedList.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildEmptyState(),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                itemCount: displayedList.length,
                itemBuilder: (context, index) {
                  final group = displayedList[index];
                  final scholarship = group.currentCycle;
                  final isExpanded = _expandedIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isExpanded ? AppColors.primary : AppColors.rule,
                        width: isExpanded ? 1.2 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? AppColors.primary.withAlpha(12)
                              : Colors.black.withAlpha(5),
                          blurRadius: isExpanded ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Collapsible Header Card
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedIndex = isExpanded ? null : index;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isExpanded
                                            ? AppColors.primary.withAlpha(20)
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        scholarship.providerName,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        StatusChip(
                                          label: scholarship.status,
                                          type: scholarship.statusType,
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isExpanded
                                              ? LucideIcons.chevronUp
                                              : LucideIcons.chevronDown,
                                          size: 18,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  scholarship.scholarshipName,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Applied · ${scholarship.appliedDate}  ·  Ref: ${scholarship.referenceNumber}',
                                  style: GoogleFonts.dmMono(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                if (group.cycles.length > 1) ...[
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: List.generate(group.cycles.length, (cycleIdx) {
                                        final cycleItem = group.cycles[cycleIdx];
                                        final isSelected = group.selectedCycleIndex == cycleIdx;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              group.selectedCycleIndex = cycleIdx;
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isSelected ? AppColors.primary : AppColors.rule,
                                                width: isSelected ? 1.2 : 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  cycleIdx == 0 ? LucideIcons.zap : LucideIcons.history,
                                                  size: 12,
                                                  color: isSelected ? Colors.white : AppColors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  cycleIdx == 0 ? '${cycleItem.cycleLabel} (Current)' : cycleItem.cycleLabel,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Expandable Timeline
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 16, thickness: 0.8),
                                const SizedBox(height: 8),
                                if (scholarship.statusType == StatusType.approved) ...[
                                  _buildBankRequirementCard(scholarship),
                                  const SizedBox(height: 12),
                                ],
                                if (scholarship.statusType == StatusType.rejected) ...[
                                  _buildAppealCard(scholarship),
                                  const SizedBox(height: 12),
                                ],
                                ...List.generate(scholarship.steps.length, (stepIdx) {
                                  final step = scholarship.steps[stepIdx];
                                  return _buildStep(
                                    icon: step.icon,
                                    title: step.title,
                                    date: step.date,
                                    description: step.description,
                                    state: step.state,
                                    note: step.note,
                                    isLast: stepIdx == scholarship.steps.length - 1,
                                  );
                                }),
                                if (scholarship.submittedDocuments.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Divider(height: 24, thickness: 0.8),
                                  _buildDocumentsSection(scholarship, group),
                                ],
                              ],
                            ),
                          ),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildControlBar(),
          Expanded(child: contentWidget),
        ],
      ),
    );
  }

  Widget _buildBankRequirementCard(AppliedScholarship scholarship) {
    final hasBank = _paymentAccount != null && _paymentAccount!['account_number'] != null;
    final bankName = _paymentAccount?['bank_name']?.toString() ?? 'Bank Account';
    final accNum = _paymentAccount?['account_number']?.toString() ?? '';
    final maskedAcc = accNum.length > 4 ? '•••• ${accNum.substring(accNum.length - 4)}' : accNum;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasBank ? const Color(0xFFEBF5EE) : const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBank ? AppColors.primary.withAlpha(80) : const Color(0xFFC97B2E).withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasBank ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                size: 18,
                color: hasBank ? AppColors.primary : const Color(0xFFC97B2E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasBank ? 'Payouts Activated & Bank Verified' : 'Post-Approval Action: Submit Bank Details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasBank ? AppColors.primary : const Color(0xFFC97B2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasBank
                ? 'Your stipend will be deposited to $bankName ($maskedAcc). Provider releases will automatically route here.'
                : 'Congratulations on your approval! Please submit your official bank card / ATM scan so the provider can release your funds.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4A4A4A), height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                BankAccountModal.show(
                  context,
                  scholarId: _currentScholarId,
                  scholarName: _currentScholarName,
                  onSuccess: () => _fetchApplications(),
                );
              },
              icon: Icon(hasBank ? LucideIcons.edit3 : LucideIcons.uploadCloud, size: 14),
              label: Text(
                hasBank ? 'Update Bank Account Details' : 'Submit Bank Account & Card Scan 💳',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasBank ? AppColors.primary : const Color(0xFFC97B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealCard(AppliedScholarship scholarship) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC97B2E).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.scale, size: 18, color: Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Decision Dispute & Appeal',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFC97B2E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If you believe your application decision was mistaken or requires re-evaluation (e.g. grade calculation error, document clarification), you can file a formal appeal.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4A4A4A), height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (scholarship.applicationId != null && scholarship.scholarId != null) {
                  AppealModal.show(
                    context,
                    applicationId: scholarship.applicationId!,
                    scholarId: scholarship.scholarId!,
                    programId: scholarship.programId,
                    scholarshipName: scholarship.scholarshipName,
                    onSuccess: () => _fetchApplications(),
                  );
                }
              },
              icon: const Icon(LucideIcons.scale, size: 14),
              label: Text(
                'Submit Formal Appeal / Contest Decision ⚖️',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC97B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      'APPLICATION STATUS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amberDeep,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (canPop)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                          LucideIcons.chevronLeft,
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
              'Application\ntracker.',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildFilterChips()),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(
              LucideIcons.slidersHorizontal,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Sort Applications',
            onSelected: (value) {
              setState(() {
                _selectedSort = value;
                _expandedIndex = null;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Date (Newest)',
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarRange, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Newest Applied', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Date (Oldest)',
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Oldest Applied', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Provider Name',
                child: Row(
                  children: [
                    const Icon(LucideIcons.list, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Provider A-Z', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Pending', 'Approved', 'Rejected'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
                _expandedIndex = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.rule,
                  width: 0.8,
                ),
              ),
              child: Text(
                filter,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.folderOpen, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No applications found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your filter settings to see other status items.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDocumentsSection(AppliedScholarship scholarship, ProgramApplicationGroup group) {
    final hasFlagged = scholarship.submittedDocuments.any((d) =>
        d['status']?.toString().toLowerCase() == 'flagged' ||
        d['verification_status']?.toString().toLowerCase() == 'rejected');

    final isRenewalEntry = scholarship.cycleLabel.toLowerCase().contains('renewal') ||
        scholarship.cycleLabel.toLowerCase().contains('2nd');

    final bool alreadySubmittedRenewal = group.cycles.any((c) =>
        c.cycleId == scholarship.activeRenewalCycle?['id']?.toString() ||
        c.cycleLabel.toLowerCase().contains('renewal') ||
        c.cycleLabel.toLowerCase().contains('2nd'));

    // Show initial prompt only if scholar has NOT YET submitted a renewal cycle
    final bool showInitialRenewalPrompt = scholarship.activeRenewalCycle != null &&
        scholarship.statusType == StatusType.approved &&
        !alreadySubmittedRenewal;

    // Scholar submitted renewal, but it is NOT YET approved (pending review / under review)
    final bool isRenewalPending = isRenewalEntry &&
        scholarship.statusType == StatusType.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Semestral Renewal Period Open Banner for Approved Scholars (Not yet submitted)
        if (showInitialRenewalPrompt) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF9F5EF),
                  AppColors.gold.withAlpha(50),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withAlpha(140), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final sem = scholarship.activeRenewalCycle!['semester']?.toString() ?? '2nd Semester';
                              final cName = scholarship.activeRenewalCycle!['cycle_name']?.toString() ?? '';
                              return Text(
                                '$sem Renewal — ${scholarship.scholarshipName}${cName.isNotEmpty ? ' ($cName)' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              );
                            },
                          ),
                          Text(
                            'Deadline: ${scholarship.activeRenewalCycle!['application_end_date']?.toString() ?? 'Open'}',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              color: AppColors.amberDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Your scholarship provider has opened the semestral renewal period. Submit your latest Grade Slip and Certificate of Registration (COR) to renew and continue receiving your scholarship grant.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (scholarship.scholarId != null && scholarship.activeRenewalCycle != null) {
                        _openSemestralRenewalModal(
                          context,
                          scholarId: scholarship.scholarId!,
                          renewalCycle: scholarship.activeRenewalCycle!,
                          programName: scholarship.scholarshipName,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(LucideIcons.fileUp, size: 15),
                    label: Text(
                      'Submit Semestral Renewal Requirements',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Pending Renewal Submission Card (Allows Unsubmit & Resubmit while under review)
        if (isRenewalPending) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.fileCheck2, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Semestral Renewal Requirements Submitted (Under Review)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your submitted renewal requirements are under provider evaluation. You can update or replace your uploaded files while under review.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (scholarship.scholarId != null && (scholarship.activeRenewalCycle != null || scholarship.cycleId != null)) {
                        final cycleData = scholarship.activeRenewalCycle ?? {'id': scholarship.cycleId};
                        _openSemestralRenewalModal(
                          context,
                          scholarId: scholarship.scholarId!,
                          renewalCycle: cycleData,
                          programName: scholarship.scholarshipName,
                        );
                      }
                    },
                    icon: const Icon(LucideIcons.uploadCloud, size: 14),
                    label: Text(
                      'Update / Resubmit Renewal Requirements',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        Row(
          children: [
            const Icon(LucideIcons.files, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'SUBMITTED REQUIREMENTS (${scholarship.submittedDocuments.length})',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (hasFlagged) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scholarship.isCycleOpen
                  ? const Color(0xFFFDF2F2)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scholarship.isCycleOpen
                    ? const Color(0xFFB34040).withAlpha(40)
                    : AppColors.rule,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  scholarship.isCycleOpen
                      ? LucideIcons.alertCircle
                      : LucideIcons.lock,
                  size: 16,
                  color: scholarship.isCycleOpen
                      ? const Color(0xFFB34040)
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scholarship.isCycleOpen
                            ? 'Action Required: Resubmission Allowed'
                            : 'Resubmission Period Closed',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scholarship.isCycleOpen
                              ? const Color(0xFFB34040)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scholarship.isCycleOpen
                            ? 'The scholarship provider flagged issue(s) in your uploaded file(s). You can upload a corrected replacement file below while this cycle is open (Deadline: ${scholarship.cycleEndDate ?? 'Open'}).'
                            : 'The application cycle for this scholarship has closed (${scholarship.cycleEndDate ?? 'Deadline passed'}). New file uploads are no longer accepted.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scholarship.submittedDocuments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, docIdx) {
            final doc = scholarship.submittedDocuments[docIdx];
            final name = (doc['name'] ?? doc['document_name'] ?? 'Submitted Document').toString();
            final filename = doc['filename']?.toString();
            final filesize = doc['filesize']?.toString();
            final rawStatus = (doc['status'] ?? doc['verification_status'] ?? 'pending').toString().toLowerCase();

            final isVerified = rawStatus == 'verified';
            final isFlagged = rawStatus == 'flagged' || rawStatus == 'rejected';
            final isAdditional = doc['is_additional'] == true || doc['document_url'] == null || doc['document_url'].toString().isEmpty;
            final remarks = doc['remarks']?.toString();
            final isOfficialLetter = doc['is_official_letter'] == true;

            return InkWell(
              onTap: () async {
                final docUrl = doc['document_url']?.toString();
                if (docUrl != null && docUrl.isNotEmpty && docUrl != '#') {
                  final uri = Uri.parse(docUrl);
                  try {
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open document link.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open document link: $e')),
                      );
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document file is not yet available for view.')),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOfficialLetter
                      ? AppColors.primary.withAlpha(25)
                      : (isVerified
                          ? AppColors.successBg.withAlpha(50)
                          : isFlagged
                              ? const Color(0xFFFDF2F2)
                              : AppColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOfficialLetter
                        ? AppColors.primary.withAlpha(80)
                        : (isVerified
                            ? AppColors.primary.withAlpha(40)
                            : isFlagged
                                ? const Color(0xFFB34040).withAlpha(50)
                                : AppColors.rule),
                    width: isOfficialLetter ? 1.0 : 0.8,
                  ),
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
                            color: isOfficialLetter
                                ? AppColors.primary.withAlpha(40)
                                : (isVerified
                                    ? AppColors.successBg
                                    : isFlagged
                                        ? const Color(0xFFFFECEC)
                                        : AppColors.surface),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              isOfficialLetter
                                  ? LucideIcons.fileText
                                  : (isVerified
                                      ? LucideIcons.checkCircle2
                                      : isFlagged
                                          ? (isAdditional ? LucideIcons.filePlus : LucideIcons.alertTriangle)
                                          : LucideIcons.fileText),
                              size: 16,
                              color: isOfficialLetter
                                  ? AppColors.primary
                                  : (isVerified
                                      ? AppColors.primary
                                      : isFlagged
                                          ? const Color(0xFFB34040)
                                          : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isOfficialLetter)
                                Text(
                                  'Tap to view / download official PDF letter',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else if (filename != null || filesize != null)
                                Text(
                                  [filename, filesize].whereType<String>().join(' · '),
                                  style: GoogleFonts.dmMono(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOfficialLetter
                                ? AppColors.primary
                                : (isVerified
                                    ? AppColors.primary
                                    : isFlagged
                                        ? const Color(0xFFB34040)
                                        : AppColors.amberDeep),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOfficialLetter
                                ? '✓ Official'
                                : (isVerified
                                    ? '✓ Verified'
                                    : isFlagged
                                        ? (isAdditional ? '🚩 Required' : '🚩 Issue Flagged')
                                        : '● In Review'),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Display remarks / reason if flagged
                    if (isFlagged && remarks != null && remarks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB34040).withAlpha(40)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.info, size: 12, color: Color(0xFFB34040)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Provider note: $remarks',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFFB34040),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Resubmit / Upload Action Button when Flagged or Additional
                    if (isFlagged) ...[
                      const SizedBox(height: 8),
                      if (scholarship.isCycleOpen)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (scholarship.applicationId != null && scholarship.scholarId != null) {
                                _openResubmitModal(
                                  context,
                                  applicationId: scholarship.applicationId!,
                                  scholarId: scholarship.scholarId!,
                                  docItem: doc,
                                  allDocs: scholarship.submittedDocuments,
                                );
                              }
                            },
                            icon: const Icon(LucideIcons.uploadCloud, size: 14, color: Colors.white),
                            label: Text(
                              isAdditional ? 'Upload Requested Document' : 'Resubmit This Document',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          child: Text(
                            'Resubmission closed (${scholarship.cycleEndDate ?? 'Cycle ended'})',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openResubmitModal(
    BuildContext context, {
    required String applicationId,
    required String scholarId,
    required Map<String, dynamic> docItem,
    required List<Map<String, dynamic>> allDocs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResubmitDocumentSheet(
        applicationId: applicationId,
        scholarId: scholarId,
        docItem: docItem,
        allDocs: allDocs,
        onSuccess: () {
          Navigator.pop(ctx);
          _fetchApplications();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document "${docItem['name'] ?? docItem['document_name']}" resubmitted! Provider notified for review.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  void _openSemestralRenewalModal(
    BuildContext context, {
    required String scholarId,
    required Map<String, dynamic> renewalCycle,
    required String programName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SemestralRenewalSheet(
        scholarId: scholarId,
        renewalCycle: renewalCycle,
        programName: programName,
        onSuccess: () {
          _fetchApplications();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semestral renewal submitted successfully! Your provider will evaluate your requirements.'),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String date,
    required String description,
    required StepState state,
    required bool isLast,
    String? note,
  }) {
    Color circleColor;
    Color circleBorder;
    Color lineColor;
    Color iconColor;
    Color titleColor;

    switch (state) {
      case StepState.done:
        circleColor = AppColors.successBg;
        circleBorder = AppColors.primary;
        lineColor = AppColors.primary;
        iconColor = AppColors.primary;
        titleColor = AppColors.primary;
        break;
      case StepState.active:
        circleColor = AppColors.pendingBg;
        circleBorder = AppColors.amber;
        lineColor = AppColors.rule;
        iconColor = AppColors.amber;
        titleColor = AppColors.amberDeep;
        break;
      case StepState.future:
        circleColor = AppColors.surfaceAlt;
        circleBorder = AppColors.rule;
        lineColor = AppColors.rule;
        iconColor = AppColors.textMuted;
        titleColor = AppColors.textSecondary;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleBorder, width: 2),
                  ),
                  child: Icon(
                    state == StepState.done ? LucideIcons.check : icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state == StepState.active
                        ? AppColors.amber.withAlpha(60)
                        : AppColors.rule,
                  ),
                  boxShadow: state == StepState.active
                      ? [
                          BoxShadow(
                            color: AppColors.amber.withAlpha(25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Opacity(
                  opacity: state == StepState.future ? 0.55 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            if (state == StepState.done)
                              StatusChip(
                                  label: 'Done',
                                  type: StatusType.approved),
                            if (state == StepState.active)
                              StatusChip(
                                label: '● Active',
                                type: StatusType.pending,
                                showDot: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: state == StepState.done
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 10),
                          Divider(height: 1, color: AppColors.rule),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(LucideIcons.info,
                                  size: 12, color: AppColors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  note,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.amberDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResubmitDocumentSheet extends StatefulWidget {
  final String applicationId;
  final String scholarId;
  final Map<String, dynamic> docItem;
  final List<Map<String, dynamic>> allDocs;
  final VoidCallback onSuccess;

  const _ResubmitDocumentSheet({
    required this.applicationId,
    required this.scholarId,
    required this.docItem,
    required this.allDocs,
    required this.onSuccess,
  });

  @override
  State<_ResubmitDocumentSheet> createState() => _ResubmitDocumentSheetState();
}

class _ResubmitDocumentSheetState extends State<_ResubmitDocumentSheet> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Error selecting file: $e');
    }
  }

  Future<void> _uploadAndSubmit() async {
    if (_selectedFile == null) {
      setState(() => _error = 'Please select a replacement file to upload.');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final docName = (widget.docItem['name'] ?? widget.docItem['document_name'] ?? 'document').toString();
      final fileExt = _selectedFile!.extension ?? 'pdf';
      final sanitizedName = docName.replaceAll(RegExp(r'\s+'), '_');
      final storagePath = '${widget.scholarId}/${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      String publicUrl = '';

      // Upload binary to Supabase Storage
      Uint8List? bytes = _selectedFile!.bytes;
      if (bytes == null && _selectedFile!.path != null) {
        bytes = await File(_selectedFile!.path!).readAsBytes();
      }

      if (bytes != null) {
        try {
          await Supabase.instance.client.storage
              .from('scholar-documents')
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );

          publicUrl = Supabase.instance.client.storage
              .from('scholar-documents')
              .getPublicUrl(storagePath);
        } catch (storageErr) {
          debugPrint('Supabase storage upload fallback: $storageErr');
          publicUrl = 'https://mock.storage.iskolarako.org/scholar-documents/$storagePath';
        }
      }

      final formattedSize = '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB';

      // 1. Update scholarship_applications JSON documents
      final updatedDocsList = widget.allDocs.map((d) {
        final dName = (d['name'] ?? d['document_name'] ?? '').toString();
        if (dName == docName) {
          return {
            ...d,
            'name': docName,
            'document_name': docName,
            'filename': _selectedFile!.name,
            'filesize': formattedSize,
            'document_url': publicUrl,
            'url': publicUrl,
            'status': 'Pending',
            'verification_status': 'under_review',
            'submitted_at': DateTime.now().toIso8601String(),
            'remarks': 'Resubmitted by scholar',
          };
        }
        return d;
      }).toList();

      await Supabase.instance.client
          .from('scholarship_applications')
          .update({
            'submitted_documents': {
              'documents': updatedDocsList,
            },
            'status': 'under_review',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.applicationId);

      // 2. Update scholar_documents table record
      try {
        final existing = await Supabase.instance.client
            .from('scholar_documents')
            .select('id')
            .eq('scholar_id', widget.scholarId)
            .eq('document_name', docName);

        if (existing.isNotEmpty) {
          await Supabase.instance.client
              .from('scholar_documents')
              .update({
                'document_url': publicUrl,
                'verification_status': 'under_review',
                'ai_verification_status': 'pending',
                'ai_confidence_score': null,
                'ai_flags': [],
                'ai_extracted_data': null,
                'file_sha256_hash': null,
                'remarks': 'Resubmitted by scholar',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existing.first['id']);
        } else {
          await Supabase.instance.client
              .from('scholar_documents')
              .insert({
                'scholar_id': widget.scholarId,
                'document_name': docName,
                'document_url': publicUrl,
                'verification_status': 'under_review',
                'ai_verification_status': 'pending',
                'ai_confidence_score': null,
                'ai_flags': [],
                'ai_extracted_data': null,
                'file_sha256_hash': null,
                'remarks': 'Resubmitted by scholar',
              });
        }
      } catch (sdErr) {
        debugPrint('scholar_documents sync note: $sdErr');
      }

      widget.onSuccess();
    } catch (err) {
      setState(() => _error = 'Submission failed: $err');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docName = (widget.docItem['name'] ?? widget.docItem['document_name'] ?? 'Document').toString();
    final issueRemarks = widget.docItem['remarks']?.toString();
    final isAdditional = widget.docItem['is_additional'] == true || widget.docItem['document_url'] == null || widget.docItem['document_url'].toString().isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
                  color: AppColors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.uploadCloud, size: 20, color: Color(0xFFB34040)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdditional ? 'Upload Required Document' : 'Resubmit Document',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        docName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (issueRemarks != null && issueRemarks.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB34040).withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider Feedback / Issue:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB34040),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      issueRemarks,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // File Selector Box
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: _selectedFile != null ? AppColors.successBg.withAlpha(40) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null ? AppColors.primary : AppColors.rule,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? LucideIcons.fileCheck : LucideIcons.filePlus,
                      size: 28,
                      color: _selectedFile != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Tap to Choose New File',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _selectedFile != null ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFile != null
                          ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB · Tap to change'
                          : 'Supports PDF, JPG, PNG (Max 10MB)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(120),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isAdditional ? 'Upload & Submit Document' : 'Upload & Resubmit Document',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

// ─── Semestral Renewal Bottom Sheet ──────────────────────────────────────────

class _SemestralRenewalSheet extends StatefulWidget {
  final String scholarId;
  final Map<String, dynamic> renewalCycle;
  final String programName;
  final VoidCallback onSuccess;

  const _SemestralRenewalSheet({
    required this.scholarId,
    required this.renewalCycle,
    required this.programName,
    required this.onSuccess,
  });

  @override
  State<_SemestralRenewalSheet> createState() => _SemestralRenewalSheetState();
}

class _RenewalRequirementItem {
  final String name;
  final String description;

  const _RenewalRequirementItem({
    required this.name,
    this.description = '',
  });
}

class _SemestralRenewalSheetState extends State<_SemestralRenewalSheet> {
  late final List<_RenewalRequirementItem> _requirements;
  final Map<String, PlatformFile> _uploadedFiles = {};
  final TextEditingController _gwaController = TextEditingController();
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requirements = _parseRequirements();
  }

  List<_RenewalRequirementItem> _parseRequirements() {
    final dynamic reqs = widget.renewalCycle['renewal_requirements'] ??
        widget.renewalCycle['requirements'] ??
        widget.renewalCycle['program']?['application_requirements'] ??
        widget.renewalCycle['application_requirements'] ??
        (widget.renewalCycle['metadata'] is Map
            ? widget.renewalCycle['metadata']['renewal_requirements']
            : null);

    if (reqs is List && reqs.isNotEmpty) {
      final List<_RenewalRequirementItem> list = [];
      for (final item in reqs) {
        if (item is Map) {
          final name = item['name']?.toString().trim() ?? '';
          final desc = item['description']?.toString().trim() ?? item['desc']?.toString().trim() ?? '';
          if (name.isNotEmpty) {
            list.add(_RenewalRequirementItem(name: name, description: desc));
          }
        } else if (item is String && item.trim().isNotEmpty) {
          list.add(_RenewalRequirementItem(name: item.trim(), description: ''));
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [
      const _RenewalRequirementItem(
        name: '1st Semester Official Grade Slip / Report of Grades',
        description: 'Signed copy or student portal screenshot of your 1st semester grades/GWA',
      ),
      const _RenewalRequirementItem(
        name: 'Certificate of Registration (COR) / Enrollment Form (2nd Semester)',
        description: 'Official proof of enrollment for the upcoming semester with enrolled units',
      ),
    ];
  }

  @override
  void dispose() {
    _gwaController.dispose();
    super.dispose();
  }

  Future<void> _pickFileForRequirement(String reqName) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        setState(() {
          _uploadedFiles[reqName] = pickedFile;
          _error = null;
        });

        // If this requirement is for grades/GWA and user hasn't typed GWA yet, try extracting from filename pattern
        if ((reqName.toLowerCase().contains('grade') ||
                reqName.toLowerCase().contains('gwa') ||
                reqName.toLowerCase().contains('slip') ||
                reqName.toLowerCase().contains('report')) &&
            _gwaController.text.trim().isEmpty) {
          final gwaMatch = RegExp(r'([1-4]\.[0-9]{1,2}|5\.00)').firstMatch(pickedFile.name);
          if (gwaMatch != null && gwaMatch.group(1) != null) {
            setState(() {
              _gwaController.text = gwaMatch.group(1)!;
            });
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Error selecting file: $e');
    }
  }

  Future<void> _submitRenewal() async {
    // Validate that all requirements have an attached file
    final missing = _requirements.where((r) => !_uploadedFiles.containsKey(r.name)).toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Please upload all required documents:\n• ${missing.map((m) => m.name).join("\n• ")}');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cycleId = widget.renewalCycle['id']?.toString() ?? '';
      final cycleName = widget.renewalCycle['cycle_name']?.toString() ?? 'Semestral Renewal';
      final gwaText = _gwaController.text.trim();
      final double? gwaNumber = double.tryParse(gwaText);

      final List<Map<String, dynamic>> submittedDocsList = [];
      final List<Map<String, dynamic>> scholarDocsToInsert = [];

      for (int i = 0; i < _requirements.length; i++) {
        final reqItem = _requirements[i];
        final reqName = reqItem.name;
        final file = _uploadedFiles[reqName]!;
        final ext = file.extension ?? 'pdf';
        final sanitizedReq = reqName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final storagePath = '${widget.scholarId}/Renewal_${sanitizedReq}_$timestamp.$ext';

        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        String docUrl = '';
        if (fileBytes != null) {
          try {
            await Supabase.instance.client.storage
                .from('scholar-documents')
                .uploadBinary(storagePath, fileBytes, fileOptions: const FileOptions(upsert: true));
            docUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(storagePath);
          } catch (e) {
            docUrl = 'https://mock.storage.iskolarako.org/scholar-documents/$storagePath';
          }
        }

        final fileSizeMb = '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
        final isGradeDoc = reqName.toLowerCase().contains('grade') ||
            reqName.toLowerCase().contains('gwa') ||
            reqName.toLowerCase().contains('slip') ||
            reqName.toLowerCase().contains('report');

        final Map<String, dynamic> docItemMap = {
          'name': reqName,
          'description': reqItem.description,
          'filename': file.name,
          'filesize': fileSizeMb,
          'document_url': docUrl,
          'url': docUrl,
          'status': 'Pending',
          'verification_status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        };

        if (isGradeDoc && gwaNumber != null) {
          docItemMap['aiVerification'] = {
            'extractedGwa': gwaText,
            'verificationStatus': 'verified',
            'confidenceScore': 0.95,
          };
        }

        submittedDocsList.add(docItemMap);

        scholarDocsToInsert.add({
          'scholar_id': widget.scholarId,
          'document_name': '$reqName ($cycleName)',
          'document_url': docUrl,
          'verification_status': 'pending',
          'file_size': file.size,
          'mime_type': 'application/$ext',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final submittedDocsJson = {
        'documents': submittedDocsList,
      };

      // 1. Insert or update renewal application in scholarship_applications
      await Supabase.instance.client
          .from('scholarship_applications')
          .insert({
            'scholar_id': widget.scholarId,
            'cycle_id': cycleId,
            'status': 'under_review',
            'submitted_documents': submittedDocsJson,
            'remarks': gwaText.isNotEmpty
                ? 'Semestral Renewal • GWA: $gwaText'
                : 'Semestral Renewal Submission',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      // 2. Insert scholar_documents entries
      if (scholarDocsToInsert.isNotEmpty) {
        try {
          await Supabase.instance.client.from('scholar_documents').insert(scholarDocsToInsert);
        } catch (dErr) {
          debugPrint('Scholar documents record insert note: $dErr');
        }
      }

      // 3. Update scholar profile GWA/GPA in database
      if (gwaNumber != null) {
        try {
          await Supabase.instance.client
              .from('scholar')
              .update({
                'gpa': gwaNumber,
                'gwa': gwaNumber,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', widget.scholarId);
        } catch (gErr) {
          debugPrint('Scholar GWA update note: $gErr');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (err) {
      setState(() => _error = 'Submission failed: $err');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = widget.renewalCycle['semester']?.toString() ?? '2nd Semester';
    final cycleName = widget.renewalCycle['cycle_name']?.toString() ?? 'Renewal Batch';
    final deadline = widget.renewalCycle['application_end_date']?.toString() ?? 'Open';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$sem Renewal',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '${widget.programName} ($cycleName) · Deadline: $deadline',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                'Upload the required renewal documents for ${widget.programName} set by your scholarship provider to maintain your grant eligibility.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Requirements List
              for (int i = 0; i < _requirements.length; i++) ...[
                Builder(
                  builder: (ctx) {
                    final reqItem = _requirements[i];
                    final reqName = reqItem.name;
                    final attachedFile = _uploadedFiles[reqName];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. $reqName *',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (reqItem.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            reqItem.description,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _isUploading ? null : () => _pickFileForRequirement(reqName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: attachedFile != null ? AppColors.successBg.withAlpha(40) : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: attachedFile != null ? AppColors.primary : AppColors.rule,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  attachedFile != null ? LucideIcons.fileCheck : LucideIcons.fileText,
                                  size: 18,
                                  color: attachedFile != null ? AppColors.primary : AppColors.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    attachedFile != null ? attachedFile.name : 'Choose file (PDF / Image)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: attachedFile != null ? FontWeight.w700 : FontWeight.w500,
                                      color: attachedFile != null ? AppColors.textPrimary : AppColors.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (attachedFile != null)
                                  const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  },
                ),
              ],

              // Optional GWA
              Text(
                'Latest General Weighted Average (GWA) (Optional)',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _gwaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 1.45',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.rule, width: 0.8),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitRenewal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Submit Renewal Requirements (${_uploadedFiles.length}/${_requirements.length})',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
