import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const DashboardScreen({super.key, this.onSelectTab});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  void refreshDashboard() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  void _navigateToTab(int tabIndex, String fallbackRoute) {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(tabIndex);
    } else {
      Navigator.pushNamed(context, fallbackRoute);
    }
  }

  String _scholarName = 'Mark Steven';
  Map<String, dynamic>? _scholarProfile;
  List<dynamic> _allPrograms = [];
  List<dynamic> _qualifiedPrograms = [];
  List<dynamic> _recentActivities = [];
  List<Map<String, dynamic>> _openRenewalAlerts = [];
  bool _isProfileComplete = false;
  bool _isLoadingData = true;
  int _unreadNotifCount = 0;
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
          table: 'notifications',
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
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_programs',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
      return;
    }

    try {
      // 1. Fetch scholar profile to resolve IDs
      final scholarData = await Supabase.instance.client
          .from('scholar')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final List<String> scholarIds = [user.id];
      if (scholarData != null && scholarData['id'] != null) {
        scholarIds.add(scholarData['id'].toString());
      }

      // 2. Execute independent queries IN PARALLEL for sub-second loading speed
      final results = await Future.wait([
        // [0] Active Programs with provider & cycles
        Supabase.instance.client
            .from('scholarship_programs')
            .select('*, provider:provider_id(*), cycles:application_cycles(*)')
            .neq('status', 'closed'),

        // [1] Unread notifications count
        Supabase.instance.client
            .from('notifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('is_read', false),

        // [2] All applications for this scholar
        Supabase.instance.client
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
            .order('created_at', ascending: false),
      ]);

      final programsData = results[0] as List<dynamic>? ?? [];
      final notifRes = results[1] as List<dynamic>? ?? [];
      final allAppsData = results[2] as List<dynamic>? ?? [];

      // Extract set of all cycle_ids the scholar has ALREADY submitted an application for
      final Set<String> submittedCycleIds = {};
      final Set<String> approvedProgramIds = {};

      for (final app in allAppsData) {
        final cycleId = app['cycle_id']?.toString();
        if (cycleId != null) {
          submittedCycleIds.add(cycleId);
        }
        final status = app['status']?.toString().toLowerCase();
        final cycle = app['cycle'] as Map<String, dynamic>?;
        final programId = cycle?['program_id']?.toString() ?? cycle?['program']?['id']?.toString();
        if (status == 'approved' && programId != null) {
          approvedProgramIds.add(programId);
        }
      }

      // Filter open renewal cycles for approved programs WHERE scholar HAS NOT YET submitted an application
      final List<Map<String, dynamic>> renewalAlerts = [];
      if (approvedProgramIds.isNotEmpty) {
        try {
          final openRenewalCycles = await Supabase.instance.client
              .from('application_cycles')
              .select('*, program:scholarship_programs(*, provider:provider(*))')
              .filter('program_id', 'in', approvedProgramIds.toList())
              .eq('status', 'open');

          final Set<String> alertSeenPrograms = {};
          for (final r in openRenewalCycles) {
            final cycleId = r['id']?.toString();
            final program = r['program'] as Map<String, dynamic>?;
            final programId = program?['id']?.toString();

            if (cycleId != null && submittedCycleIds.contains(cycleId)) {
              continue;
            }

            final cType = r['cycle_type']?.toString().toLowerCase() ?? '';
            final cName = r['cycle_name']?.toString().toLowerCase() ?? '';
            if (cType == 'renewal' || cName.contains('renewal') || cName.contains('sem')) {
              if (programId != null && !alertSeenPrograms.contains(programId)) {
                alertSeenPrograms.add(programId);
                renewalAlerts.add({
                  'scholar_id': scholarData?['id'] ?? user.id,
                  'program': program,
                  'renewal_cycle': r,
                });
              }
            }
          }
        } catch (rErr) {
          debugPrint('Note checking open renewal cycles: $rErr');
        }
      }

      if (mounted) {
        setState(() {
          _scholarProfile = scholarData;
          _isProfileComplete = EligibilityHelper.isProfileComplete(scholarData);
          _scholarName = (scholarData != null && scholarData['first_name'] != null)
              ? (scholarData['first_name'] as String)
              : 'Mark Steven';
          _unreadNotifCount = notifRes.length;

          final openPrograms = programsData
              .where((p) => EligibilityHelper.isProgramOpen(p as Map<String, dynamic>?))
              .toList();

          _allPrograms = openPrograms;
          _recentActivities = allAppsData.take(5).toList();
          _openRenewalAlerts = renewalAlerts;

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

  @override
  Widget build(BuildContext context) {
    String scholarDisplayName = _scholarName;
    if (_scholarProfile != null) {
      final fname = _scholarProfile!['first_name']?.toString() ?? '';
      final lname = _scholarProfile!['last_name']?.toString() ?? '';
      if (fname.isNotEmpty) {
        final formattedFname = fname.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : '').join(' ');
        final formattedLname = lname.isNotEmpty ? lname.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : '').join(' ') : '';
        scholarDisplayName = '$formattedFname $formattedLname'.trim();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: const Color(0xFFFAFCFA),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _buildTopHeader(context, scholarDisplayName),
            ),
          ),

          // Scrollable Content Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Banner Card ("Your future starts here.")
                  _buildHeroBanner(context),
                  const SizedBox(height: 24),

                  // 📢 Top-priority Semestral Renewal Alerts if present
                  if (_openRenewalAlerts.isNotEmpty) ...[
                    for (final alert in _openRenewalAlerts) ...[
                      _buildRenewalHomeBanner(context, alert),
                      const SizedBox(height: 20),
                    ],
                  ],

                  // 2. Quick Actions Stack Grid (2x2)
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 24),

                  // 3. Recommended For You Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended for you',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateToTab(1, AppRouter.scholarships),
                        child: Text(
                          'See all',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3D2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendedCard(context),
                  const SizedBox(height: 24),

                  // 4. Recent Activity Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateToTab(2, AppRouter.applicationTracker),
                        child: Text(
                          'View all',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3D2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
  Widget _buildTopHeader(BuildContext context, String displayName) {
    final badgeCount = _unreadNotifCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(
                LucideIcons.flame,
                size: 22,
                color: Color(0xFFE55B2B),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Good morning,',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, AppRouter.notifications);
            if (mounted) _loadDashboardData();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.bell,
                    color: Color(0xFF111827),
                    size: 20,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 2. Hero Banner Card ────────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3D2F), Color(0xFF162E23)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3D2F).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your future\nstarts here.',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find and apply for scholarships that support your goals.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _navigateToTab(1, AppRouter.scholarships),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Browse Scholarships',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3D2F),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.arrowRight,
                          size: 14,
                          color: Color(0xFF1E3D2F),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            height: 110,
            child: Image.asset(
              'assets/books-hats-icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Semestral Renewal Banner ────────────────────────────────────────────
  Widget _buildRenewalHomeBanner(BuildContext context, Map<String, dynamic> alert) {
    final program = alert['program'] as Map<String, dynamic>?;
    final renewalCycle = alert['renewal_cycle'] as Map<String, dynamic>?;
    final programName = program?['title']?.toString() ?? 'Scholarship Program';
    final sem = renewalCycle?['semester']?.toString() ?? '2nd Semester';
    final cycleName = renewalCycle?['cycle_name']?.toString() ?? 'Renewal Batch';
    final deadline = renewalCycle?['application_end_date']?.toString() ?? 'Open';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3D2F), Color(0xFF2D5941)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3D2F).withValues(alpha: 0.2),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.refreshCw, size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'ACTION REQUIRED',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Deadline: $deadline',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$sem Renewal Open',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$programName ($cycleName)',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your scholarship provider has opened the semestral renewal submission. Upload your required documents now to renew your grant eligibility.',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToTab(2, AppRouter.applicationTracker),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Submit Renewal Requirements →',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Quick Actions Grid ──────────────────────────────────────────────────
  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      _QuickActionItem(
        title: 'Find Scholarships',
        subtitle: 'Explore opportunities that match you',
        icon: LucideIcons.search,
        bgColor: const Color(0xFFEEF7F2),
        borderColor: const Color(0xFFD3ECD9),
        iconBgColor: const Color(0xFFD4EBDC),
        iconColor: const Color(0xFF1E3D2F),
        onTap: () => _navigateToTab(1, AppRouter.scholarships),
      ),
      _QuickActionItem(
        title: 'Upload Requirements',
        subtitle: 'Submit and manage your documents',
        icon: LucideIcons.folder,
        bgColor: const Color(0xFFFFF8EF),
        borderColor: const Color(0xFFFDE8D0),
        iconBgColor: const Color(0xFFFCE7CF),
        iconColor: const Color(0xFFD97706),
        onTap: () => _navigateToTab(2, AppRouter.applicationTracker),
      ),
      _QuickActionItem(
        title: 'Fund Releases',
        subtitle: 'View your scholarship payments',
        icon: LucideIcons.wallet,
        bgColor: const Color(0xFFEFF5FF),
        borderColor: const Color(0xFFD6E4FF),
        iconBgColor: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        onTap: () => _navigateToTab(3, AppRouter.fundTracking),
      ),
      _QuickActionItem(
        title: 'Track Application',
        subtitle: 'Check your application status',
        icon: LucideIcons.clipboardList,
        bgColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFFDCFCE7),
        iconBgColor: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        onTap: () => _navigateToTab(2, AppRouter.applicationTracker),
      ),
    ];

    Widget buildCard(_QuickActionItem item) {
      return GestureDetector(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(item.icon, color: item.iconColor, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                      height: 1.25,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: item.iconColor,
                    ),
                  ),
                ),
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

  // ─── 5. Recommended Card ────────────────────────────────────────────────────
  Widget _buildRecommendedCard(BuildContext context) {
    if (_isLoadingData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3D2F))),
        ),
      );
    }

    if (_qualifiedPrograms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.graduationCap,
                  color: Color(0xFF1E3D2F),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Matching Scholarships',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We couldn\'t find any scholarships matching your course, year level, or location at the moment. We will notify you when a match is found!',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.sparkles,
              color: Color(0xFFEAB308),
              size: 18,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _qualifiedPrograms.take(3).map((program) {
        final provider = program['provider'] as Map<String, dynamic>?;
        final providerName = provider?['name'] ?? 'Provider';
        final title = program['title'] ?? 'Scholarship';

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
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.graduationCap,
                        color: Color(0xFF1E3D2F),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          providerName,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 6. Recent Activity List ────────────────────────────────────────────────
  Widget _buildRecentActivity(BuildContext context) {
    if (_recentActivities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.activity,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your submitted applications, document updates, and status changes will appear here in real time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_recentActivities.length, (i) {
        final act = _recentActivities[i];
        final cycle = act['cycle'] as Map<String, dynamic>?;
        final program = cycle?['program'] as Map<String, dynamic>?;
        final title = program?['title'] ?? 'Scholarship Application';
        final dbStatus = act['status']?.toString().toLowerCase() ?? 'pending';

        String statusTitle = 'Application Submitted';
        String statusLabel = 'Submitted';
        Color bgCol = const Color(0xFFFEF3C7);
        Color txtCol = const Color(0xFFB45309);

        if (dbStatus == 'approved') {
          statusTitle = 'Application Approved! 🎓';
          statusLabel = 'Approved';
          bgCol = const Color(0xFFDCFCE7);
          txtCol = const Color(0xFF15803D);
        } else if (dbStatus == 'for_exam') {
          statusTitle = 'Shortlisted for Examination';
          statusLabel = 'For Exam';
          bgCol = const Color(0xFFE0F2FE);
          txtCol = const Color(0xFF0369A1);
        } else if (dbStatus == 'rejected' || dbStatus == 'withdrawn') {
          statusTitle = 'Application Evaluated';
          statusLabel = dbStatus == 'rejected' ? 'Rejected' : 'Withdrawn';
          bgCol = const Color(0xFFFEE2E2);
          txtCol = const Color(0xFFB91C1C);
        }

        final rawDate = act['updated_at'] != null
            ? DateTime.tryParse(act['updated_at'].toString())
            : (act['created_at'] != null ? DateTime.tryParse(act['created_at'].toString()) : DateTime.now());
        final diff = DateTime.now().difference(rawDate ?? DateTime.now());
        String timeAgo = 'Just now';
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgo = '${diff.inMinutes}m ago';
        }

        return Container(
          margin: EdgeInsets.only(bottom: i == _recentActivities.length - 1 ? 0 : 10),
          child: _ActivityCardItem(
            title: statusTitle,
            programName: title,
            timeAgo: timeAgo,
            statusLabel: statusLabel,
            statusBgColor: bgCol,
            statusTextColor: txtCol,
            onTap: () => _navigateToTab(2, AppRouter.applicationTracker),
          ),
        );
      }),
    );
  }
}

// ─── Quick Action Data Helper Model ──────────────────────────────────────────
class _QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });
}

// ─── Activity Card Item Widget ───────────────────────────────────────────────
class _ActivityCardItem extends StatelessWidget {
  final String title;
  final String programName;
  final String timeAgo;
  final String statusLabel;
  final Color statusBgColor;
  final Color statusTextColor;
  final VoidCallback onTap;

  const _ActivityCardItem({
    required this.title,
    required this.programName,
    required this.timeAgo,
    required this.statusLabel,
    required this.statusBgColor,
    required this.statusTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF86EFAC), width: 1),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                      Text(
                        timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          programName,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF6B7280),
                          ),
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
