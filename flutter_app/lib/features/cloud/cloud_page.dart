import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_backup_service.dart';
import '../../core/migration/legacy_migration_service.dart';
import '../../core/ui/qamvio_ui.dart';

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
    setState(() {
      busy=true;
      message='';
    });
    try {
      final result=await fn();
      if(!mounted) return;
      setState(()=>message=result==false?'No cloud backup was found.':ok);
    } catch(e) {
      if(mounted) setState(()=>message='Cloud error: $e');
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> migrateLegacy() async {
    setState(() {
      busy=true;
      message='';
    });
    try {
      final result=await LegacyMigrationService.instance.migrateFromLegacyCloud(
        legacyPassword:legacyPassword.text,
      );
      if(!mounted) return;
      setState(()=>message=result.message);
    } catch(e) {
      if(mounted) {
        setState(()=>message='Legacy migration failed safely: $e');
      }
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user=Supabase.instance.client.auth.currentUser;
    final account=user?.email??user?.phone??'Not signed in';
    return Scaffold(
      appBar:AppBar(title:const Text('Cloud & Backup')),
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioPageIntro(
            title:'Cloud & Backup',
            subtitle:'Protect business data, restore devices and migrate legacy QAMVIO backups.',
            icon:Icons.cloud_done_rounded,
          ),
          const SizedBox(height:18),
          const QamvioSectionTitle(
            'Account & protection',
            subtitle:'Cloud operations are linked to your signed-in QAMVIO account',
          ),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(16),
              child:Column(
                children:[
                  Row(
                    children:[
                      Container(
                        width:48,
                        height:48,
                        decoration:BoxDecoration(
                          color:const Color(0xFFEAF7F1),
                          borderRadius:BorderRadius.circular(16),
                        ),
                        child:const Icon(
                          Icons.verified_user_rounded,
                          color:QamvioUi.success,
                        ),
                      ),
                      const SizedBox(width:12),
                      Expanded(
                        child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:[
                            const Text(
                              'Signed-in account',
                              style:TextStyle(fontWeight:FontWeight.w700),
                            ),
                            const SizedBox(height:2),
                            Text(
                              account,
                              maxLines:1,
                              overflow:TextOverflow.ellipsis,
                              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                                color:const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,color:QamvioUi.success),
                    ],
                  ),
                  const Divider(height:26),
                  const Row(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Icon(Icons.schedule_rounded,color:Color(0xFF667085)),
                      SizedBox(width:10),
                      Expanded(
                        child:Text(
                          'A Flutter cloud backup is scheduled every 24 hours when internet is available.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height:18),
          const QamvioSectionTitle(
            'Flutter backup',
            subtitle:'Create or restore the current Flutter database',
          ),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(16),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  _feature(
                    context,
                    Icons.cloud_upload_outlined,
                    'Backup now',
                    'Upload the current local SQLite business database to cloud backup.',
                  ),
                  const SizedBox(height:12),
                  FilledButton.icon(
                    onPressed:busy
                      ?null
                      :()=>run(
                        ()=>CloudBackupService.instance.backupNow(),
                        'Cloud backup completed.',
                      ),
                    icon:const Icon(Icons.cloud_upload_rounded),
                    label:const Text('Backup Now'),
                  ),
                  const Divider(height:28),
                  _feature(
                    context,
                    Icons.restore_rounded,
                    'Restore latest',
                    'Replace local Flutter tables with the latest validated Flutter backup.',
                  ),
                  const SizedBox(height:12),
                  OutlinedButton.icon(
                    onPressed:busy
                      ?null
                      :()=>run(
                        ()=>CloudBackupService.instance.restoreLatest(),
                        'Latest Flutter backup restored into SQLite.',
                      ),
                    icon:const Icon(Icons.restore_rounded),
                    label:const Text('Restore Latest Flutter Backup'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height:22),
          const QamvioSectionTitle(
            'Legacy QAMVIO migration',
            subtitle:'For the old Android / HTML QAMVIO encrypted cloud backup',
          ),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(16),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  Container(
                    padding:const EdgeInsets.all(12),
                    decoration:BoxDecoration(
                      color:const Color(0xFFFFF7E8),
                      borderRadius:BorderRadius.circular(14),
                      border:Border.all(color:const Color(0xFFFFE2A8)),
                    ),
                    child:const Row(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        Icon(Icons.shield_outlined,color:QamvioUi.warning),
                        SizedBox(width:10),
                        Expanded(
                          child:Text(
                            'Migration refuses to overwrite existing Flutter business data. Keep the old app until real records and balances are verified.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height:14),
                  TextField(
                    controller:legacyPassword,
                    obscureText:true,
                    enabled:!busy,
                    decoration:const InputDecoration(
                      labelText:'Original local QAMVIO password',
                      prefixIcon:Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height:12),
                  OutlinedButton.icon(
                    onPressed:busy?null:migrateLegacy,
                    icon:const Icon(Icons.move_to_inbox_rounded),
                    label:const Text('Import Legacy QAMVIO Backup'),
                  ),
                ],
              ),
            ),
          ),
          if(busy) ...[
            const SizedBox(height:18),
            const Card(
              child:Padding(
                padding:EdgeInsets.all(18),
                child:Row(
                  children:[
                    SizedBox(
                      width:22,
                      height:22,
                      child:CircularProgressIndicator(strokeWidth:2.5),
                    ),
                    SizedBox(width:12),
                    Text(
                      'Working… please keep QAMVIO open.',
                      style:TextStyle(fontWeight:FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if(message.isNotEmpty) ...[
            const SizedBox(height:18),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(16),
                child:Row(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Icon(
                      message.toLowerCase().contains('error')||
                      message.toLowerCase().contains('failed')
                        ?Icons.error_outline_rounded
                        :Icons.check_circle_outline_rounded,
                      color:message.toLowerCase().contains('error')||
                      message.toLowerCase().contains('failed')
                        ?QamvioUi.danger
                        :QamvioUi.success,
                    ),
                    const SizedBox(width:10),
                    Expanded(child:Text(message)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height:22),
          OutlinedButton.icon(
            onPressed:busy
              ?null
              :()async {
                await Supabase.instance.client.auth.signOut();
              },
            icon:const Icon(Icons.logout_rounded),
            label:const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  )=>Row(
    crossAxisAlignment:CrossAxisAlignment.start,
    children:[
      Container(
        width:44,
        height:44,
        decoration:BoxDecoration(
          color:Theme.of(context).colorScheme.primaryContainer,
          borderRadius:BorderRadius.circular(14),
        ),
        child:Icon(
          icon,
          color:Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(width:12),
      Expanded(
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:2),
            Text(
              subtitle,
              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                color:const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
