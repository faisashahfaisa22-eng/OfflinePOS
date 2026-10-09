import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _m(dynamic v)=>QamvioUi.money(v);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState()=>_ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String periodType='day';
  DateTime date=DateTime.now();
  int year=DateTime.now().year;
  int month=DateTime.now().month;
  late Future<Map<String,dynamic>> future;

  @override
  void initState() {
    super.initState();
    future=_load();
  }

  Future<Map<String,dynamic>> _load() async {
    final db=await AppDatabase.instance.database;
    final where=_periodWhere();
    final args=_periodArgs();

    Future<double> scalar(String sql,[List<Object?> a=const []]) async {
      final r=await db.rawQuery(sql,a);
      return r.isEmpty?0:_n(r.first.values.first);
    }

    final gross=await scalar('SELECT COALESCE(SUM(subtotal),0) FROM sales WHERE $where',args);
    final discount=await scalar('SELECT COALESCE(SUM(discount),0) FROM sales WHERE $where',args);
    final net=await scalar('SELECT COALESCE(SUM(total),0) FROM sales WHERE $where',args);
    final cogs=await scalar(
      'SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,p.cost,0)),0) '
      'FROM sale_items si JOIN sales s ON s.id=si.sale_id '
      'LEFT JOIN products p ON p.id=si.product_id WHERE $where',
      args,
    );
    final invoiceCount=(await db.rawQuery('SELECT COUNT(*) c FROM sales WHERE $where',args)).first['c'] as int? ?? 0;

    final expenseWhere=_expensePeriodWhere();
    final salary=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE category='Salary' AND $expenseWhere",
      args,
    );
    final expenseOil=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE category='Oil' AND $expenseWhere",
      args,
    );
    final mechanic=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE category='Mechanic' AND $expenseWhere",
      args,
    );
    final otherExpenses=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses "
      "WHERE COALESCE(category,'Other') NOT IN ('Salary','Oil','Mechanic') AND $expenseWhere",
      args,
    );
    final saleOil=await scalar('SELECT COALESCE(SUM(oil),0) FROM sales WHERE $where',args);
    final saleOther=await scalar('SELECT COALESCE(SUM(other),0) FROM sales WHERE $where',args);
    final oil=expenseOil+saleOil;
    final other=otherExpenses+saleOther;
    final totalExpenses=salary+oil+mechanic+other;
    final grossProfit=net-cogs;
    final netProfit=grossProfit-totalExpenses;

    final allSales=await scalar('SELECT COALESCE(SUM(total),0) FROM sales');
    final allDiscount=await scalar('SELECT COALESCE(SUM(discount),0) FROM sales');
    final allSalary=await scalar("SELECT COALESCE(SUM(amount),0) FROM expenses WHERE category='Salary'");
    final allOil=await scalar("SELECT COALESCE(SUM(amount),0) FROM expenses WHERE category='Oil'")+
      await scalar('SELECT COALESCE(SUM(oil),0) FROM sales');
    final allExtra=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE COALESCE(category,'Other') NOT IN ('Salary','Oil')",
    )+await scalar('SELECT COALESCE(SUM(other),0) FROM sales');
    final salesmanLoans=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN -amount ELSE amount END),0) "
      "FROM salesman_loans",
    );
    final receivable=await scalar('SELECT COALESCE(SUM(balance),0) FROM customers');
    final payable=await scalar('SELECT COALESCE(SUM(balance),0) FROM suppliers');
    final stock=await scalar('SELECT COALESCE(SUM(stock*cost),0) FROM products');
    final capital=await scalar('SELECT COALESCE(SUM(amount),0) FROM capital');

    final cashSales=await scalar('SELECT COALESCE(SUM(paid-oil-other),0) FROM sales');
    final purchaseCash=await scalar('SELECT COALESCE(SUM(paid),0) FROM purchases');
    final supplierCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='received' THEN amount ELSE -amount END),0) "
      "FROM supplier_transactions",
    );
    final customerLoanCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE -amount END),0) "
      "FROM customer_loans",
    );
    final salesmanLoanCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE -amount END),0) "
      "FROM salesman_loans WHERE COALESCE(source,'manual') NOT IN ('sale_due','sale_recovery')",
    );
    final explicitExpenses=await scalar('SELECT COALESCE(SUM(amount),0) FROM expenses');
    final cash=cashSales-purchaseCash+supplierCash+customerLoanCash+salesmanLoanCash-explicitExpenses;
    final position=receivable+stock+cash-payable-capital;

    final productReport=await db.rawQuery(
      'SELECT p.name,p.stock,'
      'COALESCE(SUM(si.qty),0) sold_qty,'
      'COALESCE(SUM(si.total),0) net_sales '
      'FROM products p LEFT JOIN sale_items si ON si.product_id=p.id '
      'GROUP BY p.id,p.name,p.stock ORDER BY p.name COLLATE NOCASE',
    );
    final expenseReport=await db.rawQuery(
      'SELECT COALESCE(category,\'Other\') category,SUM(amount) amount '
      'FROM expenses GROUP BY category ORDER BY amount DESC',
    );
    final salesmanReport=await db.rawQuery(
      "SELECT sm.name,"
      "COALESCE((SELECT SUM(CASE WHEN l.type='payment' THEN -l.amount ELSE l.amount END) "
      "FROM salesman_loans l WHERE l.salesman_id=sm.id),0) balance "
      "FROM salesmen sm ORDER BY balance DESC",
    );

    return {
      'gross':gross,'discount':discount,'net':net,'cogs':cogs,
      'grossProfit':grossProfit,'totalExpenses':totalExpenses,'netProfit':netProfit,
      'invoiceCount':invoiceCount,'salary':salary,'oil':oil,'mechanic':mechanic,'other':other,
      'allSales':allSales,'allDiscount':allDiscount,'allSalary':allSalary,'allOil':allOil,
      'allExtra':allExtra,'salesmanLoans':salesmanLoans,'receivable':receivable,'payable':payable,
      'stock':stock,'cash':cash,'capital':capital,'position':position,
      'productReport':productReport,'expenseReport':expenseReport,'salesmanReport':salesmanReport,
    };
  }

  String _periodWhere() {
    if(periodType=='day') return 'business_date=?';
    if(periodType=='month') return 'substr(business_date,1,7)=?';
    return 'substr(business_date,1,4)=?';
  }

  String _expensePeriodWhere() {
    if(periodType=='day') return "COALESCE(business_date,substr(created_at,1,10))=?";
    if(periodType=='month') return "substr(COALESCE(business_date,created_at),1,7)=?";
    return "substr(COALESCE(business_date,created_at),1,4)=?";
  }

  List<Object?> _periodArgs() {
    if(periodType=='day') return [DateFormat('yyyy-MM-dd').format(date)];
    if(periodType=='month') return ['${year.toString().padLeft(4,'0')}-${month.toString().padLeft(2,'0')}'];
    return [year.toString()];
  }

  String get periodLabel {
    if(periodType=='day') return 'Daily • ${DateFormat('yyyy-MM-dd').format(date)}';
    if(periodType=='month') return 'Monthly • ${year.toString().padLeft(4,'0')}-${month.toString().padLeft(2,'0')}';
    return 'Yearly • $year';
  }

  Future<void> refresh() async {
    setState(()=>future=_load());
    await future;
  }

  Future<void> chooseDay() async {
    final d=await showDatePicker(
      context:context,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100),
      initialDate:date,
    );
    if(d!=null) {
      setState(()=>date=d);
      await refresh();
    }
  }

  String _csvCell(dynamic v) {
    final s=(v??'').toString().replaceAll('"','""');
    return '"$s"';
  }

  Future<void> _shareFile(String filename,String content) async {
    final dir=await getTemporaryDirectory();
    final file=File('${dir.path}/$filename');
    await file.writeAsString(content,flush:true);
    await Share.shareXFiles([XFile(file.path)],subject:filename);
  }

  Future<void> exportSales() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.rawQuery(
      'SELECT s.business_date,s.invoice_no,c.name customer,sm.name salesman,'
      's.subtotal,s.discount,s.total,s.paid,s.due,s.recovery,s.oil,s.other,s.note '
      'FROM sales s LEFT JOIN customers c ON c.id=s.customer_id '
      'LEFT JOIN salesmen sm ON sm.id=s.salesman_id ORDER BY s.created_at',
    );
    final b=StringBuffer('Date,Invoice,Customer,Salesman,Gross,Discount,Net,Received,Due,Recovery,Oil,Other,Note\n');
    for(final x in rows) {
      b.writeln([
        x['business_date'],x['invoice_no'],x['customer'],x['salesman'],x['subtotal'],
        x['discount'],x['total'],x['paid'],x['due'],x['recovery'],x['oil'],x['other'],x['note'],
      ].map(_csvCell).join(','));
    }
    await _shareFile('QAMVIO-sales.csv',b.toString());
  }

  Future<void> exportCustomers() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.rawQuery(
      'SELECT c.name,c.phone,sm.name salesman,c.credit_limit,c.opening,c.balance,c.note '
      'FROM customers c LEFT JOIN salesmen sm ON sm.id=c.salesman_id ORDER BY c.name',
    );
    final b=StringBuffer('Customer,Phone,Salesman,Credit Limit,Opening,Current Balance,Note\n');
    for(final x in rows) {
      b.writeln([
        x['name'],x['phone'],x['salesman'],x['credit_limit'],x['opening'],x['balance'],x['note'],
      ].map(_csvCell).join(','));
    }
    await _shareFile('QAMVIO-customers.csv',b.toString());
  }

  Future<void> exportSuppliers() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query('suppliers',orderBy:'name');
    final b=StringBuffer('Supplier,Phone,Opening,Current Balance,Note\n');
    for(final x in rows) {
      b.writeln([
        x['name'],x['phone'],x['opening'],x['balance'],x['note'],
      ].map(_csvCell).join(','));
    }
    await _shareFile('QAMVIO-suppliers.csv',b.toString());
  }

  Future<void> exportStock() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query('products',orderBy:'name');
    final b=StringBuffer('Product,Opening,Current,Reorder,Cost,Sale Price,Stock Value\n');
    for(final x in rows) {
      b.writeln([
        x['name'],x['opening_qty'],x['stock'],x['reorder_level'],x['cost'],x['price'],
        _n(x['stock'])*_n(x['cost']),
      ].map(_csvCell).join(','));
    }
    await _shareFile('QAMVIO-stock.csv',b.toString());
  }

  Future<void> exportLoanRecovery() async {
    final db=await AppDatabase.instance.database;
    final b=StringBuffer('QAMVIO POS — Loan & Recovery Report\n\n');
    final customer=await db.rawQuery(
      'SELECT l.*,c.name FROM customer_loans l JOIN customers c ON c.id=l.customer_id '
      'ORDER BY l.business_date,l.created_at',
    );
    b.writeln('CUSTOMER LOANS');
    for(final x in customer) {
      b.writeln('${x['business_date']??''} | ${x['name']} | ${x['type']} | ${_m(x['amount'])} | ${x['note']??''}');
    }
    final salesman=await db.rawQuery(
      'SELECT l.*,sm.name FROM salesman_loans l JOIN salesmen sm ON sm.id=l.salesman_id '
      'ORDER BY COALESCE(l.business_date,substr(l.created_at,1,10)),l.created_at',
    );
    b.writeln('\nSALESMAN LOANS / RECOVERY');
    for(final x in salesman) {
      b.writeln('${x['business_date']??''} | ${x['name']} | ${x['type']} | ${_m(x['amount'])} | ${x['source']??'manual'} | ${x['note']??''}');
    }
    await _shareFile('QAMVIO-loan-recovery.txt',b.toString());
  }

  Future<void> shareWhatsApp() async {
    try {
      await WhatsAppShare.shareBusinessReport();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('Reports'),
      actions:[
        IconButton(onPressed:shareWhatsApp,icon:const Icon(Icons.chat_rounded),tooltip:'WhatsApp report'),
      ],
    ),
    body:FutureBuilder<Map<String,dynamic>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final x=snapshot.data!;
        return RefreshIndicator(
          onRefresh:refresh,
          child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:QamvioUi.pagePadding,
            children:[
              const Text('Reports',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              _exportCard(),
              const SizedBox(height:12),
              _profitCard(context,x),
              const SizedBox(height:12),
              GridView.count(
                crossAxisCount:2,
                shrinkWrap:true,
                physics:const NeverScrollableScrollPhysics(),
                mainAxisSpacing:8,
                crossAxisSpacing:8,
                childAspectRatio:1.65,
                children:[
                  QamvioStatCard(label:'Net Sales',value:_m(x['allSales']),icon:Icons.point_of_sale_rounded),
                  QamvioStatCard(label:'Discount',value:_m(x['allDiscount']),icon:Icons.discount_rounded),
                  QamvioStatCard(label:'Salary Expense',value:_m(x['allSalary']),icon:Icons.payments_outlined),
                  QamvioStatCard(label:'Oil Expense',value:_m(x['allOil']),icon:Icons.oil_barrel_outlined),
                  QamvioStatCard(label:'Extra / Other Expense',value:_m(x['allExtra']),icon:Icons.receipt_long_outlined),
                  QamvioStatCard(label:'Salesman Loans',value:_m(x['salesmanLoans']),icon:Icons.badge_outlined),
                  QamvioStatCard(label:'Customer Receivable',value:_m(x['receivable']),icon:Icons.groups_outlined),
                  QamvioStatCard(label:'Supplier Payable',value:_m(x['payable']),icon:Icons.local_shipping_outlined),
                ],
              ),
              const SizedBox(height:12),
              Card(
                child:Padding(
                  padding:const EdgeInsets.all(14),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      const Text('Business Position Calculation',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
                      const SizedBox(height:7),
                      const Text('Customer Receivable + Stock + Cash − Supplier Payable − Owner / Partner Money'),
                      const SizedBox(height:8),
                      Text(
                        '${_m(x['receivable'])} + ${_m(x['stock'])} + ${_m(x['cash'])} − '
                        '${_m(x['payable'])} − ${_m(x['capital'])} = ${_m(x['position'])}',
                        style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height:12),
              _productReport(x['productReport'] as List<Map<String,Object?>>),
              const SizedBox(height:12),
              _expenseReport(x['expenseReport'] as List<Map<String,Object?>>),
              const SizedBox(height:12),
              _salesmanReport(x['salesmanReport'] as List<Map<String,Object?>>),
            ],
          ),
        );
      },
    ),
  );

  Widget _exportCard()=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Export Data',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          Wrap(
            spacing:7,
            runSpacing:7,
            children:[
              FilledButton(onPressed:exportSales,child:const Text('Export Sales CSV')),
              FilledButton(onPressed:exportCustomers,child:const Text('Export Customers CSV')),
              FilledButton(onPressed:exportSuppliers,child:const Text('Export Suppliers CSV')),
              FilledButton(onPressed:exportStock,child:const Text('Export Stock CSV')),
              FilledButton.tonal(onPressed:exportLoanRecovery,child:const Text('📄 Download Loan & Recovery TXT')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _profitCard(BuildContext context,Map<String,dynamic> x)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Profit & Loss — Daily, Monthly and Yearly Report',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          const Text('Net Profit = Net Sales − Cost of Goods Sold − Total Expenses. Discounts are already deducted in Net Sales.'),
          const SizedBox(height:10),
          Wrap(
            spacing:10,
            runSpacing:10,
            crossAxisAlignment:WrapCrossAlignment.end,
            children:[
              SizedBox(
                width:150,
                child:DropdownButtonFormField<String>(
                  initialValue:periodType,
                  decoration:const InputDecoration(labelText:'Report Type'),
                  items:const [
                    DropdownMenuItem(value:'day',child:Text('Daily')),
                    DropdownMenuItem(value:'month',child:Text('Monthly')),
                    DropdownMenuItem(value:'year',child:Text('Yearly')),
                  ],
                  onChanged:(v) async {
                    setState(()=>periodType=v??'day');
                    await refresh();
                  },
                ),
              ),
              if(periodType=='day')
                SizedBox(
                  width:170,
                  child:InkWell(
                    onTap:chooseDay,
                    child:InputDecorator(
                      decoration:const InputDecoration(labelText:'Date'),
                      child:Text(DateFormat('yyyy-MM-dd').format(date)),
                    ),
                  ),
                ),
              if(periodType=='month') ...[
                SizedBox(
                  width:120,
                  child:DropdownButtonFormField<int>(
                    initialValue:month,
                    decoration:const InputDecoration(labelText:'Month'),
                    items:[for(var i=1;i<=12;i++) DropdownMenuItem(value:i,child:Text(i.toString().padLeft(2,'0')))],
                    onChanged:(v) async {
                      setState(()=>month=v??month);
                      await refresh();
                    },
                  ),
                ),
                _yearField(),
              ],
              if(periodType=='year') _yearField(),
              FilledButton(onPressed:refresh,child:const Text('Search')),
            ],
          ),
          const SizedBox(height:10),
          Container(
            padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(
              color:const Color(0xFFF1F5F9),
              borderRadius:BorderRadius.circular(8),
            ),
            child:Text(periodLabel,style:const TextStyle(fontWeight:FontWeight.w800)),
          ),
          const SizedBox(height:10),
          GridView.count(
            crossAxisCount:2,
            shrinkWrap:true,
            physics:const NeverScrollableScrollPhysics(),
            mainAxisSpacing:8,
            crossAxisSpacing:8,
            childAspectRatio:1.7,
            children:[
              QamvioStatCard(label:'Gross Sales',value:_m(x['gross']),icon:Icons.attach_money_rounded),
              QamvioStatCard(label:'Discount',value:_m(x['discount']),icon:Icons.discount_outlined),
              QamvioStatCard(label:'Net Sales',value:_m(x['net']),icon:Icons.point_of_sale_outlined),
              QamvioStatCard(label:'Cost of Goods Sold',value:_m(x['cogs']),icon:Icons.inventory_2_outlined),
              QamvioStatCard(label:'Gross Profit',value:_m(x['grossProfit']),icon:Icons.trending_up_rounded),
              QamvioStatCard(label:'Total Expenses',value:_m(x['totalExpenses']),icon:Icons.receipt_long_outlined),
              QamvioStatCard(label:'Net Profit / Loss',value:_m(x['netProfit']),icon:Icons.analytics_outlined),
              QamvioStatCard(label:'Invoice Count',value:x['invoiceCount'].toString(),icon:Icons.receipt_outlined),
            ],
          ),
          const SizedBox(height:10),
          Table(
            border:TableBorder.all(color:const Color(0xFFDFE4EE)),
            children:[
              _r('Salary',x['salary']),
              _r('Oil',x['oil']),
              _r('Mechanic',x['mechanic']),
              _r('Extra / Other Expenses',x['other']),
            ],
          ),
          const SizedBox(height:7),
          const Text(
            "Note: for older Sales records without historical cost data, the system uses the product's current cost.",
            style:TextStyle(fontSize:10,color:Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );

  Widget _yearField()=>SizedBox(
    width:130,
    child:TextFormField(
      initialValue:year.toString(),
      keyboardType:TextInputType.number,
      decoration:const InputDecoration(labelText:'Year'),
      onChanged:(v)=>year=int.tryParse(v)??year,
      onFieldSubmitted:(_) async =>refresh(),
    ),
  );

  TableRow _r(String label,dynamic amount)=>TableRow(children:[
    Padding(padding:const EdgeInsets.all(8),child:Text(label)),
    Padding(padding:const EdgeInsets.all(8),child:Text(_m(amount),textAlign:TextAlign.end,style:const TextStyle(fontWeight:FontWeight.w800))),
  ]);

  Widget _productReport(List<Map<String,Object?>> rows)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Every Product — Sold Quantity',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          SingleChildScrollView(
            scrollDirection:Axis.horizontal,
            child:DataTable(
              columns:const [
                DataColumn(label:Text('Product')),
                DataColumn(label:Text('Sold Qty'),numeric:true),
                DataColumn(label:Text('Net Sales'),numeric:true),
                DataColumn(label:Text('Current Stock'),numeric:true),
              ],
              rows:[
                for(final x in rows)
                  DataRow(cells:[
                    DataCell(Text(x['name'].toString())),
                    DataCell(Text(_m(x['sold_qty']))),
                    DataCell(Text(_m(x['net_sales']))),
                    DataCell(Text(_m(x['stock']))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _expenseReport(List<Map<String,Object?>> rows)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Expense Report',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          for(final x in rows)
            ListTile(
              dense:true,
              title:Text(x['category'].toString()),
              trailing:Text(_m(x['amount']),style:const TextStyle(fontWeight:FontWeight.w900)),
            ),
        ],
      ),
    ),
  );

  Widget _salesmanReport(List<Map<String,Object?>> rows)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Salesman Loan Report',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          for(final x in rows)
            ListTile(
              dense:true,
              title:Text(x['name'].toString()),
              trailing:Text(_m(x['balance']),style:const TextStyle(fontWeight:FontWeight.w900)),
            ),
        ],
      ),
    ),
  );
}
