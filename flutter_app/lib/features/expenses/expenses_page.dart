import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override State<ExpensesPage> createState()=>_ExpensesPageState();
}
class _ExpensesPageState extends State<ExpensesPage>{
  List<Map<String,Object?>> rows=const[]; bool loading=true;
  Future<void> load()async{final x=await AppDatabase.instance.expenses();if(mounted)setState((){rows=x;loading=false;});}
  @override void initState(){super.initState();load();}
  Future<void> add()async{
    final name=TextEditingController(),category=TextEditingController(),amount=TextEditingController(),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Add Expense'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Expense Name')),
        TextField(controller:category,decoration:const InputDecoration(labelText:'Category')),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount')),
        TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save'))]));
    if(ok!=true||name.text.trim().isEmpty)return;
    await AppDatabase.instance.saveExpense(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text,category:category.text,amount:double.tryParse(amount.text)??0,note:note.text);
    await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Expenses')),
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add Expense')),
    body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('No expenses yet.')):
    ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=rows[i];return ListTile(
      leading:const CircleAvatar(child:Icon(Icons.receipt_long)),title:Text('${x['name']}'),subtitle:Text('${x['category']??''}\n${x['note']??''}'),isThreeLine:true,trailing:Text('${x['amount']}'));}));
}
