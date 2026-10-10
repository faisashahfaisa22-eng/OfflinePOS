import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/security/license_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects unsigned and malformed license tokens', () async {
    final keyPair = await Ed25519().newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final publicKey = base64UrlEncode(pub.bytes).replaceAll('=', '');
    final verifier = LicenseVerifier(publicKey);
    expect(await verifier.verify('garbage'), isFalse);
    expect(await verifier.verify('abc.def'), isFalse);
    expect(await verifier.verify(''), isFalse);
  });

  test('rejects payload signed with a different key', () async {
    final trusted = await Ed25519().newKeyPair();
    final attacker = await Ed25519().newKeyPair();
    final pub = await trusted.extractPublicKey();
    final verifier = LicenseVerifier(
      base64UrlEncode(pub.bytes).replaceAll('=', ''),
    );
    final device = await verifier.installationId();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final payload = base64UrlEncode(utf8.encode(jsonEncode({
      'typ': 'qamvio-license-v1',
      'device_id': device,
      'exp': now + 3600,
    }))).replaceAll('=', '');
    final signed = await Ed25519().sign(utf8.encode(payload), keyPair: attacker);
    final token = '$payload.${base64UrlEncode(signed.bytes).replaceAll('=', '')}';
    expect(await verifier.verify(token), isFalse);
  });
}
