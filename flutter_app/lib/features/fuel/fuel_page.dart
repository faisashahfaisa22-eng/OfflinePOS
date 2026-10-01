import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});
  @override State<FuelPage> createState()=>_FuelPageState();
}
class _FuelPageState extends State<FuelPage>{
  List<Map<String,Object?>> tanks=const[], nozzles=const[], shifts=const[];
  bool loading=true;
  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final a=await db.query('fuel_tanks',orderBy:'name');
    final b=await db.query('fuel_nozzles',orderBy:'name');
    final c=await db.query('fuel_shifts',orderBy:'started_at DESC',limit:100);
    if(mounted)setState((){tanks=a;nozzles=b;shifts=c;loading=false;});
  }
  @override void initState(){super.initState();load();}
  Future<void> addTank()async{
    final name=TextEditingController(),type=TextEditingController(text:'Diesel'),capacity=TextEditingController(),stock=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Add Fuel Tank'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Tank name')),
      TextField(controller:type,decoration:const InputDecoration(labelText:'Fuel type')),
      TextField(controller:capacity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Capacity')),
      TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Current stock')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))]));
    if(ok!=true||name.text.trim().isEmpty)return;
    final db=await AppDatabase.instance.database, now=DateTime.now().toUtc().toIso8601String();
    await db.insert('fuel_tanks',{'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':name.text.trim(),'fuel_type':type.text.trim(),'capacity':double.tryParse(capacity.text)??0,'current_stock':double.tryParse(stock.text)??0,'updated_at':now,'sync_state':0});
    await load();
  }
  Future<void> addNozzle()async{
    if(tanks.isEmpty)return;
    final tankId=tanks.first['id'].toString(),name=TextEditingController(),meter=TextEditingController(),price=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Add Nozzle'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('Tank: '+tanks.first['name'].toString()),TextField(controller:name,decoration:const InputDecoration(labelText:'Nozzle name')),
      TextField(controller:meter,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Meter reading')),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Price per litre')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))]));
    if(ok!=true||name.text.trim().isEmpty)return;
    final db=await AppDatabase.instance.database,now=DateTime.now().toUtc().toIso8601String();
    await db.insert('fuel_nozzles',{'id':DateTime.now().microsecondsSinceEpoch.toString(),'tank_id':tankId,'name':name.text.trim(),'meter_reading':double.tryParse(meter.text)??0,'price_per_unit':double.tryParse(price.text)??0,'updated_at':now,'sync_state':0});
    await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Oil / Fuel Pump')),floatingActionButton:FloatingActionButton.extended(onPressed:addTank,icon:const Icon(Icons.add),label:const Text('Add Tank')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(12),children:[
    FilledButton.icon(onPressed:addNozzle,icon:const Icon(Icons.local_gas_station),label:const Text('Add Nozzle')),const SizedBox(height:12),
    Text('Tanks: '+tanks.length.toString(),style:Theme.of(context).textTheme.titleLarge),
    ...tanks.map((x)=>Card(child:ListTile(title:Text(x['name'].toString()+' • '+x['fuel_type'].toString()),subtitle:Text('Stock '+x['current_stock'].toString()+' / '+x['capacity'].toString())))),
    Text('Nozzles: '+nozzles.length.toString(),style:Theme.of(context).textTheme.titleLarge),
    ...nozzles.map((x)=>Card(child:ListTile(title:Text(x['name'].toString()),subtitle:Text('Meter '+x['meter_reading'].toString()+' • Price/L '+x['price_per_unit'].toString())))),
    Text('Recorded shifts: '+shifts.length.toString(),style:Theme.of(context).textTheme.titleLarge),
  ]));
}