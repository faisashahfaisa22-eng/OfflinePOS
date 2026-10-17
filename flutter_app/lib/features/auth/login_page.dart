import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

enum _Mode { login, create, recover }

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
    mode=auth.hasAccounts?_Mode.login:_Mode.create;
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
    if(mode!=_Mode.login&&password.text!=confirm.text) {
      setState(()=>message='Passwords do not match.');
      return;
    }
    setState(()=>busy=true);
    try {
      switch(mode) {
        case _Mode.login:
          await auth.login(id.text,password.text);
        case _Mode.create:
          final code=await auth.createFirstAccount(id.text,password.text);
          if(mounted) await _showRecoveryCode(code);
        case _Mode.recover:
          final code=await auth.resetPasswordWithRecovery(id.text,recovery.text,password.text);
          if(mounted) await _showRecoveryCode(code);
      }
    } on AuthException catch(e) {
      if(mounted) setState(()=>message=e.message);
    } catch(e) {
      if(mounted) setState(()=>message='Error: $e');
    } finally {
      if(mounted) setState(()=>busy=false);
    }
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
                              helperText:mode==_Mode.login?null:'Min 8 characters, with a letter and a number',
                            ),
                          ),
                          if(mode!=_Mode.login) ...[
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
                              onPressed:busy?null:()=>_switch(_Mode.login),
                              icon:const Icon(Icons.login_rounded),
                              label:const Text('Sign in'),
                            ),
                          ],
                          if(mode==_Mode.login&&auth.hasAccounts)
                            TextButton(
                              onPressed:busy?null:()=>_switch(_Mode.recover),
                              child:const Text('Forgot password? Use recovery code'),
                            ),
                          if(mode==_Mode.login&&!auth.hasAccounts)
                            Padding(
                              padding:const EdgeInsets.only(top:2),
                              child:Text(
                                'Sign in works with an account already saved on this device.',
                                textAlign:TextAlign.center,
                                style:Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if(mode==_Mode.login&&!auth.hasAccounts)
                            TextButton(
                              onPressed:busy?null:()=>_switch(_Mode.create),
                              child:const Text('New here? Create admin account'),
                            ),
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
