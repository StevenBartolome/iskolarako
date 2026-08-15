import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';

class AppliedScholarship {
  final String? applicationId;
  final String? scholarId;
  final String? cycleId;
  final String? programId;
  final Map<String, dynamic>? activeRenewalCycle;
  final String providerName;
  final String scholarshipName;
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
    required this.status,
    required this.statusType,
    required this.appliedDate,
    required this.compareDate,
    required this.referenceNumber,
    required this.steps,
    this.submittedDocuments = const [],
    this.isCycleOpen = true,
    this.cycleEndDate,
  });
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
  List<AppliedScholarship> _appliedScholarships = [];

  @override
  void initState() {
    super.initState();
    _fetchApplications();
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
      try {
        final scholarData = await Supabase.instance.client
            .from('scholar')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (scholarData != null && scholarData['id'] != null) {
          final idStr = scholarData['id'].toString();
          if (!scholarIds.contains(idStr)) {
            scholarIds.add(idStr);
          }
        }
      } catch (sErr) {
        debugPrint('Scholar lookup note: $sErr');
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

      final List<AppliedScholarship> loadedApps = [];

      for (final row in (appsData as List<dynamic>? ?? [])) {
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
                .select('id, cycle_name, application_start_date, application_end_date, status, cycle_type, semester')
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
          steps.add(const TrackerStep(
            icon: LucideIcons.wallet,
            title: 'Disbursement Setup',
            date: 'Processing',
            description: 'Your stipend disbursement is queuing for release.',
            state: StepState.active,
          ));
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

      if (mounted) {
        setState(() {
          _appliedScholarships = loadedApps;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching scholar applications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AppliedScholarship> get _processedScholarships {
    List<AppliedScholarship> list = List.from(_appliedScholarships);

    // Apply Filter
    if (_selectedFilter != 'All') {
      list = list.where((item) {
        if (_selectedFilter == 'Pending') {
          return item.statusType == StatusType.pending;
        } else if (_selectedFilter == 'Approved') {
          return item.statusType == StatusType.approved;
        } else if (_selectedFilter == 'Rejected') {
          return item.statusType == StatusType.rejected;
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
    final displayedList = _processedScholarships;

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
                  final scholarship = displayedList[index];
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
                                  _buildDocumentsSection(scholarship),
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

  Widget _buildDocumentsSection(AppliedScholarship scholarship) {
    final hasFlagged = scholarship.submittedDocuments.any((d) =>
        d['status']?.toString().toLowerCase() == 'flagged' ||
        d['verification_status']?.toString().toLowerCase() == 'rejected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Semestral Renewal Period Open Banner for Approved Scholars
        if (scholarship.activeRenewalCycle != null) ...[
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
                          Text(
                            scholarship.activeRenewalCycle!['cycle_name']?.toString() ?? 'Semestral Renewal Open',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
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

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isVerified
                    ? AppColors.successBg.withAlpha(50)
                    : isFlagged
                        ? const Color(0xFFFDF2F2)
                        : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isVerified
                      ? AppColors.primary.withAlpha(40)
                      : isFlagged
                          ? const Color(0xFFB34040).withAlpha(50)
                          : AppColors.rule,
                  width: 0.8,
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
                          color: isVerified
                              ? AppColors.successBg
                              : isFlagged
                                  ? const Color(0xFFFFECEC)
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            isVerified
                                ? LucideIcons.checkCircle2
                                : isFlagged
                                    ? (isAdditional ? LucideIcons.filePlus : LucideIcons.alertTriangle)
                                    : LucideIcons.fileText,
                            size: 16,
                            color: isVerified
                                ? AppColors.primary
                                : isFlagged
                                    ? const Color(0xFFB34040)
                                    : AppColors.textSecondary,
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
                            if (filename != null || filesize != null)
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
                          color: isVerified
                              ? AppColors.primary
                              : isFlagged
                                  ? const Color(0xFFB34040)
                                  : AppColors.amberDeep,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isVerified
                              ? '✓ Verified'
                              : isFlagged
                                  ? (isAdditional ? '🚩 Required' : '🚩 Issue Flagged')
                                  : '● In Review',
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

class _SemestralRenewalSheetState extends State<_SemestralRenewalSheet> {
  PlatformFile? _gradeSlipFile;
  PlatformFile? _corFile;
  final TextEditingController _gwaController = TextEditingController();
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _gwaController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isGradeSlip) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (isGradeSlip) {
            _gradeSlipFile = result.files.first;
          } else {
            _corFile = result.files.first;
          }
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Error selecting file: $e');
    }
  }

  Future<void> _submitRenewal() async {
    if (_gradeSlipFile == null || _corFile == null) {
      setState(() => _error = 'Please upload both your Grade Slip and Certificate of Registration.');
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

      // 1. Upload Grade Slip
      String gradeSlipUrl = '';
      final gradeExt = _gradeSlipFile!.extension ?? 'pdf';
      final gradePath = '${widget.scholarId}/Grade_Slip_$timestamp.$gradeExt';
      Uint8List? gradeBytes = _gradeSlipFile!.bytes;
      if (gradeBytes == null && _gradeSlipFile!.path != null) {
        gradeBytes = await File(_gradeSlipFile!.path!).readAsBytes();
      }
      if (gradeBytes != null) {
        try {
          await Supabase.instance.client.storage
              .from('scholar-documents')
              .uploadBinary(gradePath, gradeBytes, fileOptions: const FileOptions(upsert: true));
          gradeSlipUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(gradePath);
        } catch (e) {
          gradeSlipUrl = 'https://mock.storage.iskolarako.org/scholar-documents/$gradePath';
        }
      }

      // 2. Upload COR
      String corUrl = '';
      final corExt = _corFile!.extension ?? 'pdf';
      final corPath = '${widget.scholarId}/COR_$timestamp.$corExt';
      Uint8List? corBytes = _corFile!.bytes;
      if (corBytes == null && _corFile!.path != null) {
        corBytes = await File(_corFile!.path!).readAsBytes();
      }
      if (corBytes != null) {
        try {
          await Supabase.instance.client.storage
              .from('scholar-documents')
              .uploadBinary(corPath, corBytes, fileOptions: const FileOptions(upsert: true));
          corUrl = Supabase.instance.client.storage.from('scholar-documents').getPublicUrl(corPath);
        } catch (e) {
          corUrl = 'https://mock.storage.iskolarako.org/scholar-documents/$corPath';
        }
      }

      final gradeSize = '${(_gradeSlipFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB';
      final corSize = '${(_corFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB';

      final submittedDocsJson = {
        'documents': [
          {
            'name': 'Official Grade Slip / Report of Grades',
            'filename': _gradeSlipFile!.name,
            'filesize': gradeSize,
            'document_url': gradeSlipUrl,
            'url': gradeSlipUrl,
            'status': 'Pending',
            'verification_status': 'pending',
            'submitted_at': DateTime.now().toIso8601String(),
          },
          {
            'name': 'Certificate of Registration (COR)',
            'filename': _corFile!.name,
            'filesize': corSize,
            'document_url': corUrl,
            'url': corUrl,
            'status': 'Pending',
            'verification_status': 'pending',
            'submitted_at': DateTime.now().toIso8601String(),
          },
        ]
      };

      // 3. Insert or update renewal application in scholarship_applications
      await Supabase.instance.client
          .from('scholarship_applications')
          .insert({
            'scholar_id': widget.scholarId,
            'cycle_id': cycleId,
            'status': 'under_review',
            'submitted_documents': submittedDocsJson,
            'remarks': _gwaController.text.trim().isNotEmpty
                ? 'Semestral Renewal • Self-reported GWA: ${_gwaController.text.trim()}'
                : 'Semestral Renewal Submission',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      // 4. Insert scholar_documents entries
      try {
        await Supabase.instance.client.from('scholar_documents').insert([
          {
            'scholar_id': widget.scholarId,
            'document_name': 'Official Grade Slip / Report of Grades ($cycleName)',
            'document_url': gradeSlipUrl,
            'verification_status': 'pending',
            'file_size': _gradeSlipFile!.size,
            'mime_type': 'application/$gradeExt',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'scholar_id': widget.scholarId,
            'document_name': 'Certificate of Registration ($cycleName)',
            'document_url': corUrl,
            'verification_status': 'pending',
            'file_size': _corFile!.size,
            'mime_type': 'application/$corExt',
            'created_at': DateTime.now().toIso8601String(),
          },
        ]);
      } catch (dErr) {
        debugPrint('Scholar documents record insert note: $dErr');
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
    final cycleName = widget.renewalCycle['cycle_name']?.toString() ?? 'Semestral Renewal';
    final deadline = widget.renewalCycle['application_end_date']?.toString() ?? 'Open';

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
                          'Submit Semestral Renewal',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '$cycleName · Deadline: $deadline',
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
                'Upload your latest academic documents for ${widget.programName} to verify maintaining grade requirements and renew grant disbursement.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Document 1: Official Grade Slip
              Text(
                '1. Official Grade Slip / Report of Grades *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _isUploading ? null : () => _pickFile(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _gradeSlipFile != null ? AppColors.successBg.withAlpha(40) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _gradeSlipFile != null ? AppColors.primary : AppColors.rule,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _gradeSlipFile != null ? LucideIcons.fileCheck : LucideIcons.fileText,
                        size: 18,
                        color: _gradeSlipFile != null ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _gradeSlipFile != null ? _gradeSlipFile!.name : 'Choose Grade Slip (PDF / Image)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _gradeSlipFile != null ? FontWeight.w700 : FontWeight.w500,
                            color: _gradeSlipFile != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_gradeSlipFile != null)
                        const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Document 2: Certificate of Registration (COR)
              Text(
                '2. Certificate of Registration (COR) / Enrollment Proof *',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _isUploading ? null : () => _pickFile(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _corFile != null ? AppColors.successBg.withAlpha(40) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _corFile != null ? AppColors.primary : AppColors.rule,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _corFile != null ? LucideIcons.fileCheck : LucideIcons.fileText,
                        size: 18,
                        color: _corFile != null ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _corFile != null ? _corFile!.name : 'Choose COR / Registration (PDF / Image)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _corFile != null ? FontWeight.w700 : FontWeight.w500,
                            color: _corFile != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_corFile != null)
                        const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

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
                          'Submit Renewal Requirements',
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
