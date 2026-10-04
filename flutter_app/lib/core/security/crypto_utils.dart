import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

/// Cryptographic helpers. Formats are intentionally compatible with QAMVIO v15:
///  - KDF: PBKDF2-HMAC-SHA256, 600,000 iterations, salt = UTF-8 bytes of the hex salt string
///  - Key wrapping: AES-GCM-256, 12-byte IV, ciphertext||tag as hex ({iv, ct})
class CryptoUtils {
  CryptoUtils._();

  static const int kdfIterations=600000;
  static const int saltBytes=16;
  static const int keyBytes=32;
  static const int _macBytes=16;
  static final Random _rng=Random.secure();

  static Uint8List randomBytes(int n)=>Uint8List.fromList(List<int>.generate(n,(_)=>_rng.nextInt(256)));
  static String randomSaltHex([int n=saltBytes])=>toHex(randomBytes(n));

  static String toHex(List<int> b)=>b.map((x)=>x.toRadixString(16).padLeft(2,'0')).join();
  static Uint8List fromHex(String h) {
    if(h.length.isOdd) throw const FormatException('Invalid hex string.');
    final out=Uint8List(h.length~/2);
    for(var i=0;i<out.length;i++) {
      out[i]=int.parse(h.substring(i*2,i*2+2),radix:16);
    }
    return out;
  }

  static bool constantTimeEquals(List<int> a,List<int> b) {
    if(a.length!=b.length) return false;
    var diff=0;
    for(var i=0;i<a.length;i++) {
      diff|=a[i]^b[i];
    }
    return diff==0;
  }

  /// Derives a 32-byte key from [secret] (password or recovery code). Runs in a
  /// background isolate because 600k PBKDF2 rounds would freeze the UI.
  static Future<Uint8List> deriveKey(String secret,String saltHex,{int iterations=kdfIterations}) {
    return compute(_pbkdf2Isolate,_KdfArgs(secret,saltHex,iterations));
  }

  static final AesGcm _aes=AesGcm.with256bits();

  /// Encrypts [plain] with [key]. Result: {iv, ct} as hex (ct = ciphertext||tag).
  static Future<Map<String,String>> encryptBox(List<int> plain,List<int> key) async {
    final iv=randomBytes(12);
    final box=await _aes.encrypt(plain,secretKey:SecretKey(key),nonce:iv);
    return {
      'iv':toHex(iv),
      'ct':toHex([...box.cipherText,...box.mac.bytes]),
    };
  }

  /// Throws [SecretBoxAuthenticationError] when the key is wrong or data was altered.
  static Future<Uint8List> decryptBox(Map<String,dynamic> box,List<int> key) async {
    final iv=fromHex(box['iv'] as String);
    final all=fromHex(box['ct'] as String);
    if(all.length<_macBytes) throw const FormatException('Encrypted box is too short.');
    final cipher=all.sublist(0,all.length-_macBytes);
    final mac=Mac(all.sublist(all.length-_macBytes));
    final plain=await _aes.decrypt(SecretBox(cipher,nonce:iv,mac:mac),secretKey:SecretKey(key));
    return Uint8List.fromList(plain);
  }

  /// Independent sub-key for cloud backups so the database key is never used directly.
  static Future<Uint8List> deriveBackupKey(List<int> dek) async {
    final mac=await Hmac.sha256().calculateMac(
      utf8.encode('qamvio-cloud-backup-v1'),
      secretKey:SecretKey(dek),
    );
    return Uint8List.fromList(mac.bytes);
  }

  /// Secret used ONLY to sign in to the cloud backup account. It is a one-way
  /// derivative of [password] with its own domain-separated salt, so the real
  /// password (which unwraps the database key) is never sent to the cloud
  /// server, yet the user still types a single password everywhere.
  static Future<String> deriveCloudPassword(String loginId,String password) async {
    final key=await deriveKey(password,'qamvio-cloud-auth-v1:$loginId');
    return base64Url.encode(key).replaceAll('=','');
  }

  /// Human-friendly recovery code (80 bits): XXXX-XXXX-XXXX-XXXX, no ambiguous characters.
  static String generateRecoveryCode() {
    const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final chars=List<String>.generate(16,(_)=>alphabet[_rng.nextInt(alphabet.length)]);
    return [for(var i=0;i<16;i+=4) chars.sublist(i,i+4).join()].join('-');
  }

  static String normalizeRecoveryCode(String raw)=>raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'),'');

  /// Same rules as v15: at least 8 characters, one letter and one digit.
  static String? validatePasswordStrength(String? pw) {
    if(pw==null||pw.length<8) return 'Password must be at least 8 characters.';
    if(!RegExp(r'[A-Za-z]').hasMatch(pw)) return 'Password must contain at least one letter.';
    if(!RegExp(r'[0-9]').hasMatch(pw)) return 'Password must contain at least one number.';
    return null;
  }
}

class _KdfArgs {
  final String secret;
  final String saltHex;
  final int iterations;
  const _KdfArgs(this.secret,this.saltHex,this.iterations);
}

Future<Uint8List> _pbkdf2Isolate(_KdfArgs a) async {
  final pbkdf2=Pbkdf2(macAlgorithm:Hmac.sha256(),iterations:a.iterations,bits:256);
  final key=await pbkdf2.deriveKeyFromPassword(password:a.secret,nonce:utf8.encode(a.saltHex));
  return Uint8List.fromList(await key.extractBytes());
}
