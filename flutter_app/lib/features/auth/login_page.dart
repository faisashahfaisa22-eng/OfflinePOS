import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/qamvio_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState()=>_LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final id=TextEditingController();
  final password=TextEditingController();
  bool signup=false;
  bool busy=false;
  bool obscure=true;
  String message='';

  bool get isPhone=>id.text.trim().startsWith('+');

  @override
  void dispose() {
    id.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value=id.text.trim();
    if(value.isEmpty || password.text.length<8) {
      setState(()=>message='Enter a valid email/mobile and a password of at least 8 characters.');
      return;
    }
    setState(() {
      busy=true;
      message='';
    });
    try {
      final auth=Supabase.instance.client.auth;
      if(signup) {
        if(isPhone) {
          await auth.signUp(phone:value,password:password.text);
          if(mounted) {
            setState(()=>message='Account created. Verify the SMS code when phone authentication is enabled.');
          }
        } else {
          await auth.signUp(email:value,password:password.text);
          if(mounted) {
            setState(()=>message='Account created. Confirm your email, then sign in.');
          }
        }
      } else {
        if(isPhone) {
          await auth.signInWithPassword(phone:value,password:password.text);
        } else {
          await auth.signInWithPassword(email:value,password:password.text);
        }
      }
    } on AuthException catch(e) {
      if(mounted) setState(()=>message=e.message);
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    body:SafeArea(
      child:Center(
        child:SingleChildScrollView(
          padding:const EdgeInsets.all(20),
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:480),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                Container(
                  padding:const EdgeInsets.all(22),
                  decoration:BoxDecoration(
                    gradient:const LinearGradient(
                      colors:[Color(0xFF174EA6),Color(0xFF356FD2)],
                      begin:Alignment.topLeft,
                      end:Alignment.bottomRight,
                    ),
                    borderRadius:BorderRadius.circular(28),
                    boxShadow:const [
                      BoxShadow(
                        blurRadius:28,
                        offset:Offset(0,14),
                        color:Color(0x26174EA6),
                      ),
                    ],
                  ),
                  child:Column(
                    children:[
                      Container(
                        width:72,
                        height:72,
                        decoration:BoxDecoration(
                          color:Colors.white.withValues(alpha:.14),
                          borderRadius:BorderRadius.circular(22),
                        ),
                        child:const Icon(
                          Icons.storefront_rounded,
                          size:38,
                          color:Colors.white,
                        ),
                      ),
                      const SizedBox(height:16),
                      const Text(
                        'QAMVIO POS',
                        style:TextStyle(
                          color:Colors.white,
                          fontSize:30,
                          fontWeight:FontWeight.w900,
                          letterSpacing:.2,
                        ),
                      ),
                      const SizedBox(height:6),
                      Text(
                        'Offline-first sales, inventory and accounts',
                        textAlign:TextAlign.center,
                        style:TextStyle(
                          color:Colors.white.withValues(alpha:.84),
                          fontSize:15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height:22),
                Card(
                  child:Padding(
                    padding:const EdgeInsets.all(20),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.stretch,
                      children:[
                        Text(
                          signup?'Create your account':'Welcome back',
                          style:Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight:FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height:5),
                        Text(
                          signup
                            ?'Set up secure cloud access for your QAMVIO business.'
                            :'Sign in to access your business and cloud protection.',
                          style:Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:const Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height:20),
                        TextField(
                          controller:id,
                          enabled:!busy,
                          keyboardType:TextInputType.emailAddress,
                          decoration:const InputDecoration(
                            labelText:'Email or mobile number',
                            hintText:'you@example.com or +93...',
                            prefixIcon:Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height:12),
                        TextField(
                          controller:password,
                          enabled:!busy,
                          obscureText:obscure,
                          onSubmitted:(_)=>busy?null:submit(),
                          decoration:InputDecoration(
                            labelText:'Password',
                            prefixIcon:const Icon(Icons.lock_outline_rounded),
                            suffixIcon:IconButton(
                              tooltip:obscure?'Show password':'Hide password',
                              onPressed:()=>setState(()=>obscure=!obscure),
                              icon:Icon(
                                obscure
                                  ?Icons.visibility_outlined
                                  :Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height:16),
                        FilledButton.icon(
                          onPressed:busy?null:submit,
                          icon:busy
                            ?const SizedBox(
                              width:18,
                              height:18,
                              child:CircularProgressIndicator(strokeWidth:2),
                            )
                            :Icon(signup?Icons.person_add_alt_1_rounded:Icons.login_rounded),
                          label:Text(
                            busy
                              ?'Please wait…'
                              :(signup?'Create Account':'Sign In'),
                          ),
                        ),
                        const SizedBox(height:8),
                        TextButton(
                          onPressed:busy
                            ?null
                            :()=>setState(() {
                              signup=!signup;
                              message='';
                            }),
                          child:Text(
                            signup
                              ?'Already have an account? Sign in'
                              :'New to QAMVIO? Create an account',
                          ),
                        ),
                        if(message.isNotEmpty) ...[
                          const SizedBox(height:10),
                          Container(
                            padding:const EdgeInsets.all(12),
                            decoration:BoxDecoration(
                              color:const Color(0xFFF1F4F8),
                              borderRadius:BorderRadius.circular(14),
                            ),
                            child:Row(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children:[
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size:20,
                                  color:QamvioUi.brand,
                                ),
                                const SizedBox(width:8),
                                Expanded(child:Text(message)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height:18),
                const Row(
                  mainAxisAlignment:MainAxisAlignment.center,
                  children:[
                    Icon(Icons.offline_bolt_outlined,size:18,color:Color(0xFF667085)),
                    SizedBox(width:6),
                    Text(
                      'Business operations remain offline-first',
                      style:TextStyle(color:Color(0xFF667085)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
