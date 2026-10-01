import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';

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
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(LanguageController.instance.strings.t('addExpense')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('expenseName'))),
        TextField(controller:category,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('category'))),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:LanguageController.instance.strings.t('amount'))),
        TextField(controller:note,decoration:InputDecoration(labelText:LanguageController.instance.strings.t('note'))),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(LanguageController.instance.strings.t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(LanguageController.instance.strings.t('save')))]));
    if(ok!=true||name.text.trim().isEmpty)return;
    await AppDatabase.instance.saveExpense(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text,category:category.text,amount:double.tryParse(amount.text)??0,note:note.text);
    await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(LanguageController.instance.strings.t('expenses'))),
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:Text(LanguageController.instance.strings.t('addExpense'))),
    body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?Center(child:Text(LanguageController.instance.strings.t('noExpenses'))):
    ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=rows[i];return ListTile(
      leading:const CircleAvatar(child:Icon(Icons.receipt_long)),title:Text('${x['name']}'),subtitle:Text('${x['category']??''}\n${x['note']??''}'),isThreeLine:true,trailing:Text('${x['amount']}'));}));
}
