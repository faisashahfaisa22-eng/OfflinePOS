import 'package:flutter/material.dart';
import '../../core/repositories/business_repository.dart';

class LoansPage extends StatefulWidget { const LoansPage({super.key}); @override State<LoansPage> createState()=>_LoansPageState(); }
class _LoansPageState extends State<LoansPage>{
 final repo=BusinessRepository(); List<Map<String,Object?>> rows=[];
 final name=TextEditingController(),principal=TextEditingController(),paid=TextEditingController(); String party='customer';
 @override void initState(){super.initState();load();}
 Future<void> load()async{rows=await repo.loans();if(mounted)setState((){});}
 Future<void> add()async{final p=double.tryParse(principal.text)||0, pd=double.tryParse(paid.text)||0;if(name.text.trim().isEmpty||p<=0)return;
  await repo.addLoan({'party_type':party,'party_name':name.text.trim(),'date':DateTime.now().toIso8601String(),'principal':p,'paid':pd,'balance':p-pd,'notes':''});
  name.clear();principal.clear();paid.clear();await load();
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Loans')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Wrap(spacing:8,children:[
   DropdownButton<String>(value:party,items:const [DropdownMenuItem(value:'customer',child:Text('Customer')),DropdownMenuItem(value:'supplier',child:Text('Supplier')),DropdownMenuItem(value:'salesman',child:Text('Salesman'))],onChanged:(v)=>setState(()=>party=v!)),
   SizedBox(width:180,child:TextField(controller:name,decoration:const InputDecoration(labelText:'Party Name'))),
   SizedBox(width:130,child:TextField(controller:principal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Loan'))),
   SizedBox(width:130,child:TextField(controller:paid,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Paid'))),
   FilledButton(onPressed:add,child:const Text('Save')),
  ]),
  const Divider(height:28),
  ...rows.map((r)=>Card(child:ListTile(title:Text('${r['party_name']} • ${r['party_type']}'),subtitle:Text('Principal ${r['principal']} • Paid ${r['paid']} • Balance ${r['balance']}'))))
 ]));
}
