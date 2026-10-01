import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_backup_service.dart';
import '../../core/migration/legacy_migration_service.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState()=>_CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  final legacyPassword=TextEditingController();
  bool busy=false;
  String message='';

  @override
  void dispose() {
    legacyPassword.dispose();
    super.dispose();
  }

  Future<void> run(Future<dynamic> Function() fn,String ok) async {
    setState(()=>busy=true);
    try {
      final result=await fn();
      if(!mounted) return;
      setState(()=>message=result==false?'No cloud backup was found.':ok);
    } catch(e) {
      if(mounted) setState(()=>message='Cloud error: '+e.toString());
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> migrateLegacy() async {
    setState(()=>busy=true);
    try {
      final result=await LegacyMigrationService.instance.migrateFromLegacyCloud(
        legacyPassword:legacyPassword.text,
      );
      if(!mounted) return;
      setState(()=>message=result.message);
    } catch(e) {
      if(mounted) {
        setState(()=>message='Legacy migration failed safely: '+e.toString());
      }
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user=Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar:AppBar(title:const Text('Cloud & Backup')),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          Card(
            child:ListTile(
              leading:const Icon(Icons.verified_user),
              title:Text(user?.email??user?.phone??'Not signed in'),
              subtitle:const Text(
                'Daily Flutter cloud backup is scheduled every 24 hours when internet is available.',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed:busy
              ?null
              :()=>run(
                ()=>CloudBackupService.instance.backupNow(),
                'Cloud backup completed.',
              ),
            icon:const Icon(Icons.cloud_upload),
            label:const Text('Backup Now'),
          ),
          const SizedBox(height:8),
          OutlinedButton.icon(
            onPressed:busy
              ?null
              :()=>run(
                ()=>CloudBackupService.instance.restoreLatest(),
                'Latest Flutter backup restored into SQLite.',
              ),
            icon:const Icon(Icons.restore),
            label:const Text('Restore Latest Flutter Backup'),
          ),
          const Divider(height:32),
          Text(
            'Legacy QAMVIO Migration',
            style:Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height:8),
          const Text(
            'Use this for the old Android/HTML QAMVIO cloud backup. '
            'Existing Flutter business data is never overwritten.',
          ),
          const SizedBox(height:10),
          TextField(
            controller:legacyPassword,
            obscureText:true,
            enabled:!busy,
            decoration:const InputDecoration(
              labelText:'Original local QAMVIO password',
            ),
          ),
          const SizedBox(height:8),
          OutlinedButton.icon(
            onPressed:busy?null:migrateLegacy,
            icon:const Icon(Icons.move_to_inbox),
            label:const Text('Import Legacy QAMVIO Backup'),
          ),
          const SizedBox(height:8),
          OutlinedButton.icon(
            onPressed:busy
              ?null
              :()async {
                await Supabase.instance.client.auth.signOut();
              },
            icon:const Icon(Icons.logout),
            label:const Text('Sign Out'),
          ),
          if(busy)
            const Padding(
              padding:EdgeInsets.all(16),
              child:Center(child:CircularProgressIndicator()),
            ),
          if(message.isNotEmpty)
            Padding(
              padding:const EdgeInsets.only(top:12),
              child:Text(message),
            ),
        ],
      ),
    );
  }
}
