import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/business_repository.dart';

class AccountsPage extends StatefulWidget { const AccountsPage({super.key}); @override State<AccountsPage> createState()=>_AccountsPageState(); }
class _AccountsPageState extends State<AccountsPage>{
 final repo=BusinessRepository(); List<Map<String,Object?>> rows=[]; double balance=0;
 final amount=TextEditingController(), desc=TextEditingController(); String type='in';
 @override void initState(){super.initState();load();}
 Future<void> load() async {rows=await repo.cashLedger();balance=await repo.cashBalance();if(mounted)setState((){});}
 Future<void> add() async{
  final a=double.tryParse(amount.text)||0;if(a<=0)return;
  final db=await AppDatabase.instance.database;
  await db.insert('cash_transactions',{'date':DateTime.now().toIso8601String(),'type':type,'category':'manual','reference':'','description':desc.text.trim(),'amount':a});
  amount.clear();desc.clear();await load();
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Accounts / Cash')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Card(child:ListTile(title:const Text('Cash Balance'),trailing:Text(balance.toStringAsFixed(2),style:Theme.of(context).textTheme.headlineSmall))),
  Wrap(spacing:8,children:[
   DropdownButton<String>(value:type,items:const [DropdownMenuItem(value:'in',child:Text('Cash In')),DropdownMenuItem(value:'out',child:Text('Cash Out'))],onChanged:(v)=>setState(()=>type=v!)),
   SizedBox(width:140,child:TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount'))),
   SizedBox(width:220,child:TextField(controller:desc,decoration:const InputDecoration(labelText:'Description'))),
   FilledButton(onPressed:add,child:const Text('Post')),
  ]),
  const Divider(height:28),
  ...rows.map((r)=>ListTile(leading:Icon(r['type']=='in'?Icons.south_west:Icons.north_east),title:Text('${r['category']} • ${r['amount']}'),subtitle:Text('${r['date']} ${r['description']}')))
 ]));
}
