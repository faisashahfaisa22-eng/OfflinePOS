import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/business_repository.dart';

class OilPumpPage extends StatefulWidget { const OilPumpPage({super.key}); @override State<OilPumpPage> createState()=>_OilPumpPageState(); }
class _OilPumpPageState extends State<OilPumpPage>{
 final repo=BusinessRepository(); List<Map<String,Object?>> rows=[];
 final open=TextEditingController(), close=TextEditingController(), price=TextEditingController(), cash=TextEditingController(), customer=TextEditingController(), salesman=TextEditingController();
 @override void initState(){super.initState();load();}
 Future<void> load()async{rows=await repo.fuelSales();if(mounted)setState((){});}
 Future<void> add()async{
  final o=double.tryParse(open.text)||0,c=double.tryParse(close.text)||0,p=double.tryParse(price.text)||0;
  final litres=c-o,total=litres*p, ca=double.tryParse(cash.text)??total;if(litres<=0||p<=0)return;
  await repo.addFuelSale({'nozzle_id':null,'date':DateTime.now().toIso8601String(),'opening_meter':o,'closing_meter':c,'litres':litres,'price_per_litre':p,'total':total,'cash':ca,'credit':total-ca,'customer':customer.text.trim(),'salesman':salesman.text.trim()});
  open.clear();close.clear();price.clear();cash.clear();customer.clear();salesman.clear();await load();
 }
 Future<void> addTank()async{final db=await AppDatabase.instance.database;await db.insert('fuel_tanks',{'name':'Main Tank','fuel_type':'Petrol','capacity':0.0,'current_stock':0.0});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tank created')));}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Oil Pump')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Wrap(spacing:8,runSpacing:8,children:[
   FilledButton.tonalIcon(onPressed:addTank,icon:const Icon(Icons.oil_barrel),label:const Text('Add Tank')),
   SizedBox(width:130,child:TextField(controller:open,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Opening Meter'))),
   SizedBox(width:130,child:TextField(controller:close,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Closing Meter'))),
   SizedBox(width:130,child:TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Price/Litre'))),
   SizedBox(width:130,child:TextField(controller:cash,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Cash'))),
   SizedBox(width:160,child:TextField(controller:customer,decoration:const InputDecoration(labelText:'Customer'))),
   SizedBox(width:160,child:TextField(controller:salesman,decoration:const InputDecoration(labelText:'Salesman'))),
   FilledButton(onPressed:add,child:const Text('Close / Save Shift')),
  ]),
  const Divider(height:28),
  ...rows.map((r)=>Card(child:ListTile(title:Text('${r['litres']} L • Total ${r['total']}'),subtitle:Text('Meter ${r['opening_meter']} → ${r['closing_meter']} • Cash ${r['cash']} • Credit ${r['credit']}'))))
 ]));
}
