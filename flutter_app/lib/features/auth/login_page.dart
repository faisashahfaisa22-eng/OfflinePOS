import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cloud/cloud_account.dart';
import '../../core/cloud/cloud_backup_service.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

enum _Mode { login, create, recover, restore }

/// Offline sign-in with email or mobile + local password. No internet needed.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState()=>_LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth=LocalAuthService.instance;
  final id=TextEditingController();
  final password=TextEditingController();
  final confirm=TextEditingController();
  final recovery=TextEditingController();
  late _Mode mode;
  bool busy=false;
  bool obscure=true;
  String message='';

  @override
  void initState() {
    super.initState();
    mode=auth.hasAccounts?_Mode.login:_Mode.restore;
  }

  @override
  void dispose() {
    id.dispose();
    password.dispose();
    confirm.dispose();
    recovery.dispose();
    super.dispose();
  }

  void _switch(_Mode m) {
    setState(() {
      mode=m;
      message='';
      password.clear();
      confirm.clear();
      recovery.clear();
    });
  }

  Future<void> submit() async {
    setState(()=>message='');
    final idErr=LocalAuthService.validateLoginId(id.text);
    if(idErr!=null) {
      setState(()=>message=idErr);
      return;
    }
    if((mode==_Mode.create||mode==_Mode.recover)&&password.text!=confirm.text) {
      setState(()=>message='Passwords do not match.');
      return;
    }
    setState(()=>busy=true);
    try {
      switch(mode) {
        case _Mode.login:
          await auth.login(id.text,password.text);
          unawaited(CloudAccount.syncAfterLogin(id.text,password.text));
        case _Mode.create:
          if(await _offerRestoreInstead()) return;
          final code=await auth.createFirstAccount(id.text,password.text);
          unawaited(CloudAccount.syncAfterLogin(id.text,password.text));
          if(mounted) await _showRecoveryCode(code);
        case _Mode.recover:
          final code=await auth.resetPasswordWithRecovery(id.text,recovery.text,password.text);
          unawaited(CloudAccount.syncAfterLogin(id.text,password.text));
          if(mounted) await _showRecoveryCode(code);
        case _Mode.restore:
          await _restoreFromCloud();
      }
    } on AuthException catch(e) {
      if(mounted) setState(()=>message=e.message);
    } catch(e) {
      if(mounted) setState(()=>message='Error: $e');
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  String _cloudMessage(CloudSignInResult r)=>switch(r){
    CloudSignInResult.needsConfirmation=>
      'Please confirm your email (or SMS) first, then try again.',
    CloudSignInResult.offline=>
      'No internet connection. Connect to the internet to find your account.',
    CloudSignInResult.existingOtherPassword=>
      'An account with this email already exists, but with a different password. Enter the password you used before.',
    CloudSignInResult.notFound=>
      'No account found for this email and password.',
    _=>'Could not reach the cloud. Please try again.',
  };

  String _fmt(DateTime t)=>
    '${t.year}-${t.month.toString().padLeft(2,'0')}-${t.day.toString().padLeft(2,'0')} '
    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  /// Finds the account in the cloud, tells the user a backup exists, and
  /// restores accounts + business data after the user confirms.
  Future<void> _restoreFromCloud({bool alreadyConfirmed=false}) async {
    if(alreadyConfirmed) {
      final ok=await CloudBackupService.instance.restoreFreshInstall(
        loginId:id.text,
        password:password.text,
      );
      if(!ok&&mounted) setState(()=>message='No backup found for this account.');
      return;
    }
    final r=await CloudAccount.signIn(id.text,password.text);
    if(r!=CloudSignInResult.signedIn) {
      if(mounted) setState(()=>message=_cloudMessage(r));
      return;
    }
    final when=await CloudAccount.latestBackupTime();
    if(when==null) {
      if(mounted) {
        setState(()=>message='Your cloud account exists, but it has no backup yet. You can create a new account instead.');
      }
      return;
    }
    if(!mounted) return;
    final go=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        icon:const Icon(Icons.cloud_done_rounded,size:36),
        title:const Text('You already have an account'),
        content:Text(
          'We found your account ${LocalAuthService.normalizeLoginId(id.text)} with a backup from ${_fmt(when)}.\n\n'
          'Restore it on this device? Your sales, stock, customers and all users will come back, and you sign in with the same password.',
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Not now')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Restore my account')),
        ],
      ),
    );
    if(go!=true) return;
    final ok=await CloudBackupService.instance.restoreFreshInstall(
      loginId:id.text,
      password:password.text,
    );
    if(!ok&&mounted) setState(()=>message='No backup found for this account.');
    // On success LocalAuthService notifies and the app opens the dashboard.
  }

  /// Before creating a brand-new account, check quietly (when online) whether
  /// this email already has a cloud backup, and offer to restore it instead.
  /// Returns true when the restore flow took over (so no new account is made).
  Future<bool> _offerRestoreInstead() async {
    DateTime? when;
    try {
      final r=await CloudAccount.signIn(id.text,password.text);
      if(r!=CloudSignInResult.signedIn) return false;
      when=await CloudAccount.latestBackupTime();
    } catch(_) {
      return false; // offline or cloud unreachable: just create the account
    }
    if(when==null||!mounted) return false;
    final DateTime at=when;
    final restore=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        icon:const Icon(Icons.cloud_done_rounded,size:36),
        title:const Text('You already have an account'),
        content:Text(
          'A backup from ${_fmt(at)} exists for this email.\n\n'
          'Restore it instead of starting empty? If you create a new account, '
          'the next cloud backup will REPLACE that old backup.',
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Create new anyway')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Restore my account')),
        ],
      ),
    );
    if(restore!=true) return false;
    await _restoreFromCloud(alreadyConfirmed:true); // errors show on screen; we must NOT create a new account
    return true;
  }

  Future<void> _showRecoveryCode(String code) async {
    await showDialog<void>(
      context:context,
      barrierDismissible:false,
      builder:(ctx)=>RecoveryCodeDialog(code:code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title=switch(mode){
      _Mode.login=>'Sign in',
      _Mode.create=>'Create admin account',
      _Mode.recover=>'Reset password',
      _Mode.restore=>'Find my account',
    };
    return Scaffold(
      body:SafeArea(
        child:Center(
          child:SingleChildScrollView(
            padding:const EdgeInsets.all(20),
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:460),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  QamvioPageIntro(
                    title:'QAMVIO POS',
                    subtitle:mode==_Mode.create
                      ?'Your business data is encrypted on this device with your password.'
                      :mode==_Mode.restore
                        ?'Already used QAMVIO before? Enter your email and password to bring your account and data back.'
                        :'Works fully offline. Enter your email or mobile and password.',
                    icon:Icons.lock_rounded,
                  ),
                  const SizedBox(height:18),
                  Card(
                    child:Padding(
                      padding:const EdgeInsets.all(18),
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.stretch,
                        children:[
                          Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
                          const SizedBox(height:14),
                          TextField(
                            controller:id,
                            enabled:!busy,
                            keyboardType:TextInputType.emailAddress,
                            autocorrect:false,
                            decoration:const InputDecoration(labelText:'Email or mobile (+93...)',prefixIcon:Icon(Icons.person_outline_rounded)),
                          ),
                          if(mode==_Mode.recover) ...[
                            const SizedBox(height:12),
                            TextField(
                              controller:recovery,
                              enabled:!busy,
                              autocorrect:false,
                              textCapitalization:TextCapitalization.characters,
                              decoration:const InputDecoration(labelText:'Recovery code',prefixIcon:Icon(Icons.key_rounded)),
                            ),
                          ],
                          const SizedBox(height:12),
                          TextField(
                            controller:password,
                            enabled:!busy,
                            obscureText:obscure,
                            decoration:InputDecoration(
                              labelText:mode==_Mode.recover?'New password':'Password',
                              prefixIcon:const Icon(Icons.lock_outline_rounded),
                              suffixIcon:IconButton(
                                tooltip:obscure?'Show password':'Hide password',
                                icon:Icon(obscure?Icons.visibility_rounded:Icons.visibility_off_rounded),
                                onPressed:()=>setState(()=>obscure=!obscure),
                              ),
                              helperText:(mode==_Mode.login||mode==_Mode.restore)?null:'Min 8 characters, with a letter and a number',
                            ),
                          ),
                          if(mode==_Mode.create||mode==_Mode.recover) ...[
                            const SizedBox(height:12),
                            TextField(
                              controller:confirm,
                              enabled:!busy,
                              obscureText:obscure,
                              decoration:const InputDecoration(labelText:'Confirm password',prefixIcon:Icon(Icons.lock_outline_rounded)),
                            ),
                          ],
                          if(message.isNotEmpty) ...[
                            const SizedBox(height:12),
                            Text(message,style:const TextStyle(color:QamvioUi.danger,fontWeight:FontWeight.w600)),
                          ],
                          const SizedBox(height:16),
                          FilledButton(
                            onPressed:busy?null:submit,
                            child:busy
                              ?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))
                              :Text(title),
                          ),
                          if(busy) const Padding(
                            padding:EdgeInsets.only(top:8),
                            child:Text('Deriving your encryption key... this takes a few seconds.',textAlign:TextAlign.center),
                          ),
                          const SizedBox(height:12),
                          if(mode==_Mode.create) ...[
                            const Divider(height:20),
                            const SizedBox(height:4),
                            Text(
                              'Already have an account?',
                              textAlign:TextAlign.center,
                              style:Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight:FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height:8),
                            OutlinedButton.icon(
                              onPressed:busy?null:()=>_switch(auth.hasAccounts?_Mode.login:_Mode.restore),
                              icon:const Icon(Icons.cloud_download_rounded),
                              label:Text(auth.hasAccounts?'Sign in':'Find my existing account'),
                            ),
                          ],
                          if(mode==_Mode.login&&auth.hasAccounts)
                            TextButton(
                              onPressed:busy?null:()=>_switch(_Mode.recover),
                              child:const Text('Forgot password? Use recovery code'),
                            ),
                          if(mode==_Mode.restore) ...[
                            const Divider(height:20),
                            OutlinedButton.icon(
                              onPressed:busy?null:()=>_switch(_Mode.create),
                              icon:const Icon(Icons.add_circle_outline_rounded),
                              label:const Text("I'm new - create a new account"),
                            ),
                          ],
                          if(mode==_Mode.recover)
                            TextButton(onPressed:busy?null:()=>_switch(_Mode.login),child:const Text('Back to sign in')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a recovery code ONCE. The user must confirm they saved it.
class RecoveryCodeDialog extends StatefulWidget {
  final String code;
  const RecoveryCodeDialog({required this.code,super.key});

  @override
  State<RecoveryCodeDialog> createState()=>_RecoveryCodeDialogState();
}

class _RecoveryCodeDialogState extends State<RecoveryCodeDialog> {
  bool saved=false;

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Save your recovery code'),
    content:Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text(
          'This code is the ONLY way to reset your password without losing your data. '
          'It is shown once. Write it down and keep it somewhere safe, away from this phone.',
        ),
        const SizedBox(height:14),
        Center(
          child:SelectableText(
            widget.code,
            style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,letterSpacing:1.5),
          ),
        ),
        const SizedBox(height:6),
        Center(
          child:TextButton.icon(
            onPressed:()=>Clipboard.setData(ClipboardData(text:widget.code)),
            icon:const Icon(Icons.copy_rounded),
            label:const Text('Copy'),
          ),
        ),
        CheckboxListTile(
          contentPadding:EdgeInsets.zero,
          value:saved,
          onChanged:(v)=>setState(()=>saved=v??false),
          title:const Text('I have saved this code'),
          controlAffinity:ListTileControlAffinity.leading,
        ),
      ],
    ),
    actions:[
      FilledButton(
        onPressed:saved?()=>Navigator.pop(context):null,
        child:const Text('Continue'),
      ),
    ],
  );
}
