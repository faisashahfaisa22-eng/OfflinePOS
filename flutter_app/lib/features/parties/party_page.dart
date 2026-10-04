import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

enum PartyType { customer, supplier }

class PartyPage extends StatefulWidget {
  final PartyType type;
  const PartyPage({required this.type,super.key});

  @override
  State<PartyPage> createState()=>_PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  List<Map<String,Object?>> rows=const [];
  List<Map<String,Object?>> salesmen=const [];
  List<Map<String,Object?>> supplierTx=const [];
  bool loading=true;
  String editingId='';

  final name=TextEditingController();
  final phone=TextEditingController();
  final opening=TextEditingController(text:'0');
  final creditLimit=TextEditingController(text:'0');
  final note=TextEditingController();
  String salesmanId='';

  bool get customer=>widget.type==PartyType.customer;
  bool get canEdit=>LocalAuthService.instance.canEdit;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PartyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.type!=widget.type) {
      resetForm();
      load();
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    opening.dispose();
    creditLimit.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final sm=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    final data=customer
      ?await db.rawQuery(
        'SELECT c.*,sm.name salesman_name FROM customers c '
        'LEFT JOIN salesmen sm ON sm.id=c.salesman_id ORDER BY c.name COLLATE NOCASE',
      )
      :await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    final tx=customer
      ?<Map<String,Object?>>[]
      :await db.rawQuery(
        'SELECT t.*,s.name supplier_name FROM supplier_transactions t '
        'JOIN suppliers s ON s.id=t.supplier_id ORDER BY t.created_at DESC',
      );
    if(!mounted) return;
    setState(() {
      salesmen=sm;
      rows=data;
      supplierTx=tx;
      loading=false;
    });
  }

  void resetForm() {
    setState(() {
      editingId='';
      name.clear();
      phone.clear();
      opening.text='0';
      creditLimit.text='0';
      note.clear();
      salesmanId='';
    });
  }

  void edit(Map<String,Object?> x) {
    if(!canEdit) return;
    setState(() {
      editingId=x['id'].toString();
      name.text=x['name'].toString();
      phone.text=x['phone']?.toString()??'';
      opening.text=QamvioUi.money(x['opening']);
      creditLimit.text=QamvioUi.money(x['credit_limit']);
      note.text=x['note']?.toString()??'';
      salesmanId=x['salesman_id']?.toString()??'';
    });
  }

  Future<void> saveMaster() async {
    if(!canEdit||name.text.trim().isEmpty) return;
    final id=editingId.isEmpty?DateTime.now().microsecondsSinceEpoch.toString():editingId;
    if(customer) {
      await AppDatabase.instance.saveCustomer(
        id:id,
        name:name.text.trim(),
        phone:phone.text.trim(),
        salesmanId:salesmanId.isEmpty?null:salesmanId,
        opening:double.tryParse(opening.text.trim())??0,
        creditLimit:double.tryParse(creditLimit.text.trim())??0,
        note:note.text.trim(),
      );
    } else {
      await AppDatabase.instance.saveSupplier(
        id:id,
        name:name.text.trim(),
        phone:phone.text.trim(),
        opening:double.tryParse(opening.text.trim())??0,
        note:note.text.trim(),
      );
    }
    resetForm();
    await load();
  }

  Future<void> removeMaster(Map<String,Object?> x) async {
    if(!canEdit) return;
    final section=customer?'customers':'suppliers';
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('Delete ${customer?'Customer':'Supplier'}?'),
        content:Text('Move "${x['name']}" to Recycle Bin? Linked records must be removed first.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    )??false;
    if(!ok) return;
    try {
      await AppDatabase.instance.softDeleteById(section,x['id'].toString());
      await load();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    }
  }

  Future<void> addSupplierTransaction([Map<String,Object?>? existing]) async {
    if(rows.isEmpty||!canEdit) return;
    String supplierId=existing?['supplier_id']?.toString()??rows.first['id'].toString();
    DateTime date=DateTime.tryParse(existing?['business_date']?.toString()??'')??DateTime.now();
    final paid=TextEditingController(text:existing?['type']=='payment'?QamvioUi.money(existing?['amount']):'0');
    final received=TextEditingController(text:existing?['type']=='received'?QamvioUi.money(existing?['amount']):'0');
    final memo=TextEditingController(text:existing?['note']?.toString()??'');
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Supplier Payment / Receipt'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Date'),
                  subtitle:Text(DateFormat('yyyy-MM-dd').format(date)),
                  trailing:const Icon(Icons.calendar_month_outlined),
                  onTap:() async {
                    final d=await showDatePicker(
                      context:ctx,
                      firstDate:DateTime(2000),
                      lastDate:DateTime(2100),
                      initialDate:date,
                    );
                    if(d!=null) setLocal(()=>date=d);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue:supplierId,
                  decoration:const InputDecoration(labelText:'Supplier'),
                  items:[
                    for(final x in rows)
                      DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>supplierId=v??supplierId),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:paid,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Paid to Supplier'),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:received,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Received from Supplier'),
                ),
                const SizedBox(height:10),
                TextField(controller:memo,decoration:const InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel Edit')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save')),
          ],
        ),
      ),
    );
    if(ok==true) {
      final p=double.tryParse(paid.text.trim())??0;
      final r=double.tryParse(received.text.trim())??0;
      if((p>0&&r>0)||(p<=0&&r<=0)) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Use only one amount: Paid OR Received.')),
          );
        }
      } else {
        await AppDatabase.instance.saveSupplierTransaction(
          id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
          supplierId:supplierId,
          amount:p>0?p:r,
          type:p>0?'payment':'received',
          note:memo.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    paid.dispose();
    received.dispose();
    memo.dispose();
  }

  Future<void> removeSupplierTransaction(Map<String,Object?> x) async {
    if(!canEdit) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Supplier Transaction?'),
        content:const Text('Move this payment / receipt to Recycle Bin and reverse its balance effect?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    )??false;
    if(ok) {
      await AppDatabase.instance.softDeleteById('supplierTransactions',x['id'].toString());
      await load();
    }
  }

  Future<void> shareAll() async {
    final b=StringBuffer('QAMVIO POS — ${customer?'Customer':'Supplier'} Balances\n\n');
    for(final x in rows) {
      b.writeln('${x['name']}: ${QamvioUi.money(x['balance'])}');
    }
    await WhatsAppShare.send(b.toString());
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(customer?'Customers':'Suppliers')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text(
            customer?'Customers':'Suppliers',
            style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900),
          ),
          const SizedBox(height:10),
          if(canEdit) _masterForm(context),
          const SizedBox(height:10),
          _masterTable(context),
          if(!customer) ...[
            const SizedBox(height:14),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Text('Supplier Payment / Receipt',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
                    const SizedBox(height:5),
                    const Text('Use only one amount per entry: Paid to Supplier OR Received from Supplier.'),
                    const SizedBox(height:10),
                    if(canEdit)
                      FilledButton.icon(
                        onPressed:addSupplierTransaction,
                        icon:const Icon(Icons.add),
                        label:const Text('Add Payment / Receipt'),
                      ),
                    const SizedBox(height:10),
                    SingleChildScrollView(
                      scrollDirection:Axis.horizontal,
                      child:DataTable(
                        columns:const [
                          DataColumn(label:Text('Date')),
                          DataColumn(label:Text('Supplier')),
                          DataColumn(label:Text('Paid'),numeric:true),
                          DataColumn(label:Text('Received'),numeric:true),
                          DataColumn(label:Text('Note')),
                          DataColumn(label:Text('')),
                        ],
                        rows:[
                          for(final x in supplierTx)
                            DataRow(cells:[
                              DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                              DataCell(Text(x['supplier_name'].toString())),
                              DataCell(Text(x['type']=='payment'?QamvioUi.money(x['amount']):'0.00')),
                              DataCell(Text(x['type']=='received'?QamvioUi.money(x['amount']):'0.00')),
                              DataCell(Text(x['note']?.toString()??'')),
                              DataCell(Row(
                                mainAxisSize:MainAxisSize.min,
                                children:[
                                  if(canEdit) IconButton(onPressed:()=>addSupplierTransaction(x),icon:const Icon(Icons.edit_outlined)),
                                  if(LocalAuthService.instance.canDelete) IconButton(onPressed:()=>removeSupplierTransaction(x),icon:const Icon(Icons.delete_outline_rounded)),
                                ],
                              )),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
  );

  Widget _masterForm(BuildContext context)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          if(!customer)
            const Padding(
              padding:EdgeInsets.only(bottom:10),
              child:Text('Supplier Master',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
            ),
          Wrap(
            spacing:10,
            runSpacing:10,
            crossAxisAlignment:WrapCrossAlignment.end,
            children:[
              SizedBox(width:230,child:TextField(controller:name,decoration:InputDecoration(labelText:customer?'Customer Name':'Supplier Name'))),
              SizedBox(width:210,child:TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone (with country code)',hintText:'93701234567'))),
              if(customer)
                SizedBox(width:145,child:TextField(controller:creditLimit,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Credit Limit'))),
              if(customer)
                SizedBox(
                  width:190,
                  child:DropdownButtonFormField<String>(
                    initialValue:salesmanId,
                    decoration:const InputDecoration(labelText:'Salesman'),
                    items:[
                      const DropdownMenuItem(value:'',child:Text('No Salesman')),
                      for(final x in salesmen)
                        DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                    ],
                    onChanged:(v)=>setState(()=>salesmanId=v??''),
                  ),
                ),
              SizedBox(width:145,child:TextField(controller:opening,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening Balance'))),
              SizedBox(width:230,child:TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))),
              FilledButton(onPressed:saveMaster,child:Text(editingId.isEmpty?(customer?'Save':'Save Supplier'):'Update')),
              if(editingId.isNotEmpty)
                OutlinedButton(onPressed:resetForm,child:const Text('Cancel Edit')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _masterTable(BuildContext context)=>Card(
    child:SingleChildScrollView(
      scrollDirection:Axis.horizontal,
      child:DataTable(
        columns:customer
          ?[
            const DataColumn(label:Text('Customer Name')),
            const DataColumn(label:Text('Phone')),
            const DataColumn(label:Text('Salesman')),
            const DataColumn(label:Text('Credit Limit'),numeric:true),
            const DataColumn(label:Text('Opening'),numeric:true),
            const DataColumn(label:Text('Current Balance'),numeric:true),
            const DataColumn(label:Text('Status')),
            const DataColumn(label:Text('Note')),
            DataColumn(label:TextButton.icon(onPressed:rows.isEmpty?null:shareAll,icon:const Icon(Icons.chat_rounded),label:const Text('WhatsApp All'))),
          ]
          :[
            const DataColumn(label:Text('Supplier Name')),
            const DataColumn(label:Text('Phone')),
            const DataColumn(label:Text('Opening'),numeric:true),
            const DataColumn(label:Text('Current Balance'),numeric:true),
            const DataColumn(label:Text('Note')),
            DataColumn(label:TextButton.icon(onPressed:rows.isEmpty?null:shareAll,icon:const Icon(Icons.chat_rounded),label:const Text('WhatsApp All'))),
          ],
        rows:[
          for(final x in rows)
            DataRow(
              cells:customer
                ?[
                  DataCell(Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),
                  DataCell(Text(x['phone']?.toString()??'')),
                  DataCell(Text(x['salesman_name']?.toString()??'')),
                  DataCell(Text(QamvioUi.money(x['credit_limit']))),
                  DataCell(Text(QamvioUi.money(x['opening']))),
                  DataCell(Text(QamvioUi.money(x['balance']),style:const TextStyle(fontWeight:FontWeight.w900))),
                  DataCell(Text(_status(x))),
                  DataCell(Text(x['note']?.toString()??'')),
                  DataCell(Row(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      if(canEdit) IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined)),
                      if(LocalAuthService.instance.canDelete) IconButton(onPressed:()=>removeMaster(x),icon:const Icon(Icons.delete_outline_rounded)),
                    ],
                  )),
                ]
                :[
                  DataCell(Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),
                  DataCell(Text(x['phone']?.toString()??'')),
                  DataCell(Text(QamvioUi.money(x['opening']))),
                  DataCell(Text(QamvioUi.money(x['balance']),style:const TextStyle(fontWeight:FontWeight.w900))),
                  DataCell(Text(x['note']?.toString()??'')),
                  DataCell(Row(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      IconButton(
                        tooltip:'WhatsApp',
                        onPressed:()=>WhatsAppShare.shareSupplierCredit(x),
                        icon:const Icon(Icons.chat_rounded),
                      ),
                      if(canEdit) IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined)),
                    ],
                  )),
                ],
            ),
        ],
      ),
    ),
  );

  String _status(Map<String,Object?> x) {
    final balance=(x['balance'] as num?)?.toDouble()??0;
    final limit=(x['credit_limit'] as num?)?.toDouble()??0;
    if(limit>0&&balance>limit) return 'Over Limit';
    if(balance>0) return 'Due';
    if(balance<0) return 'Advance';
    return 'Clear';
  }
}
