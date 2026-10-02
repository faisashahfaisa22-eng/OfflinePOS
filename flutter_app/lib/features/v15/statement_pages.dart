import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);

class CustomerLoansV15Page extends StatefulWidget {
  const CustomerLoansV15Page({super.key});

  @override
  State<CustomerLoansV15Page> createState()=>_CustomerLoansV15PageState();
}

class _CustomerLoansV15PageState extends State<CustomerLoansV15Page> {
  List<Map<String,Object?>> rows=const [];
  List<Map<String,Object?>> customers=const [];
  bool loading=true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final c=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final r=await db.rawQuery(
      'SELECT l.*,c.name customer_name FROM customer_loans l '
      'JOIN customers c ON c.id=l.customer_id ORDER BY l.created_at DESC',
    );
    if(!mounted) return;
    setState(() {
      customers=c;
      rows=r;
      loading=false;
    });
  }

  Future<void> add() async {
    if(customers.isEmpty) return;
    String customerId=customers.first['id'].toString();
    final given=TextEditingController(text:'0');
    final received=TextEditingController(text:'0');
    final note=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Customer Loan'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                DropdownButtonFormField<String>(
                  initialValue:customerId,
                  decoration:const InputDecoration(labelText:'Customer'),
                  items:[
                    for(final x in customers)
                      DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>customerId=v??customerId),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:given,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Given'),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:received,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Received'),
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
      final g=double.tryParse(given.text.trim())??0;
      final r=double.tryParse(received.text.trim())??0;
      final base=DateTime.now().microsecondsSinceEpoch.toString();
      if(g>0) {
        await AppDatabase.instance.saveCustomerLoan(
          id:'${base}_given',
          customerId:customerId,
          amount:g,
          type:'loan',
          note:note.text.trim(),
        );
      }
      if(r>0) {
        await AppDatabase.instance.saveCustomerLoan(
          id:'${base}_received',
          customerId:customerId,
          amount:r,
          type:'payment',
          note:note.text.trim(),
        );
      }
      await load();
    }
    given.dispose();
    received.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Customer Loans')),
    floatingActionButton:FloatingActionButton.extended(
      onPressed:add,
      icon:const Icon(Icons.add),
      label:const Text('Add Entry'),
    ),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioPageIntro(
            title:'Customer Loans',
            subtitle:'Given and received customer loan transactions.',
            icon:Icons.person_add_alt_1_rounded,
          ),
          const SizedBox(height:16),
          Card(
            child:SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:DataTable(
                columns:const [
                  DataColumn(label:Text('Date')),
                  DataColumn(label:Text('Customer')),
                  DataColumn(label:Text('Given'),numeric:true),
                  DataColumn(label:Text('Received'),numeric:true),
                  DataColumn(label:Text('Note')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text(x['created_at'].toString().split('T').first)),
                      DataCell(Text(x['customer_name'].toString())),
                      DataCell(Text(x['type']=='loan'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['type']=='payment'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['note']?.toString()??'')),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
  );
}

class SalesmanLoansV15Page extends StatefulWidget {
  const SalesmanLoansV15Page({super.key});

  @override
  State<SalesmanLoansV15Page> createState()=>_SalesmanLoansV15PageState();
}

class _SalesmanLoansV15PageState extends State<SalesmanLoansV15Page> {
  List<Map<String,Object?>> rows=const [];
  List<Map<String,Object?>> salesmen=const [];
  bool loading=true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final user=LocalAuthService.instance.current;
    List<Map<String,Object?>> s=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    if(user?.role==UserRole.salesman) {
      s=s.where((x)=>x['id']?.toString()==user?.salesmanId).toList();
    }
    final r=user?.role==UserRole.salesman
      ?await db.rawQuery(
        'SELECT l.*,sm.name salesman_name FROM salesman_loans l '
        'JOIN salesmen sm ON sm.id=l.salesman_id WHERE l.salesman_id=? '
        'ORDER BY l.created_at DESC',
        [user?.salesmanId??''],
      )
      :await db.rawQuery(
        'SELECT l.*,sm.name salesman_name FROM salesman_loans l '
        'JOIN salesmen sm ON sm.id=l.salesman_id ORDER BY l.created_at DESC',
      );
    if(!mounted) return;
    setState(() {
      salesmen=s;
      rows=r;
      loading=false;
    });
  }

  Future<void> add() async {
    if(!LocalAuthService.instance.isAdmin||salesmen.isEmpty) return;
    String salesmanId=salesmen.first['id'].toString();
    final given=TextEditingController(text:'0');
    final received=TextEditingController(text:'0');
    final note=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Salesman Loan'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                DropdownButtonFormField<String>(
                  initialValue:salesmanId,
                  decoration:const InputDecoration(labelText:'Salesman'),
                  items:[
                    for(final x in salesmen)
                      DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>salesmanId=v??salesmanId),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:given,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Given'),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:received,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Received'),
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
      final g=double.tryParse(given.text.trim())??0;
      final r=double.tryParse(received.text.trim())??0;
      final base=DateTime.now().microsecondsSinceEpoch.toString();
      if(g>0) {
        await AppDatabase.instance.saveSalesmanLoan(
          id:'${base}_given',
          salesmanId:salesmanId,
          amount:g,
          type:'loan',
          note:note.text.trim(),
        );
      }
      if(r>0) {
        await AppDatabase.instance.saveSalesmanLoan(
          id:'${base}_received',
          salesmanId:salesmanId,
          amount:r,
          type:'payment',
          note:note.text.trim(),
        );
      }
      await load();
    }
    given.dispose();
    received.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Salesman Loans')),
    floatingActionButton:LocalAuthService.instance.isAdmin
      ?FloatingActionButton.extended(
        onPressed:add,
        icon:const Icon(Icons.add),
        label:const Text('Add Entry'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioPageIntro(
            title:'Salesman Loans',
            subtitle:'Given, received and automatic invoice due/recovery entries.',
            icon:Icons.badge_rounded,
          ),
          const SizedBox(height:16),
          Card(
            child:SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:DataTable(
                columns:const [
                  DataColumn(label:Text('Date')),
                  DataColumn(label:Text('Salesman')),
                  DataColumn(label:Text('Given'),numeric:true),
                  DataColumn(label:Text('Received'),numeric:true),
                  DataColumn(label:Text('Source')),
                  DataColumn(label:Text('Note')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text(x['created_at'].toString().split('T').first)),
                      DataCell(Text(x['salesman_name'].toString())),
                      DataCell(Text(x['type']=='loan'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['type']=='payment'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['source']?.toString()??'manual')),
                      DataCell(Text(x['note']?.toString()??'')),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
  );
}

class CustomerStatementPage extends StatefulWidget {
  const CustomerStatementPage({super.key});

  @override
  State<CustomerStatementPage> createState()=>_CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  List<Map<String,Object?>> customers=const [];
  List<Map<String,Object?>> rows=const [];
  String id='';
  double opening=0;
  double balance=0;
  bool loading=true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db=await AppDatabase.instance.database;
    var c=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final user=LocalAuthService.instance.current;
    if(user?.role==UserRole.salesman) {
      c=c.where((x)=>x['salesman_id']?.toString()==user?.salesmanId).toList();
    }
    customers=c;
    id=c.isEmpty?'':c.first['id'].toString();
    await load();
  }

  Future<void> load() async {
    if(id.isEmpty) {
      if(mounted) setState(()=>loading=false);
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final customer=customers.firstWhere((x)=>x['id'].toString()==id);
    opening=_n(customer['opening']);
    final out=<Map<String,Object?>>[];
    final sales=await db.query('sales',where:'customer_id=?',whereArgs:[id],orderBy:'created_at');
    for(final s in sales) {
      final delta=_n(s['total'])-_n(s['paid']);
      out.add({
        'date':s['business_date']??s['created_at'],
        'type':'Sale / ${s['invoice_no']}',
        'debit':delta>0?delta:0.0,
        'credit':delta<0?-delta:0.0,
        'note':s['note']??'',
      });
    }
    final loans=await db.query('customer_loans',where:'customer_id=?',whereArgs:[id],orderBy:'created_at');
    for(final l in loans) {
      final isLoan=l['type']=='loan';
      out.add({
        'date':l['created_at'],
        'type':isLoan?'Loan Given':'Payment Received',
        'debit':isLoan?_n(l['amount']):0.0,
        'credit':isLoan?0.0:_n(l['amount']),
        'note':l['note']??'',
      });
    }
    out.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    var run=opening;
    for(final x in out) {
      run+=_n(x['debit'])-_n(x['credit']);
      x['balance']=run;
    }
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=run;
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Customer Statement',
    icon:Icons.people_alt_rounded,
    parties:customers,
    selected:id,
    onChanged:(v) async {
      setState(()=>id=v);
      await load();
    },
    opening:opening,
    balance:balance,
    rows:rows,
    loading:loading,
  );
}

class SupplierStatementPage extends StatefulWidget {
  const SupplierStatementPage({super.key});

  @override
  State<SupplierStatementPage> createState()=>_SupplierStatementPageState();
}

class _SupplierStatementPageState extends State<SupplierStatementPage> {
  List<Map<String,Object?>> suppliers=const [];
  List<Map<String,Object?>> rows=const [];
  String id='';
  double opening=0;
  double balance=0;
  bool loading=true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db=await AppDatabase.instance.database;
    suppliers=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    id=suppliers.isEmpty?'':suppliers.first['id'].toString();
    await load();
  }

  Future<void> load() async {
    if(id.isEmpty) {
      if(mounted) setState(()=>loading=false);
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final supplier=suppliers.firstWhere((x)=>x['id'].toString()==id);
    opening=_n(supplier['opening']);
    final out=<Map<String,Object?>>[];
    final purchases=await db.query('purchases',where:'supplier_id=?',whereArgs:[id],orderBy:'created_at');
    for(final p in purchases) {
      out.add({
        'date':p['business_date']??p['created_at'],
        'type':'Purchase / ${p['invoice_no']??''}',
        'debit':_n(p['total'])-_n(p['paid']),
        'credit':0.0,
        'note':p['note']??'',
      });
    }
    final tx=await db.query('supplier_transactions',where:'supplier_id=?',whereArgs:[id],orderBy:'created_at');
    for(final x in tx) {
      final payment=x['type']=='payment';
      out.add({
        'date':x['created_at'],
        'type':payment?'Paid to Supplier':'Received from Supplier',
        'debit':payment?-_n(x['amount']):_n(x['amount']),
        'credit':0.0,
        'note':x['note']??'',
      });
    }
    out.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    var run=opening;
    for(final x in out) {
      run+=_n(x['debit'])-_n(x['credit']);
      x['balance']=run;
    }
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=run;
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Supplier Statement',
    icon:Icons.local_shipping_rounded,
    parties:suppliers,
    selected:id,
    onChanged:(v) async {
      setState(()=>id=v);
      await load();
    },
    opening:opening,
    balance:balance,
    rows:rows,
    loading:loading,
  );
}

class SalesmanStatementPage extends StatefulWidget {
  const SalesmanStatementPage({super.key});

  @override
  State<SalesmanStatementPage> createState()=>_SalesmanStatementPageState();
}

class _SalesmanStatementPageState extends State<SalesmanStatementPage> {
  List<Map<String,Object?>> salesmen=const [];
  List<Map<String,Object?>> rows=const [];
  String id='';
  double balance=0;
  bool loading=true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db=await AppDatabase.instance.database;
    var s=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    final user=LocalAuthService.instance.current;
    if(user?.role==UserRole.salesman) {
      s=s.where((x)=>x['id']?.toString()==user?.salesmanId).toList();
    }
    salesmen=s;
    id=s.isEmpty?'':s.first['id'].toString();
    await load();
  }

  Future<void> load() async {
    if(id.isEmpty) {
      if(mounted) setState(()=>loading=false);
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final out=<Map<String,Object?>>[];
    final sales=await db.query('sales',where:'salesman_id=?',whereArgs:[id],orderBy:'created_at');
    for(final s in sales) {
      final due=_n(s['due']);
      final recovery=_n(s['recovery']);
      if(due==0&&recovery==0) continue;
      out.add({
        'date':s['business_date']??s['created_at'],
        'type':'Invoice ${s['invoice_no']}',
        'debit':due,
        'credit':recovery,
        'note':'Sale due / recovery',
      });
    }
    final loans=await db.query(
      'salesman_loans',
      where:'salesman_id=? AND COALESCE(source,\'manual\') NOT IN (\'sale_due\',\'sale_recovery\')',
      whereArgs:[id],
      orderBy:'created_at',
    );
    for(final l in loans) {
      final isLoan=l['type']=='loan';
      out.add({
        'date':l['created_at'],
        'type':isLoan?'Loan Given':'Payment Received',
        'debit':isLoan?_n(l['amount']):0.0,
        'credit':isLoan?0.0:_n(l['amount']),
        'note':l['note']??'',
      });
    }
    out.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    var run=0.0;
    for(final x in out) {
      run+=_n(x['debit'])-_n(x['credit']);
      x['balance']=run;
    }
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=run;
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Salesman Statement',
    icon:Icons.badge_rounded,
    parties:salesmen,
    selected:id,
    onChanged:(v) async {
      setState(()=>id=v);
      await load();
    },
    opening:0,
    balance:balance,
    rows:rows,
    loading:loading,
  );
}

class _StatementShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String,Object?>> parties;
  final String selected;
  final ValueChanged<String> onChanged;
  final double opening;
  final double balance;
  final List<Map<String,Object?>> rows;
  final bool loading;

  const _StatementShell({
    required this.title,
    required this.icon,
    required this.parties,
    required this.selected,
    required this.onChanged,
    required this.opening,
    required this.balance,
    required this.rows,
    required this.loading,
  });

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(title)),
    body:ListView(
      padding:QamvioUi.pagePadding,
      children:[
        QamvioPageIntro(
          title:title,
          subtitle:'Opening, debit, credit and running balance.',
          icon:icon,
        ),
        const SizedBox(height:16),
        if(parties.isEmpty)
          const QamvioEmptyState(
            icon:Icons.account_balance_wallet_outlined,
            title:'No account available',
            subtitle:'Create the account first.',
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue:selected,
            decoration:const InputDecoration(labelText:'Account'),
            items:[
              for(final p in parties)
                DropdownMenuItem(value:p['id'].toString(),child:Text(p['name'].toString())),
            ],
            onChanged:(v) {
              if(v!=null) onChanged(v);
            },
          ),
          const SizedBox(height:12),
          Row(
            children:[
              Expanded(child:_amount(context,'Opening',opening)),
              const SizedBox(width:8),
              Expanded(child:_amount(context,'Current Balance',balance)),
            ],
          ),
          const SizedBox(height:14),
          if(loading)
            const Center(child:CircularProgressIndicator())
          else
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Date')),
                    DataColumn(label:Text('Type')),
                    DataColumn(label:Text('Debit'),numeric:true),
                    DataColumn(label:Text('Credit'),numeric:true),
                    DataColumn(label:Text('Balance'),numeric:true),
                    DataColumn(label:Text('Note')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['date'].toString().split('T').first)),
                        DataCell(Text(x['type'].toString())),
                        DataCell(Text(_money(x['debit']))),
                        DataCell(Text(_money(x['credit']))),
                        DataCell(Text(_money(x['balance']),style:const TextStyle(fontWeight:FontWeight.w900))),
                        DataCell(Text(x['note']?.toString()??'')),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _amount(BuildContext context,String label,double amount)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(label,style:Theme.of(context).textTheme.bodySmall),
          const SizedBox(height:4),
          Text(_money(amount),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:19)),
        ],
      ),
    ),
  );
}
