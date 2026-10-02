import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/security/crypto_utils.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState()=>_RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  final search=TextEditingController();

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
    load();
  }

  @override
  void dispose() {
    search.removeListener(_refresh);
    search.dispose();
    super.dispose();
  }

  void _refresh()=>setState(() {});

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final r=await db.query('recycle_bin',orderBy:'deleted_at DESC');
    if(!mounted) return;
    setState(() {
      rows=r;
      loading=false;
    });
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((x)=>[
      x['section'],
      x['label'],
      x['record_json'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  Future<void> restore(Map<String,Object?> x) async {
    try {
      await AppDatabase.instance.restoreRecycle(x['id'].toString());
      await load();
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Restore failed: $e')));
    }
  }

  Future<void> forever(Map<String,Object?> x) async {
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Forever?'),
        content:const Text('This removes the recycle record permanently. It cannot be restored.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete Forever')),
        ],
      ),
    );
    if(ok==true) {
      await AppDatabase.instance.deleteRecycleForever(x['id'].toString());
      await load();
    }
  }

  Future<void> empty() async {
    if(rows.isEmpty) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Empty Recycle Bin?'),
        content:Text('Permanently delete all ${rows.length} recycle records?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Empty Recycle Bin')),
        ],
      ),
    );
    if(ok==true) {
      final db=await AppDatabase.instance.database;
      await db.delete('recycle_bin');
      await load();
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('Recycle Bin'),
      actions:[
        IconButton(
          tooltip:'Empty Recycle Bin',
          onPressed:rows.isEmpty?null:empty,
          icon:const Icon(Icons.delete_forever_outlined),
        ),
      ],
    ),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioPageIntro(
            title:'Recycle Bin',
            subtitle:'Restore deleted business records or delete them forever.',
            icon:Icons.recycling_rounded,
          ),
          const SizedBox(height:16),
          TextField(
            controller:search,
            decoration:const InputDecoration(
              labelText:'Search recycle bin',
              prefixIcon:Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height:14),
          if(filtered.isEmpty)
            const QamvioEmptyState(
              icon:Icons.recycling_outlined,
              title:'Recycle Bin is empty',
              subtitle:'Soft-deleted records will appear here.',
            )
          else
            ...filtered.map((x)=>Card(
              margin:const EdgeInsets.only(bottom:8),
              child:Padding(
                padding:const EdgeInsets.all(12),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Row(
                      children:[
                        Expanded(
                          child:Text(
                            x['label']?.toString()??x['id'].toString(),
                            style:const TextStyle(fontWeight:FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                          decoration:BoxDecoration(
                            color:const Color(0xFFF1F5F9),
                            borderRadius:BorderRadius.circular(999),
                          ),
                          child:Text(
                            x['section'].toString(),
                            style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height:4),
                    Text(
                      'Deleted: ${x['deleted_at']}',
                      style:Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height:10),
                    Row(
                      children:[
                        Expanded(
                          child:OutlinedButton.icon(
                            onPressed:()=>restore(x),
                            icon:const Icon(Icons.restore_rounded),
                            label:const Text('Restore'),
                          ),
                        ),
                        const SizedBox(width:8),
                        Expanded(
                          child:OutlinedButton.icon(
                            onPressed:()=>forever(x),
                            icon:const Icon(Icons.delete_forever_outlined),
                            label:const Text('Delete Forever'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
  );
}

class DeleteEntryPage extends StatefulWidget {
  const DeleteEntryPage({super.key});

  @override
  State<DeleteEntryPage> createState()=>_DeleteEntryPageState();
}

class _DeleteEntryPageState extends State<DeleteEntryPage> {
  static const sections=<String,String>{
    'sales':'Sales',
    'purchases':'Purchases',
    'salesmen':'Salesmen',
    'customerLoans':'Customer Loans',
    'salesmanLoans':'Salesman Loans',
    'supplierTransactions':'Supplier Payment / Receipt',
    'expenses':'Expenses',
    'capital':'Owner / Partner Money',
    'stockAdjustments':'Stock Adjustments',
    'customers':'Customers',
    'suppliers':'Suppliers',
    'products':'Products',
  };
  String section='sales';
  String clearSection='sales';
  final id=TextEditingController();
  bool busy=false;

  @override
  void dispose() {
    id.dispose();
    super.dispose();
  }

  Future<void> deleteOne() async {
    if(id.text.trim().isEmpty||busy) return;
    setState(()=>busy=true);
    try {
      await AppDatabase.instance.softDeleteById(section,id.text.trim());
      id.clear();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Record moved to Recycle Bin.')),
        );
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> clearAll() async {
    if(busy) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('Clear ${sections[clearSection]}?'),
        content:const Text(
          'Every record in this section will be moved to Recycle Bin one by one. '
          'Make a backup first.',
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Clear Section')),
        ],
      ),
    );
    if(ok!=true) return;
    setState(()=>busy=true);
    try {
      await AppDatabase.instance.clearSectionToRecycle(clearSection);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Section moved to Recycle Bin.')),
        );
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Delete Entry')),
    body:ListView(
      padding:QamvioUi.pagePadding,
      children:[
        const QamvioPageIntro(
          title:'Delete Entry',
          subtitle:'Delete one wrong entry or clear a data section. Always make a backup first.',
          icon:Icons.delete_sweep_rounded,
        ),
        const SizedBox(height:16),
        Card(
          child:Padding(
            padding:const EdgeInsets.all(16),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                const Text('Delete by Record ID',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
                const SizedBox(height:12),
                DropdownButtonFormField<String>(
                  initialValue:section,
                  decoration:const InputDecoration(labelText:'Section'),
                  items:[
                    for(final e in sections.entries)
                      DropdownMenuItem(value:e.key,child:Text(e.value)),
                  ],
                  onChanged:(v)=>setState(()=>section=v??section),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:id,
                  decoration:const InputDecoration(
                    labelText:'Record ID',
                    prefixIcon:Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height:12),
                FilledButton.icon(
                  onPressed:busy?null:deleteOne,
                  icon:const Icon(Icons.delete_outline_rounded),
                  label:const Text('Delete Record'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height:14),
        Card(
          child:Padding(
            padding:const EdgeInsets.all(16),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                const Text('Clear Whole Section',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
                const SizedBox(height:12),
                DropdownButtonFormField<String>(
                  initialValue:clearSection,
                  decoration:const InputDecoration(labelText:'Section'),
                  items:[
                    for(final e in sections.entries)
                      DropdownMenuItem(value:e.key,child:Text(e.value)),
                  ],
                  onChanged:(v)=>setState(()=>clearSection=v??clearSection),
                ),
                const SizedBox(height:12),
                OutlinedButton.icon(
                  onPressed:busy?null:clearAll,
                  icon:const Icon(Icons.delete_forever_outlined),
                  label:const Text('Clear Section'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class SafetyCenterPage extends StatefulWidget {
  const SafetyCenterPage({super.key});

  @override
  State<SafetyCenterPage> createState()=>_SafetyCenterPageState();
}

class _SafetyCenterPageState extends State<SafetyCenterPage> {
  Map<String,String> settings=const {};
  bool loading=true;
  String testResult='';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query('settings');
    final m=<String,String>{};
    for(final x in rows) {
      m[x['key'].toString()]=x['value']?.toString()??'';
    }
    if(!mounted) return;
    setState(() {
      settings=m;
      loading=false;
    });
  }

  Future<void> editBusiness() async {
    final name=TextEditingController(text:settings['business_name']??'');
    final phone=TextEditingController(text:settings['business_phone']??'');
    final address=TextEditingController(text:settings['business_address']??'');
    final currency=TextEditingController(text:settings['currency']??'AFN');
    final type=TextEditingController(text:settings['business_type']??'General');
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Business Setup'),
        content:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              TextField(controller:name,decoration:const InputDecoration(labelText:'Business Name')),
              const SizedBox(height:10),
              TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),
              const SizedBox(height:10),
              TextField(controller:address,decoration:const InputDecoration(labelText:'Address')),
              const SizedBox(height:10),
              TextField(controller:currency,decoration:const InputDecoration(labelText:'Currency')),
              const SizedBox(height:10),
              TextField(controller:type,decoration:const InputDecoration(labelText:'Business Type')),
            ],
          ),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save')),
        ],
      ),
    );
    if(ok==true) {
      final db=await AppDatabase.instance.database;
      final now=DateTime.now().toUtc().toIso8601String();
      final values={
        'business_name':name.text.trim(),
        'business_phone':phone.text.trim(),
        'business_address':address.text.trim(),
        'currency':currency.text.trim(),
        'business_type':type.text.trim(),
      };
      await db.transaction((txn) async {
        for(final e in values.entries) {
          await txn.insert(
            'settings',
            {'key':e.key,'value':e.value,'updated_at':now},
            conflictAlgorithm:ConflictAlgorithm.replace,
          );
        }
      });
      await load();
    }
    name.dispose();
    phone.dispose();
    address.dispose();
    currency.dispose();
    type.dispose();
  }

  Future<void> selfTest() async {
    setState(() => testResult = 'Running…');
    final lines = <String>[];

    // 1) SQLCipher integrity + schema
    try {
      final db = await AppDatabase.instance.database;
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      final value = integrity.isEmpty
          ? 'unknown'
          : integrity.first.values.first?.toString() ?? 'unknown';
      lines.add('SQLCipher DB integrity: $value');

      final tables = Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM sqlite_master WHERE type='table'",
            ),
          ) ??
          0;
      lines.add('Schema tables present: $tables');
    } catch (e) {
      lines.add('SQLCipher DB check FAILED: $e');
    }

    // 2) Auth state
    final auth = LocalAuthService.instance;
    lines.add('Local login unlocked: ${auth.unlocked ? 'YES' : 'NO'}');
    lines.add('Active users: ${auth.users.where((u) => u.active).length}');

    // 3) PBKDF2 determinism
    try {
      final k1 = await CryptoUtils.deriveKey(
        'selftest-pw',
        'aabb',
        iterations: 1000,
      );
      final k2 = await CryptoUtils.deriveKey(
        'selftest-pw',
        'aabb',
        iterations: 1000,
      );
      lines.add(
        'PBKDF2 iterations (production): ${CryptoUtils.kdfIterations}',
      );
      lines.add(
        'PBKDF2 deterministic: '
        '${CryptoUtils.constantTimeEquals(k1, k2) ? 'YES' : 'NO'}',
      );
      lines.add('PBKDF2 key length: ${k1.length} bytes');
    } catch (e) {
      lines.add('PBKDF2 FAILED: $e');
    }

    // 4) AES-GCM round trip + wrong-key rejection
    try {
      final key = CryptoUtils.randomBytes(32);
      final box = await CryptoUtils.encryptBox(
        const [1, 2, 3, 4, 5, 6, 7, 8],
        key,
      );
      final clear = await CryptoUtils.decryptBox(box, key);
      final ok = CryptoUtils.constantTimeEquals(
        clear,
        const [1, 2, 3, 4, 5, 6, 7, 8],
      );
      lines.add('AES-GCM round trip: ${ok ? 'YES' : 'NO'}');

      var wrongKeyRejected = false;
      try {
        await CryptoUtils.decryptBox(
          box,
          CryptoUtils.randomBytes(32),
        );
      } on SecretBoxAuthenticationError {
        wrongKeyRejected = true;
      } catch (_) {
        // A non-authentication crypto error is still a failed self-test.
      }
      lines.add(
        'AES-GCM wrong-key rejected: '
        '${wrongKeyRejected ? 'YES' : 'NO'}',
      );
    } catch (e) {
      lines.add('AES-GCM FAILED: $e');
    }

    // 5) Recovery code format
    try {
      final code = CryptoUtils.generateRecoveryCode();
      final normalized =
          CryptoUtils.normalizeRecoveryCode(code.toLowerCase());
      final okFormat =
          RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$').hasMatch(code);
      lines.add('Recovery code format: ${okFormat ? 'OK' : 'BAD'}');
      lines.add(
        'Recovery code normalized length: ${normalized.length}',
      );
    } catch (e) {
      lines.add('Recovery code FAILED: $e');
    }

    // 6) Password policy
    final weak = CryptoUtils.validatePasswordStrength('short');
    final strong = CryptoUtils.validatePasswordStrength('abcd1234');
    lines.add(
      'Password policy: weak rejected=${weak != null}, '
      'strong accepted=${strong == null}',
    );

    // 7) Cloud backup key derivation (only while unlocked)
    if (auth.unlocked) {
      try {
        final bk = await auth.backupKey();
        lines.add('Cloud backup key derived: ${bk.length} bytes');
      } catch (e) {
        lines.add('Cloud backup key FAILED: $e');
      }
    } else {
      lines.add('Cloud backup key: not available (locked)');
    }

    if (mounted) {
      setState(() => testResult = lines.join('\n'));
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Safety Center')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioPageIntro(
            title:'Safety Center',
            subtitle:'Security status, business setup and local data protection.',
            icon:Icons.shield_rounded,
          ),
          const SizedBox(height:16),
          Container(
            padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(
              color:const Color(0xFFECFDF5),
              borderRadius:BorderRadius.circular(16),
              border:Border.all(color:const Color(0xFF86EFAC)),
            ),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                const Text('🔒 Security Status',style:TextStyle(fontWeight:FontWeight.w900,fontSize:19)),
                const SizedBox(height:12),
                Wrap(
                  spacing:8,
                  runSpacing:8,
                  children:const [
                    _SecurityBadge('✓ SQLCipher','Encrypted DB'),
                    _SecurityBadge('✓ PBKDF2-600k','Password KDF'),
                    _SecurityBadge('✓ AES-GCM-256','Cloud Backup'),
                    _SecurityBadge('✓ Secure Storage','Key Wrapping'),
                  ],
                ),
                const SizedBox(height:12),
                FilledButton.icon(
                  onPressed:selfTest,
                  icon:const Icon(Icons.science_outlined),
                  label:const Text('Run Security Self-Test'),
                ),
                if(testResult.isNotEmpty) ...[
                  const SizedBox(height:10),
                  SelectableText(testResult),
                ],
              ],
            ),
          ),
          const SizedBox(height:14),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(16),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('Business Settings',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
                  const SizedBox(height:10),
                  _row('Business Name',settings['business_name']??'Not set'),
                  _row('Phone',settings['business_phone']??'—'),
                  _row('Address',settings['business_address']??'—'),
                  _row('Currency',settings['currency']??'AFN'),
                  _row('Business Type',settings['business_type']??'General'),
                  const SizedBox(height:12),
                  OutlinedButton.icon(
                    onPressed:editBusiness,
                    icon:const Icon(Icons.edit_outlined),
                    label:const Text('Edit Business Setup'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
  );

  Widget _row(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        SizedBox(width:120,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w700))),
        Expanded(child:Text(value)),
      ],
    ),
  );
}

class _SecurityBadge extends StatelessWidget {
  final String value;
  final String label;
  const _SecurityBadge(this.value,this.label);

  @override
  Widget build(BuildContext context)=>Container(
    width:145,
    padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:const Color(0xFF86EFAC)),
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text(value,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:Color(0xFF065F46))),
        const SizedBox(height:2),
        Text(label,style:const TextStyle(fontSize:10,color:Color(0xFF64748B))),
      ],
    ),
  );
}
