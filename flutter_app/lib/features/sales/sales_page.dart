import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);
String _date(DateTime d)=>DateFormat('yyyy-MM-dd').format(d);

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState()=>_SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final user=LocalAuthService.instance.current;
    const select=
      'SELECT s.*,c.name customer_name,sm.name salesman_name,'
      'COALESCE((SELECT SUM(si.qty) FROM sale_items si WHERE si.sale_id=s.id),0) qty '
      'FROM sales s '
      'LEFT JOIN customers c ON c.id=s.customer_id '
      'LEFT JOIN salesmen sm ON sm.id=s.salesman_id ';
    final List<Map<String,Object?>> data;
    if(user?.role==UserRole.salesman) {
      final sid=user?.salesmanId??'';
      data=sid.isEmpty
        ?<Map<String,Object?>>[]
        :await db.rawQuery(select+'WHERE s.salesman_id=? ORDER BY s.created_at DESC',[sid]);
    } else {
      data=await db.rawQuery(select+'ORDER BY s.created_at DESC');
    }
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  Future<void> openInvoice([Map<String,Object?>? sale]) async {
    final user=LocalAuthService.instance.current;
    final forced=user?.role==UserRole.salesman ? user?.salesmanId??'' : '';
    if(user?.role==UserRole.salesman&&forced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('This login is not linked to a Salesman account.')),
      );
      return;
    }
    final saved=await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:(_)=>V15InvoicePage(
          existingSale:sale,
          forcedSalesmanId:forced.isEmpty?null:forced,
        ),
      ),
    );
    if(saved==true) await load();
  }

  Future<void> deleteSale(Map<String,Object?> sale) async {
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Sale?'),
        content:Text('Move invoice ${sale['invoice_no']} to Recycle Bin?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    );
    if(ok==true) {
      await AppDatabase.instance.softDeleteById('sales',sale['id'].toString());
      await load();
    }
  }

  Future<void> share(Map<String,Object?> sale) async {
    try {
      await WhatsAppShare.shareInvoice(sale);
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Sales / Cash Report')),
    floatingActionButton:LocalAuthService.instance.canSell
      ?FloatingActionButton.extended(
        onPressed:()=>openInvoice(),
        icon:const Icon(Icons.add),
        label:const Text('New Sale'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Sales / Cash Report',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(
              color:const Color(0xFFEFF6FF),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:const Color(0xFFBFDBFE)),
            ),
            child:const Text(
              'Due and recovery are automatic. If a Customer is selected, the balance goes to that Customer. '
              'If no Customer is selected but a Salesman is selected, the due/recovery is posted automatically '
              'to that Salesman\'s account.',
            ),
          ),
          const SizedBox(height:10),
          if(LocalAuthService.instance.canSell)
            FilledButton.icon(
              onPressed:()=>openInvoice(),
              icon:const Icon(Icons.add_shopping_cart_rounded),
              label:const Text('New / Clear Form'),
            ),
          const SizedBox(height:14),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(12),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('Saved Sales',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
                  const SizedBox(height:8),
                  SingleChildScrollView(
                    scrollDirection:Axis.horizontal,
                    child:DataTable(
                      columns:const [
                        DataColumn(label:Text('Date')),
                        DataColumn(label:Text('Invoice')),
                        DataColumn(label:Text('Customer')),
                        DataColumn(label:Text('Salesman')),
                        DataColumn(label:Text('Qty'),numeric:true),
                        DataColumn(label:Text('Net Sale'),numeric:true),
                        DataColumn(label:Text('Received'),numeric:true),
                        DataColumn(label:Text('Due'),numeric:true),
                        DataColumn(label:Text('')),
                      ],
                      rows:[
                        for(final x in rows)
                          DataRow(cells:[
                            DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                            DataCell(Text(x['invoice_no'].toString())),
                            DataCell(Text(x['customer_name']?.toString()??'')),
                            DataCell(Text(x['salesman_name']?.toString()??'')),
                            DataCell(Text(_money(x['qty']))),
                            DataCell(Text(_money(x['total']))),
                            DataCell(Text(_money(x['paid']))),
                            DataCell(Text(_money(x['due']))),
                            DataCell(Row(
                              mainAxisSize:MainAxisSize.min,
                              children:[
                                if(LocalAuthService.instance.canSell)
                                  IconButton(
                                    tooltip:'Edit',
                                    onPressed:()=>openInvoice(x),
                                    icon:const Icon(Icons.edit_outlined),
                                  ),
                                IconButton(
                                  tooltip:'WhatsApp',
                                  onPressed:()=>share(x),
                                  icon:const Icon(Icons.chat_rounded),
                                ),
                                if(LocalAuthService.instance.isAdmin)
                                  IconButton(
                                    tooltip:'Delete',
                                    onPressed:()=>deleteSale(x),
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

class V15InvoicePage extends StatefulWidget {
  final Map<String,Object?>? existingSale;
  final String? forcedSalesmanId;

  const V15InvoicePage({
    this.existingSale,
    this.forcedSalesmanId,
    super.key,
  });

  @override
  State<V15InvoicePage> createState()=>_V15InvoicePageState();
}

class _V15InvoicePageState extends State<V15InvoicePage> {
  List<Map<String,Object?>> products=const [];
  List<Map<String,Object?>> customers=const [];
  List<Map<String,Object?>> salesmen=const [];
  final cart=<String,Map<String,Object?>>{};

  final vehicle=TextEditingController();
  final invoiceNo=TextEditingController();
  final received=TextEditingController(text:'0');
  final oil=TextEditingController(text:'0');
  final other=TextEditingController(text:'0');
  final note=TextEditingController();

  DateTime date=DateTime.now();
  String customerId='';
  String salesmanId='';
  double oldBalance=0;
  bool loading=true;
  bool saving=false;

  bool get editing=>widget.existingSale!=null;
  double get totalQty=>cart.values.fold(0,(a,x)=>a+_n(x['qty']));
  double get gross=>cart.values.fold(0,(a,x)=>a+_n(x['qty'])*_n(x['price']));
  double get lineDiscount=>cart.values.fold(0,(a,x)=>a+_n(x['discount']));
  double get net=>(gross-lineDiscount).clamp(0,double.infinity).toDouble();
  double get receivedValue=>double.tryParse(received.text.trim())??0;
  double get due=>(net-receivedValue).clamp(0,double.infinity).toDouble();
  double get recovery=>(receivedValue-net).clamp(0,double.infinity).toDouble();
  double get newBalance=>(customerId.isNotEmpty||salesmanId.isNotEmpty)
    ?oldBalance+net-receivedValue
    :0;
  double get totalCash=>receivedValue-_n(oil.text)-_n(other.text);

  @override
  void initState() {
    super.initState();
    for(final c in [received,oil,other]) {
      c.addListener(_refresh);
    }
    _load();
  }

  @override
  void dispose() {
    for(final c in [received,oil,other]) {
      c.removeListener(_refresh);
    }
    vehicle.dispose();
    invoiceNo.dispose();
    received.dispose();
    oil.dispose();
    other.dispose();
    note.dispose();
    super.dispose();
  }

  void _refresh()=>setState(() {});

  Future<void> _load() async {
    final db=await AppDatabase.instance.database;
    final p=await db.query('products',orderBy:'name COLLATE NOCASE');
    final c=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final forced=widget.forcedSalesmanId?.trim()??'';
    final sm=forced.isNotEmpty
      ?await db.query('salesmen',where:'id=?',whereArgs:[forced],limit:1)
      :await db.query('salesmen',orderBy:'name COLLATE NOCASE');

    if(editing) {
      final s=widget.existingSale!;
      vehicle.text=s['vehicle']?.toString()??'';
      invoiceNo.text=s['invoice_no']?.toString()??'';
      received.text=_money(s['paid']);
      oil.text=_money(s['oil']);
      other.text=_money(s['other']);
      note.text=s['note']?.toString()??'';
      customerId=s['customer_id']?.toString()??'';
      salesmanId=forced.isNotEmpty?forced:(s['salesman_id']?.toString()??'');
      date=DateTime.tryParse(s['business_date']?.toString()??'')??DateTime.now();
      final items=await db.query('sale_items',where:'sale_id=?',whereArgs:[s['id']]);
      for(final item in items) {
        final pid=item['product_id']?.toString()??item['id'].toString();
        cart[pid]={
          'product_id':item['product_id'],
          'product_name':item['product_name'],
          'qty':_n(item['qty']),
          'price':_n(item['price']),
          'discount':_n(item['discount']),
          'cost':_n(item['cost']),
        };
      }
    } else {
      salesmanId=forced;
      generateInvoiceNo();
    }

    if(!mounted) return;
    setState(() {
      products=p;
      customers=c;
      salesmen=sm;
      loading=false;
    });
    await _updateOldBalance();
  }

  void generateInvoiceNo() {
    final d=DateTime.now();
    invoiceNo.text='INV-${DateFormat('yyyyMMdd-HHmmss').format(d)}';
  }

  Future<void> _updateOldBalance() async {
    final db=await AppDatabase.instance.database;
    var balance=0.0;
    if(customerId.isNotEmpty) {
      final found=customers.where((x)=>x['id'].toString()==customerId);
      if(found.isNotEmpty) balance=_n(found.first['balance']);
      final oldSale=widget.existingSale;
      final oldCustomerId=oldSale==null?'':oldSale['customer_id']?.toString()??'';
      if(editing&&oldCustomerId==customerId&&oldSale!=null) {
        balance-=_n(oldSale['total'])-_n(oldSale['paid']);
      }
    } else if(salesmanId.isNotEmpty) {
      final oldSale=widget.existingSale;
      final exclude=editing&&oldSale!=null?oldSale['id']?.toString()??'':'';
      final args=<Object?>[salesmanId];
      var where='salesman_id=?';
      if(exclude.isNotEmpty) {
        where+=' AND COALESCE(linked_sale_id,\'\')<>?';
        args.add(exclude);
      }
      final r=await db.rawQuery(
        "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN -amount ELSE amount END),0) balance "
        "FROM salesman_loans WHERE $where",
        args,
      );
      balance=r.isEmpty?0:_n(r.first['balance']);
    }
    if(mounted) setState(()=>oldBalance=balance);
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

  Future<void> addItem() async {
    final selected=await showModalBottomSheet<Map<String,Object?>>(
      context:context,
      isScrollControlled:true,
      builder:(ctx)=>_ProductPicker(products:products),
    );
    if(selected==null) return;
    final id=selected['id'].toString();
    final old=cart[id];
    cart[id]={
      'product_id':id,
      'product_name':selected['name'],
      'price':old?['price']??_n(selected['price']),
      'qty':old==null?1.0:_n(old['qty'])+1,
      'discount':old?['discount']??0.0,
      'cost':_n(selected['cost']),
    };
    setState(() {});
  }

  Future<bool> _confirm(String title,String text) async {
    return await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(title),
        content:Text(text),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Continue')),
        ],
      ),
    )??false;
  }

  Future<bool> _validate() async {
    if(cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Enter sold quantity for at least one product.')),
      );
      return false;
    }
    for(final line in cart.values) {
      final amount=_n(line['price'])*_n(line['qty']);
      if(_n(line['discount'])>amount) {
        if(!await _confirm(
          'Large Discount',
          '${line['product_name']}: Discount (${_money(line['discount'])}) exceeds Amount (${_money(amount)}). Save anyway?',
        )) {
          return false;
        }
      }
    }
    final inv=invoiceNo.text.trim();
    if(inv.isNotEmpty) {
      final db=await AppDatabase.instance.database;
      final duplicate=await db.rawQuery(
        'SELECT id FROM sales WHERE lower(invoice_no)=lower(?) AND id<>? LIMIT 1',
        [inv,widget.existingSale?['id']?.toString()??''],
      );
      if(duplicate.isNotEmpty) {
        if(!await _confirm('Duplicate Invoice No','Another Sales record already uses this Invoice No. Save anyway?')) {
          return false;
        }
      }
    }
    for(final line in cart.values) {
      final pid=line['product_id']?.toString();
      if(pid==null) continue;
      final p=products.where((x)=>x['id'].toString()==pid);
      if(p.isEmpty) continue;
      var available=_n(p.first['stock']);
      if(editing) {
        final db=await AppDatabase.instance.database;
        final old=await db.query(
          'sale_items',
          columns:['qty'],
          where:'sale_id=? AND product_id=?',
          whereArgs:[widget.existingSale!['id'],pid],
          limit:1,
        );
        if(old.isNotEmpty) available+=_n(old.first['qty']);
      }
      if(_n(line['qty'])>available&&available>=0) {
        if(!await _confirm(
          'Low Stock',
          '${line['product_name']} stock is low. Available ${_money(available)}. Save anyway?',
        )) {
          return false;
        }
      }
    }
    if((due>0||recovery>0)&&customerId.isEmpty&&salesmanId.isEmpty) {
      if(!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Please select either a Customer or a Salesman so the due/recovery can be posted.')),
      );
      return false;
    }
    if(customerId.isNotEmpty) {
      final c=customers.where((x)=>x['id'].toString()==customerId);
      final limit=c.isEmpty?0:_n(c.first['credit_limit']);
      if(limit>0&&newBalance>limit) {
        if(!await _confirm('Customer Credit Limit','Customer credit limit is ${_money(limit)}. New balance will be ${_money(newBalance)}. Save anyway?')) {
          return false;
        }
      }
    } else if(salesmanId.isNotEmpty) {
      final s=salesmen.where((x)=>x['id'].toString()==salesmanId);
      final limit=s.isEmpty?0:_n(s.first['credit_limit']);
      if(limit>0&&newBalance>limit) {
        if(!await _confirm('Salesman Credit Limit','Salesman credit limit is ${_money(limit)}. New balance will be ${_money(newBalance)}. Save anyway?')) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> save() async {
    if(saving||!await _validate()) return;
    setState(()=>saving=true);
    try {
      final id=widget.existingSale?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString();
      await AppDatabase.instance.createSale(
        id:id,
        invoiceNo:invoiceNo.text.trim(),
        customerId:customerId.isEmpty?null:customerId,
        salesmanId:salesmanId.isEmpty?null:salesmanId,
        vehicle:vehicle.text.trim(),
        items:cart.values.toList(),
        paid:receivedValue,
        oil:double.tryParse(oil.text.trim())??0,
        other:double.tryParse(other.text.trim())??0,
        note:note.text.trim(),
        businessDate:date,
      );
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(editing?'Invoice updated.':'Invoice saved.')),
      );
      Navigator.pop(context,true);
    } catch(e) {
      if(mounted) {
        setState(()=>saving=false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Invoice save failed: $e')));
      }
    }
  }

  String get customerName {
    if(customerId.isEmpty) return '';
    final x=customers.where((e)=>e['id'].toString()==customerId);
    return x.isEmpty?'':x.first['name'].toString();
  }

  String get salesmanName {
    if(salesmanId.isEmpty) return '';
    final x=salesmen.where((e)=>e['id'].toString()==salesmanId);
    return x.isEmpty?'':x.first['name'].toString();
  }

  Future<void> shareCurrent() async {
    final b=StringBuffer()
      ..writeln('QAMVIO POS — Cash Report')
      ..writeln('Vehicle No: ${vehicle.text}')
      ..writeln('Salesman: $salesmanName')
      ..writeln('Date: ${_date(date)}')
      ..writeln('Customer: $customerName')
      ..writeln('Invoice No: ${invoiceNo.text}')
      ..writeln()
      ..writeln('Products:');
    for(final x in cart.values) {
      b.writeln(
        '• ${x['product_name']} | Price ${_money(x['price'])} | '
        'Qty ${_money(x['qty'])} | Amount ${_money(_n(x['price'])*_n(x['qty']))} | '
        'Discount ${_money(x['discount'])} | T Amount ${_money((_n(x['price'])*_n(x['qty'])-_n(x['discount'])).clamp(0,double.infinity))}',
      );
    }
    b
      ..writeln()
      ..writeln('G.TOTAL Qty: ${_money(totalQty)}')
      ..writeln('Gross: ${_money(gross)}')
      ..writeln('Discount: ${_money(lineDiscount)}')
      ..writeln('Invoice Net Amount: ${_money(net)}')
      ..writeln('Received Cash: ${_money(receivedValue)}')
      ..writeln('Invoice Due: ${_money(due)}')
      ..writeln('Recovery: ${_money(recovery)}')
      ..writeln('Old Account Balance: ${_money(oldBalance)}')
      ..writeln('New Account Balance: ${_money(newBalance)}')
      ..writeln('Oil Expense: ${_money(oil.text)}')
      ..writeln('Masre / Other Expense: ${_money(other.text)}')
      ..writeln('Total Cash After Expenses: ${_money(totalCash)}');
    await WhatsAppShare.send(
      b.toString(),
      phone:customerId.isEmpty?null:customers.where((x)=>x['id'].toString()==customerId).firstOrNull?['phone']?.toString(),
    );
  }

  Future<void> printCurrent() async {
    final settings=await _businessSettings();
    final doc=pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat:PdfPageFormat.a4,
        margin:const pw.EdgeInsets.all(28),
        build:(ctx)=>[
          pw.Text(
            settings['business_name']?.isNotEmpty==true?settings['business_name']!:'QAMVIO POS',
            style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold),
          ),
          pw.Text(settings['business_phone']??''),
          pw.Text(settings['business_address']??''),
          pw.SizedBox(height:10),
          pw.Text('Cash Report',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
          pw.SizedBox(height:6),
          pw.Wrap(spacing:18,runSpacing:4,children:[
            pw.Text('Vehicle No: ${vehicle.text}'),
            pw.Text('Salesman: $salesmanName'),
            pw.Text('Date: ${_date(date)}'),
            pw.Text('Customer: $customerName'),
            pw.Text('Invoice No: ${invoiceNo.text}'),
          ]),
          pw.SizedBox(height:12),
          pw.Table(
            border:pw.TableBorder.all(),
            children:[
              pw.TableRow(
                decoration:const pw.BoxDecoration(color:PdfColors.grey300),
                children:[
                  for(final h in ['Products','Price','Qty','Amount','Discount','T Amount'])
                    pw.Padding(padding:const pw.EdgeInsets.all(4),child:pw.Text(h,style:pw.TextStyle(fontWeight:pw.FontWeight.bold))),
                ],
              ),
              for(final x in cart.values)
                pw.TableRow(children:[
                  _pdfCell(x['product_name'].toString()),
                  _pdfCell(_money(x['price'])),
                  _pdfCell(_money(x['qty'])),
                  _pdfCell(_money(_n(x['price'])*_n(x['qty']))),
                  _pdfCell(_money(x['discount'])),
                  _pdfCell(_money((_n(x['price'])*_n(x['qty'])-_n(x['discount'])).clamp(0,double.infinity))),
                ]),
              pw.TableRow(children:[
                _pdfCell('G.TOTAL',bold:true),
                _pdfCell(''),
                _pdfCell(_money(totalQty),bold:true),
                _pdfCell(_money(gross),bold:true),
                _pdfCell(_money(lineDiscount),bold:true),
                _pdfCell(_money(net),bold:true),
              ]),
            ],
          ),
          pw.SizedBox(height:12),
          for(final pair in <(String,String)>[
            ('Invoice Net Amount',_money(net)),
            ('Received Cash',_money(receivedValue)),
            ('Invoice Due',_money(due)),
            ('Recovery',_money(recovery)),
            ('Old Account Balance',_money(oldBalance)),
            ('New Account Balance',_money(newBalance)),
            ('Oil Expense',_money(oil.text)),
            ('Masre / Other Expense',_money(other.text)),
            ('Total Cash After Expenses',_money(totalCash)),
          ])
            pw.Padding(
              padding:const pw.EdgeInsets.symmetric(vertical:2),
              child:pw.Row(
                mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,
                children:[pw.Text(pair.$1),pw.Text(pair.$2,style:pw.TextStyle(fontWeight:pw.FontWeight.bold))],
              ),
            ),
          pw.SizedBox(height:34),
          pw.Row(
            mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,
            children:[
              pw.Text('__________________\noffice'),
              pw.Text('__________________\nsales man'),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name:'QAMVIO-${invoiceNo.text.trim().isEmpty?'invoice':invoiceNo.text.trim()}.pdf',
      onLayout:(_)=>doc.save(),
    );
  }

  pw.Widget _pdfCell(String text,{bool bold=false})=>pw.Padding(
    padding:const pw.EdgeInsets.all(4),
    child:pw.Text(text,style:bold?pw.TextStyle(fontWeight:pw.FontWeight.bold):null),
  );

  Future<Map<String,String>> _businessSettings() async {
    final db=await AppDatabase.instance.database;
    final r=await db.query('settings');
    return {
      for(final x in r) x['key'].toString():x['value']?.toString()??'',
    };
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:Text(editing?'Edit Sales / Cash Report':'Sales / Cash Report'),
    ),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:const EdgeInsets.fromLTRB(12,8,12,80),
        children:[
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(
              color:const Color(0xFFEFF6FF),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:const Color(0xFFBFDBFE)),
            ),
            child:const Text(
              'Due and recovery are automatic. Customer balance is used when a Customer is selected. '
              'Otherwise Salesman due/recovery is posted automatically.',
            ),
          ),
          const SizedBox(height:10),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  const Text('Cash Report',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                  const SizedBox(height:12),
                  Wrap(
                    spacing:10,
                    runSpacing:10,
                    children:[
                      SizedBox(width:180,child:TextField(controller:vehicle,decoration:const InputDecoration(labelText:'Vehicle No'))),
                      SizedBox(width:210,child:_salesmanField()),
                      SizedBox(
                        width:170,
                        child:InkWell(
                          onTap:chooseDate,
                          child:InputDecorator(
                            decoration:const InputDecoration(labelText:'Date'),
                            child:Text(_date(date)),
                          ),
                        ),
                      ),
                      SizedBox(width:210,child:_customerField()),
                      SizedBox(
                        width:205,
                        child:Column(
                          crossAxisAlignment:CrossAxisAlignment.stretch,
                          children:[
                            TextField(controller:invoiceNo,decoration:const InputDecoration(labelText:'Invoice No')),
                            const SizedBox(height:5),
                            OutlinedButton(onPressed:generateInvoiceNo,child:const Text('Auto No')),
                          ],
                        ),
                      ),
                      SizedBox(
                        width:180,
                        child:OutlinedButton(
                          onPressed:() {
                            vehicle.clear();
                            invoiceNo.clear();
                            received.text='0';
                            oil.text='0';
                            other.text='0';
                            note.clear();
                            cart.clear();
                            customerId='';
                            salesmanId=widget.forcedSalesmanId??'';
                            date=DateTime.now();
                            generateInvoiceNo();
                            _updateOldBalance();
                            setState(() {});
                          },
                          child:const Text('New / Clear Form'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height:12),
                  FilledButton.icon(
                    onPressed:addItem,
                    icon:const Icon(Icons.add),
                    label:const Text('Add Item'),
                  ),
                  const SizedBox(height:8),
                  SingleChildScrollView(
                    scrollDirection:Axis.horizontal,
                    child:DataTable(
                      columnSpacing:14,
                      columns:const [
                        DataColumn(label:Text('Products')),
                        DataColumn(label:Text('Price')),
                        DataColumn(label:Text('Total Sale (Qty)')),
                        DataColumn(label:Text('Amount')),
                        DataColumn(label:Text('Discount')),
                        DataColumn(label:Text('T Amount')),
                        DataColumn(label:Text('')),
                      ],
                      rows:[
                        for(final entry in cart.entries)
                          _lineRow(entry.key,entry.value),
                        DataRow(cells:[
                          const DataCell(Text('G.TOTAL',style:TextStyle(fontWeight:FontWeight.w900))),
                          const DataCell(Text('')),
                          DataCell(Text(_money(totalQty),style:const TextStyle(fontWeight:FontWeight.w900))),
                          DataCell(Text(_money(gross),style:const TextStyle(fontWeight:FontWeight.w900))),
                          DataCell(Text(_money(lineDiscount),style:const TextStyle(fontWeight:FontWeight.w900))),
                          DataCell(Text(_money(net),style:const TextStyle(fontWeight:FontWeight.w900))),
                          const DataCell(Text('')),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height:12),
                  _summaryBox(),
                  const SizedBox(height:22),
                  const Row(
                    children:[
                      Expanded(child:Column(children:[Divider(),Text('office')])),
                      SizedBox(width:30),
                      Expanded(child:Column(children:[Divider(),Text('sales man')])),
                    ],
                  ),
                  const SizedBox(height:14),
                  Wrap(
                    spacing:8,
                    runSpacing:8,
                    children:[
                      FilledButton(
                        onPressed:saving?null:save,
                        child:Text(saving?'Saving…':'Save Invoice'),
                      ),
                      if(editing)
                        OutlinedButton(
                          onPressed:()=>Navigator.pop(context),
                          child:const Text('Cancel Edit'),
                        ),
                      OutlinedButton.icon(
                        onPressed:printCurrent,
                        icon:const Icon(Icons.print_outlined),
                        label:const Text('Print'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:shareCurrent,
                        icon:const Icon(Icons.chat_rounded),
                        label:const Text('WhatsApp Bill'),
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

  Widget _salesmanField() {
    final forced=(widget.forcedSalesmanId??'').isNotEmpty;
    if(forced) {
      return InputDecorator(
        decoration:const InputDecoration(labelText:'Salesman'),
        child:Text(salesmanName.isEmpty?'Linked Salesman':salesmanName),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue:salesmanId,
      decoration:const InputDecoration(labelText:'Salesman'),
      items:[
        const DropdownMenuItem(value:'',child:Text('Select Salesman')),
        for(final x in salesmen)
          DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
      ],
      onChanged:(v) async {
        setState(()=>salesmanId=v??'');
        await _updateOldBalance();
      },
    );
  }

  Widget _customerField()=>DropdownButtonFormField<String>(
    initialValue:customerId,
    decoration:const InputDecoration(labelText:'Customer'),
    items:[
      const DropdownMenuItem(value:'',child:Text('Select Customer')),
      for(final x in customers)
        DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
    ],
    onChanged:(v) async {
      setState(()=>customerId=v??'');
      await _updateOldBalance();
    },
  );

  DataRow _lineRow(String id, Map<String, Object?> x) {
    final amount = _n(x['price']) * _n(x['qty']);
    final t = (amount - _n(x['discount'])).clamp(0, double.infinity);

    return DataRow(
      // Stable row/field keys keep TextFormField state attached to the correct
      // product when invoice rows are inserted or removed.
      key: ValueKey('row_$id'),
      cells: [
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              x['product_name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 90,
            child: TextFormField(
              key: ValueKey('price_$id'),
              initialValue: _money(x['price']),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  setState(() => x['price'] = double.tryParse(v) ?? 0),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 90,
            child: TextFormField(
              key: ValueKey('qty_$id'),
              initialValue: _money(x['qty']),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  setState(() => x['qty'] = double.tryParse(v) ?? 0),
            ),
          ),
        ),
        DataCell(Text(_money(amount))),
        DataCell(
          SizedBox(
            width: 90,
            child: TextFormField(
              key: ValueKey('discount_$id'),
              initialValue: _money(x['discount']),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  setState(() => x['discount'] = double.tryParse(v) ?? 0),
            ),
          ),
        ),
        DataCell(
          Text(
            _money(t),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () => setState(() => cart.remove(id)),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }

  Widget _summaryBox()=>Table(
    border:TableBorder.all(color:const Color(0xFFDFE4EE)),
    columnWidths:const {0:FlexColumnWidth(1.5),1:FlexColumnWidth(1)},
    children:[
      _sumRow('Invoice Net Amount',Text(_money(net),style:const TextStyle(fontWeight:FontWeight.w900))),
      _sumRow('Received Cash',TextField(
        controller:received,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(isDense:true),
      )),
      _sumRow('Invoice Due',Text(_money(due),style:const TextStyle(fontWeight:FontWeight.w900))),
      _sumRow('Recovery',Text(_money(recovery),style:const TextStyle(fontWeight:FontWeight.w900))),
      _sumRow('Old Account Balance',Text(_money(oldBalance),style:const TextStyle(fontWeight:FontWeight.w900))),
      _sumRow('New Account Balance',Text(_money(newBalance),style:const TextStyle(fontWeight:FontWeight.w900))),
      _sumRow('Oil Expense',TextField(
        controller:oil,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(isDense:true),
      )),
      _sumRow('Masre / Other Expense',TextField(
        controller:other,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(isDense:true),
      )),
      _sumRow('Total Cash After Expenses',Text(_money(totalCash),style:const TextStyle(fontWeight:FontWeight.w900))),
    ],
  );

  TableRow _sumRow(String label,Widget value)=>TableRow(
    children:[
      Padding(
        padding:const EdgeInsets.all(10),
        child:Text(label,style:const TextStyle(fontWeight:FontWeight.w700)),
      ),
      Padding(padding:const EdgeInsets.all(6),child:value),
    ],
  );
}

class _ProductPicker extends StatefulWidget {
  final List<Map<String,Object?>> products;
  const _ProductPicker({required this.products});

  @override
  State<_ProductPicker> createState()=>_ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final search=TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q=search.text.trim().toLowerCase();
    final rows=q.isEmpty
      ?widget.products
      :widget.products.where((x)=>x['name'].toString().toLowerCase().contains(q)).toList();
    return SafeArea(
      child:Padding(
        padding:EdgeInsets.fromLTRB(
          14,0,14,MediaQuery.viewInsetsOf(context).bottom+14,
        ),
        child:SizedBox(
          height:MediaQuery.sizeOf(context).height*.72,
          child:Column(
            children:[
              const Text('Add Item',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              TextField(
                controller:search,
                autofocus:true,
                onChanged:(_)=>setState(() {}),
                decoration:const InputDecoration(
                  labelText:'Search Product',
                  prefixIcon:Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height:8),
              Expanded(
                child:ListView.builder(
                  itemCount:rows.length,
                  itemBuilder:(context,i) {
                    final x=rows[i];
                    return ListTile(
                      title:Text(x['name'].toString()),
                      subtitle:Text('Stock ${_money(x['stock'])} • Price ${_money(x['price'])}'),
                      trailing:const Icon(Icons.add_circle_outline_rounded),
                      onTap:()=>Navigator.pop(context,x),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it=iterator;
    if(!it.moveNext()) return null;
    return it.current;
  }
}
