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

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final customerData=await db.rawQuery(
      'SELECT l.*,c.name customer_name,c.phone customer_phone '
      'FROM customer_loans l JOIN customers c ON c.id=l.customer_id '
      'ORDER BY l.created_at DESC',
    );
    final salesmanData=await db.rawQuery(
      'SELECT sm.*,COALESCE(SUM(s.due),0) credit_due '
      'FROM salesmen sm LEFT JOIN sales s ON s.salesman_id=sm.id '
      'GROUP BY sm.id,sm.name,sm.phone,sm.commission,sm.active,sm.updated_at,sm.sync_state '
      'ORDER BY sm.name COLLATE NOCASE',
    );
    final supplierData=await db.query(
      'suppliers',
      orderBy:'name COLLATE NOCASE',
    );

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

  Future<void> addCustomerLoan() async {
    final db=await AppDatabase.instance.database;
    final customers=await db.query('customers',orderBy:'name');
    if(!mounted || customers.isEmpty) return;

    String customerId=customers.first['id'].toString();
    String type='loan';
    final amount=TextEditingController();
    final note=TextEditingController();

    final ok=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>StatefulBuilder(
        builder:(dialogContext,setLocal)=>AlertDialog(
          title:const Text('Customer Loan / Payment'),
          content:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              DropdownButtonFormField<String>(
                initialValue:customerId,
                items:customers.map(
                  (x)=>DropdownMenuItem(
                    value:x['id'].toString(),
                    child:Text(x['name'].toString()),
                  ),
                ).toList(),
                onChanged:(v)=>setLocal(()=>customerId=v!),
              ),
              const SizedBox(height:8),
              DropdownButtonFormField<String>(
                initialValue:type,
                items:const [
                  DropdownMenuItem(
                    value:'loan',
                    child:Text('Loan / Give credit'),
                  ),
                  DropdownMenuItem(
                    value:'payment',
                    child:Text('Payment received'),
                  ),
                ],
                onChanged:(v)=>setLocal(()=>type=v!),
              ),
              const SizedBox(height:8),
              TextField(
                controller:amount,
                keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Amount'),
              ),
              const SizedBox(height:8),
              TextField(
                controller:note,
                decoration:const InputDecoration(labelText:'Note'),
              ),
            ],
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

    if(ok!=true) return;
    await AppDatabase.instance.saveCustomerLoan(
      id:DateTime.now().microsecondsSinceEpoch.toString(),
      customerId:customerId,
      amount:double.tryParse(amount.text)??0,
      type:type,
      note:note.text,
    );
    await load();
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

  Widget customerTab() {
    if(customerRows.isEmpty) {
      return const Center(child:Text('No customer loan transactions.'));
    }
    return ListView.separated(
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
    );
  }

  Widget salesmanTab() {
    if(salesmen.isEmpty) {
      return const Center(child:Text('No salesmen found.'));
    }
    return ListView.separated(
      itemCount:salesmen.length,
      separatorBuilder:(_,__)=>const Divider(height:1),
      itemBuilder:(_,i) {
        final x=salesmen[i];
        return ListTile(
          leading:const CircleAvatar(child:Icon(Icons.badge)),
          title:Text(x['name'].toString()),
          subtitle:Text(
            'Phone: ${x['phone']??''}\nCredit due: ${WhatsAppShare.money(x['credit_due'])}',
          ),
          isThreeLine:true,
          trailing:IconButton(
            tooltip:'Share salesman credit on WhatsApp',
            icon:const Icon(Icons.chat),
            onPressed:()=>runShare(
              ()=>WhatsAppShare.shareSalesmanCredit(x),
            ),
          ),
        );
      },
    );
  }

  Widget supplierTab() {
    if(suppliers.isEmpty) {
      return const Center(child:Text('No suppliers found.'));
    }
    return ListView.separated(
      itemCount:suppliers.length,
      separatorBuilder:(_,__)=>const Divider(height:1),
      itemBuilder:(_,i) {
        final x=suppliers[i];
        return ListTile(
          leading:const CircleAvatar(child:Icon(Icons.local_shipping)),
          title:Text(x['name'].toString()),
          subtitle:Text(
            'Phone: ${x['phone']??''}\nBalance: ${WhatsAppShare.money(x['balance'])}',
          ),
          isThreeLine:true,
          trailing:IconButton(
            tooltip:'Share supplier credit on WhatsApp',
            icon:const Icon(Icons.chat),
            onPressed:()=>runShare(
              ()=>WhatsAppShare.shareSupplierCredit(x),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)=>DefaultTabController(
    length:3,
    child:Scaffold(
      appBar:AppBar(
        title:const Text('Loans / Credit'),
        actions:[
          IconButton(
            tooltip:'Add customer loan/payment',
            onPressed:addCustomerLoan,
            icon:const Icon(Icons.add),
          ),
        ],
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
