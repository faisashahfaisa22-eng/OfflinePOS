import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/database/app_database.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);
String _day(DateTime d)=>DateFormat('yyyy-MM-dd').format(d);

class CapitalPage extends StatefulWidget {
  const CapitalPage({super.key});

  @override
  State<CapitalPage> createState()=>_CapitalPageState();
}

class _CapitalPageState extends State<CapitalPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final r=await db.query('capital',orderBy:'business_date DESC, created_at DESC');
    if(!mounted) return;
    setState(() {
      rows=r;
      loading=false;
    });
  }

  Future<void> add([Map<String,Object?>? existing]) async {
    final name=TextEditingController(text:existing?['name']?.toString()??'');
    final amount=TextEditingController(text:existing==null?'':_money(existing['amount']));
    final note=TextEditingController(text:existing?['note']?.toString()??'');
    DateTime date=DateTime.tryParse(existing?['business_date']?.toString()??'')??DateTime.now();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:Text(existing==null?'Owner / Partner Money':'Edit Owner / Partner Money'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  leading:const Icon(Icons.event_outlined),
                  title:const Text('Date'),
                  subtitle:Text(_day(date)),
                  trailing:const Icon(Icons.edit_calendar_outlined),
                  onTap:() async {
                    final picked=await showDatePicker(
                      context:ctx,
                      firstDate:DateTime(2000),
                      lastDate:DateTime(2100),
                      initialDate:date,
                    );
                    if(picked!=null) setLocal(()=>date=picked);
                  },
                ),
                TextField(controller:name,decoration:InputDecoration(labelText:tr('Person / Partner'))),
                const SizedBox(height:10),
                TextField(
                  controller:amount,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:InputDecoration(labelText:tr('Amount')),
                ),
                const SizedBox(height:10),
                TextField(controller:note,decoration:InputDecoration(labelText:tr('Note'))),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save')),
          ],
        ),
      ),
    );
    if(ok==true) {
      final value=double.tryParse(amount.text.trim())??0;
      if(value>0) {
        await AppDatabase.instance.saveCapital(
          id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
          name:name.text.trim().isEmpty?'Owner / Partner':name.text.trim(),
          amount:value,
          note:note.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    name.dispose();
    amount.dispose();
    note.dispose();
  }

  Future<void> remove(Map<String,Object?> x) async {
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Owner / Partner Money?'),
        content:const Text('Move this entry to Recycle Bin?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    )??false;
    if(ok) {
      await AppDatabase.instance.softDeleteById('capital',x['id'].toString());
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total=rows.fold<double>(0,(a,x)=>a+_n(x['amount']));
    return Scaffold(
      appBar:AppBar(title:const Text('Owner / Partner Money')),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:add,
        icon:const Icon(Icons.add),
        label:const Text('Add Money'),
      ),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :ListView(
          padding:QamvioUi.pagePadding,
          children:[
            QamvioPageIntro(
              title:'Owner / Partner Money',
              subtitle:'Capital introduced by owner or partners.',
              icon:Icons.account_balance_rounded,
              trailing:Text(
                _money(total),
                style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900),
              ),
            ),
            const SizedBox(height:16),
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Date')),
                    DataColumn(label:Text('Person / Partner')),
                    DataColumn(label:Text('Amount'),numeric:true),
                    DataColumn(label:Text('Note')),
                    DataColumn(label:Text('')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['business_date'].toString())),
                        DataCell(Text(x['name'].toString())),
                        DataCell(Text(_money(x['amount']))),
                        DataCell(Text(x['note']?.toString()??'')),
                        DataCell(Row(
                          mainAxisSize:MainAxisSize.min,
                          children:[
                            IconButton(onPressed:()=>add(x),icon:const Icon(Icons.edit_outlined)),
                            IconButton(onPressed:()=>remove(x),icon:const Icon(Icons.delete_outline_rounded)),
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
}

class DailyClosingPage extends StatefulWidget {
  const DailyClosingPage({super.key});

  @override
  State<DailyClosingPage> createState()=>_DailyClosingPageState();
}

class _DailyClosingPageState extends State<DailyClosingPage> {
  DateTime date=DateTime.now();
  late Future<Map<String,dynamic>> future;

  @override
  void initState() {
    super.initState();
    future=_load();
  }

  Future<Map<String,dynamic>> _load() async {
    final db=await AppDatabase.instance.database;
    final d=_day(date);
    Future<double> one(String sql,[List<Object?> args=const []]) async {
      final r=await db.rawQuery(sql,args);
      return r.isEmpty?0:_n(r.first.values.first);
    }
    final gross=await one('SELECT COALESCE(SUM(subtotal),0) FROM sales WHERE business_date=?',[d]);
    final discount=await one('SELECT COALESCE(SUM(discount),0) FROM sales WHERE business_date=?',[d]);
    final net=await one('SELECT COALESCE(SUM(total),0) FROM sales WHERE business_date=?',[d]);
    final received=await one('SELECT COALESCE(SUM(paid),0) FROM sales WHERE business_date=?',[d]);
    final due=await one('SELECT COALESCE(SUM(due),0) FROM sales WHERE business_date=?',[d]);
    final recovery=await one('SELECT COALESCE(SUM(recovery),0) FROM sales WHERE business_date=?',[d]);
    final saleExpenses=await one('SELECT COALESCE(SUM(oil+other),0) FROM sales WHERE business_date=?',[d]);
    final expenses=await one(
      "SELECT COALESCE(SUM(amount),0) FROM expenses "
      "WHERE COALESCE(business_date,substr(created_at,1,10))=?",
      [d],
    );
    final expenseBreakdown=await db.rawQuery(
      "SELECT COALESCE(category,'Other') category,SUM(amount) amount FROM expenses "
      "WHERE COALESCE(business_date,substr(created_at,1,10))=? "
      "GROUP BY category ORDER BY amount DESC",
      [d],
    );
    final saleOil=await one('SELECT COALESCE(SUM(oil),0) FROM sales WHERE business_date=?',[d]);
    final saleOther=await one('SELECT COALESCE(SUM(other),0) FROM sales WHERE business_date=?',[d]);
    final expenseRows=<Map<String,Object?>>[...expenseBreakdown];
    if(saleOil>0) expenseRows.add({'category':'Oil (Sales)','amount':saleOil});
    if(saleOther>0) expenseRows.add({'category':'Extra / Other (Sales)','amount':saleOther});
    final cogs=await one(
      'SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,0)),0) '
      'FROM sale_items si JOIN sales s ON s.id=si.sale_id WHERE s.business_date=?',
      [d],
    );
    final qty=await one(
      'SELECT COALESCE(SUM(si.qty),0) FROM sale_items si '
      'JOIN sales s ON s.id=si.sale_id WHERE s.business_date=?',
      [d],
    );
    final count=(await db.rawQuery('SELECT COUNT(*) c FROM sales WHERE business_date=?',[d])).first['c'] as int? ?? 0;
    final invoices=await db.rawQuery(
      'SELECT s.*,c.name customer_name,sm.name salesman_name FROM sales s '
      'LEFT JOIN customers c ON c.id=s.customer_id '
      'LEFT JOIN salesmen sm ON sm.id=s.salesman_id '
      'WHERE s.business_date=? ORDER BY s.created_at',
      [d],
    );
    final salesman=await db.rawQuery(
      'SELECT sm.name,COUNT(s.id) invoices,COALESCE(SUM(s.total),0) sales,'
      'COALESCE(SUM(s.paid),0) received,COALESCE(SUM(s.due),0) due,'
      'COALESCE(SUM(s.recovery),0) recovery '
      'FROM sales s LEFT JOIN salesmen sm ON sm.id=s.salesman_id '
      'WHERE s.business_date=? GROUP BY s.salesman_id,sm.name ORDER BY sales DESC',
      [d],
    );
    final grossProfit=net-cogs;
    final totalExpenses=expenses+saleExpenses;
    return {
      'gross':gross,
      'discount':discount,
      'net':net,
      'received':received,
      'due':due,
      'recovery':recovery,
      'expenses':totalExpenses,
      'cogs':cogs,
      'grossProfit':grossProfit,
      'profit':grossProfit-totalExpenses,
      'qty':qty,
      'count':count,
      'invoices':invoices,
      'salesman':salesman,
      'expenseBreakdown':expenseRows,
    };
  }

  Future<void> chooseDate() async {
    final picked=await showDatePicker(
      context:context,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100),
      initialDate:date,
    );
    if(picked!=null) {
      setState(() {
        date=picked;
        future=_load();
      });
    }
  }

  Future<void> printClosing() async {
    final x=await future;
    final doc=pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat:PdfPageFormat.a4,
        build:(ctx)=>[
          pw.Text('QAMVIO POS — Daily Closing',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
          pw.Text('Date: ${_day(date)}'),
          pw.SizedBox(height:10),
          pw.TableHelper.fromTextArray(
            headers:['Description','Amount'],
            data:[
              ['Gross Sales',_money(x['gross'])],
              ['Discount',_money(x['discount'])],
              ['Net Sales',_money(x['net'])],
              ['Cash Received',_money(x['received'])],
              ['Due Created',_money(x['due'])],
              ['Recovery',_money(x['recovery'])],
              ['Total Expenses',_money(x['expenses'])],
              ['COGS',_money(x['cogs'])],
              ['Gross Profit',_money(x['grossProfit'])],
              ['Net Profit / Loss',_money(x['profit'])],
            ],
          ),
          pw.SizedBox(height:12),
          pw.Text('Expense Breakdown',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers:['Category','Amount'],
            data:[
              for(final r in (x['expenseBreakdown'] as List<Map<String,Object?>>))
                [r['category'],_money(r['amount'])],
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name:'QAMVIO-daily-closing-${_day(date)}.pdf',onLayout:(_)=>doc.save());
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('Daily Closing'),
      actions:[
        TextButton.icon(
          onPressed:chooseDate,
          icon:const Icon(Icons.calendar_month_outlined),
          label:Text(_day(date)),
        ),
        IconButton(
          tooltip:tr('Print Closing'),
          onPressed:printClosing,
          icon:const Icon(Icons.print_outlined),
        ),
      ],
    ),
    body:FutureBuilder<Map<String,dynamic>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final x=snapshot.data!;
        final profit=_n(x['profit']);
        return ListView(
          padding:QamvioUi.pagePadding,
          children:[
            Container(
              padding:const EdgeInsets.all(18),
              decoration:BoxDecoration(
                color:profit>=0?const Color(0xFFECFDF5):const Color(0xFFFFF1F2),
                borderRadius:BorderRadius.circular(16),
                border:Border.all(
                  color:profit>=0?const Color(0xFF86EFAC):const Color(0xFFFDA4AF),
                ),
              ),
              child:Column(
                children:[
                  Text(
                    'Net Profit / Loss • ${_day(date)}',
                    style:const TextStyle(fontWeight:FontWeight.w800),
                  ),
                  const SizedBox(height:6),
                  Text(
                    _money(profit),
                    style:TextStyle(
                      fontSize:30,
                      fontWeight:FontWeight.w900,
                      color:profit>=0?const Color(0xFF166534):const Color(0xFF9F1239),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height:14),
            GridView.count(
              crossAxisCount:2,
              shrinkWrap:true,
              physics:const NeverScrollableScrollPhysics(),
              mainAxisSpacing:8,
              crossAxisSpacing:8,
              childAspectRatio:1.9,
              children:[
                _metric(context,'Gross Sales',x['gross']),
                _metric(context,'Discount',x['discount']),
                _metric(context,'Net Sales',x['net']),
                _metric(context,'Cash Received',x['received']),
                _metric(context,'Due Created',x['due']),
                _metric(context,'Recovery',x['recovery']),
                _metric(context,'Total Expenses',x['expenses']),
                _metric(context,'COGS',x['cogs']),
                _metric(context,'Gross Profit',x['grossProfit']),
                _metric(context,'Sold Qty',x['qty']),
                _metric(context,'Invoice Count',x['count']),
                _metric(context,'Net Profit / Loss',x['profit']),
              ],
            ),
            const SizedBox(height:18),
            const QamvioSectionTitle('Expense Breakdown'),
            Card(
              child:Column(
                children:[
                  for(final r in (x['expenseBreakdown'] as List<Map<String,Object?>>))
                    ListTile(
                      dense:true,
                      title:Text(r['category'].toString()),
                      trailing:Text(_money(r['amount']),style:const TextStyle(fontWeight:FontWeight.w900)),
                    ),
                ],
              ),
            ),
            const SizedBox(height:18),
            const QamvioSectionTitle('Salesman Day Summary'),
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Salesman')),
                    DataColumn(label:Text('Invoices'),numeric:true),
                    DataColumn(label:Text('Sales'),numeric:true),
                    DataColumn(label:Text('Received'),numeric:true),
                    DataColumn(label:Text('Due'),numeric:true),
                    DataColumn(label:Text('Recovery'),numeric:true),
                  ],
                  rows:[
                    for(final r in (x['salesman'] as List<Map<String,Object?>>))
                      DataRow(cells:[
                        DataCell(Text(r['name']?.toString()??'Unassigned')),
                        DataCell(Text(r['invoices'].toString())),
                        DataCell(Text(_money(r['sales']))),
                        DataCell(Text(_money(r['received']))),
                        DataCell(Text(_money(r['due']))),
                        DataCell(Text(_money(r['recovery']))),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height:18),
            const QamvioSectionTitle('Invoices for Date'),
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Invoice')),
                    DataColumn(label:Text('Customer')),
                    DataColumn(label:Text('Salesman')),
                    DataColumn(label:Text('Net'),numeric:true),
                    DataColumn(label:Text('Received'),numeric:true),
                    DataColumn(label:Text('Due'),numeric:true),
                  ],
                  rows:[
                    for(final r in (x['invoices'] as List<Map<String,Object?>>))
                      DataRow(cells:[
                        DataCell(Text(r['invoice_no'].toString())),
                        DataCell(Text(r['customer_name']?.toString()??'')),
                        DataCell(Text(r['salesman_name']?.toString()??'')),
                        DataCell(Text(_money(r['total']))),
                        DataCell(Text(_money(r['paid']))),
                        DataCell(Text(_money(r['due']))),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(BuildContext context,String label,dynamic value)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisAlignment:MainAxisAlignment.center,
        children:[
          Text(label,style:Theme.of(context).textTheme.bodySmall),
          const SizedBox(height:3),
          Text(
            value is int?value.toString():_money(value),
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
          ),
        ],
      ),
    ),
  );
}

class CashBookPage extends StatefulWidget {
  const CashBookPage({super.key});

  @override
  State<CashBookPage> createState()=>_CashBookPageState();
}

class _CashBookPageState extends State<CashBookPage> {
  DateTime? from;
  DateTime? to;
  final search=TextEditingController();
  late Future<List<Map<String,Object?>>> future;

  @override
  void initState() {
    super.initState();
    search.addListener(_filterRefresh);
    future=_load();
  }

  @override
  void dispose() {
    search.removeListener(_filterRefresh);
    search.dispose();
    super.dispose();
  }

  void _filterRefresh()=>setState(() {});

  Future<List<Map<String,Object?>>> _load() async {
    final db=await AppDatabase.instance.database;
    final out=<Map<String,Object?>>[];

    final sales=await db.query('sales');
    for(final x in sales) {
      final date=x['business_date']??x['created_at'];
      if(_n(x['paid'])>0) {
        out.add({
          'date':date,'type':'Sale Cash','ref':x['invoice_no'],
          'in':_n(x['paid']),'out':0.0,'note':x['note']??'',
        });
      }
      if(_n(x['oil'])>0) {
        out.add({
          'date':date,'type':'Oil Expense','ref':x['invoice_no'],
          'in':0.0,'out':_n(x['oil']),'note':'Invoice ${x['invoice_no']}',
        });
      }
      if(_n(x['other'])>0) {
        out.add({
          'date':date,'type':'Other Expense','ref':x['invoice_no'],
          'in':0.0,'out':_n(x['other']),'note':'Invoice ${x['invoice_no']}',
        });
      }
    }

    final purchases=await db.query('purchases');
    for(final x in purchases) {
      if(_n(x['paid'])<=0) continue;
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':'Purchase Payment',
        'ref':x['invoice_no']??x['id'],
        'in':0.0,'out':_n(x['paid']),'note':x['note']??'',
      });
    }

    final supplierTx=await db.query('supplier_transactions');
    for(final x in supplierTx) {
      final payment=x['type']=='payment';
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':payment?'Supplier Paid':'Supplier Received',
        'ref':x['id'],
        'in':payment?0.0:_n(x['amount']),
        'out':payment?_n(x['amount']):0.0,
        'note':x['note']??'',
      });
    }

    final customerLoans=await db.query('customer_loans');
    for(final x in customerLoans) {
      final given=x['type']=='loan';
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':given?'Customer Loan Given':'Customer Loan Received',
        'ref':x['id'],
        'in':given?0.0:_n(x['amount']),
        'out':given?_n(x['amount']):0.0,
        'note':x['note']??'',
      });
    }

    final salesmanLoans=await db.rawQuery(
      "SELECT * FROM salesman_loans "
      "WHERE COALESCE(source,'manual') NOT IN ('sale_due','sale_recovery')",
    );
    for(final x in salesmanLoans) {
      final given=x['type']=='loan';
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':given?'Salesman Loan Given':'Salesman Loan Received',
        'ref':x['id'],
        'in':given?0.0:_n(x['amount']),
        'out':given?_n(x['amount']):0.0,
        'note':x['note']??'',
      });
    }

    final expenses=await db.query('expenses');
    for(final x in expenses) {
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':'Expense / ${x['category']??''}',
        'ref':x['id'],
        'in':0.0,'out':_n(x['amount']),
        'note':'${x['name']??''} ${x['note']??''}'.trim(),
      });
    }

    out.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    var running=0.0;
    for(final x in out) {
      running+=_n(x['in'])-_n(x['out']);
      x['balance']=running;
    }
    return out;
  }

  List<Map<String,Object?>> _filtered(List<Map<String,Object?>> rows) {
    final q=search.text.trim().toLowerCase();
    return rows.where((x) {
      final ds=x['date'].toString().split('T').first;
      final d=DateTime.tryParse(ds);
      if(from!=null&&d!=null&&d.isBefore(DateTime(from!.year,from!.month,from!.day))) return false;
      if(to!=null&&d!=null&&d.isAfter(DateTime(to!.year,to!.month,to!.day))) return false;
      if(q.isEmpty) return true;
      return [x['type'],x['ref'],x['note'],x['date']]
        .join(' ').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _pick(bool start) async {
    final current=start?(from??DateTime.now()):(to??DateTime.now());
    final d=await showDatePicker(
      context:context,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100),
      initialDate:current,
    );
    if(d!=null) {
      setState(() {
        if(start) {
          from=d;
        } else {
          to=d;
        }
      });
    }
  }

  Future<void> printBook(List<Map<String,Object?>> rows) async {
    final filtered=_filtered(rows);
    final doc=pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat:PdfPageFormat.a4,
        build:(ctx)=>[
          pw.Text('QAMVIO POS — Cash Book',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
          pw.Text(
            'From: ${from==null?'All':_day(from!)}   To: ${to==null?'All':_day(to!)}   Search: ${search.text}',
          ),
          pw.SizedBox(height:10),
          pw.TableHelper.fromTextArray(
            headers:['Date','Type','Reference','Cash In','Cash Out','Running Balance','Note'],
            data:[
              for(final x in filtered)
                [
                  x['date'].toString().split('T').first,
                  x['type'],x['ref']??'',
                  _money(x['in']),_money(x['out']),_money(x['balance']),x['note']??'',
                ],
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name:'QAMVIO-cash-book.pdf',onLayout:(_)=>doc.save());
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Cash Book')),
    body:FutureBuilder<List<Map<String,Object?>>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final all=snapshot.data!;
        final rows=_filtered(all);
        final cashIn=rows.fold<double>(0,(a,x)=>a+_n(x['in']));
        final cashOut=rows.fold<double>(0,(a,x)=>a+_n(x['out']));
        final balance=cashIn-cashOut;
        return ListView(
          padding:QamvioUi.pagePadding,
          children:[
            const Text('Cash Book',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:const Color(0xFFEFF6FF),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:const Color(0xFFBFDBFE)),
              ),
              child:const Text(
                'Automatic cash ledger built from Sales, Purchases, Loans, Supplier Payments and Expenses. '
                'Automatic invoice due/recovery entries are not double-counted.',
              ),
            ),
            const SizedBox(height:10),
            Wrap(
              spacing:8,
              runSpacing:8,
              crossAxisAlignment:WrapCrossAlignment.end,
              children:[
                SizedBox(
                  width:150,
                  child:InkWell(
                    onTap:()=>_pick(true),
                    child:InputDecorator(
                      decoration:InputDecoration(labelText:tr('From')),
                      child:Text(from==null?'All':_day(from!)),
                    ),
                  ),
                ),
                SizedBox(
                  width:150,
                  child:InkWell(
                    onTap:()=>_pick(false),
                    child:InputDecorator(
                      decoration:InputDecoration(labelText:tr('To')),
                      child:Text(to==null?'All':_day(to!)),
                    ),
                  ),
                ),
                SizedBox(
                  width:260,
                  child:TextField(
                    controller:search,
                    decoration:InputDecoration(
                      labelText:tr('Search'),
                      hintText:tr('Type, reference, note...'),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed:()=>setState(() { from=null; to=null; search.clear(); }),
                  child:const Text('Refresh'),
                ),
                OutlinedButton.icon(
                  onPressed:()=>printBook(all),
                  icon:const Icon(Icons.print_outlined),
                  label:const Text('Print'),
                ),
              ],
            ),
            const SizedBox(height:12),
            Row(
              children:[
                Expanded(child:_summary(context,'Cash In',cashIn,QamvioUi.success)),
                const SizedBox(width:8),
                Expanded(child:_summary(context,'Cash Out',cashOut,QamvioUi.danger)),
                const SizedBox(width:8),
                Expanded(child:_summary(context,'Net Cash Movement',balance,Theme.of(context).colorScheme.primary)),
              ],
            ),
            const SizedBox(height:14),
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Date')),
                    DataColumn(label:Text('Type')),
                    DataColumn(label:Text('Reference')),
                    DataColumn(label:Text('Cash In'),numeric:true),
                    DataColumn(label:Text('Cash Out'),numeric:true),
                    DataColumn(label:Text('Running Balance'),numeric:true),
                    DataColumn(label:Text('Note')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['date'].toString().split('T').first)),
                        DataCell(Text(x['type'].toString())),
                        DataCell(Text(x['ref']?.toString()??'')),
                        DataCell(Text(_money(x['in']),style:const TextStyle(color:QamvioUi.success,fontWeight:FontWeight.w800))),
                        DataCell(Text(_money(x['out']),style:const TextStyle(color:QamvioUi.danger,fontWeight:FontWeight.w800))),
                        DataCell(Text(_money(x['balance']),style:const TextStyle(fontWeight:FontWeight.w900))),
                        DataCell(Text(x['note']?.toString()??'')),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _summary(BuildContext context,String label,double value,Color color)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(label,style:Theme.of(context).textTheme.bodySmall),
          const SizedBox(height:4),
          Text(
            _money(value),
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:color),
          ),
        ],
      ),
    ),
  );
}
