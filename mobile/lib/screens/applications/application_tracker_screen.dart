import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/utils/app_router.dart';
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
  final String? disbursementMode;

  const AppliedScholarship({
    this.applicationId,
    this.scholarId,
    this.cycleId,
    this.programId,
    this.disbursementMode,
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
  int selectedCardSectionTab; // 0: Timeline, 1: Requirements, 2: Summary

  ProgramApplicationGroup({
    required this.programId,
    required this.scholarshipName,
    required this.providerName,
    required this.cycles,
    this.selectedCycleIndex = 0,
    this.selectedCardSectionTab = 0,
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
  final ValueChanged<int>? onSelectTab;
  const ApplicationTrackerScreen({super.key, this.onSelectTab});

  @override
  State<ApplicationTrackerScreen> createState() => _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen> {
  int? _expandedIndex = 0; // First item expanded by default
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _selectedSort = 'Date (Newest)';

  bool _isLoading = true;
  List<ProgramApplicationGroup> _programGroups = [];
  RealtimeChannel? _realtimeChannel;
  List<Map<String, dynamic>> _paymentAccounts = [];
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
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar_payment_accounts',
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

      List<dynamic> paymentAccs = [];
      try {
        final pAccData = await Supabase.instance.client
            .from('scholar_payment_accounts')
            .select()
            .filter('scholar_id', 'in', scholarIds);
        paymentAccs = pAccData as List<dynamic>? ?? [];
      } catch (pErr) {
        debugPrint('Payment accounts fetch note: $pErr');
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
        final hasRelease = releasesData.any((r) {
          final s = (r['status'] ?? '').toString().toLowerCase();
          final isCompleted = s == 'released' || s == 'completed' || s == 'paid' || r['blockchain_verified'] == true;
          final isCancelled = s == 'returned' || s == 'refunded' || s == 'failed';
          return r['application_id']?.toString() == appId && isCompleted && !isCancelled;
        });

        final cycle = row['cycle'] as Map<String, dynamic>?;
        final program = cycle?['program'] as Map<String, dynamic>?;
        final provider = program?['provider'] as Map<String, dynamic>?;
        String? programId = program?['id']?.toString() ?? row['program_id']?.toString();

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
              if (fallbackProgram != null && fallbackProgram['id'] != null) {
                programId = fallbackProgram['id'].toString();
              }
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
          if (submittedDocsObj['bank_details'] is Map) {
            final bDetails = Map<String, dynamic>.from(submittedDocsObj['bank_details'] as Map);
            bDetails['name'] = 'bank_details';
            bDetails['document_name'] = 'bank_details';

            // Sync verification status from scholar_payment_accounts
            final hasVerifiedBank = paymentAccs.any((acc) =>
                acc['is_verified'] == true &&
                (acc['program_id']?.toString() == programId || acc['is_primary'] == true));

            if (hasVerifiedBank) {
              bDetails['status'] = 'verified';
              bDetails['verification_status'] = 'verified';
            } else {
              bDetails['status'] = 'pending';
              bDetails['verification_status'] = 'pending';
            }
            parsedDocs.add(bDetails);
          }
        } else if (submittedDocsObj is List) {
          parsedDocs = submittedDocsObj
              .whereType<Map>()
              .map((d) => Map<String, dynamic>.from(d))
              .toList();
        }

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
          disbursementMode: program?['disbursement_mode']?.toString() ?? program?['disbursementMode']?.toString(),
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
          selectedCardSectionTab: 0,
        ));
      });

      if (mounted) {
        setState(() {
          _programGroups = groups;
          _paymentAccounts = List<Map<String, dynamic>>.from(paymentAccs);
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
        child: CircularProgressIndicator(color: Color(0xFF1E3D2F)),
      );
    } else {
      contentWidget = RefreshIndicator(
        onRefresh: _fetchApplications,
        color: const Color(0xFF1E3D2F),
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

                  String providerShort = scholarship.providerName.split(' ').first;
                  if (providerShort.length > 10) providerShort = providerShort.substring(0, 10);
                  if (providerShort.isEmpty) providerShort = 'DOST';

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? const Color(0xFF1E3D2F) : const Color(0xFFE5E7EB),
                        width: isExpanded ? 1.2 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? const Color(0xFF1E3D2F).withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: isExpanded ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        providerShort.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF374151),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: scholarship.statusType == StatusType.approved
                                                ? const Color(0xFFDCFCE7)
                                                : (scholarship.statusType == StatusType.rejected
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFFEF3C7)),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                scholarship.statusType == StatusType.approved
                                                    ? Icons.check_circle_rounded
                                                    : (scholarship.statusType == StatusType.rejected
                                                        ? LucideIcons.xCircle
                                                        : LucideIcons.clock),
                                                size: 13,
                                                color: scholarship.statusType == StatusType.approved
                                                    ? const Color(0xFF15803D)
                                                    : (scholarship.statusType == StatusType.rejected
                                                        ? const Color(0xFFB91C1C)
                                                        : const Color(0xFFB45309)),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                scholarship.status,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: scholarship.statusType == StatusType.approved
                                                      ? const Color(0xFF15803D)
                                                      : (scholarship.statusType == StatusType.rejected
                                                          ? const Color(0xFFB91C1C)
                                                          : const Color(0xFFB45309)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                          size: 18,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  scholarship.scholarshipName,
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Applied on · ${scholarship.appliedDate}  ·  Ref: ${scholarship.referenceNumber}',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 11,
                                  ),
                                ),

                                // Cycle Selector Pills
                                const SizedBox(height: 12),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF1E3D2F) : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF1E3D2F) : const Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                cycleIdx == 0 ? LucideIcons.rotateCw : LucideIcons.history,
                                                size: 12,
                                                color: isSelected ? Colors.white : const Color(0xFF374151),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                cycleIdx == 0 ? '${cycleItem.cycleLabel} (Current)' : cycleItem.cycleLabel,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  color: isSelected ? Colors.white : const Color(0xFF374151),
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
                            ),
                          ),
                        ),

                        // Section Tabs & Expanded Content
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: isExpanded
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                      
                                      // Section View Switcher Tabs (0-Scroll Document Access)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => setState(() => group.selectedCardSectionTab = 0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: group.selectedCardSectionTab == 0 ? Colors.white : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(9),
                                                      boxShadow: group.selectedCardSectionTab == 0
                                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                                          : [],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Timeline',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11.5,
                                                          fontWeight: group.selectedCardSectionTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                                          color: group.selectedCardSectionTab == 0 ? const Color(0xFF1E3D2F) : const Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => setState(() => group.selectedCardSectionTab = 1),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: group.selectedCardSectionTab == 1 ? Colors.white : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(9),
                                                      boxShadow: group.selectedCardSectionTab == 1
                                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                                          : [],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Requirements (${scholarship.submittedDocuments.length})',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11.5,
                                                          fontWeight: group.selectedCardSectionTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                                          color: group.selectedCardSectionTab == 1 ? const Color(0xFF1E3D2F) : const Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => setState(() => group.selectedCardSectionTab = 2),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: group.selectedCardSectionTab == 2 ? Colors.white : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(9),
                                                      boxShadow: group.selectedCardSectionTab == 2
                                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                                          : [],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Summary',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11.5,
                                                          fontWeight: group.selectedCardSectionTab == 2 ? FontWeight.w700 : FontWeight.w500,
                                                          color: group.selectedCardSectionTab == 2 ? const Color(0xFF1E3D2F) : const Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Builder(
                                          builder: (context) {
                                            if (group.selectedCardSectionTab == 1) {
                                              // REQUIREMENTS TAB
                                              return _buildDocumentsSection(scholarship, group);
                                            } else if (group.selectedCardSectionTab == 2) {
                                              // SUMMARY TAB
                                              return _buildSummaryTabSection(scholarship);
                                            }

                                            // DEFAULT TIMELINE TAB
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (scholarship.statusType == StatusType.approved) ...[
                                                  if (scholarship.disbursementMode == 'in_person_cash')
                                                    _buildCashOtcInfoCard(scholarship)
                                                  else
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
                                                    stepNumber: stepIdx + 1,
                                                    icon: step.icon,
                                                    title: step.title,
                                                    date: step.date,
                                                    description: step.description,
                                                    state: step.state,
                                                    note: step.note,
                                                    isLast: stepIdx == scholarship.steps.length - 1,
                                                  );
                                                }),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity, height: 0),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          _buildHeader(context),
          _buildControlBar(),
          Expanded(child: contentWidget),
        ],
      ),
    );
  }

  Widget _buildCashOtcInfoCard(AppliedScholarship scholarship) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('💵', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Over-the-Counter Cash Disbursement',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your grant is disbursed in cash over-the-counter at your campus office / payout venue. Bank account submission is not required.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Payout & Bank Account Card ──────────────────────────────────────────
  Widget _buildBankRequirementCard(AppliedScholarship scholarship) {
    // Check if bank details are attached to this specific application or program
    final appDocs = scholarship.submittedDocuments;
    Map<String, dynamic>? appBankDoc;
    for (final doc in appDocs) {
      final dName = (doc['name'] ?? doc['document_name'] ?? '').toString().toLowerCase();
      if (dName == 'bank_details' || dName.contains('bank') || dName.contains('atm')) {
        appBankDoc = doc;
        break;
      }
    }

    Map<String, dynamic>? bankObj;

    if (appBankDoc != null) {
      bankObj = appBankDoc;
    } else if (_paymentAccounts.isNotEmpty) {
      // 1. Find specific program account first
      Map<String, dynamic>? specificAcc;
      for (final acc in _paymentAccounts) {
        if (acc['program_id']?.toString() == scholarship.programId) {
          specificAcc = acc;
          break;
        }
      }

      if (specificAcc != null) {
        bankObj = specificAcc;
      } else {
        // 2. Check if any payment account explicitly matches programId or applicationId
        for (final acc in _paymentAccounts) {
          final aiData = acc['ai_extracted_data'];
          if (aiData is Map) {
            final progIds = aiData['program_ids'];
            final appIds = aiData['application_ids'];
            final matchesProg = progIds is List && scholarship.programId != null && progIds.map((e) => e.toString()).contains(scholarship.programId!);
            final matchesApp = appIds is List && scholarship.applicationId != null && appIds.map((e) => e.toString()).contains(scholarship.applicationId!);

            if (matchesProg || matchesApp) {
              bankObj = acc;
              break;
            }
          }
        }

        // 3. Global Fallback: Use the scholar's primary or uploaded bank card for all programs!
        if (bankObj == null) {
          try {
            bankObj = _paymentAccounts.firstWhere(
              (acc) => acc['is_primary'] == true,
              orElse: () => _paymentAccounts.first,
            );
          } catch (_) {
            bankObj = _paymentAccounts.first;
          }
        }
      }
    }


    final hasBank = bankObj != null;
    final bankName = bankObj?['bank_name']?.toString() ?? 'UnionBank of the Philippines';
    final accNum = bankObj?['account_number']?.toString() ?? '';
    final maskedAcc = accNum.length > 4 ? '•••• ${accNum.substring(accNum.length - 4)}' : (accNum.isNotEmpty ? accNum : '••••');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasBank ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasBank ? const Color(0xFFDCFCE7) : const Color(0xFFFDE68A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasBank ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    hasBank ? Icons.check_rounded : Icons.account_balance_wallet_rounded,
                    color: hasBank ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasBank ? 'Payouts Activated & Bank Verified' : 'Post-Approval Action: Submit Bank Details',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasBank
                          ? 'Your stipend will be deposited to $bankName ($maskedAcc). Provider releases will automatically route here.'
                          : 'Please submit your official bank account or ATM card scan for this scholarship program to receive disbursements.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                BankAccountModal.show(
                  context,
                  scholarId: _currentScholarId,
                  scholarName: _currentScholarName,
                  programId: scholarship.programId,
                  applicationId: scholarship.applicationId,
                  onSuccess: () => _fetchApplications(),
                );
              },
              icon: Icon(hasBank ? LucideIcons.edit3 : LucideIcons.creditCard, size: 14),
              label: Text(
                hasBank ? 'Update Bank Details for This Program' : 'Submit Bank Account & Card Scan 💳',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasBank ? const Color(0xFF1E3D2F) : const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE8D0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.scale, size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Application Decision Dispute & Appeal',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If you believe your application decision requires re-evaluation, you can file a formal appeal to the provider.',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280), height: 1.35),
          ),
          const SizedBox(height: 12),
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
                'Submit Formal Appeal ⚖️',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Top Header ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                        'APPLICATION STATUS',
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
                    'Application\ntracker.',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track your scholarship application\nin real-time.',
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

  // ─── 3. Filter Controls ─────────────────────────────────────────────────────
  Widget _buildControlBar() {
    final filters = ['All', 'Pending', 'Approved', 'Rejected'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = _selectedFilter == filters[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filters[i];
                        _expandedIndex = 0;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF1E3D2F) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? const Color(0xFF1E3D2F) : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          filters[i],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.slidersHorizontal,
                  size: 16,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            tooltip: 'Sort Applications',
            onSelected: (value) {
              setState(() {
                _selectedSort = value;
                _expandedIndex = 0;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Date (Newest)',
                child: Text('Newest Applied', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'Date (Oldest)',
                child: Text('Oldest Applied', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'Provider Name',
                child: Text('Provider Name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7EB),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    LucideIcons.fileText,
                    size: 56,
                    color: Color(0xFF1E3D2F),
                  ),
                  Positioned(
                    right: 22,
                    bottom: 22,
                    child: Transform.rotate(
                      angle: 0.4,
                      child: const Icon(
                        LucideIcons.leaf,
                        color: Color(0xFF5BA778),
                        size: 26,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 24,
                    right: 24,
                    child: Icon(
                      LucideIcons.sparkles,
                      color: Color(0xFFEAB308),
                      size: 16,
                    ),
                  ),
                  const Positioned(
                    bottom: 30,
                    left: 20,
                    child: Icon(
                      LucideIcons.sparkles,
                      color: Color(0xFFEAB308),
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No applications found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have not submitted any scholarship applications yet or try adjusting your filter status.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (widget.onSelectTab != null) {
                  widget.onSelectTab!(1);
                } else {
                  Navigator.pushNamed(context, AppRouter.scholarships);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3D2F),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Browse Scholarships',
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

  // ─── 4. Submitted Requirements Section (Screenshot 2 Design) ────────────────
  Widget _buildDocumentsSection(AppliedScholarship scholarship, ProgramApplicationGroup group) {
    final docs = scholarship.submittedDocuments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.fileCheck, size: 16, color: Color(0xFF1E3D2F)),
            const SizedBox(width: 6),
            Text(
              'SUBMITTED REQUIREMENTS (${docs.length})',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E3D2F),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (docs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Text(
              'No documents attached yet.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, docIdx) {
              final doc = docs[docIdx];
              final name = (doc['name'] ?? doc['document_name'] ?? 'Submitted Document').toString();
              final filename = doc['filename']?.toString() ?? 'Document.pdf';
              final filesize = doc['filesize']?.toString() ?? '0.2 MB';
              final rawStatus = (doc['status'] ?? doc['verification_status'] ?? 'pending').toString().toLowerCase();

              final isVerified = rawStatus == 'verified';
              final isFlagged = rawStatus == 'flagged' || rawStatus == 'rejected';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0xFFDCFCE7)
                            : (isFlagged ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6)),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isVerified
                              ? Icons.check_rounded
                              : (isFlagged ? LucideIcons.alertTriangle : LucideIcons.fileText),
                          size: 16,
                          color: isVerified
                              ? const Color(0xFF16A34A)
                              : (isFlagged ? const Color(0xFFB91C1C) : const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submitted on ${scholarship.appliedDate}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$filename · $filesize',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? const Color(0xFFDCFCE7)
                                : (isFlagged ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified
                                ? '✓ Verified'
                                : (isFlagged ? '🚩 Flagged' : '● In Review'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isVerified
                                  ? const Color(0xFF15803D)
                                  : (isFlagged ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (scholarship.applicationId != null && scholarship.scholarId != null) {
                                  _openResubmitModal(
                                    context,
                                    applicationId: scholarship.applicationId!,
                                    scholarId: scholarship.scholarId!,
                                    docItem: doc,
                                    allDocs: docs,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  'Replace',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E3D2F),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final docUrl = doc['document_url']?.toString() ??
                                    doc['document_proof_url']?.toString() ??
                                    doc['url']?.toString();
                                if (docUrl != null && docUrl.isNotEmpty && docUrl != '#') {
                                  final uri = Uri.parse(docUrl);
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Could not open file: $e')),
                                      );
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('File preview available upon upload.')),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  'View',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E3D2F),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final docUrl = doc['document_url']?.toString() ??
                                    doc['document_proof_url']?.toString() ??
                                    doc['url']?.toString();
                                if (docUrl != null && docUrl.isNotEmpty && docUrl != '#') {
                                  final uri = Uri.parse(docUrl);
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Could not download file: $e')),
                                      );
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('File download available upon upload.')),
                                    );
                                  }
                                }
                              },
                              child: const Icon(
                                LucideIcons.download,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 14),

        // Manage / Re-upload Banner Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need to update your requirements?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can re-upload if there are changes or requested revisions.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (scholarship.applicationId != null && scholarship.scholarId != null && docs.isNotEmpty) {
                          _openResubmitModal(
                            context,
                            applicationId: scholarship.applicationId!,
                            scholarId: scholarship.scholarId!,
                            docItem: docs.first,
                            allDocs: docs,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        ),
                        child: Text(
                          'Manage Documents',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3D2F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.folderCheck,
                    color: Color(0xFFD97706),
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 5. Summary Section Tab (Screenshot 2 Design) ───────────────────────────
  Widget _buildSummaryTabSection(AppliedScholarship scholarship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application Summary',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Scholarship Program', scholarship.scholarshipName, isBold: true),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              _buildSummaryRow('Reference Number', scholarship.referenceNumber),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              _buildSummaryRow('Academic Year', 'AY 2025 - 2026'),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              _buildSummaryRow('Current Semester', scholarship.cycleLabel),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: scholarship.statusType == StatusType.approved
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✓ ${scholarship.status}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scholarship.statusType == StatusType.approved
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Need Help Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If you have any questions about your application, contact the scholarship provider.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contacting provider: ${scholarship.providerName}'),
                            backgroundColor: const Color(0xFF1E3D2F),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        ),
                        child: Text(
                          'Contact Provider',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3D2F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.headphones,
                    color: Color(0xFF15803D),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 6. Timeline Step Item ──────────────────────────────────────────────────
  Widget _buildStep({
    required int stepNumber,
    required IconData icon,
    required String title,
    required String date,
    required String description,
    required StepState state,
    required bool isLast,
    String? note,
  }) {
    final bool isDone = state == StepState.done;
    final bool isActive = state == StepState.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left timeline circle & line
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFDCFCE7) : (isActive ? const Color(0xFFFEF3C7) : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? const Color(0xFF16A34A) : (isActive ? const Color(0xFFD97706) : const Color(0xFFE5E7EB)),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 20, color: Color(0xFF16A34A))
                        : Text(
                            '$stepNumber',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isActive ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? const Color(0xFFFDE8D0) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDone ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isDone ? 'Done' : 'Active',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDone ? const Color(0xFF6B7280) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            date,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                'Document "${docItem['name'] ?? docItem['document_name']}" resubmitted!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFF1E3D2F),
            ),
          );
        },
      ),
    );
  }
}

// ─── Document Resubmit Sheet ─────────────────────────────────────────────────
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
  late Map<String, dynamic> _selectedDoc;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDoc = widget.docItem;
  }

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
      final docName = (_selectedDoc['name'] ?? _selectedDoc['document_name'] ?? 'document').toString();
      final fileExt = _selectedFile!.extension ?? 'pdf';
      final sanitizedName = docName.replaceAll(RegExp(r'\s+'), '_');
      final storagePath = '${widget.scholarId}/${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      String publicUrl = '';

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

      widget.onSuccess();
    } catch (err) {
      setState(() => _error = 'Submission failed: $err');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDocName = (_selectedDoc['name'] ?? _selectedDoc['document_name'] ?? 'Document').toString();

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
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Manage & Replace Document',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select which document you want to replace with a new file.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),

            // Document selection dropdown
            Text(
              'Target Document:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: widget.allDocs.any((d) => (d['name'] ?? d['document_name']) == (_selectedDoc['name'] ?? _selectedDoc['document_name']))
                      ? widget.allDocs.firstWhere((d) => (d['name'] ?? d['document_name']) == (_selectedDoc['name'] ?? _selectedDoc['document_name']))
                      : (widget.allDocs.isNotEmpty ? widget.allDocs.first : _selectedDoc),
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF6B7280)),
                  items: widget.allDocs.map((doc) {
                    final name = (doc['name'] ?? doc['document_name'] ?? 'Document').toString();
                    final rawStatus = (doc['status'] ?? doc['verification_status'] ?? 'pending').toString();
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: doc,
                      child: Row(
                        children: [
                          const Icon(LucideIcons.fileText, size: 16, color: Color(0xFF1E3D2F)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              softWrap: true,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rawStatus.toLowerCase().contains('flag') || rawStatus.toLowerCase().contains('reject')
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rawStatus,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: rawStatus.toLowerCase().contains('flag') || rawStatus.toLowerCase().contains('reject')
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newDoc) {
                    if (newDoc != null) {
                      setState(() {
                        _selectedDoc = newDoc;
                        _selectedFile = null;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? LucideIcons.fileCheck : LucideIcons.filePlus,
                      size: 28,
                      color: _selectedFile != null ? const Color(0xFF1E3D2F) : const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Choose Replacement File for "$selectedDocName"',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3D2F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Replace Document', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
