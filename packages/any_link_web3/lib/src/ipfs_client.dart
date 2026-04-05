import 'dart:io';
import 'package:any_link/any_link.dart';

/// IPFS client for uploading and fetching content via HTTP gateways.
///
/// Supports Pinata, Infura, and any IPFS HTTP API.
///
/// ```dart
/// final ipfs = IpfsClient(
///   client: anyLinkClient,
///   gatewayUrl: 'https://api.pinata.cloud/pinning',
///   apiKey: 'your_pinata_key',
/// );
///
/// final cid = await ipfs.upload(File('/path/to/file.jpg'));
/// print('IPFS CID: $cid');
/// ```
class IpfsClient {
  final AnyLinkClient client;
  final String gatewayUrl;
  final String? apiKey;
  final String? apiSecret;

  IpfsClient({
    required this.client,
    required this.gatewayUrl,
    this.apiKey,
    this.apiSecret,
  });

  /// Upload a [file] to IPFS and return the CID.
  Future<String> upload(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = AnyLinkFormData();
    form.addFile('file', file.path, fileName: file.path.split('/').last);

    final headers = <String, String>{};
    if (apiKey != null) headers['pinata_api_key'] = apiKey!;
    if (apiSecret != null) headers['pinata_secret_api_key'] = apiSecret!;

    final response = await client.post(
      '$gatewayUrl/pinFileToIPFS',
      body: form,
      headers: headers,
      onSendProgress: onProgress,
    );

    final json = response.jsonMap;
    return json['IpfsHash'] as String? ?? json['cid'] as String? ?? '';
  }

  /// Fetch the bytes at [cid] from the public IPFS gateway.
  Future<List<int>> fetch(String cid) async {
    final response = await client.get('https://ipfs.io/ipfs/$cid');
    return response.bodyBytes;
  }

  /// Pin an existing [cid] by hash (Pinata API).
  Future<void> pin(String cid) async {
    final headers = <String, String>{};
    if (apiKey != null) headers['pinata_api_key'] = apiKey!;
    if (apiSecret != null) headers['pinata_secret_api_key'] = apiSecret!;

    await client.post(
      '$gatewayUrl/pinByHash',
      body: {'hashToPin': cid},
      headers: headers,
    );
  }

  /// Unpin [cid] from Pinata.
  Future<void> unpin(String cid) async {
    final headers = <String, String>{};
    if (apiKey != null) headers['pinata_api_key'] = apiKey!;
    if (apiSecret != null) headers['pinata_secret_api_key'] = apiSecret!;

    await client.delete('$gatewayUrl/unpin/$cid', headers: headers);
  }
}
