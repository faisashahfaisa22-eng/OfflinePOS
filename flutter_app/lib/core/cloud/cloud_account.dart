import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../security/crypto_utils.dart';
import '../security/local_auth_service.dart';

enum CloudSignInResult {
  /// Cloud session is active.
  signedIn,

  /// Account exists but the email/SMS confirmation is still pending.
  needsConfirmation,

  /// No cloud account for these details, or the password is wrong.
  notFound,

  /// The cloud account exists but was created with a different (older) password.
  existingOtherPassword,

  /// No internet connection.
  offline,

  /// Any other cloud error.
  failed,
}

/// One email/mobile + ONE password for the app and the cloud backup.
///
/// The password typed by the user is never sent to the cloud server. Only a
/// one-way derivative ([CryptoUtils.deriveCloudPassword]) is used as the cloud
/// password, so the backup stays unreadable for the server.
class CloudAccount {
  CloudAccount._();

  static bool _isPhone(String id) => id.startsWith('+');

  static bool _looksOffline(String message) {
    final m = message.toLowerCase();
    return m.contains('socket') ||
        m.contains('network') ||
        m.contains('connection') ||
        m.contains('host lookup') ||
        m.contains('clientexception') ||
        m.contains('timed out');
  }

  /// Signs in to the cloud account for [loginRaw]. With [createIfMissing] a
  /// missing cloud account is created (it may still need confirmation).
  static Future<CloudSignInResult> signIn(
    String loginRaw,
    String password, {
    bool createIfMissing = false,
  }) async {
    final id = LocalAuthService.normalizeLoginId(loginRaw);
    final cloudPw = await CryptoUtils.deriveCloudPassword(id, password);
    final auth = sb.Supabase.instance.client.auth;

    try {
      if (_isPhone(id)) {
        await auth.signInWithPassword(phone: id, password: cloudPw);
      } else {
        await auth.signInWithPassword(email: id, password: cloudPw);
      }
      return CloudSignInResult.signedIn;
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (_looksOffline(msg)) return CloudSignInResult.offline;
      if (msg.contains('not confirmed')) {
        return CloudSignInResult.needsConfirmation;
      }
      final invalid = msg.contains('invalid login credentials');
      if (!invalid) return CloudSignInResult.failed;
      if (!createIfMissing) return CloudSignInResult.notFound;
    } catch (_) {
      return CloudSignInResult.offline;
    }

    // Reached only for "invalid credentials" with createIfMissing.
    try {
      final res = _isPhone(id)
          ? await auth.signUp(phone: id, password: cloudPw)
          : await auth.signUp(email: id, password: cloudPw);
      if (res.session != null) return CloudSignInResult.signedIn;
      final identities = res.user?.identities;
      if (identities != null && identities.isEmpty) {
        return CloudSignInResult.existingOtherPassword;
      }
      return CloudSignInResult.needsConfirmation;
    } on sb.AuthException catch (e) {
      return _looksOffline(e.message)
          ? CloudSignInResult.offline
          : CloudSignInResult.failed;
    } catch (_) {
      return CloudSignInResult.offline;
    }
  }

  /// Returns the timestamp of the newest cloud backup of the signed-in cloud
  /// account, or null when there is none.
  static Future<DateTime?> latestBackupTime() async {
    final client = sb.Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('qamvio_flutter_backups')
        .select('updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return DateTime.tryParse('${row['updated_at']}')?.toLocal();
  }

  /// Called after the primary Admin signs in, creates the account, or changes
  /// the password. Keeps the cloud login in step with the ONE password the user
  /// types: connects (or creates) the cloud account when there is no session,
  /// and re-keys the cloud password when the app password has changed.
  /// Never throws: offline simply means the backup waits.
  static Future<CloudSignInResult?> syncAfterLogin(
    String loginRaw,
    String password,
  ) async {
    try {
      final auth = LocalAuthService.instance;
      final id = LocalAuthService.normalizeLoginId(loginRaw);
      if (auth.primaryAdminLoginId != id) return null;

      final cloud = sb.Supabase.instance.client.auth;
      if (cloud.currentUser == null) {
        return await signIn(id, password, createIfMissing: true);
      }
      await _alignCloudPassword(id, password);
      return CloudSignInResult.signedIn;
    } catch (_) {
      return null;
    }
  }

  static String _fingerprint(String cloudPw) =>
      sha256.convert(utf8.encode('qamvio-fp:$cloudPw')).toString();

  /// Updates the cloud password only when the derived value changed since the
  /// last time it was stored (first run after upgrading from the old separate
  /// cloud password, or after the app password was changed).
  static Future<void> _alignCloudPassword(String id, String password) async {
    final cloud = sb.Supabase.instance.client.auth;
    final user = cloud.currentUser;
    if (user == null) return;

    final cloudPw = await CryptoUtils.deriveCloudPassword(id, password);
    final prefs = await SharedPreferences.getInstance();
    final key = 'qamvio_cloud_pw_fp_${user.id}';
    final fp = _fingerprint(cloudPw);
    if (prefs.getString(key) == fp) return;

    try {
      await cloud.updateUser(sb.UserAttributes(password: cloudPw));
      await prefs.setString(key, fp);
    } on sb.AuthException catch (e) {
      // Same password already stored on the server: nothing to change.
      if (e.message.toLowerCase().contains('different from the old')) {
        await prefs.setString(key, fp);
      }
    }
  }

  /// For accounts created by older versions that used a separate cloud
  /// password: signs in with that old password once, then moves the cloud
  /// account to the single derived password.
  static Future<CloudSignInResult> connectWithLegacyPassword({
    required String loginRaw,
    required String password,
    required String legacyPassword,
  }) async {
    final id = LocalAuthService.normalizeLoginId(loginRaw);
    final cloud = sb.Supabase.instance.client.auth;
    try {
      if (_isPhone(id)) {
        await cloud.signInWithPassword(phone: id, password: legacyPassword);
      } else {
        await cloud.signInWithPassword(email: id, password: legacyPassword);
      }
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (_looksOffline(msg)) return CloudSignInResult.offline;
      if (msg.contains('not confirmed')) {
        return CloudSignInResult.needsConfirmation;
      }
      return CloudSignInResult.notFound;
    } catch (_) {
      return CloudSignInResult.offline;
    }
    await _alignCloudPassword(id, password);
    return CloudSignInResult.signedIn;
  }
}
