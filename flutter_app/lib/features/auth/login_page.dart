import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final id = TextEditingController();
  final password = TextEditingController();
  bool signup = false, busy = false;
  String message = '';

  bool get isPhone => id.text.trim().startsWith('+');

  Future<void> submit() async {
    final value=id.text.trim();
    if(value.isEmpty || password.text.length<8){
      setState(()=>message='Enter a valid email/mobile and a password of at least 8 characters.');
      return;
    }
    setState(()=>busy=true);
    try {
      final auth=Supabase.instance.client.auth;
      if(signup){
        if(isPhone) {
          await auth.signUp(phone:value,password:password.text);
          setState(()=>message='Account created. Verify the SMS code when phone authentication is enabled.');
        } else {
          await auth.signUp(email:value,password:password.text);
          setState(()=>message='Account created. Confirm your email, then sign in.');
        }
      } else {
        if(isPhone) {
          await auth.signInWithPassword(phone:value,password:password.text);
        } else {
          await auth.signInWithPassword(email:value,password:password.text);
        }
      }
    } on AuthException catch(e) {
      setState(()=>message=e.message);
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QAMVIO Account')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth:460),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min,
        children:[
          Text(signup?'Create QAMVIO Account':'Sign in to QAMVIO',style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:18),
          TextField(controller:id,decoration:const InputDecoration(labelText:'Email or mobile number',hintText:'you@example.com or +93...')),
          const SizedBox(height:12),
          TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
          const SizedBox(height:14),
          FilledButton(onPressed:busy?null:submit,child:Text(busy?'Please wait…':(signup?'Sign Up':'Login'))),
          TextButton(onPressed:busy?null:()=>setState(()=>signup=!signup),child:Text(signup?'Already have an account? Login':'Create new account')),
          if(message.isNotEmpty) Padding(padding:const EdgeInsets.only(top:10),child:Text(message,textAlign:TextAlign.center)),
        ],
      )),
    )),
  );
}
