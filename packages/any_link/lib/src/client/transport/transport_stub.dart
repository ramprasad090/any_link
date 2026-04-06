import '../../models/request.dart';
import '../../models/response.dart';
import '../../models/config.dart';

/// Stub transport — never instantiated; satisfies the analyzer on unknown platforms.
AnyLinkTransport createTransport(AnyLinkConfig config) =>
    throw UnsupportedError('Unsupported platform');

abstract class AnyLinkTransport {
  Future<AnyLinkResponse> send(AnyLinkRequest request, Uri uri);
  void close({bool force = false});
}
  