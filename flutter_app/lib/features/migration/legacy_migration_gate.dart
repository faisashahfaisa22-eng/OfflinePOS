import 'package:flutter/material.dart';

import '../../core/migration/legacy_migration_service.dart';
import '../dashboard/dashboard_page.dart';

class LegacyMigrationGate extends StatefulWidget {
  const LegacyMigrationGate({super.key});

  @override
  State<LegacyMigrationGate> createState()=>_LegacyMigrationGateState();
}

class _LegacyMigrationGateState extends State<LegacyMigrationGate> {
  final password=TextEditingController();
  late Future<bool> pending;
  bool busy=false;
  bool continueWithoutImport=false;
  bool migrated=false;
  String message='';

  @override
  void initState() {
    super.initState();
    pending=LegacyMigrationService.instance.hasPendingMigration();
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> migrate() async {
    setState(()=>busy=true);
    try {
      final result=await LegacyMigrationService.instance.migrateFromLegacyCloud(
        legacyPassword:password.text,
      );
      if(!mounted) return;
      setState(() {
        message=result.message;
        migrated=result.migrated;
      });
    } catch(e) {
      if(mounted) {
        setState(()=>message='Migration failed safely: '+e.toString());
      }
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if(migrated||continueWithoutImport) return const DashboardPage();

    return FutureBuilder<bool>(
      future:pending,
      builder:(context,snapshot) {
        if(snapshot.connectionState!=ConnectionState.done) {
          return const Scaffold(
            body:Center(child:CircularProgressIndicator()),
          );
        }
        if(snapshot.data!=true) return const DashboardPage();

        return Scaffold(
          appBar:AppBar(title:const Text('QAMVIO Data Migration')),
          body:Center(
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:520),
              child:ListView(
                shrinkWrap:true,
                padding:const EdgeInsets.all(20),
                children:[
                  const Icon(Icons.shield_outlined,size:58),
                  const SizedBox(height:14),
                  Text(
                    'Legacy QAMVIO backup found',
                    style:Theme.of(context).textTheme.headlineSmall,
                    textAlign:TextAlign.center,
                  ),
                  const SizedBox(height:10),
                  const Text(
                    'The old encrypted cloud backup will be opened only with your original local QAMVIO password. '
                    'The Flutter database must be empty. Import runs in one SQLite transaction, row counts are validated '
                    'before commit, and the old cloud backup is never deleted or overwritten.',
                    textAlign:TextAlign.center,
                  ),
                  const SizedBox(height:18),
                  TextField(
                    controller:password,
                    obscureText:true,
                    enabled:!busy,
                    decoration:const InputDecoration(
                      labelText:'Original local QAMVIO password',
                      helperText:'This may differ from your cloud account password.',
                    ),
                  ),
                  const SizedBox(height:14),
                  FilledButton.icon(
                    onPressed:busy?null:migrate,
                    icon:const Icon(Icons.move_to_inbox),
                    label:Text(
                      busy
                        ?'Migrating & validating…'
                        :'Import Legacy Data Safely',
                    ),
                  ),
                  TextButton(
                    onPressed:busy
                      ?null
                      :()=>setState(()=>continueWithoutImport=true),
                    child:const Text('Continue without importing now'),
                  ),
                  if(busy)
                    const Padding(
                      padding:EdgeInsets.all(12),
                      child:Center(child:CircularProgressIndicator()),
                    ),
                  if(message.isNotEmpty)
                    Card(
                      child:Padding(
                        padding:const EdgeInsets.all(12),
                        child:Text(message),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
