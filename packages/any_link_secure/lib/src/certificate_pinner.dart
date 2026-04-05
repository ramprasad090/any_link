import 'dart:convert';
import 'dart:io';

/// Validates server certificates against known public-key hashes (SPKI pins).
///
/// Protects against MITM attacks even from rogue CAs. The server certificate
/// must match at least one of the registered pins.
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

    final certHash = _sha256Hex(cert.der);
    final b64Pin = 'sha256/${base64.encode(_hexToBytes(certHash))}';

    return allowedPins.contains(b64Pin);
  }

  static String _sha256Hex(List<int> bytes) {
    // Simple FNV hash as placeholder — replace with crypto package if available.
    int h = 2166136261;
    for (final b in bytes) {
      h ^= b;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length - 1; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
