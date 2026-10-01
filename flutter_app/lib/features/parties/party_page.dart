import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';

enum PartyType { customer, supplier }

class PartyPage extends StatefulWidget {
  final PartyType type;
  const PartyPage({required this.type, super.key});
  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  List<Map<String, Object?>> rows = const [];
  bool loading = true;
  bool get customer => widget.type == PartyType.customer;

  Future<void> load() async {
    final data = customer ? await AppDatabase.instance.customers() : await AppDatabase.instance.suppliers();
    if (mounted) setState(() { rows = data; loading = false; });
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> add() async {
    final name=TextEditingController(), phone=TextEditingController(), address=TextEditingController();
    final ok=await showDialog<bool>(context: context,builder:(context)=>AlertDialog(
      title: Text(LanguageController.instance.strings.t(customer?'addCustomer':'addSupplier')),
      content: Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('name'))),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('phone'))),
        TextField(controller:address,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('address'))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(LanguageController.instance.strings.t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(LanguageController.instance.strings.t('save')))],
    ));
    if(ok!=true||name.text.trim().isEmpty)return;
    final id=DateTime.now().microsecondsSinceEpoch.toString();
    if(customer){
      await AppDatabase.instance.saveCustomer(id:id,name:name.text,phone:phone.text,address:address.text);
    }else{
      await AppDatabase.instance.saveSupplier(id:id,name:name.text,phone:phone.text,address:address.text);
    }
    await load();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(LanguageController.instance.strings.t(customer?'customers':'suppliers'))),
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:Text(LanguageController.instance.strings.t(customer?'addCustomer':'addSupplier'))),
    body:loading?const Center(child:CircularProgressIndicator()):
      rows.isEmpty?Center(child:Text(LanguageController.instance.strings.t(customer?'noCustomers':'noSuppliers'))):
      ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){
        final x=rows[i];
        return ListTile(leading:CircleAvatar(child:Icon(customer?Icons.person:Icons.local_shipping)),
          title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}\n${x['address']??''}'),isThreeLine:true,
          trailing:Text('Balance: ${x['balance']??0}'));
      }),
  );
}
