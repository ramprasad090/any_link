import 'package:any_link/any_link.dart';

/// Routes JSON-RPC calls through multiple RPC endpoints with failover and
/// latency-based routing.
///
/// ```dart
/// final gateway = DecentralizedGateway(
///   rpcEndpoints: [
///     'https://mainnet.infura.io/v3/KEY1',
///     'https://eth-mainnet.alchemyapi.io/v2/KEY2',
///     'https://rpc.ankr.com/eth',
///   ],
/// );
///
/// final rpc = JsonRpcClient(client: gateway.client, endpoint: gateway.bestEndpoint);
/// ```
class DecentralizedGateway {
  final List<String> rpcEndpoints;
  late final AnyLinkClient client;

  String? _bestEndpoint;
  final Map<String, double> _latencies = {};

  DecentralizedGateway({required this.rpcEndpoints}) {
    client = AnyLinkClient(
      config: AnyLinkConfig(baseUrl: rpcEndpoints.first),
    );
    _measureLatencies();
  }

  /// The endpoint with the lowest measured latency.
  String get bestEndpoint => _bestEndpoint ?? rpcEndpoints.first;

  Future<void> _measureLatencies() async {
    for (final endpoint in rpcEndpoints) {
      try {
        final sw = Stopwatch()..start();
        await client.post(
          endpoint,
          body: {'jsonrpc': '2.0', 'method': 'eth_blockNumber', 'params': [], 'id': 1},
        );
        sw.stop();
        _latencies[endpoint] = sw.elapsedMilliseconds.toDouble();
      } catch (_) {
        _latencies[endpoint] = double.infinity;
      }
    }

    _bestEndpoint = _latencies.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  /// Make a JSON-RPC call, auto-failing over to the next endpoint on error.
  Future<Map<String, dynamic>> callWithFailover(
    String method,
    List<dynamic> params,
  ) async {
    for (final endpoint in _sortedByLatency()) {
      try {
        final response = await client.post(endpoint, body: {
          'jsonrpc': '2.0',
          'method': method,
          'params': params,
          'id': 1,
        });
        return response.jsonMap;
      } catch (_) {
        continue;
      }
    }
    throw AnyLinkError(message: 'All RPC endpoints failed');
  }

  List<String> _sortedByLatency() {
    final sorted = List<String>.from(rpcEndpoints);
    sorted.sort((a, b) => (_latencies[a] ?? 999999).compareTo(_latencies[b] ?? 999999));
    return sorted;
  }

  void close() => client.close();
}
