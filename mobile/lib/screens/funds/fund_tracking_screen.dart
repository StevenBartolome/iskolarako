import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';

class _ProviderDisbursement {
  final String providerName;
  final String scholarshipName;
  final String amount;
  final String date;
  final IconData icon;
  final String txHash;
  final List<_DisbursementBreakdownItem> breakdown;

  const _ProviderDisbursement({
    required this.providerName,
    required this.scholarshipName,
    required this.amount,
    required this.date,
    required this.icon,
    required this.txHash,
    required this.breakdown,
  });
}

class _DisbursementBreakdownItem {
  final String label;
  final String value;

  const _DisbursementBreakdownItem({required this.label, required this.value});
}

class FundTrackingScreen extends StatefulWidget {
  const FundTrackingScreen({super.key});

  @override
  State<FundTrackingScreen> createState() => _FundTrackingScreenState();
}

class _FundTrackingScreenState extends State<FundTrackingScreen> {
  int? _expandedIndex = 0; // First item expanded by default

  // Aligned Provider Disbursements List
  final List<_ProviderDisbursement> _providerDisbursements = [
    _ProviderDisbursement(
      providerName: 'CHED',
      scholarshipName: 'Undergraduate Stipend (Q3)',
      amount: '₱ 40,000.00',
      date: 'Oct 15, 2026 · 10:22 AM',
      icon: LucideIcons.graduationCap,
      txHash: '0x8fB3c19A2d4eF57b9aC0d2e314aa19bC3f7e9a12',
      breakdown: [
        _DisbursementBreakdownItem(label: 'Tuition Support', value: '₱ 20,000.00'),
        _DisbursementBreakdownItem(label: 'Monthly Stipend (x2)', value: '₱ 16,000.00'),
        _DisbursementBreakdownItem(label: 'Book Allowance', value: '₱ 4,000.00'),
      ],
    ),
    _ProviderDisbursement(
      providerName: 'SM Foundation',
      scholarshipName: 'SM Scholarship Allowance',
      amount: '₱ 15,000.00',
      date: 'Jul 15, 2026 · 2:30 PM',
      icon: LucideIcons.landmark,
      txHash: '0x7aC2c19B1c4eE57a9bA0d1e314bb19aB3f6c8a24',
      breakdown: [
        _DisbursementBreakdownItem(label: 'Monthly Living Allowance', value: '₱ 15,000.00'),
      ],
    ),
    _ProviderDisbursement(
      providerName: 'DOST-SEI',
      scholarshipName: 'DOST Book Allowance',
      amount: '₱ 10,000.00',
      date: 'Jun 01, 2026 · 9:00 AM',
      icon: LucideIcons.building,
      txHash: '0x9eD4c19C3d4fF57b9cB0d3e414cc19cC3f8d9a35',
      breakdown: [
        _DisbursementBreakdownItem(label: 'Semester Book stipend', value: '₱ 10,000.00'),
      ],
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildHeroAmountCard(),
                  const SizedBox(height: 16),
                  _buildTransactionDetails(),
                  const SizedBox(height: 16),
                  _buildBlockchainRecord(context),
                  const SizedBox(height: 20),
                  _buildLedger(),
                  _buildScholarsDisbursements(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withAlpha(50), width: 2.5),
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(18),
                ),
                child: const Icon(LucideIcons.wallet,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          Text(
            '₱ 65,000.00',
            style: GoogleFonts.dmMono(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w500,
              letterSpacing: -1,
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
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeroBadge(
                icon: LucideIcons.checkCircle2,
                label: 'PayMongo Transfer',
              ),
              const SizedBox(width: 8),
              _HeroBadge(
                icon: LucideIcons.shieldCheck,
                label: 'Blockchain Logged',
                isGold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails() {
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
          _TxRow(label: 'From', value: 'CHED — Scholarship Fund'),
          _TxRow(
              label: 'To', value: 'Juan dela Cruz · BPI ×4821'),
          _TxRow(
              label: 'Amount',
              value: '₱ 40,000.00',
              valueColor: AppColors.primary,
              isMono: true),
          _TxRow(label: 'Date & Time', value: 'Oct 15, 2026 · 10:22 AM'),
          _TxRow(
              label: 'Payment via', value: 'PayMongo · Instant Transfer'),
          _TxRow(
              label: 'Reference No.',
              value: 'PM-20261015-84729',
              isMono: true),
        ],
      ),
    );
  }

  Widget _buildBlockchainRecord(BuildContext context) {
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
              Row(
                children: [
                  const Icon(LucideIcons.shieldCheck,
                      size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'LATEST BLOCKCHAIN RECORD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
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
                      'VERIFIED',
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
            'TRANSACTION HASH',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(90),
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(const ClipboardData(
                  text: '0x8fB3c19A2d4eF57b9aC0d2e314aa19bC3f7e9a12'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transaction hash copied to clipboard'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: Text(
              '0x8fB3c19A2d4eF57b9aC0d2e314aa19bC3f7e9a12',
              style: GoogleFonts.dmMono(
                color: Colors.white.withAlpha(170),
                fontSize: 11,
                letterSpacing: 0.5,
                height: 1.4,
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
                      '#18,472,931',
                      style: GoogleFonts.dmMono(
                          color: Colors.white.withAlpha(200), fontSize: 13),
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
                      'IskolarChain PH',
                      style: GoogleFonts.dmMono(
                          color: Colors.white.withAlpha(200), fontSize: 13),
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
            'This record is permanently logged on-chain and cannot be altered. '
            'Long-press the hash to copy. This serves as your tamper-proof receipt.',
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
            itemCount: 3,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.rule),
            itemBuilder: (_, i) {
              final isRecent = i == 0;
              return _LedgerTile(
                title: _ledgerTitles[i],
                date: _ledgerDates[i],
                amount: _ledgerAmounts[i],
                isRecent: isRecent,
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
        ...List.generate(_providerDisbursements.length, (index) {
          final item = _providerDisbursements[index];
          final isExpanded = _expandedIndex == index;

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
                          child: Center(
                            child: Icon(
                              item.icon,
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
                                item.providerName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.scholarshipName,
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
                                item.date,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.amount,
                                  style: GoogleFonts.dmMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
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
                            const SizedBox(height: 4),
                            StatusChip(
                              label: 'Released',
                              type: StatusType.released,
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
                        const SizedBox(height: 8),
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
                        ...item.breakdown.map((b) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    b.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    b.value,
                                    style: GoogleFonts.dmMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
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
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: item.txHash));
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
                                    item.txHash,
                                    style: GoogleFonts.dmMono(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const Icon(LucideIcons.copy,
                                    size: 12, color: AppColors.textMuted),
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

// ─── Support widgets ─────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 13,
              color: isGold ? AppColors.gold : Colors.white.withAlpha(200)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color:
                  isGold ? AppColors.gold : Colors.white.withAlpha(200),
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
      padding: const EdgeInsets.symmetric(vertical: 9),
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
          Text(
            value,
            style: isMono
                ? GoogleFonts.dmMono(
                    fontSize: 12,
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  )
                : GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isRecent
                  ? AppColors.successBg
                  : AppColors.releasedBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.wallet,
              size: 20,
              color:
                  isRecent ? AppColors.primary : AppColors.released,
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
                      fontSize: 13,
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
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

const _ledgerTitles = [
  'CHED Merit Stipend',
  'SM Foundation Stipend',
  'DOST Book Allowance',
];
const _ledgerDates = ['Oct 15, 2026', 'Jul 15, 2026', 'Jun 01, 2026'];
const _ledgerAmounts = ['+₱40,000', '+₱15,000', '+₱10,000'];
