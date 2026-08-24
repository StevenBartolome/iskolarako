import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/blockchain_service.dart';

class BlockchainVerifiedBadge extends StatefulWidget {
  final String txHash;
  final bool compact;
  final double dbAmount;
  final String dbScholarId;
  final String dbScholarName;

  const BlockchainVerifiedBadge({
    super.key,
    required this.txHash,
    this.compact = false,
    required this.dbAmount,
    required this.dbScholarId,
    required this.dbScholarName,
  });

  @override
  State<BlockchainVerifiedBadge> createState() => _BlockchainVerifiedBadgeState();
}

class _BlockchainVerifiedBadgeState extends State<BlockchainVerifiedBadge> {
  bool _isValidating = false;
  bool _isTampered = false;
  double? _onChainAmount;
  String? _onChainScholarId;

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  @override
  void didUpdateWidget(covariant BlockchainVerifiedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.txHash != widget.txHash ||
        oldWidget.dbAmount != widget.dbAmount ||
        oldWidget.dbScholarId != widget.dbScholarId ||
        oldWidget.dbScholarName != widget.dbScholarName) {
      _runAudit();
    }
  }

  Future<void> _runAudit() async {
    if (widget.txHash.isEmpty || !widget.txHash.startsWith('0x')) return;

    // Defer execution to the next microtask to prevent setState during build phase
    await Future.microtask(() {});

    if (!mounted) return;
    setState(() {
      _isValidating = true;
      _isTampered = false;
    });

    BlockchainService? service;
    try {
      service = BlockchainService();
      final res = await service.verifyDisbursementOnChain(
        txHash: widget.txHash,
        dbAmount: widget.dbAmount,
        dbScholarId: widget.dbScholarId,
        dbScholarName: widget.dbScholarName,
      );

      if (mounted) {
        setState(() {
          _isTampered = res.isTampered;
          _onChainAmount = res.onChainAmount;
          _onChainScholarId = res.onChainScholarId;
        });
      }
    } catch (e) {
      debugPrint('Mobile badge audit failed: $e');
    } finally {
      service?.dispose();
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _openExplorer() async {
    final urlStr = BlockchainService.getExplorerUrl(widget.txHash);
    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Polygonscan: $urlStr')),
        );
      }
    }
  }

  void _showTamperDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(
                'Audit Discrepancy',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A verification discrepancy has been detected for this transaction. The app database values do not align with the cryptographically sealed Polygon blockchain receipt.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50.withAlpha(150),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.4),
                    2: FlexColumnWidth(1.4),
                  },
                  children: [
                    TableRow(
                      children: [
                        _buildCell('Field', isHeader: true),
                        _buildCell('Database', isHeader: true),
                        _buildCell('Blockchain', isHeader: true),
                      ],
                    ),
                    TableRow(
                      children: [
                        _buildCell('Amount'),
                        _buildCell('₱${widget.dbAmount.toStringAsFixed(2)}', isDestructive: true),
                        _buildCell('₱${(_onChainAmount ?? widget.dbAmount).toStringAsFixed(2)}', isGreen: true),
                      ],
                    ),
                    TableRow(
                      children: [
                        _buildCell('Recipient'),
                        _buildCell(widget.dbScholarName, isDestructive: true),
                        _buildCell(_onChainScholarId ?? 'Verified', isGreen: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '*This transaction is under audit review. Please contact IskoAko support immediately.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                Navigator.pop(context);
                _openExplorer();
              },
              child: Text(
                'View Polygon Receipt',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isDestructive = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? Colors.grey.shade800
              : isDestructive
                  ? Colors.red.shade800
                  : isGreen
                      ? Colors.green.shade800
                      : Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the hash is pending or invalid, show a pending badge
    if (widget.txHash.isEmpty || widget.txHash == 'Pending Hash' || !widget.txHash.startsWith('0x')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F5EF),
          border: Border.all(color: const Color(0xFFD9D2C5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, color: Colors.grey.shade600, size: 12),
            const SizedBox(width: 6),
            Text(
              'Pending On-Chain',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // If it's flagged as tampered, show red mismatch alert
    if (_isTampered) {
      if (widget.compact) {
        return InkWell(
          onTap: _showTamperDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Audit Discrepancy',
                  style: GoogleFonts.inter(
                    color: Colors.red.shade900,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.open_in_new, color: Colors.red, size: 10),
              ],
            ),
          ),
        );
      }

      return InkWell(
        onTap: _showTamperDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Audit Discrepancy Detected',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tap to view ledger audit details',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, color: Colors.red, size: 14),
            ],
          ),
        ),
      );
    }

    // Normal verified states
    if (widget.compact) {
      return InkWell(
        onTap: _openExplorer,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9), // Light Green
            border: Border.all(color: const Color(0xFF81C784)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 12),
              const SizedBox(width: 4),
              Text(
                _isValidating ? 'Auditing...' : 'Blockchain Verified',
                style: GoogleFonts.inter(
                  color: const Color(0xFF2E7D32),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.open_in_new, color: Color(0xFF2E7D32), size: 10),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: _openExplorer,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          border: Border.all(color: const Color(0xFF66BB6A)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF2E7D32), size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isValidating ? 'Validating Blockchain Proof...' : 'Verified on Polygon Blockchain',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1B5E20),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'TX: ${_truncateHash(widget.txHash)}',
                  style: GoogleFonts.dmMono(
                    color: Colors.green.shade800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, color: Color(0xFF2E7D32), size: 14),
          ],
        ),
      ),
    );
  }

  String _truncateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }
}
