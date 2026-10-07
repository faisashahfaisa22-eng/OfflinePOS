import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);
String _day(DateTime d)=>DateFormat('yyyy-MM-dd').format(d);

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
      'JOIN customers c ON c.id=l.customer_id '
      'ORDER BY COALESCE(l.business_date,substr(l.created_at,1,10)) DESC,l.created_at DESC',
    );
    if(!mounted) return;
    setState(() {
      customers=c;
      rows=r;
      loading=false;
    });
  }

  Future<void> edit([Map<String,Object?>? existing]) async {
    if(customers.isEmpty||!LocalAuthService.instance.canEdit) return;
    String customerId=existing?['customer_id']?.toString()??customers.first['id'].toString();
    DateTime date=DateTime.tryParse(existing?['business_date']?.toString()??'')??DateTime.now();
    final given=TextEditingController(text:existing?['type']=='loan'?_money(existing?['amount']):'0');
    final received=TextEditingController(text:existing?['type']=='payment'?_money(existing?['amount']):'0');
    final note=TextEditingController(text:existing?['note']?.toString()??'');
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Customer Loans'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Date'),
                  subtitle:Text(_day(date)),
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
                  initialValue:customerId,
                  decoration:InputDecoration(labelText:tr('Customer')),
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
                  decoration:InputDecoration(labelText:tr('Loan Given')),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:received,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:InputDecoration(labelText:tr('Loan Received')),
                ),
                const SizedBox(height:10),
                TextField(controller:note,decoration:InputDecoration(labelText:tr('Note'))),
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
      final g=double.tryParse(given.text.trim())??0;
      final r=double.tryParse(received.text.trim())??0;
      if((g>0&&r>0)||(g<=0&&r<=0)) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Use only one amount: Loan Given OR Loan Received.')),
          );
        }
      } else {
        await AppDatabase.instance.saveCustomerLoan(
          id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
          customerId:customerId,
          amount:g>0?g:r,
          type:g>0?'loan':'payment',
          note:note.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    given.dispose();
    received.dispose();
    note.dispose();
  }

  Future<void> remove(Map<String,Object?> x) async {
    if(!LocalAuthService.instance.canDelete) return;
    final ok=await _confirmDelete('Customer loan');
    if(ok) {
      await AppDatabase.instance.softDeleteById('customerLoans',x['id'].toString());
      await load();
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Customer Loans')),
    floatingActionButton:LocalAuthService.instance.canEdit
      ?FloatingActionButton.extended(
        onPressed:()=>edit(),
        icon:const Icon(Icons.add),
        label:const Text('Add Entry'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Customer Loans',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
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
                  DataColumn(label:Text('')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                      DataCell(Text(x['customer_name'].toString())),
                      DataCell(Text(x['type']=='loan'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['type']=='payment'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['note']?.toString()??'')),
                      DataCell(Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          if(LocalAuthService.instance.canEdit)
                            IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined)),
                          if(LocalAuthService.instance.canDelete)
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

  Future<bool> _confirmDelete(String label) async=>await showDialog<bool>(
    context:context,
    builder:(ctx)=>AlertDialog(
      title:Text('Delete $label?'),
      content:const Text('The record will be moved to Recycle Bin and balances will be reversed.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
      ],
    ),
  )??false;
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
    var s=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    if(user?.role==UserRole.salesman) {
      s=s.where((x)=>x['id']?.toString()==user?.salesmanId).toList();
    }
    final raw=user?.role==UserRole.salesman
      ?await db.rawQuery(
        'SELECT l.*,sm.name salesman_name FROM salesman_loans l '
        'JOIN salesmen sm ON sm.id=l.salesman_id WHERE l.salesman_id=? '
        'ORDER BY COALESCE(l.business_date,substr(l.created_at,1,10)),l.created_at',
        [user?.salesmanId??''],
      )
      :await db.rawQuery(
        'SELECT l.*,sm.name salesman_name FROM salesman_loans l '
        'JOIN salesmen sm ON sm.id=l.salesman_id '
        'ORDER BY COALESCE(l.business_date,substr(l.created_at,1,10)),l.created_at',
      );

    final balances=<String,double>{};
    final chronological=<Map<String,Object?>>[];
    for(final x in raw) {
      final row=Map<String,Object?>.from(x);
      final sid=row['salesman_id'].toString();
      final delta=row['type']=='payment'?-_n(row['amount']):_n(row['amount']);
      balances[sid]=(balances[sid]??0)+delta;
      row['running_balance']=balances[sid];
      chronological.add(row);
    }

    if(!mounted) return;
    setState(() {
      salesmen=s;
      rows=chronological.reversed.toList();
      loading=false;
    });
  }

  Future<void> edit([Map<String,Object?>? existing]) async {
    if(!LocalAuthService.instance.canEdit||salesmen.isEmpty) return;
    if(existing!=null&&(existing['source']?.toString()??'manual')!='manual') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Automatic invoice Due / Recovery entries are edited from the Sales invoice.')),
      );
      return;
    }
    String salesmanId=existing?['salesman_id']?.toString()??salesmen.first['id'].toString();
    DateTime date=DateTime.tryParse(existing?['business_date']?.toString()??'')??DateTime.now();
    final given=TextEditingController(text:existing?['type']=='loan'?_money(existing?['amount']):'0');
    final received=TextEditingController(text:existing?['type']=='payment'?_money(existing?['amount']):'0');
    final note=TextEditingController(text:existing?['note']?.toString()??'');
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Salesman Loans'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Date'),
                  subtitle:Text(_day(date)),
                  trailing:const Icon(Icons.calendar_month_outlined),
                  onTap:() async {
                    final d=await showDatePicker(context:ctx,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:date);
                    if(d!=null) setLocal(()=>date=d);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue:salesmanId,
                  decoration:InputDecoration(labelText:tr('Salesman')),
                  items:[
                    for(final x in salesmen)
                      DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>salesmanId=v??salesmanId),
                ),
                const SizedBox(height:10),
                TextField(controller:given,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr('Loan Given'))),
                const SizedBox(height:10),
                TextField(controller:received,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr('Loan Received'))),
                const SizedBox(height:10),
                TextField(controller:note,decoration:InputDecoration(labelText:tr('Note'))),
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
      final g=double.tryParse(given.text.trim())??0;
      final r=double.tryParse(received.text.trim())??0;
      if((g>0&&r>0)||(g<=0&&r<=0)) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Use only one amount: Loan Given OR Loan Received.')),
          );
        }
      } else {
        await AppDatabase.instance.saveSalesmanLoan(
          id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
          salesmanId:salesmanId,
          amount:g>0?g:r,
          type:g>0?'loan':'payment',
          note:note.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    given.dispose();
    received.dispose();
    note.dispose();
  }

  Future<void> remove(Map<String,Object?> x) async {
    if(!LocalAuthService.instance.canDelete) return;
    if((x['source']?.toString()??'manual')!='manual') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Automatic invoice entry must be deleted/edited from Sales.')),
      );
      return;
    }
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Salesman Loan?'),
        content:const Text('Move this manual loan/payment to Recycle Bin?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    )??false;
    if(ok) {
      await AppDatabase.instance.softDeleteById('salesmanLoans',x['id'].toString());
      await load();
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Salesman Loans')),
    floatingActionButton:LocalAuthService.instance.canEdit
      ?FloatingActionButton.extended(
        onPressed:()=>edit(),
        icon:const Icon(Icons.add),
        label:const Text('Add Entry'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Salesman Loans',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(
              color:const Color(0xFFEFF6FF),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:const Color(0xFFBFDBFE)),
            ),
            child:const Text('Select the Salesman from the Salesmen page list. Automatic Invoice Due / Recovery entries are also included.'),
          ),
          const SizedBox(height:10),
          Card(
            child:SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:DataTable(
                columns:const [
                  DataColumn(label:Text('Date')),
                  DataColumn(label:Text('Salesman')),
                  DataColumn(label:Text('Given'),numeric:true),
                  DataColumn(label:Text('Received'),numeric:true),
                  DataColumn(label:Text('Balance'),numeric:true),
                  DataColumn(label:Text('Note')),
                  DataColumn(label:Text('')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
                      DataCell(Text(x['salesman_name'].toString())),
                      DataCell(Text(x['type']=='loan'?_money(x['amount']):'0.00')),
                      DataCell(Text(x['type']=='payment'?_money(x['amount']):'0.00')),
                      DataCell(Text(_money(x['running_balance']),style:const TextStyle(fontWeight:FontWeight.w900))),
                      DataCell(Text(x['note']?.toString()??'')),
                      DataCell(Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                          if(LocalAuthService.instance.canEdit)
                            IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined)),
                          if(LocalAuthService.instance.canDelete)
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

class CustomerStatementPage extends StatefulWidget {
  const CustomerStatementPage({super.key});

  @override
  State<CustomerStatementPage> createState()=>_CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  List<Map<String,Object?>> parties=const [];
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
    var p=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final user=LocalAuthService.instance.current;
    if(user?.role==UserRole.salesman) {
      p=p.where((x)=>x['salesman_id']?.toString()==user?.salesmanId).toList();
    }
    parties=p;
    id=p.isEmpty?'':p.first['id'].toString();
    await load();
  }

  Future<void> load() async {
    if(id.isEmpty) {
      if(mounted) setState(()=>loading=false);
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final customer=parties.firstWhere((x)=>x['id'].toString()==id);
    opening=_n(customer['opening']);
    final out=<Map<String,Object?>>[];
    final sales=await db.query('sales',where:'customer_id=?',whereArgs:[id],orderBy:'created_at');
    for(final s in sales) {
      final delta=_n(s['total'])-_n(s['paid']);
      out.add({
        'date':s['business_date']??s['created_at'],
        'type':'Sale',
        'ref':s['invoice_no'],
        'debit':delta>0?delta:0.0,
        'credit':delta<0?-delta:0.0,
        'note':s['note']??'',
      });
    }
    final loans=await db.query('customer_loans',where:'customer_id=?',whereArgs:[id],orderBy:'created_at');
    for(final l in loans) {
      final loan=l['type']=='loan';
      out.add({
        'date':l['business_date']??l['created_at'],
        'type':loan?'Loan Given':'Loan Received',
        'ref':l['id'],
        'debit':loan?_n(l['amount']):0.0,
        'credit':loan?0.0:_n(l['amount']),
        'note':l['note']??'',
      });
    }
    _running(out,opening);
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=out.isEmpty?opening:_n(out.last['balance']);
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Customer Statement / Ledger',
    parties:parties,
    selected:id,
    onChanged:(v) async { setState(()=>id=v); await load(); },
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
  List<Map<String,Object?>> parties=const [];
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
    parties=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    id=parties.isEmpty?'':parties.first['id'].toString();
    await load();
  }

  Future<void> load() async {
    if(id.isEmpty) {
      if(mounted) setState(()=>loading=false);
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final supplier=parties.firstWhere((x)=>x['id'].toString()==id);
    opening=_n(supplier['opening']);
    final out=<Map<String,Object?>>[];
    final purchases=await db.query('purchases',where:'supplier_id=?',whereArgs:[id],orderBy:'created_at');
    for(final p in purchases) {
      out.add({
        'date':p['business_date']??p['created_at'],
        'type':'Purchase',
        'ref':p['invoice_no']??p['id'],
        'debit':_n(p['due']),
        'credit':0.0,
        'note':p['note']??'',
      });
    }
    final tx=await db.query('supplier_transactions',where:'supplier_id=?',whereArgs:[id],orderBy:'created_at');
    for(final x in tx) {
      final paid=x['type']=='payment';
      out.add({
        'date':x['business_date']??x['created_at'],
        'type':paid?'Paid to Supplier':'Received from Supplier',
        'ref':x['id'],
        'debit':paid?-_n(x['amount']):_n(x['amount']),
        'credit':0.0,
        'note':x['note']??'',
      });
    }
    _running(out,opening);
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=out.isEmpty?opening:_n(out.last['balance']);
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Supplier Statement / Ledger',
    parties:parties,
    selected:id,
    onChanged:(v) async { setState(()=>id=v); await load(); },
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
  List<Map<String,Object?>> parties=const [];
  List<Map<String,Object?>> rows=const [];
  String id='';
  double balance=0;
  bool loading=true;
  String lastDue='—';
  String lastRecovery='—';
  String lastTxn='—';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db=await AppDatabase.instance.database;
    var p=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    final user=LocalAuthService.instance.current;
    if(user?.role==UserRole.salesman) {
      p=p.where((x)=>x['id']?.toString()==user?.salesmanId).toList();
    }
    parties=p;
    id=p.isEmpty?'':p.first['id'].toString();
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
    final loans=await db.query('salesman_loans',where:'salesman_id=?',whereArgs:[id],orderBy:'created_at');
    for(final l in loans) {
      final loan=l['type']=='loan';
      final source=l['source']?.toString()??'manual';
      out.add({
        'date':l['business_date']??l['created_at'],
        'type':source=='sale_due'
          ?'Invoice Due'
          :source=='sale_recovery'
            ?'Invoice Recovery'
            :loan?'Loan Given':'Loan Received',
        'ref':l['linked_sale_id']??l['id'],
        'debit':loan?_n(l['amount']):0.0,
        'credit':loan?0.0:_n(l['amount']),
        'note':l['note']??'',
        'source':source,
      });
    }
    _running(out,0);
    String due='—',recovery='—',txn='—';
    for(final x in out.reversed) {
      final d=x['date'].toString().split('T').first;
      if(txn=='—') txn=d;
      if(due=='—'&&x['source']=='sale_due') due=d;
      if(recovery=='—'&&x['source']=='sale_recovery') recovery=d;
    }
    if(!mounted) return;
    setState(() {
      rows=out;
      balance=out.isEmpty?0:_n(out.last['balance']);
      lastDue=due;
      lastRecovery=recovery;
      lastTxn=txn;
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>_StatementShell(
    title:'Salesman Statement / Ledger',
    notice:'This statement includes manual Salesman Loans plus automatic Invoice Due / Recovery entries created from Sales / Cash Report.',
    parties:parties,
    selected:id,
    onChanged:(v) async { setState(()=>id=v); await load(); },
    opening:0,
    balance:balance,
    rows:rows,
    loading:loading,
    extraSummary:[
      _MiniKpi(label:'Last Due Date',value:lastDue),
      _MiniKpi(label:'Last Recovery Date',value:lastRecovery),
      _MiniKpi(label:'Last Transaction Date',value:lastTxn),
    ],
  );
}

void _running(List<Map<String,Object?>> rows,double opening) {
  rows.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
  var run=opening;
  for(final x in rows) {
    run+=_n(x['debit'])-_n(x['credit']);
    x['balance']=run;
  }
}

class _StatementShell extends StatelessWidget {
  final String title;
  final String? notice;
  final List<Map<String,Object?>> parties;
  final String selected;
  final ValueChanged<String> onChanged;
  final double opening;
  final double balance;
  final List<Map<String,Object?>> rows;
  final bool loading;
  final List<Widget> extraSummary;

  const _StatementShell({
    required this.title,
    this.notice,
    required this.parties,
    required this.selected,
    required this.onChanged,
    required this.opening,
    required this.balance,
    required this.rows,
    required this.loading,
    this.extraSummary=const [],
  });

  Future<void> _print() async {
    final doc=pw.Document();
    final selectedName=parties.where((x)=>x['id'].toString()==selected).map((x)=>x['name'].toString()).firstOrNull??'';
    doc.addPage(
      pw.MultiPage(
        pageFormat:PdfPageFormat.a4,
        build:(ctx)=>[
          pw.Text('QAMVIO POS',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
          pw.Text(title,style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold)),
          pw.Text('Account: $selectedName'),
          pw.Text('Opening: ${_money(opening)}     Current Balance: ${_money(balance)}'),
          pw.SizedBox(height:10),
          pw.TableHelper.fromTextArray(
            headers:['Date','Type','Ref','Debit','Credit','Balance','Note'],
            data:[
              for(final x in rows)
                [
                  x['date'].toString().split('T').first,
                  x['type'],
                  x['ref']??'',
                  _money(x['debit']),
                  _money(x['credit']),
                  _money(x['balance']),
                  x['note']??'',
                ],
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name:'QAMVIO-statement.pdf',onLayout:(_)=>doc.save());
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(title)),
    body:ListView(
      padding:QamvioUi.pagePadding,
      children:[
        Text(title,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
        if(notice!=null) ...[
          const SizedBox(height:8),
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(
              color:const Color(0xFFEFF6FF),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:const Color(0xFFBFDBFE)),
            ),
            child:Text(notice!),
          ),
        ],
        const SizedBox(height:10),
        if(parties.isEmpty)
          const QamvioEmptyState(
            icon:Icons.account_balance_wallet_outlined,
            title:'No account available',
            subtitle:'Create the account first.',
          )
        else ...[
          Wrap(
            spacing:8,
            runSpacing:8,
            crossAxisAlignment:WrapCrossAlignment.end,
            children:[
              SizedBox(
                width:260,
                child:DropdownButtonFormField<String>(
                  initialValue:selected,
                  decoration:InputDecoration(labelText:tr('Account')),
                  items:[
                    for(final p in parties)
                      DropdownMenuItem(value:p['id'].toString(),child:Text(p['name'].toString())),
                  ],
                  onChanged:(v) {
                    if(v!=null) onChanged(v);
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed:_print,
                icon:const Icon(Icons.print_outlined),
                label:const Text('Print'),
              ),
            ],
          ),
          const SizedBox(height:10),
          Wrap(
            spacing:8,
            runSpacing:8,
            children:[
              _MiniKpi(label:'Opening Balance',value:_money(opening)),
              _MiniKpi(label:'Current Balance',value:_money(balance)),
              ...extraSummary,
            ],
          ),
          const SizedBox(height:10),
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
                    DataColumn(label:Text('Ref')),
                    DataColumn(label:Text('Debit / Given'),numeric:true),
                    DataColumn(label:Text('Credit / Received'),numeric:true),
                    DataColumn(label:Text('Balance'),numeric:true),
                    DataColumn(label:Text('Note')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['date'].toString().split('T').first)),
                        DataCell(Text(x['type'].toString())),
                        DataCell(Text(x['ref']?.toString()??'')),
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
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  const _MiniKpi({required this.label,required this.value});

  @override
  Widget build(BuildContext context)=>Container(
    width:175,
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:Theme.of(context).cardColor,
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:const Color(0xFFDFE4EE)),
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text(value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(label,style:const TextStyle(fontSize:10,color:Color(0xFF64748B))),
      ],
    ),
  );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it=iterator;
    if(!it.moveNext()) return null;
    return it.current;
  }
}
