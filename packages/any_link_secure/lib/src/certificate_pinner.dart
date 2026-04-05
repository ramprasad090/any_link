import 'dart:convert';
import 'dart:io';
import 'crypto/sha256.dart';

/// Validates server certificates against known public-key hashes (SPKI pins).
///
/// Protects against MITM attacks even from rogue CAs. The server certificate
/// must match at least one of the registered pins.
///
/// Pins are SHA-256 hashes of the DER-encoded certificate, base64-encoded
/// with the `sha256/` prefix — the same format used by Chrome and Android.
///
/// ```dart
/// final pinner = CertificatePinner(pins: {
///   'api.example.com': ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
/// });
///
/// final client = HttpClient()
///   ..badCertificateCallback = pinner.badCertificateCallback;
/// ```
class CertificatePinner {
  /// Mapping from hostname to list of allowed SHA-256 SPKI pin strings.
  final Map<String, List<String>> pins;

  const CertificatePinner({required this.pins});

  /// Returns `false` (reject) if the certificate does NOT match any pin for
  /// the given [host]. Pass as [HttpClient.badCertificateCallback].
  bool badCertificateCallback(X509Certificate cert, String host, int port) {
    final allowedPins = pins[host];
    if (allowedPins == null) return true; // No pin registered — accept.

    final digest = Sha256.hash(cert.der);
    final b64Pin = 'sha256/${base64.encode(digest)}';

    return allowedPins.contains(b64Pin);
  }
}
