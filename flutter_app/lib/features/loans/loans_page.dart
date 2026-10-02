import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/share/whatsapp_share.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState()=>_LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  List<Map<String,Object?>> customerRows=const [];
  List<Map<String,Object?>> salesmen=const [];
  List<Map<String,Object?>> suppliers=const [];
  bool loading=true;

  double _n(dynamic value)=>value is num
    ?value.toDouble()
    :double.tryParse(value?.toString()??'')??0;

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final customerData=await db.rawQuery(
      'SELECT l.*,c.name customer_name,c.phone customer_phone '
      'FROM customer_loans l JOIN customers c ON c.id=l.customer_id '
      'ORDER BY l.created_at DESC',
    );
    final salesmanData=await db.rawQuery(
      "SELECT sm.*,"
      "COALESCE((SELECT SUM(s.due) FROM sales s WHERE s.salesman_id=sm.id),0) invoice_due,"
      "COALESCE((SELECT SUM(CASE WHEN l.type='payment' THEN -l.amount ELSE l.amount END) "
      "FROM salesman_loans l WHERE l.salesman_id=sm.id "
      "AND COALESCE(l.source,'manual') NOT IN ('sale_due','sale_recovery')),0) manual_loan_balance "
      "FROM salesmen sm ORDER BY sm.name COLLATE NOCASE",
    );
    final supplierData=await db.query('suppliers',orderBy:'name COLLATE NOCASE');

    if(!mounted) return;
    setState(() {
      customerRows=customerData;
      salesmen=salesmanData;
      suppliers=supplierData;
      loading=false;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> _entryDialog({
    required String title,
    required List<Map<String,Object?>> parties,
    required String initialType,
    required String partyLabel,
    required List<DropdownMenuItem<String>> typeItems,
    required Future<void> Function(String,double,String,String) save,
  }) async {
    if(parties.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('Add a $partyLabel first.')),
        );
      }
      return;
    }

    String partyId=parties.first['id'].toString();
    String type=initialType;
    final amount=TextEditingController();
    final note=TextEditingController();

    final ok=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>StatefulBuilder(
        builder:(dialogContext,setLocal)=>AlertDialog(
          title:Text(title),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                DropdownButtonFormField<String>(
                  initialValue:partyId,
                  decoration:InputDecoration(labelText:partyLabel),
                  items:parties.map(
                    (x)=>DropdownMenuItem(
                      value:x['id'].toString(),
                      child:Text(x['name'].toString()),
                    ),
                  ).toList(),
                  onChanged:(v)=>setLocal(()=>partyId=v!),
                ),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:type,
                  decoration:const InputDecoration(labelText:'Transaction'),
                  items:typeItems,
                  onChanged:(v)=>setLocal(()=>type=v!),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:amount,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(labelText:'Amount'),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:note,
                  decoration:const InputDecoration(labelText:'Note'),
                ),
              ],
            ),
          ),
          actions:[
            TextButton(
              onPressed:()=>Navigator.pop(dialogContext,false),
              child:const Text('Cancel'),
            ),
            FilledButton(
              onPressed:()=>Navigator.pop(dialogContext,true),
              child:const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if(ok!=true) {
      amount.dispose();
      note.dispose();
      return;
    }

    final value=double.tryParse(amount.text.trim())??0;
    final memo=note.text.trim();
    amount.dispose();
    note.dispose();

    if(value<=0) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Amount must be greater than zero.')),
        );
      }
      return;
    }

    await save(partyId,value,type,memo);
    await load();
  }

  Future<void> addCustomerLoan() async {
    final db=await AppDatabase.instance.database;
    final parties=await db.query('customers',orderBy:'name COLLATE NOCASE');
    await _entryDialog(
      title:'Customer Loan / Payment',
      parties:parties,
      initialType:'loan',
      partyLabel:'Customer',
      typeItems:const [
        DropdownMenuItem(value:'loan',child:Text('Loan / Give credit')),
        DropdownMenuItem(value:'payment',child:Text('Payment received')),
      ],
      save:(partyId,amount,type,note)=>AppDatabase.instance.saveCustomerLoan(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        customerId:partyId,
        amount:amount,
        type:type,
        note:note,
      ),
    );
  }

  Future<void> addSalesmanLoan([String? selectedId]) async {
    final db=await AppDatabase.instance.database;
    var parties=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    if(selectedId!=null && parties.isNotEmpty) {
      parties=[
        ...parties.where((x)=>x['id'].toString()==selectedId),
        ...parties.where((x)=>x['id'].toString()!=selectedId),
      ];
    }
    await _entryDialog(
      title:'Salesman Loan / Payment',
      parties:parties,
      initialType:'loan',
      partyLabel:'Salesman',
      typeItems:const [
        DropdownMenuItem(value:'loan',child:Text('Loan given to salesman')),
        DropdownMenuItem(value:'payment',child:Text('Payment received from salesman')),
      ],
      save:(partyId,amount,type,note)=>AppDatabase.instance.saveSalesmanLoan(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        salesmanId:partyId,
        amount:amount,
        type:type,
        note:note,
      ),
    );
  }

  Future<void> addSupplierTransaction([String? selectedId]) async {
    final db=await AppDatabase.instance.database;
    var parties=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    if(selectedId!=null && parties.isNotEmpty) {
      parties=[
        ...parties.where((x)=>x['id'].toString()==selectedId),
        ...parties.where((x)=>x['id'].toString()!=selectedId),
      ];
    }
    await _entryDialog(
      title:'Supplier Payment / Receipt',
      parties:parties,
      initialType:'payment',
      partyLabel:'Supplier',
      typeItems:const [
        DropdownMenuItem(value:'payment',child:Text('Paid to supplier')),
        DropdownMenuItem(value:'received',child:Text('Received from supplier')),
      ],
      save:(partyId,amount,type,note)=>AppDatabase.instance.saveSupplierTransaction(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        supplierId:partyId,
        amount:amount,
        type:type,
        note:note,
      ),
    );
  }

  Future<void> showSalesmanLedger(Map<String,Object?> salesman) async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query(
      'salesman_loans',
      where:'salesman_id=?',
      whereArgs:[salesman['id']],
      orderBy:'created_at DESC',
    );
    if(!mounted) return;
    final invoiceDue=_n(salesman['invoice_due']);
    final manual=_n(salesman['manual_loan_balance']);
    await showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>SizedBox(
        height:MediaQuery.sizeOf(sheetContext).height*.75,
        child:Column(
          children:[
            ListTile(
              title:Text('${salesman['name']} — Ledger'),
              subtitle:Text(
                'Invoice due: ${WhatsAppShare.money(invoiceDue)} • '
                'Manual loan: ${WhatsAppShare.money(manual)} • '
                'Total: ${WhatsAppShare.money(invoiceDue+manual)}',
              ),
              trailing:IconButton(
                tooltip:'Close',
                onPressed:()=>Navigator.pop(sheetContext),
                icon:const Icon(Icons.close),
              ),
            ),
            const Divider(height:1),
            Expanded(
              child:rows.isEmpty
                ?const Center(child:Text('No salesman loan transactions.'))
                :ListView.separated(
                    itemCount:rows.length,
                    separatorBuilder:(_,__)=>const Divider(height:1),
                    itemBuilder:(_,i) {
                      final x=rows[i];
                      final payment=x['type']=='payment';
                      return ListTile(
                        leading:Icon(payment?Icons.south_west:Icons.north_east),
                        title:Text(payment?'Payment received':'Loan given'),
                        subtitle:Text(
                          '${x['created_at']??''}\n${x['note']??''}',
                        ),
                        isThreeLine:true,
                        trailing:Text(
                          '${payment?'-':'+'}${WhatsAppShare.money(x['amount'])}',
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showSupplierLedger(Map<String,Object?> supplier) async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query(
      'supplier_transactions',
      where:'supplier_id=?',
      whereArgs:[supplier['id']],
      orderBy:'created_at DESC',
    );
    if(!mounted) return;
    await showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>SizedBox(
        height:MediaQuery.sizeOf(sheetContext).height*.75,
        child:Column(
          children:[
            ListTile(
              title:Text('${supplier['name']} — Supplier Ledger'),
              subtitle:Text(
                'Current payable balance: ${WhatsAppShare.money(supplier['balance'])}',
              ),
              trailing:IconButton(
                tooltip:'Close',
                onPressed:()=>Navigator.pop(sheetContext),
                icon:const Icon(Icons.close),
              ),
            ),
            const Divider(height:1),
            Expanded(
              child:rows.isEmpty
                ?const Center(child:Text('No supplier payment transactions.'))
                :ListView.separated(
                    itemCount:rows.length,
                    separatorBuilder:(_,__)=>const Divider(height:1),
                    itemBuilder:(_,i) {
                      final x=rows[i];
                      final paid=x['type']=='payment';
                      return ListTile(
                        leading:Icon(paid?Icons.north_east:Icons.south_west),
                        title:Text(paid?'Paid to supplier':'Received from supplier'),
                        subtitle:Text(
                          '${x['created_at']??''}\n${x['note']??''}',
                        ),
                        isThreeLine:true,
                        trailing:Text(
                          '${paid?'-':'+'}${WhatsAppShare.money(x['amount'])}',
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> runShare(Future<void> Function() fn) async {
    try {
      await fn();
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('WhatsApp: $e')),
      );
    }
  }

  Widget _addButton({
    required String label,
    required VoidCallback onPressed,
  })=>Padding(
    padding:const EdgeInsets.fromLTRB(12,12,12,8),
    child:SizedBox(
      width:double.infinity,
      child:FilledButton.icon(
        onPressed:onPressed,
        icon:const Icon(Icons.add),
        label:Text(label),
      ),
    ),
  );

  Widget customerTab()=>Column(
    children:[
      _addButton(label:'Add Customer Loan / Payment',onPressed:addCustomerLoan),
      Expanded(
        child:customerRows.isEmpty
          ?const Center(child:Text('No customer loan transactions.'))
          :ListView.separated(
              itemCount:customerRows.length,
              separatorBuilder:(_,__)=>const Divider(height:1),
              itemBuilder:(_,i) {
                final x=customerRows[i];
                return ListTile(
                  leading:const CircleAvatar(child:Icon(Icons.person)),
                  title:Text(x['customer_name'].toString()),
                  subtitle:Text(
                    '${x['type']??''} • ${x['note']??''}\n${x['created_at']??''}',
                  ),
                  isThreeLine:true,
                  trailing:Text(WhatsAppShare.money(x['amount'])),
                );
              },
            ),
      ),
    ],
  );

  Widget salesmanTab()=>Column(
    children:[
      _addButton(
        label:'Add Salesman Loan / Payment',
        onPressed:()=>addSalesmanLoan(),
      ),
      Expanded(
        child:salesmen.isEmpty
          ?const Center(child:Text('No salesmen found.'))
          :ListView.separated(
              itemCount:salesmen.length,
              separatorBuilder:(_,__)=>const Divider(height:1),
              itemBuilder:(_,i) {
                final x=salesmen[i];
                final invoiceDue=_n(x['invoice_due']);
                final manual=_n(x['manual_loan_balance']);
                final total=invoiceDue+manual;
                return ListTile(
                  onTap:()=>showSalesmanLedger(x),
                  leading:const CircleAvatar(child:Icon(Icons.badge)),
                  title:Text(x['name'].toString()),
                  subtitle:Text(
                    'Invoice due: ${WhatsAppShare.money(invoiceDue)}\n'
                    'Manual loan: ${WhatsAppShare.money(manual)} • '
                    'Total: ${WhatsAppShare.money(total)}',
                  ),
                  isThreeLine:true,
                  trailing:Row(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      IconButton(
                        tooltip:'Add loan/payment',
                        icon:const Icon(Icons.add_card),
                        onPressed:()=>addSalesmanLoan(x['id'].toString()),
                      ),
                      IconButton(
                        tooltip:'Share salesman statement on WhatsApp',
                        icon:const Icon(Icons.chat),
                        onPressed:()=>runShare(
                          ()=>WhatsAppShare.shareSalesmanCredit(x),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    ],
  );

  Widget supplierTab()=>Column(
    children:[
      _addButton(
        label:'Add Supplier Payment / Receipt',
        onPressed:()=>addSupplierTransaction(),
      ),
      Expanded(
        child:suppliers.isEmpty
          ?const Center(child:Text('No suppliers found.'))
          :ListView.separated(
              itemCount:suppliers.length,
              separatorBuilder:(_,__)=>const Divider(height:1),
              itemBuilder:(_,i) {
                final x=suppliers[i];
                return ListTile(
                  onTap:()=>showSupplierLedger(x),
                  leading:const CircleAvatar(child:Icon(Icons.local_shipping)),
                  title:Text(x['name'].toString()),
                  subtitle:Text(
                    'Phone: ${x['phone']??''}\n'
                    'Payable balance: ${WhatsAppShare.money(x['balance'])}',
                  ),
                  isThreeLine:true,
                  trailing:Row(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      IconButton(
                        tooltip:'Add payment/receipt',
                        icon:const Icon(Icons.payments),
                        onPressed:()=>addSupplierTransaction(x['id'].toString()),
                      ),
                      IconButton(
                        tooltip:'Share supplier statement on WhatsApp',
                        icon:const Icon(Icons.chat),
                        onPressed:()=>runShare(
                          ()=>WhatsAppShare.shareSupplierCredit(x),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context)=>DefaultTabController(
    length:3,
    child:Scaffold(
      appBar:AppBar(
        title:const Text('Loans / Credit'),
        bottom:const TabBar(
          tabs:[
            Tab(text:'Customer'),
            Tab(text:'Salesman'),
            Tab(text:'Supplier'),
          ],
        ),
      ),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :TabBarView(
          children:[
            customerTab(),
            salesmanTab(),
            supplierTab(),
          ],
        ),
    ),
  );
}
