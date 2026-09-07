import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/utils/eligibility_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScholarshipListScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const ScholarshipListScreen({super.key, this.onSelectTab});

  @override
  State<ScholarshipListScreen> createState() => _ScholarshipListScreenState();
}

class _ScholarshipListScreenState extends State<ScholarshipListScreen> {
  int _activeFilter = 0;
  final List<String> _filters = [
    'All',
    'Government',
    'NGO / Private',
    'Merit-Based',
    'Need-Based',
    'Both Merit & Need',
  ];

  Map<String, dynamic>? _scholarProfile;
  List<dynamic> _allPrograms = [];
  List<dynamic> _qualifiedPrograms = [];
  List<dynamic> _displayedPrograms = [];
  bool _isProfileComplete = false;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  RealtimeChannel? _realtimeChannel;

  void _navigateToProfileTab() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(4);
    } else {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
    _searchController.addListener(_applyFilters);
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('scholarship-list-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_programs',
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'application_cycles',
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar',
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'provider',
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_applications',
          callback: (payload) {
            if (mounted) _loadData();
          },
        );
    _realtimeChannel?.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
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
            .neq('status', 'closed');

        if (mounted) {
          setState(() {
            _scholarProfile = scholarData;
            _isProfileComplete = EligibilityHelper.isProfileComplete(scholarData);
            final openPrograms = (programsData as List<dynamic>?)
                    ?.where((p) => EligibilityHelper.isProgramOpen(p as Map<String, dynamic>?))
                    .toList() ??
                [];
            _allPrograms = openPrograms;

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
      } else if (filterLabel.contains('Both') || (filterLabel.contains('Merit') && filterLabel.contains('Need'))) {
        filtered = filtered.where((p) {
          final t = p['scholarship_type']?.toString().toLowerCase() ?? '';
          return t.contains('merit') && t.contains('need');
        }).toList();
      } else if (filterLabel.contains('Merit')) {
        filtered = filtered.where((p) => p['scholarship_type']?.toString().toLowerCase().contains('merit') == true).toList();
      } else if (filterLabel.contains('Need')) {
        filtered = filtered.where((p) => p['scholarship_type']?.toString().toLowerCase().contains('need') == true).toList();
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
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                                  'SCHOLARSHIPS & GRANTS',
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
                              'Browse\nscholarships.',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Find scholarships that fit your goals and help you achieve your dreams',
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
                  const SizedBox(height: 16),

                  // Search bar
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                        const Icon(
                          LucideIcons.search,
                          color: Color(0xFF9CA3AF),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => _applyFilters(),
                            decoration: InputDecoration(
                              hintText: 'Search by name or provider...',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF9CA3AF),
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
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                            child: const Icon(
                              LucideIcons.x,
                              color: Color(0xFF9CA3AF),
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horizontal Filter Chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        _filters[i],
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
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

          // Counter Text
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  '${_displayedPrograms.length} scholarships available',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable List or Empty State
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF1E3D2F),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3D2F)),
                      ),
                    )
                  : _displayedPrograms.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!_isProfileComplete) ...[
                                      const Icon(
                                        LucideIcons.alertTriangle,
                                        size: 64,
                                        color: Color(0xFFE65100),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Complete Your Profile',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'To search and view matching scholarships, please complete all required profile fields and identity verification.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF6B7280),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      GestureDetector(
                                        onTap: _navigateToProfileTab,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3D2F),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: Text(
                                            'Go to Profile Setup',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      const _EmptyScholarshipGraphic(),
                                      const SizedBox(height: 20),
                                      Text(
                                        'No scholarships found',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your search or filters to\nsee more results.',
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
                                          setState(() {
                                            _searchController.clear();
                                            _activeFilter = 0;
                                            _applyFilters();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3D2F),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: Text(
                                            'Clear Filters',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _displayedPrograms.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _ScholarshipCard(
                            program: _displayedPrograms[i],
                            scholar: _scholarProfile,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Graphic for Empty Scholarship State ──────────────────────────────
class _EmptyScholarshipGraphic extends StatelessWidget {
  const _EmptyScholarshipGraphic();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            LucideIcons.graduationCap,
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
    );
  }
}

// ─── Scholarship Card Component ──────────────────────────────────────────────
class _ScholarshipCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic>? scholar;

  const _ScholarshipCard({required this.program, this.scholar});

  @override
  Widget build(BuildContext context) {
    final provider = program['provider'] as Map<String, dynamic>?;
    final providerName = provider?['name'] ?? 'Provider';
    final title = program['title'] ?? 'Scholarship Program';
    final amountText = calculateGrantValueSummary(program);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRouter.scholarshipDetail,
        arguments: {
          'program': program,
          'scholar': scholar,
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
              color: Colors.black.withValues(alpha: 0.02),
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
            Text(
              amountText,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3D2F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(num amount) {
  final str = amount.toStringAsFixed(0);
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return '₱${str.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
}

String calculateGrantValueSummary(Map<String, dynamic>? program) {
  if (program == null) return 'Grant Assistance';

  double totalMonetaryGrant = 0.0;

  // 1. Base program grant amount
  final amountVal = double.tryParse(program['amount']?.toString() ?? '') ??
      double.tryParse(program['grant_amount']?.toString() ?? '') ?? 0.0;
  totalMonetaryGrant += amountVal;

  // 2. Stipend / Allowance amount
  if (program['covers_stipend'] == true && program['stipend_amount'] != null) {
    totalMonetaryGrant += double.tryParse(program['stipend_amount'].toString()) ?? 0.0;
  }

  // 3. Book / Device Allowance amount
  if (program['covers_allowance'] == true && program['allowance_amount'] != null) {
    totalMonetaryGrant += double.tryParse(program['allowance_amount'].toString()) ?? 0.0;
  }

  // 4. Fixed Cap Tuition Subsidy
  final coversTuition = program['covers_tuition'] == true || program['coverstuition'] == true;
  final tuitionType = program['tuition_coverage_type']?.toString();
  final tuitionMax = double.tryParse(program['tuition_max_amount']?.toString() ?? '');
  if (coversTuition && tuitionType == 'fixed_cap' && tuitionMax != null) {
    totalMonetaryGrant += tuitionMax;
  }

  // 5. Custom Benefits List
  if (program['custom_benefits'] != null && program['custom_benefits'] is List) {
    for (final b in (program['custom_benefits'] as List)) {
      if (b is Map && b['amount'] != null) {
        totalMonetaryGrant += double.tryParse(b['amount'].toString()) ?? 0.0;
      }
    }
  }

  if (totalMonetaryGrant > 0) {
    return _formatCurrency(totalMonetaryGrant);
  }

  if (coversTuition) {
    if (tuitionType == 'fixed_cap' && tuitionMax != null && tuitionMax > 0) {
      return _formatCurrency(tuitionMax);
    }
    return 'Full Tuition Covered';
  }

  return 'Grant Assistance';
}
