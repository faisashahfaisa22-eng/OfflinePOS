import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState()=>_ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  String editingId='';
  DateTime date=DateTime.now();
  String category='Salary';

  final name=TextEditingController();
  final amount=TextEditingController();
  final note=TextEditingController();

  bool get canEdit=>LocalAuthService.instance.canEdit;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final data=await db.query('expenses',orderBy:'business_date DESC, created_at DESC');
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  void resetForm() {
    setState(() {
      editingId='';
      date=DateTime.now();
      category='Salary';
      name.clear();
      amount.clear();
      note.clear();
    });
  }

  void edit(Map<String,Object?> x) {
    if(!canEdit) return;
    setState(() {
      editingId=x['id'].toString();
      date=DateTime.tryParse(x['business_date']?.toString()??'')??DateTime.now();
      category=x['category']?.toString()??'Salary';
      name.text=x['name'].toString();
      amount.text=QamvioUi.money(x['amount']);
      note.text=x['note']?.toString()??'';
    });
  }

  Future<void> chooseDate() async {
    final d=await showDatePicker(
      context:context,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100),
      initialDate:date,
    );
    if(d!=null) setState(()=>date=d);
  }

  Future<void> save() async {
    if(!canEdit) return;
    final value=double.tryParse(amount.text.trim())??0;
    if(name.text.trim().isEmpty||value<=0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Expense name and valid amount are required.')),
      );
      return;
    }
    await AppDatabase.instance.saveExpense(
      id:editingId.isEmpty?DateTime.now().microsecondsSinceEpoch.toString():editingId,
      name:name.text.trim(),
      category:category,
      amount:value,
      note:note.text.trim(),
      businessDate:date,
    );
    resetForm();
    await load();
  }

  Future<void> remove(Map<String,Object?> x) async {
    if(!LocalAuthService.instance.canDelete) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Expense?'),
        content:Text('Move "${x['name']}" to Recycle Bin?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    );
    if(ok==true) {
      await AppDatabase.instance.softDeleteById('expenses',x['id'].toString());
      await load();
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Expenses')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Expenses',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          if(canEdit)
            Card(
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Wrap(
                  spacing:10,
                  runSpacing:10,
                  crossAxisAlignment:WrapCrossAlignment.end,
                  children:[
                    SizedBox(
                      width:160,
                      child:InkWell(
                        onTap:chooseDate,
                        child:InputDecorator(
                          decoration:const InputDecoration(labelText:'Date'),
                          child:Text(DateFormat('yyyy-MM-dd').format(date)),
                        ),
                      ),
                    ),
                    SizedBox(width:220,child:TextField(controller:name,decoration:const InputDecoration(labelText:'Expense Name',hintText:'Enter expense name'))),
                    SizedBox(
                      width:180,
                      child:DropdownButtonFormField<String>(
                        initialValue:category,
                        decoration:const InputDecoration(labelText:'Expense Category'),
                        items:const [
                          DropdownMenuItem(value:'Salary',child:Text('Salary')),
                          DropdownMenuItem(value:'Oil',child:Text('Oil')),
                          DropdownMenuItem(value:'Mechanic',child:Text('Mechanic')),
                          DropdownMenuItem(value:'Extra',child:Text('Extra Expense')),
                          DropdownMenuItem(value:'Other',child:Text('Other Expense')),
                        ],
                        onChanged:(v)=>setState(()=>category=v??category),
                      ),
                    ),
                    SizedBox(width:150,child:TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount'))),
                    SizedBox(width:250,child:TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))),
                    FilledButton(onPressed:save,child:Text(editingId.isEmpty?'Save Expense':'Update Expense')),
                    if(editingId.isNotEmpty)
                      OutlinedButton(onPressed:resetForm,child:const Text('Cancel Edit')),
                  ],
                ),
              ),
            ),
          const SizedBox(height:10),
          Card(
            child:SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:DataTable(
                columns:const [
                  DataColumn(label:Text('Date')),
                  DataColumn(label:Text('Expense Name')),
                  DataColumn(label:Text('Expense Category')),
                  DataColumn(label:Text('Amount'),numeric:true),
                  DataColumn(label:Text('Note')),
                  DataColumn(label:Text('')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                      DataCell(Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),
                      DataCell(Text(x['category']?.toString()??'')),
                      DataCell(Text(QamvioUi.money(x['amount']))),
                      DataCell(Text(x['note']?.toString()??'')),
                      DataCell(Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          if(canEdit) IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined)),
                          if(LocalAuthService.instance.canDelete) IconButton(onPressed:()=>remove(x),icon:const Icon(Icons.delete_outline_rounded)),
                        ],
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
  );
}
