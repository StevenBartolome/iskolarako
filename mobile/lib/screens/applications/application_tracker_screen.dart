import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';

class AppliedScholarship {
  final String providerName;
  final String scholarshipName;
  final String status;
  final StatusType statusType;
  final String appliedDate;
  final DateTime compareDate;
  final String referenceNumber;
  final List<TrackerStep> steps;

  const AppliedScholarship({
    required this.providerName,
    required this.scholarshipName,
    required this.status,
    required this.statusType,
    required this.appliedDate,
    required this.compareDate,
    required this.referenceNumber,
    required this.steps,
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
          statusType = StatusType.rejected;
        }

        final rawDate = row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) : DateTime.now();
        final compareDate = rawDate ?? DateTime.now();

        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final appliedDate = '${months[compareDate.month - 1]} ${compareDate.day}, ${compareDate.year}';

        final submittedDocsObj = row['submitted_documents'];
        String refNum = 'ISK-${compareDate.year}-${row['id'].toString().substring(0, 5).toUpperCase()}';
        if (submittedDocsObj is Map && submittedDocsObj['reference_number'] != null) {
          refNum = submittedDocsObj['reference_number'].toString();
        }

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
            icon: LucideIcons.fileCheck2,
            title: 'Document Verification',
            date: dbStatus == 'pending' ? 'In Progress' : 'Verified',
            description: dbStatus == 'pending'
                ? 'Provider committee is verifying submitted requirements.'
                : 'All uploaded documents passed initial completeness and verification check.',
            state: dbStatus == 'pending' ? StepState.active : StepState.done,
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
          providerName: providerName,
          scholarshipName: scholarshipName,
          status: statusLabel,
          statusType: statusType,
          appliedDate: appliedDate,
          compareDate: compareDate,
          referenceNumber: refNum,
          steps: steps,
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
                _expandedIndex = null; // collapse on sort change
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
                _expandedIndex = null; // collapse on filter change
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
