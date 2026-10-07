import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';

import '../../core/migration/legacy_migration_service.dart';
import '../../core/ui/qamvio_ui.dart';
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
  bool obscure=true;
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
    setState(() {
      busy=true;
      message='';
    });
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
        setState(()=>message='Migration failed safely: $e');
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
          body:SafeArea(
            child:Center(
              child:SingleChildScrollView(
                padding:const EdgeInsets.all(20),
                child:ConstrainedBox(
                  constraints:const BoxConstraints(maxWidth:560),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.stretch,
                    children:[
                      const QamvioPageIntro(
                        title:'Legacy Backup Found',
                        subtitle:'Move your old QAMVIO business data into the new Flutter database safely.',
                        icon:Icons.move_to_inbox_rounded,
                      ),
                      const SizedBox(height:18),
                      Card(
                        child:Padding(
                          padding:const EdgeInsets.all(18),
                          child:Column(
                            crossAxisAlignment:CrossAxisAlignment.stretch,
                            children:[
                              Text(
                                'Protected migration',
                                style:Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight:FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height:6),
                              Text(
                                'Your old encrypted cloud backup is opened only with the original local QAMVIO password. The Flutter business database must be empty before import.',
                                style:Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color:const Color(0xFF667085),
                                  height:1.4,
                                ),
                              ),
                              const SizedBox(height:16),
                              _safetyRow(
                                context,
                                Icons.lock_outline_rounded,
                                'Encrypted backup remains protected',
                              ),
                              const SizedBox(height:10),
                              _safetyRow(
                                context,
                                Icons.sync_alt_rounded,
                                'Import runs in one SQLite transaction',
                              ),
                              const SizedBox(height:10),
                              _safetyRow(
                                context,
                                Icons.fact_check_outlined,
                                'Row counts are validated before commit',
                              ),
                              const SizedBox(height:10),
                              _safetyRow(
                                context,
                                Icons.cloud_done_outlined,
                                'Old cloud backup is never deleted or overwritten',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height:16),
                      TextField(
                        controller:password,
                        obscureText:obscure,
                        enabled:!busy,
                        decoration:InputDecoration(
                          labelText:'Original local QAMVIO password',
                          helperText:'This may differ from your cloud account password.',
                          prefixIcon:const Icon(Icons.lock_outline_rounded),
                          suffixIcon:IconButton(
                            onPressed:busy
                              ?null
                              :()=>setState(()=>obscure=!obscure),
                            icon:Icon(
                              obscure
                                ?Icons.visibility_outlined
                                :Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height:14),
                      FilledButton.icon(
                        onPressed:busy?null:migrate,
                        icon:busy
                          ?const SizedBox(
                            width:18,
                            height:18,
                            child:CircularProgressIndicator(strokeWidth:2),
                          )
                          :const Icon(Icons.shield_outlined),
                        label:Text(
                          busy
                            ?'Migrating & validating…'
                            :'Import Legacy Data Safely',
                        ),
                      ),
                      const SizedBox(height:8),
                      OutlinedButton.icon(
                        onPressed:busy
                          ?null
                          :()=>setState(()=>continueWithoutImport=true),
                        icon:const Icon(Icons.schedule_rounded),
                        label:const Text('Continue Without Importing Now'),
                      ),
                      if(message.isNotEmpty) ...[
                        const SizedBox(height:16),
                        Card(
                          child:Padding(
                            padding:const EdgeInsets.all(16),
                            child:Row(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children:[
                                Icon(
                                  message.toLowerCase().contains('failed')
                                    ?Icons.error_outline_rounded
                                    :Icons.info_outline_rounded,
                                  color:message.toLowerCase().contains('failed')
                                    ?QamvioUi.danger
                                    :QamvioUi.brand,
                                ),
                                const SizedBox(width:10),
                                Expanded(child:Text(message)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _safetyRow(
    BuildContext context,
    IconData icon,
    String text,
  )=>Row(
    children:[
      Container(
        width:36,
        height:36,
        decoration:BoxDecoration(
          color:const Color(0xFFEAF7F1),
          borderRadius:BorderRadius.circular(12),
        ),
        child:Icon(icon,size:19,color:QamvioUi.success),
      ),
      const SizedBox(width:10),
      Expanded(
        child:Text(
          text,
          style:const TextStyle(fontWeight:FontWeight.w700),
        ),
      ),
    ],
  );
}
