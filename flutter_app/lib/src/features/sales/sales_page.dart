import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override State<SalesPage> createState()=>_SalesPageState();
}
class _SalesPageState extends State<SalesPage> {
  Future<List<Map<String,Object?>>> load() async {
    final db=await AppDatabase.instance.database;
    return db.query('sales',orderBy:'sale_date DESC, created_at DESC');
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Sales / Invoices')),
    body:FutureBuilder<List<Map<String,Object?>>>(future:load(),builder:(context,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      if(snap.data!.isEmpty)return const Center(child:Text('Invoice table ready — no sales yet.'));
      return ListView.builder(itemCount:snap.data!.length,itemBuilder:(_,i){final s=snap.data![i];return ListTile(leading:const Icon(Icons.receipt_long),title:Text('${s['invoice_no']}'),subtitle:Text('${s['sale_date']}'),trailing:Text('${s['total']}'));});
    }),
  );
}
