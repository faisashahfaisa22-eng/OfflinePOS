import 'dart:convert';
import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_database.dart';
import 'crypto_utils.dart';

enum UserRole { admin, cashier, salesman }

extension UserRoleX on UserRole {
  String get label=>switch(this){
    UserRole.admin=>'Admin',
    UserRole.cashier=>'Cashier',
    UserRole.salesman=>'Salesman',
  };
  static UserRole parse(String v)=>UserRole.values.firstWhere(
    (r)=>r.label.toLowerCase()==v.toLowerCase(),
    orElse:()=>UserRole.cashier,
  );
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString()=>message;
}

class AuthUser {
  final String id;
  final String loginId;
  final UserRole role;
  final String salesmanId;
  final bool active;
  final String createdAt;
  final String kekSalt;
  final Map<String,String> wdekPw;
  final String recSalt;
  final Map<String,String> wdekRec;

  const AuthUser({
    required this.id,
    required this.loginId,
    required this.role,
    required this.salesmanId,
    required this.active,
    required this.createdAt,
    required this.kekSalt,
    required this.wdekPw,
    required this.recSalt,
    required this.wdekRec,
  });

  AuthUser copyWith({
    UserRole? role,
    String? salesmanId,
    bool? active,
    String? kekSalt,
    Map<String,String>? wdekPw,
    String? recSalt,
    Map<String,String>? wdekRec,
  })=>AuthUser(
    id:id,
    loginId:loginId,
    role:role??this.role,
    salesmanId:salesmanId??this.salesmanId,
    active:active??this.active,
    createdAt:createdAt,
    kekSalt:kekSalt??this.kekSalt,
    wdekPw:wdekPw??this.wdekPw,
    recSalt:recSalt??this.recSalt,
    wdekRec:wdekRec??this.wdekRec,
  );

  Map<String,dynamic> toJson()=>{
    'id':id,
    'loginId':loginId,
    'role':role.label,
    'salesmanId':salesmanId,
    'active':active,
    'createdAt':createdAt,
    'kekSalt':kekSalt,
    'wdekPw':wdekPw,
    'recSalt':recSalt,
    'wdekRec':wdekRec,
  };

  factory AuthUser.fromJson(Map<String,dynamic> j)=>AuthUser(
    id:j['id'] as String,
    loginId:j['loginId'] as String,
    role:UserRoleX.parse(j['role'] as String? ?? 'Cashier'),
    salesmanId:(j['salesmanId'] as String?) ?? '',
    active:(j['active'] as bool?) ?? true,
    createdAt:(j['createdAt'] as String?) ?? '',
    kekSalt:j['kekSalt'] as String,
    wdekPw:Map<String,String>.from(j['wdekPw'] as Map),
    recSalt:j['recSalt'] as String,
    wdekRec:Map<String,String>.from(j['wdekRec'] as Map),
  );
}

/// Offline account system (QAMVIO v15 behaviour, hardened):
///  * login with email or mobile (+country code) and a local password
///  * a random 32-byte data key (DEK) encrypts the SQLCipher database
///  * every user has their own copy of the DEK wrapped under their password
///    AND under their own recovery code (v15 only wrapped it for the first admin,
///    so additional users could not unlock the database after a restart)
///  * Supabase is NOT used for login; it is only a backup destination
class LocalAuthService extends ChangeNotifier {
  LocalAuthService._();
  static final LocalAuthService instance=LocalAuthService._();

  static const _storeKey='qamvio_auth_v2';
  static const _lockKey='qamvio_login_lock_v2';
  static const maxAttempts=5;
  static const baseLockSeconds=60;

  final FlutterSecureStorage _store=const FlutterSecureStorage();

  List<AuthUser> _users=[];
  AuthUser? _current;
  Uint8List? _dek;
  bool _loaded=false;

  bool get loaded=>_loaded;
  bool get hasAccounts=>_users.isNotEmpty;
  bool get unlocked=>_current!=null&&_dek!=null;
  AuthUser? get current=>_current;
  bool get isAdmin=>_current?.role==UserRole.admin;
  List<AuthUser> get users=>List.unmodifiable(_users);

  // ---------------------------------------------------------------- identity

  static String normalizeLoginId(String raw) {
    var v=raw.trim();
    if(v.contains('@')) return v.toLowerCase();
    v=v.replaceAll(RegExp(r'[\s\-()]'),'');
    if(v.startsWith('00')) v='+${v.substring(2)}';
    return v;
  }

  static String? validateLoginId(String raw) {
    final v=normalizeLoginId(raw);
    if(v.isEmpty) return 'Email or mobile number is required.';
    final isEmail=RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    final isPhone=RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(v);
    if(!isEmail&&!isPhone) return 'Enter a valid email, or a mobile number with country code (example: +93...).';
    return null;
  }

  // ------------------------------------------------------------- persistence

  Future<void> load() async {
    final raw=await _store.read(key:_storeKey);
    if(raw!=null&&raw.isNotEmpty) {
      final list=(jsonDecode(raw) as Map<String,dynamic>)['users'] as List;
      _users=list.map((e)=>AuthUser.fromJson(Map<String,dynamic>.from(e as Map))).toList();
    }
    _loaded=true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.write(key:_storeKey,value:jsonEncode({'v':2,'users':_users.map((u)=>u.toJson()).toList()}));
  }

  // ----------------------------------------------------------------- lockout

  Future<int> lockSecondsRemaining() async {
    final raw=await _store.read(key:_lockKey);
    if(raw==null) return 0;
    final m=jsonDecode(raw) as Map<String,dynamic>;
    final until=(m['until'] as int?) ?? 0;
    final left=until-DateTime.now().millisecondsSinceEpoch;
    return left>0?(left/1000).ceil():0;
  }

  Future<void> _registerFailure() async {
    final raw=await _store.read(key:_lockKey);
    final m=raw==null?<String,dynamic>{}:jsonDecode(raw) as Map<String,dynamic>;
    var count=((m['count'] as int?) ?? 0)+1;
    var level=(m['level'] as int?) ?? 0;
    var until=(m['until'] as int?) ?? 0;
    if(count>=maxAttempts) {
      // 60s, 120s, 240s ... capped at 1 hour
      final secs=(baseLockSeconds*(1<<(level>6?6:level))).clamp(baseLockSeconds,3600).toInt();
      until=DateTime.now().millisecondsSinceEpoch+secs*1000;
      count=0;
      level++;
    }
    await _store.write(key:_lockKey,value:jsonEncode({'count':count,'level':level,'until':until}));
  }

  Future<void> _clearFailures()=>_store.delete(key:_lockKey);

  Future<void> _ensureNotLocked() async {
    final s=await lockSecondsRemaining();
    if(s>0) throw AuthException('Too many failed attempts. Try again in $s seconds.');
  }

  // ----------------------------------------------------------------- helpers

  Future<AuthUser> _buildUser({
    required String loginId,
    required String password,
    required Uint8List dek,
    required UserRole role,
    required String salesmanId,
    required String recoveryCode,
    String? id,
    String? createdAt,
  }) async {
    final kekSalt=CryptoUtils.randomSaltHex();
    final recSalt=CryptoUtils.randomSaltHex();
    final pwKek=await CryptoUtils.deriveKey(password,kekSalt);
    final recKek=await CryptoUtils.deriveKey(CryptoUtils.normalizeRecoveryCode(recoveryCode),recSalt);
    return AuthUser(
      id:id??CryptoUtils.randomSaltHex(8),
      loginId:loginId,
      role:role,
      salesmanId:salesmanId,
      active:true,
      createdAt:createdAt??DateTime.now().toUtc().toIso8601String(),
      kekSalt:kekSalt,
      wdekPw:await CryptoUtils.encryptBox(dek,pwKek),
      recSalt:recSalt,
      wdekRec:await CryptoUtils.encryptBox(dek,recKek),
    );
  }

  Future<void> _unlockDatabase(AuthUser user,Uint8List dek) async {
    _dek=dek;
    await AppDatabase.instance.unlock(dek);
    await AppDatabase.instance.database; // opens (and migrates a legacy plain DB) now
    _current=user;
    notifyListeners();
  }

  // --------------------------------------------------------------- operations

  /// First run: creates the Admin account and a brand new encrypted database.
  /// Returns the recovery code. It is shown ONCE and cannot be retrieved later.
  Future<String> createFirstAccount(String loginRaw,String password) async {
    if(hasAccounts) throw const AuthException('An account already exists on this device.');
    final idErr=validateLoginId(loginRaw);
    if(idErr!=null) throw AuthException(idErr);
    final pwErr=CryptoUtils.validatePasswordStrength(password);
    if(pwErr!=null) throw AuthException(pwErr);
    final dek=CryptoUtils.randomBytes(CryptoUtils.keyBytes);
    final code=CryptoUtils.generateRecoveryCode();
    final user=await _buildUser(
      loginId:normalizeLoginId(loginRaw),
      password:password,
      dek:dek,
      role:UserRole.admin,
      salesmanId:'',
      recoveryCode:code,
    );
    _users=[user];
    await _save();
    await _unlockDatabase(user,dek);
    return code;
  }

  Future<void> login(String loginRaw,String password) async {
    await _ensureNotLocked();
    final loginId=normalizeLoginId(loginRaw);
    final matches=_users.where((u)=>u.loginId==loginId&&u.active);
    if(matches.isEmpty) {
      await _registerFailure();
      throw const AuthException('Invalid email/mobile or password.');
    }
    final user=matches.first;
    Uint8List dek;
    try {
      final kek=await CryptoUtils.deriveKey(password,user.kekSalt);
      dek=await CryptoUtils.decryptBox(user.wdekPw,kek);
    } on SecretBoxAuthenticationError {
      await _registerFailure();
      throw const AuthException('Invalid email/mobile or password.');
    }
    await _clearFailures();
    try {
      await _unlockDatabase(user,dek);
    } catch(e) {
      _dek=null;
      await AppDatabase.instance.lock();
      throw AuthException('Cannot open the encrypted database: $e');
    }
  }

  /// Forgot password: unlocks with the recovery code, sets a new password and
  /// rotates the recovery code. The database itself is untouched (same DEK).
  Future<String> resetPasswordWithRecovery(String loginRaw,String recoveryCode,String newPassword) async {
    await _ensureNotLocked();
    final pwErr=CryptoUtils.validatePasswordStrength(newPassword);
    if(pwErr!=null) throw AuthException(pwErr);
    final loginId=normalizeLoginId(loginRaw);
    final idx=_users.indexWhere((u)=>u.loginId==loginId&&u.active);
    if(idx<0) {
      await _registerFailure();
      throw const AuthException('Invalid email/mobile or recovery code.');
    }
    final user=_users[idx];
    Uint8List dek;
    try {
      final recKek=await CryptoUtils.deriveKey(CryptoUtils.normalizeRecoveryCode(recoveryCode),user.recSalt);
      dek=await CryptoUtils.decryptBox(user.wdekRec,recKek);
    } on SecretBoxAuthenticationError {
      await _registerFailure();
      throw const AuthException('Invalid email/mobile or recovery code.');
    }
    await _clearFailures();
    final newCode=CryptoUtils.generateRecoveryCode();
    final rebuilt=await _buildUser(
      loginId:user.loginId,
      password:newPassword,
      dek:dek,
      role:user.role,
      salesmanId:user.salesmanId,
      recoveryCode:newCode,
      id:user.id,
      createdAt:user.createdAt,
    );
    _users[idx]=rebuilt;
    await _save();
    await _unlockDatabase(rebuilt,dek);
    return newCode;
  }

  /// Admin only. The new user gets the DEK wrapped under their own password and
  /// recovery code, so they can unlock the database on their own. Returns the recovery code.
  Future<String> createUser({
    required String loginRaw,
    required String password,
    required UserRole role,
    String salesmanId='',
  }) async {
    if(!isAdmin||_dek==null) throw const AuthException('Admin access required.');
    final idErr=validateLoginId(loginRaw);
    if(idErr!=null) throw AuthException(idErr);
    final pwErr=CryptoUtils.validatePasswordStrength(password);
    if(pwErr!=null) throw AuthException(pwErr);
    if(role==UserRole.salesman&&salesmanId.isEmpty) throw const AuthException('Select a linked Salesman.');
    final loginId=normalizeLoginId(loginRaw);
    if(_users.any((u)=>u.loginId==loginId)) throw const AuthException('Login ID already exists.');
    final code=CryptoUtils.generateRecoveryCode();
    final user=await _buildUser(
      loginId:loginId,
      password:password,
      dek:_dek!,
      role:role,
      salesmanId:role==UserRole.salesman?salesmanId:'',
      recoveryCode:code,
    );
    _users=[..._users,user];
    await _save();
    notifyListeners();
    return code;
  }

  Future<void> setActive(String userId,bool active) async {
    if(!isAdmin) throw const AuthException('Admin access required.');
    final idx=_users.indexWhere((u)=>u.id==userId);
    if(idx<0) return;
    final target=_users[idx];
    if(!active&&target.role==UserRole.admin&&_users.where((u)=>u.role==UserRole.admin&&u.active).length<=1) {
      throw const AuthException('At least one active Admin must remain.');
    }
    if(target.id==_current?.id&&!active) throw const AuthException('You cannot deactivate your own account.');
    _users[idx]=target.copyWith(active:active);
    await _save();
    notifyListeners();
  }

  Future<void> deleteUser(String userId) async {
    if(!isAdmin) throw const AuthException('Admin access required.');
    final target=_users.firstWhere((u)=>u.id==userId,orElse:()=>throw const AuthException('User not found.'));
    if(target.id==_current?.id) throw const AuthException('You cannot delete your own account.');
    if(target.role==UserRole.admin&&_users.where((u)=>u.role==UserRole.admin&&u.active).length<=1) {
      throw const AuthException('At least one active Admin must remain.');
    }
    _users=_users.where((u)=>u.id!=userId).toList();
    await _save();
    notifyListeners();
  }

  /// Re-wraps the DEK for the signed-in user under a new password. Returns a new recovery code.
  Future<String> changeOwnPassword(String currentPassword,String newPassword) async {
    final user=_current;
    if(user==null||_dek==null) throw const AuthException('Not signed in.');
    final pwErr=CryptoUtils.validatePasswordStrength(newPassword);
    if(pwErr!=null) throw AuthException(pwErr);
    try {
      final kek=await CryptoUtils.deriveKey(currentPassword,user.kekSalt);
      await CryptoUtils.decryptBox(user.wdekPw,kek);
    } on SecretBoxAuthenticationError {
      throw const AuthException('Current password is incorrect.');
    }
    final code=CryptoUtils.generateRecoveryCode();
    final rebuilt=await _buildUser(
      loginId:user.loginId,
      password:newPassword,
      dek:_dek!,
      role:user.role,
      salesmanId:user.salesmanId,
      recoveryCode:code,
      id:user.id,
      createdAt:user.createdAt,
    );
    final idx=_users.indexWhere((u)=>u.id==user.id);
    _users[idx]=rebuilt;
    _current=rebuilt;
    await _save();
    notifyListeners();
    return code;
  }

  /// Key used to encrypt cloud backups. Only available while unlocked.
  Future<Uint8List> backupKey() async {
    final dek=_dek;
    if(dek==null) throw const AuthException('Sign in first.');
    return CryptoUtils.deriveBackupKey(dek);
  }

  Future<void> logout() async {
    _dek=null;
    _current=null;
    await AppDatabase.instance.lock();
    notifyListeners();
  }
}
