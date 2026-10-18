import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override State<ExpensesPage> createState()=>_ExpensesPageState();
}
class _ExpensesPageState extends State<ExpensesPage> {
  Future<List<Map<String,Object?>>> load() async {
    final db=await AppDatabase.instance.database;
    return db.query('expenses',orderBy:'expense_date DESC, created_at DESC');
  }
  Future<void> addExpense() async {
    final name=TextEditingController(), amount=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Add Expense'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Expense Name')),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))],
    ));
    if(ok!=true||name.text.trim().isEmpty)return;
    final now=DateTime.now().toUtc().toIso8601String(), db=await AppDatabase.instance.database;
    await db.insert('expenses',{'id':'e_${DateTime.now().microsecondsSinceEpoch}','name':name.text.trim(),'amount':double.tryParse(amount.text)??0,'expense_date':DateTime.now().toIso8601String().substring(0,10),'created_at':now,'updated_at':now});
    setState((){});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Expenses')),
    floatingActionButton:FloatingActionButton.extended(onPressed:addExpense,icon:const Icon(Icons.add),label:const Text('Add Expense')),
    body:FutureBuilder<List<Map<String,Object?>>>(future:load(),builder:(context,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      if(snap.data!.isEmpty)return const Center(child:Text('No expenses yet'));
      return ListView.builder(itemCount:snap.data!.length,itemBuilder:(_,i){final x=snap.data![i];return ListTile(title:Text('${x['name']}'),subtitle:Text('${x['expense_date']}'),trailing:Text('${x['amount']}'));});
    }),
  );
}
