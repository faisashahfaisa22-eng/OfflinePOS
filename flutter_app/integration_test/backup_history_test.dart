import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qamvio_pos/core/cloud/cloud_backup_service.dart';
import 'package:qamvio_pos/core/database/app_database.dart';
import 'package:qamvio_pos/core/security/crypto_utils.dart';
import 'package:qamvio_pos/core/security/local_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('encrypted backup is deterministic by state and integrity protected', () async {
    final auth=LocalAuthService.instance;
    await auth.load();
    if(auth.hasAccounts) {
      await auth.discardRestoredAccounts();
    }
    await AppDatabase.instance.deleteFile();

    await auth.createFirstAccount(
      'backup-test@example.com',
      'Backup1234',
    );

    await AppDatabase.instance.saveProduct(
      id:'backup-product',
      name:'Backup Product',
      stock:10,
      cost:4,
      price:7,
    );

    final first=await CloudBackupService.instance.encryptedEnvelope(
      reason:'test',
    );
    final second=await CloudBackupService.instance.encryptedEnvelope(
      reason:'test',
    );

    expect(first['format'],2);
    expect(first['enc'],'aes-gcm-256');
    expect(first['schema_version'],7);
    expect(first['reason'],'test');
    expect(first['backup_id'],isNotEmpty);
    expect(first['state_sha256'],isNotEmpty);
    expect(first['integrity_sha256'],isNotEmpty);

    // Fresh AES-GCM IVs/ciphertext are expected, but unchanged protected state
    // must produce the same stable hash so cloud history can deduplicate it.
    expect(second['state_sha256'],first['state_sha256']);
    expect(second['iv'],isNot(first['iv']));
    expect(second['ct'],isNot(first['ct']));

    final key=await auth.backupKey();
    final plain=await CryptoUtils.decryptBox(
      {'iv':first['iv'],'ct':first['ct']},
      key,
    );
    expect(
      crypto.sha256.convert(plain).toString(),
      first['integrity_sha256'],
    );

    final decoded=jsonDecode(utf8.decode(plain)) as Map<String,dynamic>;
    final data=Map<String,dynamic>.from(decoded['data'] as Map);
    final products=data['products'] as List;
    final product=Map<String,dynamic>.from(
      products.firstWhere(
        (e)=>(e as Map)['id']=='backup-product',
      ) as Map,
    );
    expect((product['stock'] as num).toDouble(),10);

    await AppDatabase.instance.saveProduct(
      id:'backup-product',
      name:'Backup Product',
      stock:12,
      cost:4,
      price:7,
    );
    final changed=await CloudBackupService.instance.encryptedEnvelope(
      reason:'test',
    );
    expect(changed['state_sha256'],isNot(first['state_sha256']));

    await auth.logout();
  });
}
