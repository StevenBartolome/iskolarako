import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/app_components.dart';


class ScholarshipListScreen extends StatefulWidget {
  const ScholarshipListScreen({super.key});

  @override
  State<ScholarshipListScreen> createState() => _ScholarshipListScreenState();
}

class _ScholarshipListScreenState extends State<ScholarshipListScreen> {
  int _activeFilter = 0;
  final List<String> _filters = [
    'All', 'Government', 'NGO / Private', 'Merit', 'Need-based', 'STEM'
  ];

  static const List<_ScholarshipData> _items = [
    _ScholarshipData(
      title: 'DOST-SEI Undergraduate Scholarship',
      provider: 'Dept. of Science & Technology',
      amount: '₱40,000',
      period: 'per semester',
      tag: 'Government',
      tagType: StatusType.approved,
      deadlineLabel: '5 days left',
      isUrgent: true,
      slots: 72,
      totalSlots: 100,
    ),
    _ScholarshipData(
      title: 'Ayala Foundation Excellence Grant',
      provider: 'Ayala Foundation, Inc.',
      amount: '₱60,000',
      period: 'per year',
      tag: 'NGO / Private',
      tagType: StatusType.pending,
      deadlineLabel: 'Open · Dec 31',
      isUrgent: false,
    ),
    _ScholarshipData(
      title: 'QC Academic Achievement Award',
      provider: 'Quezon City Government',
      amount: '₱25,000',
      period: 'per semester',
      tag: 'Government',
      tagType: StatusType.released,
      deadlineLabel: 'Open · No deadline',
      isUrgent: false,
    ),
    _ScholarshipData(
      title: 'SM Foundation Scholars Program',
      provider: 'SM Foundation',
      amount: '₱30,000',
      period: 'per year',
      tag: 'NGO / Private',
      tagType: StatusType.pending,
      deadlineLabel: '18 days left',
      isUrgent: false,
    ),
    _ScholarshipData(
      title: 'CHED Merit Scholarship Program',
      provider: 'Commission on Higher Education',
      amount: '₱22,000',
      period: 'per semester',
      tag: 'Government',
      tagType: StatusType.approved,
      deadlineLabel: '12 days left',
      isUrgent: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
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
                            'SCHOLARSHIPS & GRANTS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDeep,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
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
                            LucideIcons.sliders,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Browse\nscholarships.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Filter by category, income level, or academic field',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.rule, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withAlpha(8),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.search,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by name or provider…',
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              fillColor: Colors.transparent,
                              filled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = _activeFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryDark
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.primaryDark : AppColors.rule,
                      ),
                    ),
                    child: Text(
                      _filters[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  '${_items.length} scholarships available',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _ScholarshipCard(data: _items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _ScholarshipData {
  final String title;
  final String provider;
  final String amount;
  final String period;
  final String tag;
  final StatusType tagType;
  final String deadlineLabel;
  final bool isUrgent;
  final int? slots;
  final int? totalSlots;

  const _ScholarshipData({
    required this.title,
    required this.provider,
    required this.amount,
    required this.period,
    required this.tag,
    required this.tagType,
    required this.deadlineLabel,
    required this.isUrgent,
    this.slots,
    this.totalSlots,
  });
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _ScholarshipCard extends StatelessWidget {
  final _ScholarshipData data;

  const _ScholarshipCard({required this.data});

  Color get _accentColor {
    switch (data.tagType) {
      case StatusType.approved:
        return AppColors.primary;
      case StatusType.pending:
        return AppColors.amber;
      case StatusType.released:
        return AppColors.released;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderLeftColor: _accentColor,
      onTap: () =>
          Navigator.pushNamed(context, AppRouter.scholarshipDetail),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(label: data.tag, type: data.tagType),
                    const SizedBox(height: 8),
                    Text(
                      data.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.provider,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data.tagType == StatusType.pending
                      ? LucideIcons.award
                      : LucideIcons.graduationCap,
                  color: _accentColor,
                  size: 22,
                ),
              ),
            ],
          ),
          // Slots bar
          if (data.slots != null && data.totalSlots != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: data.slots! / data.totalSlots!,
                minHeight: 5,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${data.slots} / ${data.totalSlots} slots remaining',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.rule),
          const SizedBox(height: 12),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${data.amount} / ${data.period}',
                  style: GoogleFonts.dmMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 11,
                    color: data.isUrgent
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.deadlineLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: data.isUrgent
                          ? AppColors.error
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
