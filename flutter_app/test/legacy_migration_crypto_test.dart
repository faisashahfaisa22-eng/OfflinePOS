import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/migration/legacy_migration_service.dart';

void main() {
  final payload=<String,dynamic>{
    'format':2,
    'encrypted':true,
    'db_meta':{
      'v':16,
      'salt':'00112233445566778899aabbccddeeff',
      'iter':600000,
      'wdek_pw':{
        'iv':'000102030405060708090a0b',
        'ct':'2a5854dcc526258f4a93b7faa25da3249d26c6b221428b345d55c3a413c636fdb866825d04f9faac9e8f6df5899ff99d',
      },
    },
    'db_box':{
      'v':2,
      'iv':'0c0d0e0f1011121314151617',
      'ct':'e3dc19aa1012893043596aefcaf0048e3121d7cc864c1986b9cc9b8d8182fad878920b07cde7550073965e2087cf7ff8b6678bfd8b977bc03aaf0835d98868822c0662a481d7b2389b1fe60f392e30bd4775e06522b76c53e50ff590438807ebc0d1bd805c453fd74bb770f8c5bc4785125b1351900d5e565fbb99b6418e915e4f8b82180533ae0b4a883b833cb83b41f0e27766b2eb951415866fea2b8ba23e0716178fb3524ebfd6868e1aba9a8db60a0adca817f356ae2c5201c19882c70ac3c632dd127d671cae312fb550293f33fe21e5222a6bb71100d0d8beb08fdd1a6fbe74026921e5387211f7b4868ce616cad4d203585b43fe71d5e5dde476d201d0773225a9c36c5a95313bb5d1e30e1e172da95d1860d61cb186d5080ca3cdd1bc30b78b7dd3ec44ffe90b39b23d5b0d4f31d11d0e06dfd5197fd5ef24e5354b2a89d0e0682f83095a5ef0459a88934779bf34fc8dcca346ec712e8c0d01c60835b00a97355b46a07182513a',
    },
  };

  test('decrypts wrapped QAMVIO PBKDF2 AES-GCM legacy backup',() async {
    final data=await LegacyCrypto.decryptLegacyPayload(
      payload,
      'Migration123',
    );
    final products=data['products'] as List;
    expect(products,hasLength(1));
    expect((products.first as Map)['name'],'Tea');
  });

  test('wrong legacy password fails authenticated decryption',() async {
    expect(
      () async=>LegacyCrypto.decryptLegacyPayload(payload,'wrong-password'),
      throwsA(isA<StateError>()),
    );
  });
}
