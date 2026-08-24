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

class BlockchainService {
  static const String rpcUrl = 'https://polygon-amoy.g.alchemy.com/v2/alch_LdmO-wF5wwCTE5pMgXUAg';
  static const String contractAddressHex = '0x24919E55678bA8bB67891A7FbA2067aA001557Bb';

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
      return MobileAuditResult(isTampered: false, error: 'Invalid transaction hash format');
    }

    final cacheKey = '${txHash}_${dbAmount.round()}_${dbScholarId.toLowerCase()}_${dbScholarName.toLowerCase()}';
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
      final txInfo = await _client.getTransactionByHash(txHash).timeout(
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
      final scholarMismatch = dbScholarId.toLowerCase() != onChainScholarId.toLowerCase() &&
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
      return MobileAuditResult(
        isTampered: false,
        error: err.toString(),
      );
    }
  }

  void dispose() {
    _client.dispose();
  }
}
