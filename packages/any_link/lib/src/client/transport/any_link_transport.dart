import '../../models/request.dart';
import '../../models/response.dart';

/// Abstract HTTP transport. Implemented by [IoTransport] (native) and
/// [WebTransport] (Flutter Web). Selected at compile time via conditional import.
abstract class AnyLinkTransport {
  Future<AnyLinkResponse> send(AnyLinkRequest request, Uri uri);
  void close({bool force = false});
}
