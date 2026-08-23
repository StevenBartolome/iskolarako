import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/services/blockchain_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FundTrackingScreen extends StatefulWidget {
  const FundTrackingScreen({super.key});

  @override
  State<FundTrackingScreen> createState() => _FundTrackingScreenState();
}

class _FundTrackingScreenState extends State<FundTrackingScreen> {
  int? _expandedIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _releasesData = [];

  @override
  void initState() {
    super.initState();
    _fetchFundReleases();
  }

  Future<void> _fetchFundReleases() async {
    setState(() => _isLoading = true);
    try {
      // PostgREST query to join scholar, scholarship_programs and provider
      final response = await Supabase.instance.client
          .from('fund_releases')
          .select('''
            *,
            scholar:scholar_id(first_name, last_name, school),
            scholarship_programs:program_id(title, provider:provider_id(name))
          ''')
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
    for (final item in _releasesData) {
      final amt = item['amount'];
      if (amt != null) {
        total += (amt is num) ? amt.toDouble() : (double.tryParse(amt.toString()) ?? 0.0);
      }
    }
    return total;
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
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                            'DISBURSED FUNDS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDeep,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      if (Navigator.canPop(context))
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
                    'Disbursed\nfunds.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Blockchain-logged transfers & PayMongo receipts',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchFundReleases,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildHeroAmountCard(),
                          const SizedBox(height: 16),
                          if (_releasesData.isNotEmpty) ...[
                            _buildTransactionDetails(),
                            const SizedBox(height: 16),
                            _buildBlockchainRecord(context),
                            const SizedBox(height: 20),
                            _buildLedger(),
                            const SizedBox(height: 16),
                            _buildScholarsDisbursements(),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.inbox, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No Fund Disbursements Yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When providers release scholarship funds, the transaction details and immutable blockchain records will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stamp ring
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withAlpha(50), width: 2.5),
            ),
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(18),
                ),
                child: const Icon(LucideIcons.wallet,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Total Amount Disbursed',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(160),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatAmount(_totalDisbursedAmount),
              style: GoogleFonts.dmMono(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w500,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Stipends & Grants Released',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          // FittedBox prevents 22px right overflow bug
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _HeroBadge(
                  icon: LucideIcons.checkCircle2,
                  label: 'PayMongo Transfer',
                ),
                const SizedBox(width: 8),
                const _HeroBadge(
                  icon: LucideIcons.shieldCheck,
                  label: 'Blockchain Logged',
                  isGold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails() {
    final latest = _releasesData.firstWhere(
      (r) => r['blockchain_tx_hash'] != null && r['blockchain_tx_hash'].toString().isNotEmpty,
      orElse: () => _releasesData.first,
    );

    final providerName = _getProviderName(latest);
    final scholarName = _getScholarName(latest);
    final amountStr = _formatAmount(latest['amount']);
    final dateStr = _formatDate(latest['created_at']);
    final paymongoId = latest['paymongo_payment_id']?.toString() ?? 'Pending';
    final paymongoStatus = latest['paymongo_status']?.toString() ?? 'processed';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Transfer Details',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          _TxRow(label: 'From', value: providerName),
          _TxRow(label: 'To', value: scholarName),
          _TxRow(
              label: 'Amount',
              value: amountStr,
              valueColor: AppColors.primary,
              isMono: true),
          _TxRow(label: 'Date & Time', value: dateStr),
          _TxRow(
              label: 'Payment via', value: 'PayMongo · $paymongoStatus'),
          _TxRow(
              label: 'Reference No.',
              value: paymongoId,
              isMono: true),
        ],
      ),
    );
  }

  Widget _buildBlockchainRecord(BuildContext context) {
    final latest = _releasesData.firstWhere(
      (r) => r['blockchain_tx_hash'] != null && r['blockchain_tx_hash'].toString().isNotEmpty,
      orElse: () => _releasesData.first,
    );
    final txHash = latest['blockchain_tx_hash']?.toString() ?? 'Pending Hash';
    final blockNo = latest['blockchain_block_number']?.toString() ?? 'Pending';
    final isVerified = latest['blockchain_verified'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'POLYGON BLOCKCHAIN RECORD',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.gold.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.gold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'VERIFIED' : 'PENDING',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'TRANSACTION HASH (POLYGON AMOY)',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(90),
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              if (txHash.startsWith('0x')) {
                final url = Uri.parse(BlockchainService.getExplorerUrl(txHash));
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: txHash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transaction hash copied to clipboard'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      txHash,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmMono(
                        color: Colors.white.withAlpha(220),
                        fontSize: 10,
                        letterSpacing: 0.3,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.externalLink, color: AppColors.gold, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BLOCK NO.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(90),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#$blockNo',
                      style: GoogleFonts.dmMono(
                          color: Colors.white.withAlpha(200), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NETWORK',
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(90),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Polygon Amoy Testnet',
                      style: GoogleFonts.dmMono(
                          color: Colors.white.withAlpha(200), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withAlpha(20),
          ),
          const SizedBox(height: 12),
          Text(
            'This record is permanently logged on Polygon blockchain and cannot be altered. '
            'Tap hash to view live block explorer proof.',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(80),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedger() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Transaction Ledger'),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _releasesData.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.rule),
            itemBuilder: (_, i) {
              final release = _releasesData[i];
              final title = _getScholarshipTitle(release);
              final date = _formatDate(release['created_at']);
              final amount = _formatAmount(release['amount']);
              return _LedgerTile(
                title: title,
                date: date,
                amount: '+$amount',
                isRecent: i == 0,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScholarsDisbursements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const SectionHeading(title: 'Disbursements by Provider'),
        const SizedBox(height: 12),
        ...List.generate(_releasesData.length, (index) {
          final isExpanded = _expandedIndex == index;
          final rel = _releasesData[index];

          final providerName = _getProviderName(rel);
          final scholarshipName = _getScholarshipTitle(rel);
          final amountStr = _formatAmount(rel['amount']);
          final dateStr = _formatDate(rel['created_at']);
          final txHash = rel['blockchain_tx_hash']?.toString() ?? 'Pending Hash';
          final fundType = rel['fund_type']?.toString().toUpperCase() ?? 'STIPEND';

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.primary.withAlpha(20)
                                : AppColors.primary.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.graduationCap,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scholarshipName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                children: [
                                  Text(
                                    amountStr,
                                    style: GoogleFonts.dmMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? LucideIcons.chevronUp
                                        : LucideIcons.chevronDown,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            StatusChip(
                              label: rel['status'] == 'failed'
                                  ? 'Failed / Bounced'
                                  : rel['status'] == 'refunded'
                                  ? 'Refunded'
                                  : 'Released',
                              type: rel['status'] == 'failed'
                                  ? StatusType.rejected
                                  : rel['status'] == 'refunded'
                                  ? StatusType.pending
                                  : StatusType.released,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 16, thickness: 0.8),
                        if (rel['status'] == 'failed') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withAlpha(76)),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Bank Transfer Bounced: ${rel['failure_reason'] ?? 'Invalid bank account details.'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'FUNDS BREAKDOWN',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$fundType Grant Support',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                amountStr,
                                style: GoogleFonts.dmMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: AppColors.rule),
                        const SizedBox(height: 10),
                        Text(
                          'TAMPER-PROOF TRANSACTION HASH',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            if (txHash.startsWith('0x')) {
                              final url = Uri.parse(BlockchainService.getExplorerUrl(txHash));
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: txHash));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction hash copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.rule),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.shieldCheck,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    txHash,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmMono(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.externalLink,
                                    size: 12, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
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
        }),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isGold;

  const _HeroBadge({
    required this.icon,
    required this.label,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: isGold ? AppColors.gold : Colors.white.withAlpha(200)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isGold ? AppColors.gold : Colors.white.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMono;

  const _TxRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: isMono
                  ? GoogleFonts.dmMono(
                      fontSize: 11,
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    )
                  : GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final bool isRecent;

  const _LedgerTile({
    required this.title,
    required this.date,
    required this.amount,
    required this.isRecent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRecent
                  ? AppColors.successBg
                  : AppColors.releasedBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.wallet,
              size: 18,
              color: isRecent ? AppColors.primary : AppColors.released,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(date,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                const VerifiedBadge(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
