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

class TrackerStep {
  final IconData icon;
  final String title;
  final String date;
  final String description;
  final _StepState state;
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

enum _StepState { done, active, future }

class ApplicationTrackerScreen extends StatefulWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  State<ApplicationTrackerScreen> createState() => _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen> {
  int? _expandedIndex = 0; // First item expanded by default
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _selectedSort = 'Date (Newest)'; // 'Date (Newest)', 'Date (Oldest)', 'Provider Name'

  final List<AppliedScholarship> _appliedScholarships = [
    AppliedScholarship(
      providerName: 'DOST-SEI',
      scholarshipName: 'DOST-SEI Undergraduate Scholarship',
      status: 'Under Review',
      statusType: StatusType.pending,
      appliedDate: 'Oct 10, 2026',
      compareDate: DateTime(2026, 10, 10),
      referenceNumber: 'ISK-2026-04821',
      steps: [
        TrackerStep(
          icon: LucideIcons.send,
          title: 'Application Submitted',
          date: 'Oct 10, 2026 · 9:41 AM',
          description: 'Your application and all initial requirements have been received by the portal.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.fileCheck2,
          title: 'Documents Verified',
          date: 'Oct 12, 2026 · 2:05 PM',
          description: 'All uploaded documents passed authenticity checks. Your file is complete.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.search,
          title: 'Under Review',
          date: 'Since Oct 14, 2026 · Est. 5–10 business days',
          description: 'The scholarship committee is evaluating your application. You\'ll be notified when a decision is made.',
          state: _StepState.active,
          note: 'No action needed from you right now.',
        ),
        TrackerStep(
          icon: LucideIcons.award,
          title: 'Final Decision',
          date: 'Pending · Awaiting committee',
          description: 'You will be notified once the scholarship committee reaches a final decision.',
          state: _StepState.future,
        ),
        TrackerStep(
          icon: LucideIcons.wallet,
          title: 'Funds Released',
          date: 'Pending · Via PayMongo · Blockchain-verified',
          description: 'Upon approval, your stipend will be transferred directly to your registered account.',
          state: _StepState.future,
        ),
      ],
    ),
    AppliedScholarship(
      providerName: 'SM Foundation',
      scholarshipName: 'SM College Scholarship Program',
      status: 'Approved',
      statusType: StatusType.approved,
      appliedDate: 'Sep 15, 2026',
      compareDate: DateTime(2026, 9, 15),
      referenceNumber: 'ISK-2026-09110',
      steps: [
        TrackerStep(
          icon: LucideIcons.send,
          title: 'Application Submitted',
          date: 'Sep 15, 2026 · 10:15 AM',
          description: 'Initial application form and documents submitted to SM Foundation portal.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.fileCheck2,
          title: 'Documents Verified',
          date: 'Sep 20, 2026 · 4:30 PM',
          description: 'Income documents and scholastic records successfully verified.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.search,
          title: 'Home Visit & Interview',
          date: 'Completed on Oct 02, 2026',
          description: 'SM Foundation regional representative completed the home visit and interview.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.award,
          title: 'Final Approval',
          date: 'Oct 15, 2026 · 11:00 AM',
          description: 'Congratulations! You have been selected as an SM Foundation Scholar.',
          state: _StepState.done,
          note: 'An onboarding package has been sent to your registered email.',
        ),
        TrackerStep(
          icon: LucideIcons.wallet,
          title: 'First Stipend Release',
          date: 'Processing · Estimated release: Nov 15, 2026',
          description: 'Bank account verification completed. Stipend is queuing for disbursement.',
          state: _StepState.active,
        ),
      ],
    ),
    AppliedScholarship(
      providerName: 'Aboitiz Foundation',
      scholarshipName: 'Aboitiz College Scholarship',
      status: 'Interview Stage',
      statusType: StatusType.pending,
      appliedDate: 'Oct 20, 2026',
      compareDate: DateTime(2026, 10, 20),
      referenceNumber: 'ISK-2026-11029',
      steps: [
        TrackerStep(
          icon: LucideIcons.send,
          title: 'Application Submitted',
          date: 'Oct 20, 2026 · 2:10 PM',
          description: 'Application successfully uploaded through the Iskolarako Portal.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.fileCheck2,
          title: 'Documents Verified',
          date: 'Oct 25, 2026 · 9:00 AM',
          description: 'Primary documents verified. Academic standing authenticated.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.userCheck,
          title: 'Technical Panel Interview',
          date: 'Scheduled · Aug 08, 2026 · 2:00 PM',
          description: 'Your panel interview is scheduled. Please prepare your portfolio and setup.',
          state: _StepState.active,
          note: 'Interview link: meet.google.com/abc-defg-hij',
        ),
        TrackerStep(
          icon: LucideIcons.award,
          title: 'Deliberation & Matching',
          date: 'Pending · Post-interview',
          description: 'The Aboitiz matching panel will review interview scores and allocate scholarship slots.',
          state: _StepState.future,
        ),
        TrackerStep(
          icon: LucideIcons.wallet,
          title: 'Disbursement Setup',
          date: 'Pending · Post-contracting',
          description: 'Setup of corporate allowance matching card and initial release scheduling.',
          state: _StepState.future,
        ),
      ],
    ),
    AppliedScholarship(
      providerName: 'Megaworld Foundation',
      scholarshipName: 'Megaworld Scholarship Program',
      status: 'Rejected',
      statusType: StatusType.rejected,
      appliedDate: 'Aug 10, 2026',
      compareDate: DateTime(2026, 8, 10),
      referenceNumber: 'ISK-2026-02104',
      steps: [
        TrackerStep(
          icon: LucideIcons.send,
          title: 'Application Submitted',
          date: 'Aug 10, 2026 · 1:15 PM',
          description: 'Your application has been received by Megaworld Foundation.',
          state: _StepState.done,
        ),
        TrackerStep(
          icon: LucideIcons.xCircle,
          title: 'Application Unsuccessful',
          date: 'Aug 20, 2026 · 4:00 PM',
          description: 'Thank you for your interest. Unfortunately, your application did not meet the annual family income ceiling requirement.',
          state: _StepState.active,
        ),
      ],
    ),
  ];

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

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildControlBar(),
          Expanded(
            child: displayedList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
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
    required _StepState state,
    required bool isLast,
    String? note,
  }) {
    Color circleColor;
    Color circleBorder;
    Color lineColor;
    Color iconColor;
    Color titleColor;

    switch (state) {
      case _StepState.done:
        circleColor = AppColors.successBg;
        circleBorder = AppColors.primary;
        lineColor = AppColors.primary;
        iconColor = AppColors.primary;
        titleColor = AppColors.primary;
        break;
      case _StepState.active:
        circleColor = AppColors.pendingBg;
        circleBorder = AppColors.amber;
        lineColor = AppColors.rule;
        iconColor = AppColors.amber;
        titleColor = AppColors.amberDeep;
        break;
      case _StepState.future:
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
                    state == _StepState.done ? LucideIcons.check : icon,
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
                    color: state == _StepState.active
                        ? AppColors.amber.withAlpha(60)
                        : AppColors.rule,
                  ),
                  boxShadow: state == _StepState.active
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
                  opacity: state == _StepState.future ? 0.55 : 1.0,
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
                            if (state == _StepState.done)
                              StatusChip(
                                  label: 'Done',
                                  type: StatusType.approved),
                            if (state == _StepState.active)
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
                            color: state == _StepState.done
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
