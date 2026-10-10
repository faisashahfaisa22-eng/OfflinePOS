import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Offline verification of a server-signed QAMVIO entitlement.
/// Token format: base64url(JSON payload).base64url(Ed25519 signature).
/// The signing private key MUST stay on the server.
class LicenseVerifier {
  LicenseVerifier(this.publicKeyBase64Url);
  final String publicKeyBase64Url;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'qamvio_license_token_v1';
  static const _deviceKey = 'qamvio_license_install_id_v1';
  static const _lastSeenKey = 'qamvio_license_last_seen_v1';

  static Uint8List _decode(String input) =>
      Uint8List.fromList(base64Url.decode(base64Url.normalize(input)));

  Future<String> installationId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final id = base64UrlEncode(bytes).replaceAll('=', '');
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }

  Future<void> saveToken(String token) async {
    if (!await verify(token)) throw const FormatException('Invalid license');
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<bool> hasValidLicense() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && await verify(token);
  }

  Future<bool> verify(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return false;
      final message = utf8.encode(parts[0]);
      final signature = Signature(
        _decode(parts[1]),
        publicKey: SimplePublicKey(
          _decode(publicKeyBase64Url),
          type: KeyPairType.ed25519,
        ),
      );
      if (!await Ed25519().verify(message, signature: signature)) return false;
      final payload = jsonDecode(utf8.decode(_decode(parts[0])));
      if (payload is! Map<String, dynamic>) return false;
      if (payload['typ'] != 'qamvio-license-v1') return false;
      if (payload['device_id'] != await installationId()) return false;
      final expiry = payload['exp'];
      if (expiry is! int) return false;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final last = int.tryParse(await _storage.read(key: _lastSeenKey) ?? '');
      if (last != null && now + 300 < last) return false;
      if (now >= expiry) return false;
      if (last == null || now > last) {
        await _storage.write(key: _lastSeenKey, value: '$now');
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
