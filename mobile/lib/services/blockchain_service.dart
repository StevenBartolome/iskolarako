import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class FundReleaseRecord {
  final String scholarshipId;
  final String scholarId;
  final double amountPHP;
  final DateTime releasedAt;
  final String paymongoPaymentId;
  final String status;

  FundReleaseRecord({
    required this.scholarshipId,
    required this.scholarId,
    required this.amountPHP,
    required this.releasedAt,
    required this.paymongoPaymentId,
    required this.status,
  });
}

class MobileAuditResult {
  final bool isTampered;
  final double? onChainAmount;
  final String? onChainScholarId;
  final String? error;

  MobileAuditResult({
    required this.isTampered,
    this.onChainAmount,
    this.onChainScholarId,
    this.error,
  });
}

/// Result of verifying a scholar profile's blockchain integrity anchor.
class BlockchainProfileIntegrityResult {
  final bool isAnchored;
  final bool isTampered;
  final String? currentHash;
  final String? onChainHash;
  final String? txHash;
  final String? error;
  final String? tamperReason;

  BlockchainProfileIntegrityResult({
    required this.isAnchored,
    required this.isTampered,
    this.currentHash,
    this.onChainHash,
    this.txHash,
    this.error,
    this.tamperReason,
  });
}

class BlockchainService {
  static const String rpcUrl =
      'https://polygon-amoy.g.alchemy.com/v2/alch_LdmO-wF5wwCTE5pMgXUAg';
  static const String contractAddressHex =
      '0xafbef846a4aCf3efeFB992706bFdBb5dF7500829';

  static final Map<String, Map<String, dynamic>> _auditCache = {};

  static const String _abiJson = '''
  [
    {
      "inputs": [],
      "name": "decodeRecordReleaseHelper",
      "outputs": [
        {"name": "scholarshipId", "type": "string"},
        {"name": "scholarId", "type": "string"},
        {"name": "amountCentavos", "type": "uint256"},
        {"name": "paymongoPaymentId", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"name": "scholarshipId", "type": "string"},
        {"name": "scholarId", "type": "string"},
        {"name": "amountCentavos", "type": "uint256"},
        {"name": "paymongoPaymentId", "type": "string"}
      ],
      "name": "recordRelease",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"name":"index","type":"uint256"}],
      "name": "getRelease",
      "outputs": [{"name":"","components":[
        {"name":"scholarshipId","type":"string"},
        {"name":"scholarId","type":"string"},
        {"name":"amountCentavos","type":"uint256"},
        {"name":"releasedAt","type":"uint256"},
        {"name":"paymongoPaymentId","type":"string"},
        {"name":"status","type":"string"}
      ],"type":"tuple"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getTotalReleases",
      "outputs": [{"name":"","type":"uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "decodeAnchorProfileHelper",
      "outputs": [
        {"name": "scholarId", "type": "string"},
        {"name": "profileHash", "type": "bytes32"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  final Web3Client _client = Web3Client(rpcUrl, http.Client());
  late final DeployedContract _contract;

  BlockchainService() {
    _contract = DeployedContract(
      ContractAbi.fromJson(_abiJson, 'IskoAkoFundLedger'),
      EthereumAddress.fromHex(contractAddressHex),
    );
  }

  /// Read a fund release record by release ID index directly from Polygon blockchain
  Future<FundReleaseRecord> getRelease(int index) async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getRelease'),
      params: [BigInt.from(index)],
    );

    final data = result[0] as List;
    final centavos = (data[2] as BigInt).toInt();
    final timestamp = (data[3] as BigInt).toInt();

    return FundReleaseRecord(
      scholarshipId: data[0] as String,
      scholarId: data[1] as String,
      amountPHP: centavos / 100.0,
      releasedAt: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      paymongoPaymentId: data[4] as String,
      status: data[5] as String,
    );
  }

  /// Get total count of releases on-chain
  Future<int> getTotalReleases() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getTotalReleases'),
      params: [],
    );
    return (result[0] as BigInt).toInt();
  }

  /// Returns explorer URL for a given transaction hash
  static String getExplorerUrl(String txHash) {
    return 'https://amoy.polygonscan.com/tx/$txHash';
  }

  /// Verify a database record against the raw transaction input recorded on the Polygon Amoy blockchain
  Future<MobileAuditResult> verifyDisbursementOnChain({
    required String txHash,
    required double dbAmount,
    required String dbScholarId,
    required String dbScholarName,
  }) async {
    if (txHash.isEmpty || !txHash.startsWith('0x') || txHash.length != 66) {
      return MobileAuditResult(
        isTampered: false,
        error: 'Invalid transaction hash format',
      );
    }

    final cacheKey =
        '${txHash}_${dbAmount.round()}_${dbScholarId.toLowerCase()}_${dbScholarName.toLowerCase()}';
    if (_auditCache.containsKey(cacheKey)) {
      final cached = _auditCache[cacheKey]!;
      return MobileAuditResult(
        isTampered: cached['isTampered'] as bool,
        onChainAmount: cached['onChainAmount'] as double?,
        onChainScholarId: cached['onChainScholarId'] as String?,
        error: cached['error'] as String?,
      );
    }

    try {
      final txInfo = await _client
          .getTransactionByHash(txHash)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('On-chain audit network timeout'),
          );
      if (txInfo == null) {
        throw Exception('Transaction details not found on-chain');
      }

      final inputData = txInfo.input;
      if (inputData.length < 4) {
        throw Exception('Invalid transaction input payload length');
      }

      final decodeHelperFn = _contract.function('decodeRecordReleaseHelper');

      // Skip function selector (first 4 bytes)
      final paramsData = inputData.sublist(4);
      final paramsHex = bytesToHex(paramsData, include0x: true);
      final decoded = decodeHelperFn.decodeReturnValues(paramsHex);

      if (decoded.length < 4) {
        throw Exception('Failed to decode expected recordRelease arguments');
      }

      // Decoded arguments: [scholarshipId, scholarId, amountCentavos, paymongoPaymentId]
      final String onChainScholarId = decoded[1] as String;
      final BigInt onChainAmountCentavos = decoded[2] as BigInt;
      final double onChainAmount = onChainAmountCentavos.toDouble() / 100.0;

      final amountMismatch = dbAmount.round() != onChainAmount.round();
      final scholarMismatch =
          dbScholarId.toLowerCase() != onChainScholarId.toLowerCase() &&
          dbScholarName.toLowerCase() != onChainScholarId.toLowerCase();

      final result = MobileAuditResult(
        isTampered: amountMismatch || scholarMismatch,
        onChainAmount: onChainAmount,
        onChainScholarId: onChainScholarId,
      );

      _auditCache[cacheKey] = {
        'isTampered': result.isTampered,
        'onChainAmount': result.onChainAmount,
        'onChainScholarId': result.onChainScholarId,
      };

      return result;
    } catch (err) {
      debugPrint('Error during blockchain transaction audit check: $err');
      return MobileAuditResult(isTampered: false, error: err.toString());
    }
  }

  // ─── Scholar Profile Blockchain Integrity ────────────────────────────────

  /// Computes the keccak256 profile hash from the scholar's current DB fields.
  /// This must match the canonical format used by the anchor-scholar-profile edge function:
  /// "scholarId|FIRST_NAME|LAST_NAME|MIDDLE_NAME|SUFFIX|BIRTH_DATE|GENDER|FACE_STATUS|VERIFIED_AT"
  static String computeProfileHash(Map<String, dynamic> scholar) {
    final parts = [
      (scholar['id'] ?? '').toString(),
      (scholar['first_name'] ?? '').toString().toUpperCase().trim(),
      (scholar['last_name'] ?? '').toString().toUpperCase().trim(),
      (scholar['middle_name'] ?? '').toString().toUpperCase().trim(),
      (scholar['suffix'] ?? '').toString().toUpperCase().trim(),
      (scholar['birth_date'] ?? '').toString().trim(),
      (scholar['gender'] ?? '').toString().toLowerCase().trim(),
      (scholar['face_verification_status'] ?? '').toString(),
      (scholar['face_verified_at'] ?? '').toString().trim(),
    ];
    final canonicalString = parts.join('|');
    final hash = keccakUtf8(canonicalString);
    return bytesToHex(hash, include0x: true);
  }

  /// Verify a scholar's profile integrity by comparing the on-chain hash
  /// (from the raw blockchain transaction) against the current database fields.
  ///
  /// [scholar] should contain: id, first_name, last_name, middle_name, suffix,
  ///   birth_date, gender, face_verification_status, face_verified_at,
  ///   profile_blockchain_tx_hash, profile_blockchain_hash, profile_blockchain_verified
  Future<BlockchainProfileIntegrityResult> verifyProfileIntegrity({
    required Map<String, dynamic> scholar,
  }) async {
    final storedTxHash =
        scholar['profile_blockchain_tx_hash']?.toString() ?? '';
    final storedHash = scholar['profile_blockchain_hash']?.toString() ?? '';
    final isAnchored = scholar['profile_blockchain_verified'] == true;
    final faceStatus = scholar['face_verification_status']?.toString();

    // Check if marked verified in DB but not anchored on blockchain
    if (faceStatus == 'verified' &&
        (!isAnchored || storedTxHash.isEmpty || storedHash.isEmpty)) {
      return BlockchainProfileIntegrityResult(
        isAnchored: false,
        isTampered: true,
        error:
            'Profile marked verified in database but lacks blockchain anchor.',
        tamperReason:
            'Face status was marked "verified" in database without a blockchain transaction anchor. Direct database alteration detected.',
      );
    }

    if (!isAnchored || storedTxHash.isEmpty || storedHash.isEmpty) {
      return BlockchainProfileIntegrityResult(
        isAnchored: false,
        isTampered: false,
        error: 'Profile has not been anchored on blockchain yet.',
      );
    }

    // Recompute hash from current DB fields
    final currentHash = computeProfileHash(scholar);

    // Quick check: compare stored hash with recomputed hash
    if (currentHash.toLowerCase() != storedHash.toLowerCase()) {
      return BlockchainProfileIntegrityResult(
        isAnchored: true,
        isTampered: true,
        currentHash: currentHash,
        onChainHash: storedHash,
        txHash: storedTxHash,
        tamperReason:
            'Cryptographic hash mismatch: Current profile fields (name, birth date, gender, or status) do not match the on-chain anchor fingerprint.',
      );
    }

    // Optional deep check: verify against actual on-chain transaction data
    if (storedTxHash.startsWith('0x') && storedTxHash.length == 66) {
      try {
        final txInfo = await _client
            .getTransactionByHash(storedTxHash)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw Exception('Blockchain network timeout'),
            );
        if (txInfo != null && txInfo.input.length > 4) {
          final decodeHelperFn = _contract.function(
            'decodeAnchorProfileHelper',
          );
          final paramsData = txInfo.input.sublist(4);
          final paramsHex = bytesToHex(paramsData, include0x: true);
          final decoded = decodeHelperFn.decodeReturnValues(paramsHex);

          if (decoded.length >= 2) {
            // decoded[1] is bytes32 profileHash
            final List<int> onChainHashBytes = decoded[1] as List<int>;
            final onChainHash = bytesToHex(onChainHashBytes, include0x: true);

            if (currentHash.toLowerCase() != onChainHash.toLowerCase()) {
              return BlockchainProfileIntegrityResult(
                isAnchored: true,
                isTampered: true,
                currentHash: currentHash,
                onChainHash: onChainHash,
                txHash: storedTxHash,
                tamperReason:
                    'On-chain transaction hash mismatch: Database profile hash differs from the hash recorded in the Polygon block.',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[BlockchainService] On-chain deep verify error: $e');
        // Fall through to the stored hash comparison result below
      }
    }

    return BlockchainProfileIntegrityResult(
      isAnchored: true,
      isTampered: false,
      currentHash: currentHash,
      onChainHash: storedHash,
      txHash: storedTxHash,
    );
  }

  void dispose() {
    _client.dispose();
  }
}
