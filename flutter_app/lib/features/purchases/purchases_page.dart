import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);
String _day(DateTime d)=>DateFormat('yyyy-MM-dd').format(d);

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState()=>_PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final data=await db.rawQuery(
      'SELECT p.*,s.name supplier_name FROM purchases p '
      'LEFT JOIN suppliers s ON s.id=p.supplier_id '
      'ORDER BY p.created_at DESC',
    );
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  Future<void> openPurchase([Map<String,Object?>? purchase]) async {
    final saved=await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder:(_)=>V15PurchaseForm(existing:purchase)),
    );
    if(saved==true) await load();
  }

  Future<void> deletePurchase(Map<String,Object?> x) async {
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Purchase?'),
        content:Text('Move purchase ${x['invoice_no']??x['id']} to Recycle Bin?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    );
    if(ok==true) {
      await AppDatabase.instance.softDeleteById('purchases',x['id'].toString());
      await load();
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Purchases')),
    floatingActionButton:LocalAuthService.instance.canEdit
      ?FloatingActionButton.extended(
        onPressed:()=>openPurchase(),
        icon:const Icon(Icons.add),
        label:const Text('New Purchase'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Purchases',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          if(LocalAuthService.instance.canEdit)
            FilledButton.icon(
              onPressed:()=>openPurchase(),
              icon:const Icon(Icons.add_shopping_cart_rounded),
              label:const Text('New Purchase'),
            ),
          const SizedBox(height:14),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(12),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('Purchase History',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
                  const SizedBox(height:8),
                  SingleChildScrollView(
                    scrollDirection:Axis.horizontal,
                    child:DataTable(
                      columns:const [
                        DataColumn(label:Text('Date')),
                        DataColumn(label:Text('Supplier')),
                        DataColumn(label:Text('Invoice')),
                        DataColumn(label:Text('Total'),numeric:true),
                        DataColumn(label:Text('Paid'),numeric:true),
                        DataColumn(label:Text('Due'),numeric:true),
                        DataColumn(label:Text('')),
                      ],
                      rows:[
                        for(final x in rows)
                          DataRow(cells:[
                            DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                            DataCell(Text(x['supplier_name']?.toString()??'')),
                            DataCell(Text(x['invoice_no']?.toString()??'')),
                            DataCell(Text(_money(x['total']))),
                            DataCell(Text(_money(x['paid']))),
                            DataCell(Text(_money(x['due']))),
                            DataCell(Row(
                              mainAxisSize:MainAxisSize.min,
                              children:[
                                if(LocalAuthService.instance.canEdit)
                                  IconButton(
                                    tooltip:'Edit',
                                    onPressed:()=>openPurchase(x),
                                    icon:const Icon(Icons.edit_outlined),
                                  ),
                                if(LocalAuthService.instance.isAdmin)
                                  IconButton(
                                    tooltip:'Delete',
                                    onPressed:()=>deletePurchase(x),
                                    icon:const Icon(Icons.delete_outline_rounded),
                                  ),
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
      ),
  );
}

class V15PurchaseForm extends StatefulWidget {
  final Map<String,Object?>? existing;
  const V15PurchaseForm({this.existing,super.key});

  @override
  State<V15PurchaseForm> createState()=>_V15PurchaseFormState();
}

class _V15PurchaseFormState extends State<V15PurchaseForm> {
  List<Map<String,Object?>> suppliers=const [];
  List<Map<String,Object?>> products=const [];
  final lines=<Map<String,Object?>>[];

  DateTime date=DateTime.now();
  String supplierId='';
  String selectedProductId='';
  final invoiceNo=TextEditingController();
  final paid=TextEditingController(text:'0');
  final note=TextEditingController();
  final qty=TextEditingController();
  final cost=TextEditingController();
  bool loading=true;
  bool saving=false;

  bool get editing=>widget.existing!=null;
  double get total=>lines.fold<double>(0,(a,x)=>a+_n(x['qty'])*_n(x['cost']));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    invoiceNo.dispose();
    paid.dispose();
    note.dispose();
    qty.dispose();
    cost.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db=await AppDatabase.instance.database;
    final s=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    final p=await db.query('products',orderBy:'name COLLATE NOCASE');
    if(editing) {
      final x=widget.existing!;
      date=DateTime.tryParse(x['business_date']?.toString()??'')??DateTime.now();
      supplierId=x['supplier_id']?.toString()??'';
      invoiceNo.text=x['invoice_no']?.toString()??'';
      paid.text=_money(x['paid']);
      note.text=x['note']?.toString()??'';
      final old=await db.query('purchase_items',where:'purchase_id=?',whereArgs:[x['id']]);
      for(final item in old) {
        lines.add({
          'product_id':item['product_id'],
          'product_name':item['product_name'],
          'qty':_n(item['qty']),
          'cost':_n(item['cost']),
        });
      }
    } else if(s.isNotEmpty) {
      supplierId=s.first['id'].toString();
    }
    if(p.isNotEmpty) selectedProductId=p.first['id'].toString();
    if(!mounted) return;
    setState(() {
      suppliers=s;
      products=p;
      loading=false;
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

  void addLine() {
    if(selectedProductId.isEmpty) return;
    final p=products.where((x)=>x['id'].toString()==selectedProductId);
    if(p.isEmpty) return;
    final q=double.tryParse(qty.text.trim())??0;
    final c=double.tryParse(cost.text.trim())??0;
    if(q<=0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Qty must be greater than zero.')),
      );
      return;
    }
    setState(() {
      lines.add({
        'product_id':selectedProductId,
        'product_name':p.first['name'],
        'qty':q,
        'cost':c,
      });
      qty.clear();
      cost.clear();
    });
  }

  Future<void> save() async {
    if(saving||supplierId.isEmpty||lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Select Supplier and add at least one line.')),
      );
      return;
    }
    setState(()=>saving=true);
    try {
      await AppDatabase.instance.createPurchase(
        id:widget.existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
        supplierId:supplierId,
        items:lines,
        paid:double.tryParse(paid.text.trim())??0,
        invoiceNo:invoiceNo.text.trim(),
        note:note.text.trim(),
        businessDate:date,
      );
      if(!mounted) return;
      Navigator.pop(context,true);
    } catch(e) {
      if(mounted) {
        setState(()=>saving=false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Purchase save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(editing?'Edit Purchase':'Purchases')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :suppliers.isEmpty||products.isEmpty
        ?const QamvioEmptyState(
          icon:Icons.shopping_cart_outlined,
          title:'Supplier and Product required',
          subtitle:'Create Supplier and Product records before Purchase.',
        )
        :ListView(
          padding:QamvioUi.pagePadding,
          children:[
            Card(
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    Wrap(
                      spacing:10,
                      runSpacing:10,
                      children:[
                        SizedBox(
                          width:170,
                          child:InkWell(
                            onTap:chooseDate,
                            child:InputDecorator(
                              decoration:const InputDecoration(labelText:'Date'),
                              child:Text(_day(date)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width:220,
                          child:DropdownButtonFormField<String>(
                            initialValue:supplierId,
                            decoration:const InputDecoration(labelText:'Supplier'),
                            items:[
                              for(final x in suppliers)
                                DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                            ],
                            onChanged:(v)=>setState(()=>supplierId=v??supplierId),
                          ),
                        ),
                        SizedBox(width:180,child:TextField(controller:invoiceNo,decoration:const InputDecoration(labelText:'Invoice No'))),
                        SizedBox(width:150,child:TextField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Paid'))),
                        SizedBox(width:260,child:TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))),
                      ],
                    ),
                    const Divider(height:28),
                    Wrap(
                      spacing:10,
                      runSpacing:10,
                      crossAxisAlignment:WrapCrossAlignment.end,
                      children:[
                        SizedBox(
                          width:260,
                          child:DropdownButtonFormField<String>(
                            initialValue:selectedProductId,
                            decoration:const InputDecoration(labelText:'Product'),
                            items:[
                              for(final x in products)
                                DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                            ],
                            onChanged:(v) {
                              setState(()=>selectedProductId=v??selectedProductId);
                              final p=products.where((x)=>x['id'].toString()==selectedProductId);
                              if(p.isNotEmpty) cost.text=_money(p.first['cost']);
                            },
                          ),
                        ),
                        SizedBox(width:130,child:TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Qty'))),
                        SizedBox(width:150,child:TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cost Price'))),
                        OutlinedButton(onPressed:addLine,child:const Text('Add Line')),
                      ],
                    ),
                    const SizedBox(height:10),
                    SingleChildScrollView(
                      scrollDirection:Axis.horizontal,
                      child:DataTable(
                        columns:const [
                          DataColumn(label:Text('Product')),
                          DataColumn(label:Text('Qty'),numeric:true),
                          DataColumn(label:Text('Cost'),numeric:true),
                          DataColumn(label:Text('Amount'),numeric:true),
                          DataColumn(label:Text('')),
                        ],
                        rows:[
                          for(var i=0;i<lines.length;i++)
                            DataRow(cells:[
                              DataCell(Text(lines[i]['product_name'].toString())),
                              DataCell(Text(_money(lines[i]['qty']))),
                              DataCell(Text(_money(lines[i]['cost']))),
                              DataCell(Text(_money(_n(lines[i]['qty'])*_n(lines[i]['cost'])))),
                              DataCell(IconButton(
                                onPressed:()=>setState(()=>lines.removeAt(i)),
                                icon:const Icon(Icons.close_rounded),
                              )),
                            ]),
                          DataRow(cells:[
                            const DataCell(Text('Total',style:TextStyle(fontWeight:FontWeight.w900))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            DataCell(Text(_money(total),style:const TextStyle(fontWeight:FontWeight.w900))),
                            const DataCell(Text('')),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height:10),
                    Wrap(
                      spacing:8,
                      children:[
                        FilledButton(
                          onPressed:saving?null:save,
                          child:Text(saving?'Saving…':'Save Purchase'),
                        ),
                        if(editing)
                          OutlinedButton(
                            onPressed:()=>Navigator.pop(context),
                            child:const Text('Cancel Edit'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
  );
}
