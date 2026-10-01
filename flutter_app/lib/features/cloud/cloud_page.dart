import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cloud/cloud_backup_service.dart';
class CloudPage extends StatefulWidget{const CloudPage({super.key});@override State<CloudPage> createState()=>_CloudPageState();}
class _CloudPageState extends State<CloudPage>{
 bool busy=false; String message='';
 Future<void> run(Future<dynamic> Function() fn,String ok)async{setState(()=>busy=true);try{final r=await fn();setState(()=>message=(r==false?'No cloud backup was found.':ok));}catch(e){setState(()=>message='Cloud error: '+e.toString());}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context){final u=Supabase.instance.client.auth.currentUser;return Scaffold(appBar:AppBar(title:const Text('Cloud & Backup')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Card(child:ListTile(leading:const Icon(Icons.verified_user),title:Text(u?.email??u?.phone??'Not signed in'),subtitle:const Text('Daily cloud backup is scheduled every 24 hours when internet is available.'))),
  FilledButton.icon(onPressed:busy?null:()=>run(()=>CloudBackupService.instance.backupNow(),'Cloud backup completed.'),icon:const Icon(Icons.cloud_upload),label:const Text('Backup Now')),
  const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:()=>run(()=>CloudBackupService.instance.restoreLatest(),'Latest cloud backup restored into SQLite.'),icon:const Icon(Icons.restore),label:const Text('Restore Latest')),
  const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:()async{await Supabase.instance.client.auth.signOut();},icon:const Icon(Icons.logout),label:const Text('Sign Out')),
  if(busy)const Padding(padding:EdgeInsets.all(16),child:Center(child:CircularProgressIndicator())),if(message.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text(message)),
 ]));}
}