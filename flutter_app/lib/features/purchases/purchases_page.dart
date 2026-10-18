import 'package:flutter/material.dart';
import '../../core/repositories/business_repository.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});
  @override State<PurchasesPage> createState()=>_PurchasesPageState();
}
class _PurchasesPageState extends State<PurchasesPage> {
  final repo=BusinessRepository();
  List<Map<String,Object?>> rows=[];
  final invoice=TextEditingController(), supplier=TextEditingController(), total=TextEditingController(), paid=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load() async { rows=await repo.purchases(); if(mounted)setState((){}); }
  Future<void> add() async {
    final t=double.tryParse(total.text)||0, p=double.tryParse(paid.text)||0;
    if(invoice.text.trim().isEmpty||t<=0)return;
    await repo.addPurchase({
      'invoice_no':invoice.text.trim(),'supplier_id':null,'date':DateTime.now().toIso8601String(),
      'subtotal':t,'discount':0.0,'total':t,'paid':p,'due':t-p,'notes':'Supplier: ${supplier.text.trim()}'
    },[{'product_name':'Purchase invoice total','qty':1.0,'unit_cost':t,'total':t}]);
    invoice.clear();supplier.clear();total.clear();paid.clear();await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Purchases')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Wrap(spacing:8,runSpacing:8,children:[
        SizedBox(width:180,child:TextField(controller:invoice,decoration:const InputDecoration(labelText:'Invoice No'))),
        SizedBox(width:180,child:TextField(controller:supplier,decoration:const InputDecoration(labelText:'Supplier'))),
        SizedBox(width:150,child:TextField(controller:total,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Total'))),
        SizedBox(width:150,child:TextField(controller:paid,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Paid'))),
        FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Save Purchase')),
      ]),
      const SizedBox(height:18),
      ...rows.map((r)=>Card(child:ListTile(title:Text('${r['invoice_no']} • ${r['total']}'),subtitle:Text('${r['date']} • Paid ${r['paid']} • Due ${r['due']}'))))
    ]),
  );
}
