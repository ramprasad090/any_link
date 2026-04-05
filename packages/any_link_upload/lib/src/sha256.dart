import 'dart:typed_data';

/// Pure-Dart SHA-256 implementation — no third-party dependencies.
///
/// Implements FIPS 180-4. Used internally by [CertificatePinner],
/// [RequestSigner], and [PayloadEncryptor].
class Sha256 {
  // SHA-256 round constants.
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  // Initial hash values.
  static const List<int> _h0 = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];

  /// Compute SHA-256 digest of [data]. Returns 32-byte digest.
  static Uint8List hash(List<int> data) {
    // Pre-processing: padding.
    final msg = _pad(data);
    final words = Uint32List(msg.length ~/ 4);
    for (var i = 0; i < words.length; i++) {
      words[i] = (msg[i * 4] << 24) |
          (msg[i * 4 + 1] << 16) |
          (msg[i * 4 + 2] << 8) |
          msg[i * 4 + 3];
    }

    var h = List<int>.from(_h0);

    // Process each 512-bit (16-word) chunk.
    for (var chunk = 0; chunk < words.length; chunk += 16) {
      final w = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = words[chunk + i];
      }
      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ _shr(w[i - 15], 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ _shr(w[i - 2], 10);
        w[i] = _add(w[i - 16], s0, w[i - 7], s1);
      }

      var a = h[0], b = h[1], c = h[2], d = h[3];
      var e = h[4], f = h[5], g = h[6], hh = h[7];

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = _add(hh, s1, ch, _k[i], w[i]);
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = _add(s0, maj);

        hh = g; g = f; f = e;
        e = _add(d, temp1);
        d = c; c = b; b = a;
        a = _add(temp1, temp2);
      }

      h[0] = _add(h[0], a);
      h[1] = _add(h[1], b);
      h[2] = _add(h[2], c);
      h[3] = _add(h[3], d);
      h[4] = _add(h[4], e);
      h[5] = _add(h[5], f);
      h[6] = _add(h[6], g);
      h[7] = _add(h[7], hh);
    }

    // Produce digest.
    final digest = Uint8List(32);
    for (var i = 0; i < 8; i++) {
      digest[i * 4] = (h[i] >> 24) & 0xff;
      digest[i * 4 + 1] = (h[i] >> 16) & 0xff;
      digest[i * 4 + 2] = (h[i] >> 8) & 0xff;
      digest[i * 4 + 3] = h[i] & 0xff;
    }
    return digest;
  }

  /// Compute HMAC-SHA256. Returns 32-byte MAC.
  static Uint8List hmac(List<int> key, List<int> message) {
    const blockSize = 64;
    var k = key.length > blockSize ? hash(key) : List<int>.from(key);
    if (k.length < blockSize) k = [...k, ...List.filled(blockSize - k.length, 0)];

    final ipad = List<int>.generate(blockSize, (i) => k[i] ^ 0x36);
    final opad = List<int>.generate(blockSize, (i) => k[i] ^ 0x5c);

    final inner = hash([...ipad, ...message]);
    return hash([...opad, ...inner]);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  static List<int> _pad(List<int> data) {
    final bitLen = data.length * 8;
    final padded = List<int>.from(data)..add(0x80);
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    // Append original length as 64-bit big-endian.
    for (var i = 7; i >= 0; i--) {
      padded.add((bitLen >> (i * 8)) & 0xff);
    }
    return padded;
  }

  static int _rotr(int x, int n) =>
      (((x & 0xFFFFFFFF) >>> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static int _shr(int x, int n) => (x & 0xFFFFFFFF) >>> n;

  static int _add(int a, [int b = 0, int c = 0, int d = 0, int e = 0]) =>
      (a + b + c + d + e) & 0xFFFFFFFF;
}
