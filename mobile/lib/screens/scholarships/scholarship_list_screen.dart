import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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

  Map<String, dynamic>? _scholarProfile;
  List<dynamic> _allPrograms = [];
  List<dynamic> _qualifiedPrograms = [];
  List<dynamic> _displayedPrograms = [];
  bool _isProfileComplete = false;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final scholarData = await Supabase.instance.client
            .from('scholar')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        final programsData = await Supabase.instance.client
            .from('scholarship_programs')
            .select('*, provider:provider_id(*), cycles:application_cycles(*)')
            .eq('status', 'active');

        if (mounted) {
          setState(() {
            _scholarProfile = scholarData;
            _isProfileComplete = EligibilityHelper.isProfileComplete(scholarData);
            _allPrograms = programsData;

            if (_isProfileComplete && scholarData != null) {
              _qualifiedPrograms = _allPrograms
                  .where((p) => EligibilityHelper.isQualified(scholarData, p))
                  .toList();
            } else {
              _qualifiedPrograms = [];
            }
            _applyFilters();
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading list screen: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    List<dynamic> filtered = List.from(_qualifiedPrograms);

    // 1. Chip filter
    if (_activeFilter > 0) {
      final filterLabel = _filters[_activeFilter];
      if (filterLabel == 'Government') {
        filtered = filtered.where((p) {
          final prov = p['provider'] as Map<String, dynamic>?;
          return prov?['provider_type']?.toString().toLowerCase() == 'public';
        }).toList();
      } else if (filterLabel == 'NGO / Private') {
        filtered = filtered.where((p) {
          final prov = p['provider'] as Map<String, dynamic>?;
          final type = prov?['provider_type']?.toString().toLowerCase() ?? '';
          return type == 'private' || type == 'ngo';
        }).toList();
      } else if (filterLabel == 'Merit') {
        filtered = filtered.where((p) => p['scholarship_type']?.toString().toLowerCase().contains('merit') == true).toList();
      } else if (filterLabel == 'Need-based') {
        filtered = filtered.where((p) => p['scholarship_type']?.toString().toLowerCase().contains('need') == true).toList();
      } else if (filterLabel == 'STEM') {
        filtered = filtered.where((p) {
          final title = p['title']?.toString().toLowerCase() ?? '';
          final desc = p['description']?.toString().toLowerCase() ?? '';
          final category = p['category']?.toString().toLowerCase() ?? '';
          return category.contains('stem') || title.contains('stem') || desc.contains('stem');
        }).toList();
      }
    }

    // 2. Search query filter
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final title = p['title']?.toString().toLowerCase() ?? '';
        final prov = p['provider'] as Map<String, dynamic>?;
        final provName = prov?['name']?.toString().toLowerCase() ?? '';
        return title.contains(query) || provName.contains(query);
      }).toList();
    }

    setState(() {
      _displayedPrograms = filtered;
    });
  }

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
                            controller: _searchController,
                            onChanged: (_) => _applyFilters(),
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
                  onTap: () => setState(() {
                    _activeFilter = i;
                    _applyFilters();
                  }),
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
                  '${_displayedPrograms.length} scholarships available',
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary)))
                : _displayedPrograms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            !_isProfileComplete
                                ? 'Complete your profile to view matching scholarships'
                                : 'No qualified scholarships found.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: _displayedPrograms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ScholarshipCard(
                          program: _displayedPrograms[i],
                          scholar: _scholarProfile,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _ScholarshipCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic>? scholar;

  const _ScholarshipCard({required this.program, this.scholar});

  Color get _accentColor {
    final type = program['scholarship_type']?.toString().toLowerCase() ?? 'merit';
    if (type.contains('merit')) {
      return AppColors.primary;
    } else if (type.contains('need')) {
      return AppColors.amber;
    } else {
      return AppColors.released;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = program['provider'] as Map<String, dynamic>?;
    final providerName = provider?['name'] ?? 'Provider';
    final title = program['title'] ?? 'Scholarship';
    final coversTuition = program['covers_tuition'] == true;
    final coversStipend = program['covers_stipend'] == true;
    final stipendAmt = program['stipend_amount'] != null ? '₱${program['stipend_amount']}' : '₱0';
    final amountText = coversStipend ? '$stipendAmt' : (coversTuition ? 'Tuition Covered' : 'Varies');
    final periodText = coversStipend ? 'per semester' : '';

    return AppCard(
      borderLeftColor: _accentColor,
      onTap: () => Navigator.pushNamed(
        context,
        AppRouter.scholarshipDetail,
        arguments: {
          'program': program,
          'scholar': scholar,
        },
      ),
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
                    StatusChip(
                      label: providerName.length > 25
                          ? providerName.substring(0, 25) + '...'
                          : providerName,
                      type: program['scholarship_type']
                                  ?.toString()
                                  .toLowerCase()
                                  .contains('merit') ==
                              true
                          ? StatusType.approved
                          : StatusType.pending,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      providerName,
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
                  program['scholarship_type']
                              ?.toString()
                              .toLowerCase()
                              .contains('need') ==
                          true
                      ? LucideIcons.award
                      : LucideIcons.graduationCap,
                  color: _accentColor,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.rule),
          const SizedBox(height: 12),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$amountText $periodText',
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
                  const Icon(
                    LucideIcons.clock,
                    size: 11,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Open',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
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
