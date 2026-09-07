import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:iskoako/widgets/blockchain_verified_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FundTrackingScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const FundTrackingScreen({super.key, this.onSelectTab});

  @override
  State<FundTrackingScreen> createState() => _FundTrackingScreenState();
}

class _FundTrackingScreenState extends State<FundTrackingScreen> {
  int? _expandedProgramIndex = 0; // First program expanded by default
  String _selectedProgramFilter = 'All'; // 'All' or specific program title
  bool _isLoading = true;
  List<Map<String, dynamic>> _releasesData = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchFundReleases();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('fund-tracking-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fund_releases',
          callback: (payload) {
            if (mounted) _fetchFundReleases(true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholar_payment_accounts',
          callback: (payload) {
            if (mounted) _fetchFundReleases(true);
          },
        );
    _realtimeChannel?.subscribe();
  }

  Future<void> _fetchFundReleases([bool silent = false]) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final List<String> targetScholarIds = [user.id];
    try {
      final scholarRow = await Supabase.instance.client
          .from('scholar')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (scholarRow != null && scholarRow['id'] != null) {
        final sId = scholarRow['id'].toString();
        if (!targetScholarIds.contains(sId)) {
          targetScholarIds.add(sId);
        }
      }
    } catch (sErr) {
      debugPrint('Scholar ID lookup note: $sErr');
    }

    try {
      final response = await Supabase.instance.client
          .from('fund_releases')
          .select('''
            *,
            scholar:scholar_id(first_name, last_name, school),
            scholarship_programs:program_id(title, provider:provider_id(name))
          ''')
          .filter('scholar_id', 'in', targetScholarIds)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _releasesData = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Primary query error, attempting simple select: $e');
      try {
        final simpleResponse = await Supabase.instance.client
            .from('fund_releases')
            .select('*')
            .filter('scholar_id', 'in', targetScholarIds)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _releasesData = List<Map<String, dynamic>>.from(simpleResponse);
            _isLoading = false;
          });
        }
      } catch (err) {
        debugPrint('Error fetching fund releases: $err');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  double get _totalDisbursedAmount {
    double total = 0.0;
    for (final item in _filteredReleases) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      final pmStatus = (item['paymongo_status'] ?? '').toString().toLowerCase();
      final isCompleted = s == 'released' || s == 'completed' || s == 'paid' || pmStatus == 'paid' || item['blockchain_verified'] == true;
      final isFailedOrReturned = s == 'failed' || s == 'returned' || s == 'refunded' || pmStatus == 'failed' || pmStatus == 'refunded';

      if (isCompleted && !isFailedOrReturned) {
        final amt = item['amount'];
        if (amt != null) {
          total += (amt is num) ? amt.toDouble() : (double.tryParse(amt.toString()) ?? 0.0);
        }
      }
    }
    return total;
  }


  List<Map<String, dynamic>> get _filteredReleases {
    if (_selectedProgramFilter == 'All') {
      return _releasesData;
    }
    return _releasesData.where((r) => _getScholarshipTitle(r) == _selectedProgramFilter).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByProgram {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final rel in _filteredReleases) {
      final progTitle = _getScholarshipTitle(rel);
      if (!groups.containsKey(progTitle)) {
        groups[progTitle] = [];
      }
      groups[progTitle]!.add(rel);
    }
    return groups;
  }

  List<String> get _allProgramTitles {
    final Set<String> titles = {};
    for (final r in _releasesData) {
      titles.add(_getScholarshipTitle(r));
    }
    return titles.toList();
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '₱ 0.00';
    final double val = (amount is num) ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0.0);
    final String formatted = val.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱ $formatted';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $ampm';
    } catch (_) {
      return dateStr.toString();
    }
  }

  String _getProviderName(Map<String, dynamic> item) {
    final providerName = item['scholarship_programs']?['provider']?['name'] ??
        item['program']?['provider']?['name'];
    if (providerName != null && providerName.toString().isNotEmpty) {
      return providerName.toString();
    }
    return 'Scholarship Provider';
  }

  String _getScholarshipTitle(Map<String, dynamic> item) {
    final title = item['scholarship_programs']?['title'] ?? item['program']?['title'];
    if (title != null && title.toString().isNotEmpty) {
      return title.toString();
    }
    return 'Scholarship Grant';
  }

  String _getScholarName(Map<String, dynamic> item) {
    if (item['scholar'] != null && item['scholar'] is Map) {
      final first = item['scholar']['first_name'] ?? '';
      final last = item['scholar']['last_name'] ?? '';
      final fullName = '$first $last'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    return 'Scholar Recipient';
  }

  @override
  Widget build(BuildContext context) {
    final programGroups = _groupedByProgram;
    final programNames = programGroups.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3D2F)),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchFundReleases,
                    color: const Color(0xFF1E3D2F),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeroAmountCard(),
                          const SizedBox(height: 16),

                          if (_allProgramTitles.length > 1) ...[
                            _buildProgramFilterChips(),
                            const SizedBox(height: 16),
                          ],

                          if (_releasesData.isNotEmpty) ...[
                            // Header Title for Program Cards
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PROGRAM DISBURSEMENTS',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E3D2F),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${programNames.length} Program${programNames.length > 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Per-Program Cards
                            ...List.generate(programNames.length, (progIdx) {
                              final programTitle = programNames[progIdx];
                              final releasesList = programGroups[programTitle] ?? [];
                              final isExpanded = _expandedProgramIndex == progIdx;

                              return _buildProgramReleaseCard(
                                programIndex: progIdx,
                                programTitle: programTitle,
                                releases: releasesList,
                                isExpanded: isExpanded,
                              );
                            }),

                            const SizedBox(height: 16),
                            _buildBlockchainVerificationSection(),
                          ] else
                            _buildEmptyState(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                        'DISBURSED FUNDS',
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
                    'Disbursed\nfunds.',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Blockchain-logged transfers & PayMongo receipts',
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

  // ─── 2. Hero Card ──────────────────────────────────────────────────────────
  Widget _buildHeroAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(LucideIcons.wallet, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TOTAL AMOUNT DISBURSED',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatAmount(_totalDisbursedAmount),
              style: GoogleFonts.dmMono(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Stipends & Grants Released',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF4ADE80)),
                      const SizedBox(width: 5),
                      Text(
                        'PayMongo Direct Route',
                        style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 5),
                      Text(
                        'Blockchain Immutable',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Filter Chips ────────────────────────────────────────────────────────
  Widget _buildProgramFilterChips() {
    final filters = ['All', ..._allProgramTitles];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = _selectedProgramFilter == filters[i];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProgramFilter = filters[i];
                _expandedProgramIndex = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── 4. Per-Program Release Card ───────────────────────────────────────────
  Widget _buildProgramReleaseCard({
    required int programIndex,
    required String programTitle,
    required List<Map<String, dynamic>> releases,
    required bool isExpanded,
  }) {
    double programTotal = 0.0;
    for (final r in releases) {
      final amt = r['amount'];
      if (amt != null) {
        programTotal += (amt is num) ? amt.toDouble() : (double.tryParse(amt.toString()) ?? 0.0);
      }
    }

    final firstRelease = releases.first;
    final providerName = _getProviderName(firstRelease);
    String providerShort = providerName.split(' ').first;
    if (providerShort.length > 10) providerShort = providerShort.substring(0, 10);
    if (providerShort.isEmpty) providerShort = 'DOST';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
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
        children: [
          // Program Header Tap Target
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedProgramIndex = isExpanded ? null : programIndex;
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
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatAmount(programTotal),
                              style: GoogleFonts.dmMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF15803D),
                              ),
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
                    programTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$providerName · ${releases.length} Disbursement Release${releases.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Smooth Collapsible Content (Prevents character text squeezing)
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRANSACTION HISTORY (${releases.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E3D2F),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: releases.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, rIdx) {
                                  final rel = releases[rIdx];
                                  final amountStr = _formatAmount(rel['amount']);
                                  final dateStr = _formatDate(rel['created_at']);
                                  final fundType = (rel['fund_type'] ?? 'STIPEND').toString().toUpperCase();
                                  final status = (rel['status'] ?? 'released').toString().toLowerCase();
                                  final paymongoId = rel['paymongo_payment_id']?.toString() ?? 'PayMongo Verified';
                                  final txHash = rel['blockchain_tx_hash']?.toString() ?? 'Pending Hash';

                                  final isFailed = status == 'failed';
                                  final isRefunded = status == 'refunded' || status == 'returned';


                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isFailed ? const Color(0xFFFDF2F2) : const Color(0xFFFAFCFA),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isFailed ? const Color(0xFFFEE2E2) : const Color(0xFFE5E7EB),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: isFailed
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFDCFCE7),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isFailed ? LucideIcons.alertTriangle : LucideIcons.wallet,
                                                  size: 16,
                                                  color: isFailed ? const Color(0xFFB91C1C) : const Color(0xFF16A34A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$fundType Release',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF111827),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    dateStr,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      color: const Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  amountStr,
                                                  style: GoogleFonts.dmMono(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isFailed ? const Color(0xFFB91C1C) : const Color(0xFF1E3D2F),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isFailed
                                                        ? const Color(0xFFFEE2E2)
                                                        : (isRefunded ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isFailed ? 'Failed' : (isRefunded ? 'Refunded' : 'Released'),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isFailed
                                                          ? const Color(0xFFB91C1C)
                                                          : (isRefunded ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Ref: $paymongoId',
                                          style: GoogleFonts.dmMono(
                                            fontSize: 9.5,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        BlockchainVerifiedBadge(
                                          txHash: txHash,
                                          compact: true,
                                          dbAmount: double.tryParse(rel['amount']?.toString() ?? '0') ?? 0.0,
                                          dbScholarId: rel['scholar_id']?.toString() ?? '',
                                          dbScholarName: _getScholarName(rel),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
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
  }

  // ─── 5. Blockchain Verification Footer ─────────────────────────────────────
  Widget _buildBlockchainVerificationSection() {
    final latest = _releasesData.firstWhere(
      (r) => r['blockchain_tx_hash'] != null && r['blockchain_tx_hash'].toString().isNotEmpty,
      orElse: () => _releasesData.first,
    );
    final txHash = latest['blockchain_tx_hash']?.toString() ?? 'Pending Hash';
    final double dbAmount = double.tryParse(latest['amount']?.toString() ?? '0') ?? 0.0;
    final String dbScholarId = latest['scholar_id']?.toString() ?? '';
    final String dbScholarName = _getScholarName(latest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATEST BLOCKCHAIN VERIFICATION',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E3D2F),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        BlockchainVerifiedBadge(
          txHash: txHash,
          compact: false,
          dbAmount: dbAmount,
          dbScholarId: dbScholarId,
          dbScholarName: dbScholarName,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
                    LucideIcons.wallet,
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
              'No Fund Disbursements Yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When providers release scholarship funds, the transaction details and immutable blockchain records will appear here per program.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
