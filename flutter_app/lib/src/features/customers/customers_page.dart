import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override State<CustomersPage> createState() => _CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage> {
  Future<List<Map<String,Object?>>> load() async {
    final db=await AppDatabase.instance.database;
    return db.query('customers',orderBy:'name COLLATE NOCASE');
  }
  Future<void> addCustomer() async {
    final name=TextEditingController(), phone=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Add Customer'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Customer name')),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile number')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))],
    ));
    if(ok!=true||name.text.trim().isEmpty)return;
    final now=DateTime.now().toUtc().toIso8601String(), db=await AppDatabase.instance.database;
    await db.insert('customers',{'id':'c_${DateTime.now().microsecondsSinceEpoch}','name':name.text.trim(),'phone':phone.text.trim(),'created_at':now,'updated_at':now});
    setState((){});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Customers')),
    floatingActionButton:FloatingActionButton.extended(onPressed:addCustomer,icon:const Icon(Icons.person_add),label:const Text('Add Customer')),
    body:FutureBuilder<List<Map<String,Object?>>>(future:load(),builder:(context,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      if(snap.data!.isEmpty)return const Center(child:Text('No customers yet'));
      return ListView.builder(itemCount:snap.data!.length,itemBuilder:(_,i){final x=snap.data![i];return ListTile(title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}'),trailing:Text('Balance ${x['balance']}'));});
    }),
  );
}
