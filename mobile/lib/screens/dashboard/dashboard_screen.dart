import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  void refreshDashboard() {
    if (mounted) {
      _loadDashboardData();
    }
  }
  int _activeFilterIndex = 0;
  final List<String> _filters = [
    'All',
    'STEM',
    'Arts & Humanities',
    'LGU-Funded',
    'Private/NGO'
  ];

  String _scholarName = 'SCHOLAR';
  Map<String, dynamic>? _scholarProfile;
  List<dynamic> _allPrograms = [];
  List<dynamic> _qualifiedPrograms = [];
  List<dynamic> _recentActivities = [];
  bool _isProfileComplete = false;
  bool _isLoadingData = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('dashboard-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_applications',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_programs',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_notifications',
          callback: (payload) {
            if (mounted) _loadDashboardData();
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

  Future<void> _loadDashboardData() async {
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

        final List<String> scholarIds = [user.id];
        if (scholarData != null && scholarData['id'] != null) {
          scholarIds.add(scholarData['id'].toString());
        }

        List<dynamic> activities = [];
        try {
          activities = await Supabase.instance.client
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
              .order('created_at', ascending: false)
              .limit(5);
        } catch (actErr) {
          debugPrint('Note loading recent activities: $actErr');
        }

        if (mounted) {
          setState(() {
            _scholarProfile = scholarData;
            _isProfileComplete = EligibilityHelper.isProfileComplete(scholarData);
            _scholarName = (scholarData != null && scholarData['first_name'] != null)
                ? (scholarData['first_name'] as String).toUpperCase()
                : 'SCHOLAR';

            _allPrograms = programsData;
            _recentActivities = activities;

            if (_isProfileComplete && scholarData != null) {
              _qualifiedPrograms = _allPrograms
                  .where((p) => EligibilityHelper.isQualified(scholarData, p))
                  .toList();
            } else {
              _qualifiedPrograms = [];
            }
            _isLoadingData = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading dashboard data: $e');
        if (mounted) {
          setState(() {
            _isLoadingData = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Clean light cream white
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _buildTopHeader(context),
            ),
          ),

            // Scrollable Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Headlines
                    _buildHeadlines(),
                    const SizedBox(height: 20),

              // 3. Stat Cards Row (3 horizontal cards)
              _buildStatCardsRow(),
              const SizedBox(height: 20),

              // 4. Search Bar
              _buildSearchBar(),
              const SizedBox(height: 16),

              // 5. Scrollable Filter Chips
              _buildFilterChipsRow(),
              const SizedBox(height: 20),

              // 6. Urgent Alert Card with Sawtooth / Stamp Bottom Edge
              _buildUrgentBanner(context),
              const SizedBox(height: 24),

              // 7. 2x2 Quick Actions Stack
              const SectionHeading(
                title: 'Quick Actions',
              ),
              const SizedBox(height: 14),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 28),

              // 8. Recommended For You Section
              SectionHeading(
                title: 'Recommended for you',
                actionLabel: 'See all',
                onAction: () =>
                    Navigator.pushNamed(context, AppRouter.scholarshipDetail),
              ),
              const SizedBox(height: 14),
              _buildRecommendedCard(context),
              const SizedBox(height: 20),

              // 9. Recent Activity
              const SectionHeading(
                title: 'Recent Activity',
                actionLabel: 'View all',
              ),
              const SizedBox(height: 14),
              _buildRecentActivity(context),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  // ─── 1. Top Header Row ──────────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
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
              'MAGANDANG UMAGA, $_scholarName',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.amberDeep,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRouter.notifications),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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
                    LucideIcons.bell,
                    color: AppColors.amber,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 2. Headlines ───────────────────────────────────────────────────────────
  Widget _buildHeadlines() {
    final count = _qualifiedPrograms.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your next\nscholarship.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isProfileComplete
              ? '$count opportunity(ies) matched to your profile'
              : 'Complete your profile to find matching opportunities',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─── 3. Stat Cards Row ──────────────────────────────────────────────────────
  Widget _buildStatCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            value: '3',
            label: 'APPLICATIONS',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            value: '1',
            label: 'APPROVED',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            value: '₱60K',
            label: 'EST. FUNDING',
            isMono: true,
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  // ─── 4. Search Bar ──────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.rule, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search scholarships, providers...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
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
    );
  }

  // ─── 5. Filter Chips Row ────────────────────────────────────────────────────
  Widget _buildFilterChipsRow() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _activeFilterIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _activeFilterIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.amber : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.amber : AppColors.rule,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.amber.withAlpha(40),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                _filters[index],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── 6. Urgent Banner Card (Sawtooth / Stamp Edge) ─────────────────────────
  Widget _buildUrgentBanner(BuildContext context) {
    return ClipPath(
      clipper: SawtoothClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: AppColors.error, // Deep burgundy red
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  '12 days left',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'DOST-SEI Undergraduate Scholarship closes on Jul 27 — 1 requirement still pending.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withAlpha(230),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 7. 2x2 Quick Actions Stack Grid ─────────────────────────────────────
  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      _SlideableActionData(
        title: 'Find Scholarships',
        subtitle: 'Explore 14 matching opportunities',
        icon: LucideIcons.search,
        badge: 'NEW',
        bgGradient: const LinearGradient(
          colors: [Color(0xFF1A3C2E), Color(0xFF2D5941)],
        ),
        iconBg: Colors.white.withAlpha(30),
        iconColor: Colors.white,
        textColor: Colors.white,
        onTap: () => Navigator.pushNamed(context, AppRouter.scholarshipDetail),
      ),
      _SlideableActionData(
        title: 'Upload Requirements',
        subtitle: '1 document pending upload',
        icon: LucideIcons.uploadCloud,
        badge: '1 PENDING',
        bgGradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
        ),
        iconBg: AppColors.amber.withAlpha(40),
        iconColor: AppColors.amberDeep,
        textColor: AppColors.textPrimary,
        borderColor: AppColors.amber.withAlpha(80),
        onTap: () => Navigator.pushNamed(context, AppRouter.documentUpload),
      ),
      _SlideableActionData(
        title: 'Fund Releases',
        subtitle: '₱ 40,000 disbursement logged',
        icon: LucideIcons.wallet,
        badge: 'VERIFIED',
        bgGradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        iconBg: AppColors.released.withAlpha(30),
        iconColor: AppColors.released,
        textColor: AppColors.textPrimary,
        borderColor: AppColors.released.withAlpha(60),
        onTap: () => Navigator.pushNamed(context, AppRouter.fundTracking),
      ),
      _SlideableActionData(
        title: 'Track Application',
        subtitle: 'Under Review by committee',
        icon: LucideIcons.clipboardList,
        badge: 'IN PROGRESS',
        bgGradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        iconBg: AppColors.primary.withAlpha(30),
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
        borderColor: AppColors.primary.withAlpha(60),
        onTap: () => Navigator.pushNamed(context, AppRouter.applicationTracker),
      ),
    ];

    Widget buildCard(_SlideableActionData item) {
      return GestureDetector(
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: item.bgGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.borderColor ?? Colors.transparent,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge,
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: item.iconColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: item.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: item.textColor.withAlpha(180),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: buildCard(actions[0])),
            const SizedBox(width: 12),
            Expanded(child: buildCard(actions[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: buildCard(actions[2])),
            const SizedBox(width: 12),
            Expanded(child: buildCard(actions[3])),
          ],
        ),
      ],
    );
  }

  // ─── 8. Recommended Card (Matches Image Design) ────────────────────────────
  Widget _buildRecommendedCard(BuildContext context) {
    if (_isLoadingData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
        ),
      );
    }

    if (!_isProfileComplete) {
      return AppCard(
        borderLeftColor: AppColors.error,
        padding: const EdgeInsets.all(18),
        onTap: () async {
          final updated =
              await Navigator.pushNamed(context, AppRouter.profileEdit);
          if (updated == true) {
            setState(() {
              _isLoadingData = true;
            });
            _loadDashboardData();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete Your Profile',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fill out your location details, year level, GWA, and course under your profile to unlock and view matching scholarships you are qualified to apply for.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Set Up Profile',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.arrowRight,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ),
      );
    }

    if (_qualifiedPrograms.isEmpty) {
      return AppCard(
        borderLeftColor: AppColors.textMuted,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Matching Scholarships',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any scholarships matching your course, year level, GWA, or location at this moment. We will notify you when a match is found!',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    // Display the list of matching scholarships
    return Column(
      children: _qualifiedPrograms.take(3).map((program) {
        final provider = program['provider'] as Map<String, dynamic>?;
        final providerName = provider?['name'] ?? 'Provider';
        final providerShort = providerName.length > 10
            ? providerName.substring(0, 10) + '...'
            : providerName;
        final title = program['title'] ?? 'Scholarship';
        final coversTuition = program['covers_tuition'] == true;
        final coversStipend = program['covers_stipend'] == true;
        final stipendAmt = program['stipend_amount'] != null
            ? '₱${program['stipend_amount']}'
            : '₱0';
        final amountText = coversStipend
            ? '$stipendAmt/sem'
            : (coversTuition ? 'Tuition Covered' : 'Varies');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.scholarshipDetail,
              arguments: {
                'program': program,
                'scholar': _scholarProfile,
              },
            ),
            child: AppCard(
              borderLeftColor: AppColors.gold,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            providerShort.isNotEmpty
                                ? providerShort.substring(0, providerShort.length > 3 ? 3 : providerShort.length).toUpperCase()
                                : 'SP',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.gold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (coversTuition) _TagPill(label: 'Full tuition'),
                      if (coversStipend) _TagPill(label: 'Stipend'),
                      _TagPill(
                          label: program['scholarship_type']
                                  ?.toString()
                                  .toUpperCase() ??
                              'MERIT'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const DashedDivider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVAILABILITY',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            program['availability_scope']
                                    ?.toString()
                                    .toUpperCase() ??
                                'NATIONWIDE',
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'COVERAGE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            amountText,
                            style: GoogleFonts.dmMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 9. Recent Activity List ────────────────────────────────────────────────
  Widget _buildRecentActivity(BuildContext context) {
    if (_recentActivities.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Recent Activity',
              style: GoogleFonts.playfairDisplay(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your submitted scholarship applications and status updates will appear here live.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < _recentActivities.length; i++) {
      final act = _recentActivities[i];
      final cycle = act['cycle'] as Map<String, dynamic>?;
      final program = cycle?['program'] as Map<String, dynamic>?;

      final title = program?['title'] ?? 'Scholarship Program';
      final dbStatus = act['status']?.toString().toLowerCase() ?? 'pending';

      String statusTitle = 'Application Submitted';
      IconData icon = LucideIcons.send;
      Color iconColor = AppColors.primary;
      StatusType statusType = StatusType.pending;

      if (dbStatus == 'pending') {
        statusTitle = 'Application Submitted';
        icon = LucideIcons.send;
        iconColor = AppColors.primary;
        statusType = StatusType.pending;
      } else if (dbStatus == 'under_review') {
        statusTitle = 'Under Review';
        icon = LucideIcons.hourglass;
        iconColor = AppColors.amber;
        statusType = StatusType.pending;
      } else if (dbStatus == 'for_exam') {
        statusTitle = 'For Exam / Evaluation';
        icon = LucideIcons.fileCheck2;
        iconColor = AppColors.amber;
        statusType = StatusType.pending;
      } else if (dbStatus == 'approved') {
        statusTitle = 'Application Approved';
        icon = LucideIcons.checkCircle2;
        iconColor = AppColors.primary;
        statusType = StatusType.approved;
      } else if (dbStatus == 'rejected') {
        statusTitle = 'Application Unsuccessful';
        icon = LucideIcons.xCircle;
        iconColor = AppColors.error;
        statusType = StatusType.rejected;
      } else if (dbStatus == 'withdrawn') {
        statusTitle = 'Application Withdrawn';
        icon = LucideIcons.xCircle;
        iconColor = AppColors.textMuted;
        statusType = StatusType.rejected;
      }

      final rawDate = act['created_at'] != null ? DateTime.tryParse(act['created_at'].toString()) : DateTime.now();
      final diff = DateTime.now().difference(rawDate ?? DateTime.now());
      String timeAgo = 'Just now';
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes}m ago';
      }

      if (i > 0) {
        children.add(Divider(height: 1, color: AppColors.rule));
      }

      children.add(
        _ActivityTile(
          icon: icon,
          iconColor: iconColor,
          title: statusTitle,
          subtitle: title,
          time: timeAgo,
          statusType: statusType,
          onTap: () => Navigator.pushNamed(context, AppRouter.applicationTracker),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

// ─── Custom Sawtooth Clipper ─────────────────────────────────────────────────
class SawtoothClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 12);

    const triangleWidth = 18.0;
    const triangleHeight = 12.0;
    final count = (size.width / triangleWidth).ceil();

    for (int i = 0; i < count; i++) {
      final x = i * triangleWidth;
      path.lineTo(x + triangleWidth / 2, size.height);
      path.lineTo(x + triangleWidth, size.height - triangleHeight);
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─── Custom Dashed Line Divider ──────────────────────────────────────────────
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.rule),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Mini Stat Card Component ────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isMono;
  final bool isHighlighted;

  const _MiniStatCard({
    required this.value,
    required this.label,
    this.isMono = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppColors.amber.withAlpha(120)
              : AppColors.rule,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: isMono
                ? GoogleFonts.dmMono(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  )
                : GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Tag Pill Helper ─────────────────────────────────────────────────────────
class _TagPill extends StatelessWidget {
  final String label;

  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.amberDeep,
        ),
      ),
    );
  }
}

// ─── Slideable Action Data Model ─────────────────────────────────────────────
class _SlideableActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final LinearGradient bgGradient;
  final Color iconBg;
  final Color iconColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SlideableActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.bgGradient,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });
}

// ─── Activity Tile Sub-component ─────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final StatusType statusType;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.statusType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(label: statusType.name, type: statusType),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
