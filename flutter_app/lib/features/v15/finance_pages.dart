import 'package:flutter/material.dart';
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
                TextField(controller:name,decoration:const InputDecoration(labelText:'Person / Partner')),
                const SizedBox(height:10),
                TextField(
                  controller:amount,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Amount'),
                ),
                const SizedBox(height:10),
                TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
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
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE substr(created_at,1,10)=?",
      [d],
    );
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
      'COALESCE(SUM(s.paid),0) received,COALESCE(SUM(s.due),0) due '
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
                  ],
                  rows:[
                    for(final r in (x['salesman'] as List<Map<String,Object?>>))
                      DataRow(cells:[
                        DataCell(Text(r['name']?.toString()??'Unassigned')),
                        DataCell(Text(r['invoices'].toString())),
                        DataCell(Text(_money(r['sales']))),
                        DataCell(Text(_money(r['received']))),
                        DataCell(Text(_money(r['due']))),
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
  late Future<List<Map<String,Object?>>> future;

  @override
  void initState() {
    super.initState();
    future=_load();
  }

  Future<List<Map<String,Object?>>> _load() async {
    final db=await AppDatabase.instance.database;
    final out=<Map<String,Object?>>[];

    final sales=await db.query('sales');
    for(final x in sales) {
      if(_n(x['paid'])>0) {
        out.add({
          'date':x['business_date']??x['created_at'],
          'type':'Sale Cash',
          'in':_n(x['paid']),
          'out':0.0,
          'note':'Invoice ${x['invoice_no']}',
        });
      }
      if(_n(x['oil'])>0) {
        out.add({
          'date':x['business_date']??x['created_at'],
          'type':'Oil Expense',
          'in':0.0,
          'out':_n(x['oil']),
          'note':'Invoice ${x['invoice_no']}',
        });
      }
      if(_n(x['other'])>0) {
        out.add({
          'date':x['business_date']??x['created_at'],
          'type':'Other Expense',
          'in':0.0,
          'out':_n(x['other']),
          'note':'Invoice ${x['invoice_no']}',
        });
      }
    }

    final purchases=await db.query('purchases');
    for(final x in purchases) {
      if(_n(x['paid'])<=0) continue;
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':'Purchase Payment',
        'in':0.0,
        'out':_n(x['paid']),
        'note':'Purchase ${x['invoice_no']??''}',
      });
    }

    final supplierTx=await db.query('supplier_transactions');
    for(final x in supplierTx) {
      final payment=x['type']=='payment';
      out.add({
        'date':x['created_at'],
        'type':payment?'Supplier Paid':'Supplier Received',
        'in':payment?0.0:_n(x['amount']),
        'out':payment?_n(x['amount']):0.0,
        'note':x['note']??'',
      });
    }

    final customerLoans=await db.query('customer_loans');
    for(final x in customerLoans) {
      final given=x['type']=='loan';
      out.add({
        'date':x['created_at'],
        'type':given?'Customer Loan Given':'Customer Loan Received',
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
        'date':x['created_at'],
        'type':given?'Salesman Loan Given':'Salesman Loan Received',
        'in':given?0.0:_n(x['amount']),
        'out':given?_n(x['amount']):0.0,
        'note':x['note']??'',
      });
    }

    final expenses=await db.query('expenses');
    for(final x in expenses) {
      out.add({
        'date':x['created_at'],
        'type':'Expense / ${x['category']??''}',
        'in':0.0,
        'out':_n(x['amount']),
        'note':x['name']??x['note']??'',
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

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Cash Book')),
    body:FutureBuilder<List<Map<String,Object?>>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final rows=snapshot.data!;
        final cashIn=rows.fold<double>(0,(a,x)=>a+_n(x['in']));
        final cashOut=rows.fold<double>(0,(a,x)=>a+_n(x['out']));
        final balance=cashIn-cashOut;
        return ListView(
          padding:QamvioUi.pagePadding,
          children:[
            const QamvioPageIntro(
              title:'Cash Book',
              subtitle:'Automatic cash movement from sales, purchases, loans and expenses.',
              icon:Icons.menu_book_rounded,
            ),
            const SizedBox(height:14),
            Row(
              children:[
                Expanded(child:_summary(context,'Cash In',cashIn,QamvioUi.success)),
                const SizedBox(width:8),
                Expanded(child:_summary(context,'Cash Out',cashOut,QamvioUi.danger)),
                const SizedBox(width:8),
                Expanded(child:_summary(context,'Balance',balance,Theme.of(context).colorScheme.primary)),
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
                    DataColumn(label:Text('Cash In'),numeric:true),
                    DataColumn(label:Text('Cash Out'),numeric:true),
                    DataColumn(label:Text('Balance'),numeric:true),
                    DataColumn(label:Text('Note')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['date'].toString().split('T').first)),
                        DataCell(Text(x['type'].toString())),
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
