import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';

import '../../core/database/app_database.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

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
          SnackBar(content:Text('${tr('Add a')} $partyLabel ${tr('first.')}')),
        );
      }
      return;
    }

    String partyId=parties.first['id'].toString();
    String type=initialType;
    final amount=TextEditingController();
    final note=TextEditingController();

    final ok=await showModalBottomSheet<bool>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>StatefulBuilder(
        builder:(sheetContext,setLocal)=>Padding(
          padding:EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom+20,
          ),
          child:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                Text(
                  title,
                  style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                    fontWeight:FontWeight.w900,
                  ),
                ),
                const SizedBox(height:4),
                Text('${tr('Record a ledger transaction for this')} $partyLabel ${tr('account.')}'),
                const SizedBox(height:18),
                DropdownButtonFormField<String>(
                  initialValue:partyId,
                  decoration:InputDecoration(
                    labelText:partyLabel,
                    prefixIcon:const Icon(Icons.person_outline_rounded),
                  ),
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
                  decoration:InputDecoration(
                    labelText:tr('Transaction type'),
                    prefixIcon:Icon(Icons.swap_vert_rounded),
                  ),
                  items:typeItems,
                  onChanged:(v)=>setLocal(()=>type=v!),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:amount,
                  autofocus:true,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:InputDecoration(
                    labelText:tr('Amount'),
                    prefixIcon:Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:note,
                  decoration:InputDecoration(
                    labelText:tr('Note'),
                    prefixIcon:Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height:18),
                FilledButton.icon(
                  onPressed:()=>Navigator.pop(sheetContext,true),
                  icon:const Icon(Icons.save_outlined),
                  label:const Text('Save Transaction'),
                ),
                const SizedBox(height:8),
                TextButton(
                  onPressed:()=>Navigator.pop(sheetContext,false),
                  child:const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if(ok==true) {
      final value=double.tryParse(amount.text.trim())??0;
      if(value>0) {
        await save(partyId,value,type,note.text.trim());
        await load();
      } else if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Amount must be greater than zero.')),
        );
      }
    }

    amount.dispose();
    note.dispose();
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
              title:Text('${salesman['name']} — ${tr('Ledger')}'),
              subtitle:Text(
                '${tr('Invoice due')}: ${WhatsAppShare.money(invoiceDue)} • '
                '${tr('Manual loan')}: ${WhatsAppShare.money(manual)} • '
                '${tr('Total')}: ${WhatsAppShare.money(invoiceDue+manual)}',
              ),
              trailing:IconButton(
                tooltip:tr('Close'),
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
              title:Text('${supplier['name']} — ${tr('Supplier Ledger')}'),
              subtitle:Text(
                '${tr('Current payable balance')}: ${WhatsAppShare.money(supplier['balance'])}',
              ),
              trailing:IconButton(
                tooltip:tr('Close'),
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
        SnackBar(content:Text('${tr('WhatsApp')}: $e')),
      );
    }
  }

  Widget _addButton({
    required String label,
    required VoidCallback onPressed,
  })=>Padding(
    padding:const EdgeInsets.fromLTRB(0,10,0,10),
    child:SizedBox(
      width:double.infinity,
      child:FilledButton.icon(
        onPressed:onPressed,
        icon:const Icon(Icons.add_rounded),
        label:Text(label),
      ),
    ),
  );

  Widget customerTab()=>ListView(
    padding:const EdgeInsets.fromLTRB(16,0,16,96),
    children:[
      _addButton(label:'Add Customer Loan / Payment',onPressed:addCustomerLoan),
      if(customerRows.isEmpty)
        const QamvioEmptyState(
          icon:Icons.person_outline_rounded,
          title:'No customer loan transactions',
          subtitle:'Loan and payment entries will appear here.',
        )
      else
        ...customerRows.map((x)=>Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Row(
                children:[
                  Container(
                    width:46,
                    height:46,
                    decoration:BoxDecoration(
                      color:Theme.of(context).colorScheme.primaryContainer,
                      borderRadius:BorderRadius.circular(15),
                    ),
                    child:Icon(
                      Icons.person_rounded,
                      color:Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width:12),
                  Expanded(
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        Text(
                          x['customer_name'].toString(),
                          style:const TextStyle(fontWeight:FontWeight.w900),
                        ),
                        const SizedBox(height:3),
                        Text(
                          '${x['type']??''} • ${x['note']??''}',
                          maxLines:1,
                          overflow:TextOverflow.ellipsis,
                          style:Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:const Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height:3),
                        Text(
                          '${x['created_at']??''}',
                          style:Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:const Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    QamvioUi.money(x['amount']),
                    style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                  ),
                ],
              ),
            ),
          ),
        )),
    ],
  );

  Widget salesmanTab()=>ListView(
    padding:const EdgeInsets.fromLTRB(16,0,16,96),
    children:[
      _addButton(
        label:'Add Salesman Loan / Payment',
        onPressed:()=>addSalesmanLoan(),
      ),
      if(salesmen.isEmpty)
        const QamvioEmptyState(
          icon:Icons.badge_outlined,
          title:'No salesmen found',
          subtitle:'Add salesmen before recording salesman loans or payments.',
        )
      else
        ...salesmen.map((x) {
          final invoiceDue=_n(x['invoice_due']);
          final manual=_n(x['manual_loan_balance']);
          final total=invoiceDue+manual;
          return Padding(
            padding:const EdgeInsets.only(bottom:10),
            child:Card(
              child:InkWell(
                borderRadius:BorderRadius.circular(20),
                onTap:()=>showSalesmanLedger(x),
                child:Padding(
                  padding:const EdgeInsets.all(14),
                  child:Column(
                    children:[
                      Row(
                        children:[
                          Container(
                            width:46,
                            height:46,
                            decoration:BoxDecoration(
                              color:Theme.of(context).colorScheme.primaryContainer,
                              borderRadius:BorderRadius.circular(15),
                            ),
                            child:Icon(
                              Icons.badge_rounded,
                              color:Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width:12),
                          Expanded(
                            child:Column(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children:[
                                Text(
                                  x['name'].toString(),
                                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                                ),
                                const SizedBox(height:3),
                                Text(
                                  x['phone']?.toString()??'',
                                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:const Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            QamvioUi.money(total),
                            style:TextStyle(
                              fontWeight:FontWeight.w900,
                              fontSize:17,
                              color:total>0?Theme.of(context).colorScheme.primary:null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height:12),
                      Wrap(
                        spacing:8,
                        runSpacing:8,
                        children:[
                          QamvioAmountPill(label:'Invoice due',amount:invoiceDue),
                          QamvioAmountPill(label:'Manual loan',amount:manual),
                        ],
                      ),
                      const Divider(height:22),
                      Row(
                        children:[
                          Expanded(
                            child:OutlinedButton.icon(
                              onPressed:()=>addSalesmanLoan(x['id'].toString()),
                              icon:const Icon(Icons.add_card_rounded),
                              label:const Text('Transaction'),
                            ),
                          ),
                          const SizedBox(width:10),
                          Expanded(
                            child:FilledButton.tonalIcon(
                              onPressed:()=>runShare(
                                ()=>WhatsAppShare.shareSalesmanCredit(x),
                              ),
                              icon:const Icon(Icons.chat_rounded),
                              label:const Text('WhatsApp'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
    ],
  );

  Widget supplierTab()=>ListView(
    padding:const EdgeInsets.fromLTRB(16,0,16,96),
    children:[
      _addButton(
        label:'Add Supplier Payment / Receipt',
        onPressed:()=>addSupplierTransaction(),
      ),
      if(suppliers.isEmpty)
        const QamvioEmptyState(
          icon:Icons.local_shipping_outlined,
          title:'No suppliers found',
          subtitle:'Add suppliers before recording payment transactions.',
        )
      else
        ...suppliers.map((x)=>Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:Card(
            child:InkWell(
              borderRadius:BorderRadius.circular(20),
              onTap:()=>showSupplierLedger(x),
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  children:[
                    Row(
                      children:[
                        Container(
                          width:46,
                          height:46,
                          decoration:BoxDecoration(
                            color:Theme.of(context).colorScheme.primaryContainer,
                            borderRadius:BorderRadius.circular(15),
                          ),
                          child:Icon(
                            Icons.local_shipping_rounded,
                            color:Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width:12),
                        Expanded(
                          child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,
                            children:[
                              Text(
                                x['name'].toString(),
                                style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                              ),
                              const SizedBox(height:3),
                              Text(
                                x['phone']?.toString()??'',
                                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color:const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:CrossAxisAlignment.end,
                          children:[
                            Text(
                              QamvioUi.money(x['balance']),
                              style:TextStyle(
                                fontWeight:FontWeight.w900,
                                fontSize:17,
                                color:Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Text(
                              'Payable',
                              style:TextStyle(fontSize:11,color:Color(0xFF667085)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height:22),
                    Row(
                      children:[
                        Expanded(
                          child:OutlinedButton.icon(
                            onPressed:()=>addSupplierTransaction(x['id'].toString()),
                            icon:const Icon(Icons.payments_outlined),
                            label:const Text('Payment'),
                          ),
                        ),
                        const SizedBox(width:10),
                        Expanded(
                          child:FilledButton.tonalIcon(
                            onPressed:()=>runShare(
                              ()=>WhatsAppShare.shareSupplierCredit(x),
                            ),
                            icon:const Icon(Icons.chat_rounded),
                            label:const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )),
    ],
  );

  @override
  Widget build(BuildContext context)=>DefaultTabController(
    length:3,
    child:Scaffold(
      appBar:AppBar(title:const Text('Loans / Credit')),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :Column(
          children:[
            const Padding(
              padding:EdgeInsets.fromLTRB(16,6,16,12),
              child:QamvioPageIntro(
                title:'Loans & Credit',
                subtitle:'Customer loans, salesman outstanding balances and supplier payments.',
                icon:Icons.account_balance_wallet_rounded,
              ),
            ),
            Padding(
              padding:const EdgeInsets.symmetric(horizontal:16),
              child:Container(
                decoration:BoxDecoration(
                  color:Colors.white,
                  borderRadius:BorderRadius.circular(16),
                  border:Border.all(color:const Color(0xFFE7ECF3)),
                ),
                child:const TabBar(
                  dividerColor:Colors.transparent,
                  tabs:[
                    Tab(text:'Customer'),
                    Tab(text:'Salesman'),
                    Tab(text:'Supplier'),
                  ],
                ),
              ),
            ),
            const SizedBox(height:4),
            Expanded(
              child:TabBarView(
                children:[
                  customerTab(),
                  salesmanTab(),
                  supplierTab(),
                ],
              ),
            ),
          ],
        ),
    ),
  );

}
