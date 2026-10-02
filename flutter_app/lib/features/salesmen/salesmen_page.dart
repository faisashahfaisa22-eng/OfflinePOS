import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

class SalesmenPage extends StatefulWidget {
  const SalesmenPage({super.key});

  @override
  State<SalesmenPage> createState()=>_SalesmenPageState();
}

class _SalesmenPageState extends State<SalesmenPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  String editingId='';

  final name=TextEditingController();
  final phone=TextEditingController();
  final creditLimit=TextEditingController(text:'0');
  final note=TextEditingController();

  bool get canEdit=>LocalAuthService.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    creditLimit.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final user=LocalAuthService.instance.current;
    var r=await db.rawQuery(
      "SELECT sm.*,"
      "COALESCE((SELECT SUM(s.due-s.recovery) FROM sales s "
      "WHERE s.salesman_id=sm.id AND s.customer_id IS NULL),0)+"
      "COALESCE((SELECT SUM(CASE WHEN l.type='payment' THEN -l.amount ELSE l.amount END) "
      "FROM salesman_loans l WHERE l.salesman_id=sm.id "
      "AND COALESCE(l.source,'manual') NOT IN ('sale_due','sale_recovery')),0) current_due,"
      "(SELECT COUNT(*) FROM customers c WHERE c.salesman_id=sm.id) customers_count "
      "FROM salesmen sm ORDER BY sm.name COLLATE NOCASE",
    );
    if(user?.role==UserRole.salesman) {
      r=r.where((x)=>x['id']?.toString()==user?.salesmanId).toList();
    }
    if(!mounted) return;
    setState(() {
      rows=r;
      loading=false;
    });
  }

  void resetForm() {
    setState(() {
      editingId='';
      name.clear();
      phone.clear();
      creditLimit.text='0';
      note.clear();
    });
  }

  void edit(Map<String,Object?> x) {
    if(!canEdit) return;
    setState(() {
      editingId=x['id'].toString();
      name.text=x['name'].toString();
      phone.text=x['phone']?.toString()??'';
      creditLimit.text=QamvioUi.money(x['credit_limit']);
      note.text=x['note']?.toString()??'';
    });
  }

  Future<void> save() async {
    if(!canEdit) return;
    final n=name.text.trim();
    if(n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Salesman name required.')),
      );
      return;
    }
    final db=await AppDatabase.instance.database;
    final duplicate=await db.rawQuery(
      'SELECT id FROM salesmen WHERE lower(name)=lower(?) AND id<>? LIMIT 1',
      [n,editingId],
    );
    if(duplicate.isNotEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Salesman already exists.')),
        );
      }
      return;
    }
    await AppDatabase.instance.saveSalesman(
      id:editingId.isEmpty?DateTime.now().microsecondsSinceEpoch.toString():editingId,
      name:n,
      phone:phone.text.trim(),
      commission:0,
      creditLimit:double.tryParse(creditLimit.text.trim())??0,
      note:note.text.trim(),
      active:true,
    );
    resetForm();
    await load();
  }

  Future<void> shareAll() async {
    final b=StringBuffer('QAMVIO POS — Salesman Outstanding\n\n');
    for(final x in rows) {
      b.writeln('${x['name']}: ${QamvioUi.money(x['current_due'])}');
    }
    await WhatsAppShare.send(b.toString());
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Salesmen')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Salesmen',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(
              color:const Color(0xFFEFF6FF),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:const Color(0xFFBFDBFE)),
            ),
            child:const Text(
              'Create a Salesman first. The same Salesman list is used in Customers, '
              'Sales Invoice, and Salesman Loans. One Salesman can have multiple Customers.',
            ),
          ),
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
                    SizedBox(width:230,child:TextField(controller:name,decoration:const InputDecoration(labelText:'Salesman Name'))),
                    SizedBox(width:210,child:TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone (with country code)',hintText:'93701234567'))),
                    SizedBox(width:150,child:TextField(controller:creditLimit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Credit Limit'))),
                    SizedBox(width:240,child:TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))),
                    FilledButton(onPressed:save,child:Text(editingId.isEmpty?'Save Salesman':'Update')),
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
                columns:[
                  const DataColumn(label:Text('Salesman')),
                  const DataColumn(label:Text('Phone')),
                  const DataColumn(label:Text('Credit Limit'),numeric:true),
                  const DataColumn(label:Text('Current Due'),numeric:true),
                  const DataColumn(label:Text('Customers'),numeric:true),
                  const DataColumn(label:Text('Note')),
                  DataColumn(
                    label:TextButton.icon(
                      onPressed:rows.isEmpty?null:shareAll,
                      icon:const Icon(Icons.chat_rounded),
                      label:const Text('WhatsApp All'),
                    ),
                  ),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),
                      DataCell(Text(x['phone']?.toString()??'')),
                      DataCell(Text(QamvioUi.money(x['credit_limit']))),
                      DataCell(Text(QamvioUi.money(x['current_due']),style:const TextStyle(fontWeight:FontWeight.w900))),
                      DataCell(Text(x['customers_count'].toString())),
                      DataCell(Text(x['note']?.toString()??'')),
                      DataCell(Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          IconButton(
                            tooltip:'WhatsApp',
                            onPressed:()=>WhatsAppShare.shareSalesmanCredit(x),
                            icon:const Icon(Icons.chat_rounded),
                          ),
                          if(canEdit)
                            IconButton(
                              tooltip:'Edit',
                              onPressed:()=>edit(x),
                              icon:const Icon(Icons.edit_outlined),
                            ),
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
