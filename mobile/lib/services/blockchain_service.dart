import 'package:http/http.dart' as http;
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

class BlockchainService {
  static const String rpcUrl = 'https://polygon-amoy.g.alchemy.com/v2/alch_LdmO-wF5wwCTE5pMgXUAg';
  static const String contractAddressHex = '0x24919E55678bA8bB67891A7FbA2067aA001557Bb';

  static const String _abiJson = '''
  [
    {
      "inputs": [{"name":"index","type":"uint256"}],
      "name": "getRelease",
      "outputs": [{"components":[
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

  void dispose() {
    _client.dispose();
  }
}
