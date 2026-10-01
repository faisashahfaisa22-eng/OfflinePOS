import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
class ReportsPage extends StatefulWidget{const ReportsPage({super.key});@override State<ReportsPage> createState()=>_ReportsPageState();}
class _ReportsPageState extends State<ReportsPage>{
 late Future<Map<String,num>> data;@override void initState(){super.initState();data=AppDatabase.instance.extendedReportTotals();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Reports')),body:FutureBuilder<Map<String,num>>(future:data,builder:(context,s){final x=s.data??{};return ListView(padding:const EdgeInsets.all(16),children:[r('Sales',x['sales']??0),r('Purchases',x['purchases']??0),r('Expenses',x['expenses']??0),r('Gross profit estimate',x['profit']??0),r('Receivables / Due',x['due']??0),r('Supplier due',x['supplierDue']??0),r('Inventory cost value',x['stockCost']??0),r('Inventory sale value',x['stockRetail']??0)]);}));
 Widget r(String n,num v)=>Card(child:ListTile(title:Text(n),trailing:Text(v.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.bold))));
}