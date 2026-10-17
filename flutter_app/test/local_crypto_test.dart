import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/security/crypto_utils.dart';
import 'package:qamvio_pos/core/security/local_auth_service.dart';

void main() {
  test('hex round trip',() {
    final b=CryptoUtils.randomBytes(32);
    expect(CryptoUtils.fromHex(CryptoUtils.toHex(b)),b);
  });

  test('PBKDF2 is deterministic and salt/secret sensitive',() async {
    final a=await CryptoUtils.deriveKey('pass1234','aabb',iterations:1000);
    final b=await CryptoUtils.deriveKey('pass1234','aabb',iterations:1000);
    final c=await CryptoUtils.deriveKey('pass1235','aabb',iterations:1000);
    final d=await CryptoUtils.deriveKey('pass1234','aabc',iterations:1000);
    expect(a,b);
    expect(a==c,isFalse);
    expect(a==d,isFalse);
    expect(a.length,32);
  });

  test('AES-GCM key wrap round trip and wrong key rejected',() async {
    final dek=CryptoUtils.randomBytes(32);
    final kek=CryptoUtils.randomBytes(32);
    final box=await CryptoUtils.encryptBox(dek,kek);
    expect(await CryptoUtils.decryptBox(box,kek),dek);
    expect(
      ()=>CryptoUtils.decryptBox(box,CryptoUtils.randomBytes(32)),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('tampered ciphertext is rejected',() async {
    final kek=CryptoUtils.randomBytes(32);
    final box=await CryptoUtils.encryptBox([1,2,3,4,5,6,7,8],kek);
    final ct=box['ct']!;
    final flipped=(ct.startsWith('0')?'1':'0')+ct.substring(1);
    expect(
      ()=>CryptoUtils.decryptBox({'iv':box['iv'],'ct':flipped},kek),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('backup key differs from the data key and is stable',() async {
    final dek=CryptoUtils.randomBytes(32);
    final k1=await CryptoUtils.deriveBackupKey(dek);
    final k2=await CryptoUtils.deriveBackupKey(dek);
    expect(k1,k2);
    expect(k1==dek,isFalse);
  });

  test('recovery code format',() {
    final c=CryptoUtils.generateRecoveryCode();
    expect(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$').hasMatch(c),isTrue);
    expect(CryptoUtils.normalizeRecoveryCode(c.toLowerCase()).length,16);
  });

  test('password strength rules match v15',() {
    expect(CryptoUtils.validatePasswordStrength('short1'),isNotNull);
    expect(CryptoUtils.validatePasswordStrength('abcdefgh'),isNotNull);
    expect(CryptoUtils.validatePasswordStrength('12345678'),isNotNull);
    expect(CryptoUtils.validatePasswordStrength('abcd1234'),isNull);
  });

  test('login id normalisation and validation',() {
    expect(LocalAuthService.normalizeLoginId('  User@Mail.COM '),'user@mail.com');
    expect(LocalAuthService.normalizeLoginId('0093 70-123 4567'),'+93701234567');
    expect(LocalAuthService.validateLoginId('user@mail.com'),isNull);
    expect(LocalAuthService.validateLoginId('+93701234567'),isNull);
    expect(LocalAuthService.validateLoginId('abc'),isNotNull);
    expect(LocalAuthService.validateLoginId('0701234567'),isNotNull);
  });
}
