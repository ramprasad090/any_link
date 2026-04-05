import 'dart:developer' as dev;
import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Detects API versioning headers and warns about deprecations / sunset dates.
///
/// Logs a warning when the server sets:
/// - `Sunset: <date>` — this API version will be removed
/// - `Deprecation: true` — this endpoint is deprecated
/// - `X-API-Version: <v>` that differs from [currentVersion]
class VersionInterceptor extends AnyLinkInterceptor {
  /// The API version your app targets (e.g. `"v2"`).
  final String currentVersion;

  /// Called when the server-reported version differs from [currentVersion].
  final void Function(String expected, String actual)? onVersionMismatch;

  VersionInterceptor({
    required this.currentVersion,
    this.onVersionMismatch,
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async => request;

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    _checkSunset(response);
    _checkDeprecation(response);
    _checkVersionMismatch(response);
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  void _checkSunset(AnyLinkResponse r) {
    final sunset = r.sunsetDate;
    if (sunset != null) {
      dev.log(
        '⚠️  [any_link] API sunset date: $sunset for ${r.requestMethod} ${r.requestPath}. '
        'Migrate before this date.',
        name: 'any_link.version',
      );
    }
  }

  void _checkDeprecation(AnyLinkResponse r) {
    final dep = r.deprecation;
    if (dep != null && dep.isNotEmpty) {
      dev.log(
        '⚠️  [any_link] Deprecated endpoint: ${r.requestMethod} ${r.requestPath}',
        name: 'any_link.version',
      );
    }
  }

  void _checkVersionMismatch(AnyLinkResponse r) {
    final serverVersion = r.apiVersion;
    if (serverVersion != null && serverVersion != currentVersion) {
      dev.log(
        '⚠️  [any_link] Version mismatch: expected $currentVersion, server returned $serverVersion',
        name: 'any_link.version',
      );
      onVersionMismatch?.call(currentVersion, serverVersion);
    }
  }
}
