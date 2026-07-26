import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';


class FundTrackingScreen extends StatelessWidget {
  const FundTrackingScreen({super.key});

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
            'Amount Disbursed',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(160),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₱ 40,000.00',
            style: GoogleFonts.dmMono(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w500,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CHED Merit Stipend · S.Y. 2026–2027',
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
            'Transfer Details',
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
                    'BLOCKCHAIN RECORD',
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
  'CHED Merit Stipend',
  'DOST-SEI Book Allowance',
];
const _ledgerDates = ['Oct 15, 2026', 'Jul 15, 2026', 'Jun 1, 2026'];
const _ledgerAmounts = ['+₱15,000', '+₱15,000', '+₱10,000'];
