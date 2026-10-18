import 'package:flutter/material.dart';
import '../../core/repositories/business_repository.dart';

class PharmacyPage extends StatefulWidget { const PharmacyPage({super.key}); @override State<PharmacyPage> createState()=>_PharmacyPageState(); }
class _PharmacyPageState extends State<PharmacyPage>{
 final repo=BusinessRepository(); List<Map<String,Object?>> rows=[];
 final medicine=TextEditingController(),batch=TextEditingController(),expiry=TextEditingController(),qty=TextEditingController(),buy=TextEditingController(),sell=TextEditingController();
 @override void initState(){super.initState();load();}
 Future<void> load()async{rows=await repo.medicineBatches();if(mounted)setState((){});}
 Future<void> add()async{
  final q=double.tryParse(qty.text)||0;if(medicine.text.trim().isEmpty||batch.text.trim().isEmpty||expiry.text.trim().isEmpty||q<=0)return;
  await repo.addMedicineBatch({'medicine_name':medicine.text.trim(),'batch_no':batch.text.trim(),'expiry_date':expiry.text.trim(),'qty':q,'purchase_price':double.tryParse(buy.text)||0,'sale_price':double.tryParse(sell.text)||0});
  medicine.clear();batch.clear();expiry.clear();qty.clear();buy.clear();sell.clear();await load();
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pharmacy')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Wrap(spacing:8,runSpacing:8,children:[
   SizedBox(width:170,child:TextField(controller:medicine,decoration:const InputDecoration(labelText:'Medicine'))),
   SizedBox(width:130,child:TextField(controller:batch,decoration:const InputDecoration(labelText:'Batch No'))),
   SizedBox(width:140,child:TextField(controller:expiry,decoration:const InputDecoration(labelText:'Expiry YYYY-MM-DD'))),
   SizedBox(width:100,child:TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Qty'))),
   SizedBox(width:120,child:TextField(controller:buy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Buy Price'))),
   SizedBox(width:120,child:TextField(controller:sell,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Sale Price'))),
   FilledButton(onPressed:add,child:const Text('Add Batch')),
  ]),
  const Divider(height:28),
  ...rows.map((r){final expired=DateTime.tryParse(r['expiry_date'] as String? ?? '')?.isBefore(DateTime.now())??false;return Card(child:ListTile(
   leading:Icon(expired?Icons.warning_amber:Icons.medication),
   title:Text('${r['medicine_name']} • ${r['batch_no']}'),
   subtitle:Text('Expiry ${r['expiry_date']} • Qty ${r['qty']} • Sale ${r['sale_price']}'),
   trailing:expired?const Text('EXPIRED'):null,
  ));})
 ]));
}
