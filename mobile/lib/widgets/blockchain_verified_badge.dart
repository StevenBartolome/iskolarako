import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/blockchain_service.dart';

class BlockchainVerifiedBadge extends StatelessWidget {
  final String txHash;
  final bool compact;

  const BlockchainVerifiedBadge({
    super.key,
    required this.txHash,
    this.compact = false,
  });

  Future<void> _openExplorer(BuildContext context) async {
    final urlStr = BlockchainService.getExplorerUrl(txHash);
    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Polygonscan: $urlStr')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: () => _openExplorer(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9), // Light Green
            border: Border.all(color: const Color(0xFF81C784)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Color(0xFF2E7D32), size: 12),
              SizedBox(width: 4),
              Text(
                'Blockchain Verified',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.open_in_new, color: Color(0xFF2E7D32), size: 10),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _openExplorer(context),
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
                const Text(
                  'Verified on Polygon Blockchain',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'TX: ${_truncateHash(txHash)}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 10,
                    fontFamily: 'monospace',
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
