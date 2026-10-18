import 'package:flutter/material.dart';
import '../../core/repositories/business_repository.dart';

class SettingsPage extends StatefulWidget { const SettingsPage({super.key}); @override State<SettingsPage> createState()=>_SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage>{
 final repo=BusinessRepository(); final name=TextEditingController(),currency=TextEditingController(),phone=TextEditingController(),address=TextEditingController(),footer=TextEditingController();
 String type='general_store';
 static const types=['general_store','retail_store','pharmacy','oil_pump','wholesale','services'];
 @override void initState(){super.initState();load();}
 Future<void> load()async{final s=await repo.settings();name.text=s['business_name'] as String? ??'';currency.text=s['currency'] as String? ??'AFN';phone.text=s['phone'] as String? ??'';address.text=s['address'] as String? ??'';footer.text=s['invoice_footer'] as String? ??'';type=s['business_type'] as String? ??'general_store';if(mounted)setState((){});}
 Future<void> save()async{await repo.saveSettings({'business_name':name.text.trim(),'business_type':type,'currency':currency.text.trim(),'phone':phone.text.trim(),'address':address.text.trim(),'invoice_footer':footer.text.trim()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Settings saved')));}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Settings / Business Type')),body:ListView(padding:const EdgeInsets.all(16),children:[
  TextField(controller:name,decoration:const InputDecoration(labelText:'Business Name')),const SizedBox(height:10),
  DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Business Type'),items:types.map((x)=>DropdownMenuItem(value:x,child:Text(x.replaceAll('_',' ').toUpperCase()))).toList(),onChanged:(v)=>setState(()=>type=v!)),const SizedBox(height:10),
  TextField(controller:currency,decoration:const InputDecoration(labelText:'Currency')),const SizedBox(height:10),
  TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),const SizedBox(height:10),
  TextField(controller:address,decoration:const InputDecoration(labelText:'Address')),const SizedBox(height:10),
  TextField(controller:footer,decoration:const InputDecoration(labelText:'Invoice Footer')),const SizedBox(height:16),
  FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('Save Settings')),
 ]));
}
