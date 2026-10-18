import 'package:flutter/material.dart';
import '../../core/repositories/business_repository.dart';

class ReportsPage extends StatefulWidget { const ReportsPage({super.key}); @override State<ReportsPage> createState()=>_ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage>{
 final repo=BusinessRepository(); Map<String,double> data={};
 @override void initState(){super.initState();load();}
 Future<void> load()async{data=await repo.reportSummary();if(mounted)setState((){});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Reports')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
  for(final e in data.entries) Card(child:ListTile(title:Text(e.key),trailing:Text(e.value.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.bold))))
 ])));
}
