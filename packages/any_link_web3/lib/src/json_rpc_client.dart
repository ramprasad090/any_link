import 'package:any_link/any_link.dart';

/// Generic JSON-RPC 2.0 client for Ethereum, Solana, or any blockchain node.
///
/// Built on [AnyLinkClient] — inherits logging, retry, auth.
///
/// ```dart
/// final rpc = JsonRpcClient(
///   client: anyLinkClient,
///   endpoint: 'https://mainnet.infura.io/v3/YOUR_KEY',
/// );
///
/// final balance = await rpc.getBalance('0xYourAddress');
/// print('Balance: $balance wei');
/// ```
class JsonRpcClient {
  final AnyLinkClient client;
  final String endpoint;
  int _id = 1;

  JsonRpcClient({required this.client, required this.endpoint});

  /// Call any JSON-RPC [method] with [params] and decode the result as [T].
  Future<T> call<T>(String method, List<dynamic> params) async {
    final response = await client.post(endpoint, body: {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': _id++,
    });

    final json = response.jsonMap;
    if (json.containsKey('error')) {
      final err = json['error'] as Map<String, dynamic>;
      throw AnyLinkError(
        message: err['message'] as String? ?? 'JSON-RPC error',
        statusCode: err['code'] as int?,
        errorCode: err['code']?.toString(),
      );
    }

    return json['result'] as T;
  }

  /// Get the ETH/native token balance of [address] in wei.
  Future<BigInt> getBalance(String address) async {
    final hex = await call<String>('eth_getBalance', [address, 'latest']);
    return BigInt.parse(hex.substring(2), radix: 16);
  }

  /// Send a signed transaction and return the transaction hash.
  Future<String> sendTransaction(Map<String, dynamic> tx) =>
      call<String>('eth_sendTransaction', [tx]);

  /// Get the receipt of [txHash].
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) =>
      call<Map<String, dynamic>?>('eth_getTransactionReceipt', [txHash]);

  /// Get the current block number.
  Future<int> getBlockNumber() async {
    final hex = await call<String>('eth_blockNumber', []);
    return int.parse(hex.substring(2), radix: 16);
  }
}
