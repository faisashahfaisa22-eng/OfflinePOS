import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_account.dart';
import '../../core/cloud/cloud_backup_service.dart';
import '../../core/migration/legacy_migration_service.dart';
import '../../core/security/local_auth_service.dart' show LocalAuthService;
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

  Future<void> restoreFlow() async {
    final cred=await showDialog<_RestoreCredentials>(
      context:context,
      builder:(_)=>const _RestoreDialog(),
    );
    if(cred==null||!mounted) return;

    final confirmed=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Replace local business data?'),
        content:const Text(
          'Restoring the cloud backup will replace the current Flutter business '
          'tables on this device. This cannot be undone from this screen. '
          'Continue only if the cloud backup is the copy you want to restore.',
        ),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(dialogContext,false),
            child:const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed:()=>Navigator.pop(dialogContext,true),
            icon:const Icon(Icons.restore_rounded),
            label:const Text('Replace & Restore'),
          ),
        ],
      ),
    );
    if(confirmed!=true) return;

    await run(
      ()async {
        final ok=await CloudBackupService.instance.restoreLatest(
          loginId:cred.loginId,
          secret:cred.secret,
          secretIsRecoveryCode:cred.isRecoveryCode,
        );
        if(!ok) throw StateError('No cloud backup found for this cloud account.');
      },
      'Latest Flutter backup restored into SQLite.',
    );
  }

  @override
  Widget build(BuildContext context)=>StreamBuilder<AuthState>(
    stream:Supabase.instance.client.auth.onAuthStateChange,
    builder:(context,_)=>Supabase.instance.client.auth.currentSession==null
      ?Scaffold(
        appBar:AppBar(title:const Text('Cloud & Backup')),
        body:ListView(
          padding:QamvioUi.pagePadding,
          children:const [
            QamvioPageIntro(
              title:'Cloud account',
              subtitle:'Sign in only to back up or restore. QAMVIO itself works fully offline.',
              icon:Icons.cloud_off_rounded,
            ),
            SizedBox(height:18),
            CloudSignInPanel(),
          ],
        ),
      )
      :_buildSignedIn(context),
  );

  Widget _buildSignedIn(BuildContext context) {
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
                    'Encrypt the current local business database and upload the protected backup.',
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
                    'Validate, decrypt and replace local Flutter tables with the selected cloud backup.',
                  ),
                  const SizedBox(height:12),
                  OutlinedButton.icon(
                    onPressed:busy
                      ?null
                      :restoreFlow,
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
                    decoration:InputDecoration(
                      labelText:tr('Original local QAMVIO password'),
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
            label:const Text('Disconnect cloud account'),
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

class _RestoreCredentials {
  final String loginId;
  final String secret;
  final bool isRecoveryCode;
  const _RestoreCredentials(this.loginId,this.secret,this.isRecoveryCode);
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState()=>_RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final id=TextEditingController();
  final secret=TextEditingController();
  bool recovery=false;

  @override
  void dispose() {
    id.dispose();
    secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Unlock the cloud backup'),
    content:Column(
      mainAxisSize:MainAxisSize.min,
      children:[
        const Text('Enter the email/mobile and password (or recovery code) of the account that created the backup. This is what decrypts it.'),
        const SizedBox(height:12),
        TextField(controller:id,decoration:InputDecoration(labelText:tr('Email or mobile'))),
        const SizedBox(height:8),
        TextField(
          controller:secret,
          obscureText:!recovery,
          decoration:InputDecoration(labelText:recovery?'Recovery code':'Password'),
        ),
        SwitchListTile(
          contentPadding:EdgeInsets.zero,
          value:recovery,
          onChanged:(v)=>setState(()=>recovery=v),
          title:const Text('Use recovery code'),
        ),
      ],
    ),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
      FilledButton(
        onPressed:()=>Navigator.pop(context,_RestoreCredentials(id.text,secret.text,recovery)),
        child:const Text('Restore'),
      ),
    ],
  );
}

/// Supabase account used ONLY for cloud backup (not for app login).
class CloudSignInPanel extends StatefulWidget {
  const CloudSignInPanel({super.key});

  @override
  State<CloudSignInPanel> createState()=>_CloudSignInPanelState();
}

/// Connects THIS device to the cloud backup with the same email and the same
/// password used to sign in to QAMVIO (no separate cloud password).
class _CloudSignInPanelState extends State<CloudSignInPanel> {
  final password=TextEditingController();
  final legacy=TextEditingController();
  bool busy=false;
  bool showLegacy=false;
  String message='';

  @override
  void dispose() {
    password.dispose();
    legacy.dispose();
    super.dispose();
  }

  String _text(CloudSignInResult r)=>switch(r){
    CloudSignInResult.signedIn=>'Connected. Your data will be backed up automatically.',
    CloudSignInResult.needsConfirmation=>'Please confirm your email (or SMS) first, then press Connect again.',
    CloudSignInResult.offline=>'No internet connection.',
    CloudSignInResult.existingOtherPassword=>'This email already has a cloud account made with a different password. Open "Older cloud password" below and enter it once.',
    CloudSignInResult.notFound=>'Could not connect. Check your QAMVIO password.',
    CloudSignInResult.failed=>'Cloud error. Please try again.',
  };

  Future<void> submit() async {
    final user=LocalAuthService.instance.current;
    if(user==null) return;
    if(password.text.isEmpty) {
      setState(()=>message='Enter your QAMVIO password.');
      return;
    }
    setState(() {
      busy=true;
      message='';
    });
    try {
      final CloudSignInResult r;
      if(legacy.text.isNotEmpty) {
        r=await CloudAccount.connectWithLegacyPassword(
          loginRaw:user.loginId,
          password:password.text,
          legacyPassword:legacy.text,
        );
      } else {
        r=await CloudAccount.signIn(user.loginId,password.text,createIfMissing:true);
      }
      if(mounted) setState(()=>message=_text(r));
    } catch(e) {
      if(mounted) setState(()=>message='Cloud error: $e');
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user=LocalAuthService.instance.current;
    final primary=LocalAuthService.instance.primaryAdminLoginId;
    if(user==null||user.loginId!=primary) {
      return Card(
        child:Padding(
          padding:const EdgeInsets.all(16),
          child:Text('${tr('Cloud backup is managed by the owner account')} ${primary??''}. ${tr('Sign in with that account to connect it.')}'),
        ),
      );
    }
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Text('Backup account: ${user.loginId}',style:const TextStyle(fontWeight:FontWeight.w800)),
            const SizedBox(height:4),
            const Text('Use the same password you use to sign in to QAMVIO.'),
            const SizedBox(height:10),
            TextField(controller:password,enabled:!busy,obscureText:true,decoration:InputDecoration(labelText:tr('QAMVIO password'))),
            TextButton(
              onPressed:busy?null:()=>setState(()=>showLegacy=!showLegacy),
              child:Text(showLegacy?'Hide older cloud password':'Older cloud password (only if asked)'),
            ),
            if(showLegacy)
              TextField(controller:legacy,enabled:!busy,obscureText:true,decoration:InputDecoration(labelText:tr('Older separate cloud password'))),
            if(message.isNotEmpty) Padding(padding:const EdgeInsets.only(top:10),child:Text(message)),
            const SizedBox(height:12),
            FilledButton(onPressed:busy?null:submit,child:const Text('Connect cloud backup')),
          ],
        ),
      ),
    );
  }
}
