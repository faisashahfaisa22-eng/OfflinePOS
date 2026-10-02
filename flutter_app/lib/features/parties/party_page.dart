import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

enum PartyType { customer, supplier }

class PartyPage extends StatefulWidget {
  final PartyType type;
  const PartyPage({required this.type,super.key});

  @override
  State<PartyPage> createState()=>_PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  final search=TextEditingController();

  bool get customer=>widget.type==PartyType.customer;

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
    load();
  }

  @override
  void dispose() {
    search.removeListener(_refresh);
    search.dispose();
    super.dispose();
  }

  void _refresh()=>setState(() {});

  Future<void> load() async {
    final data=customer
      ?await AppDatabase.instance.customers()
      :await AppDatabase.instance.suppliers();
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((x)=>[
      x['name'],
      x['phone'],
      x['address'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  double get totalBalance=>rows.fold<double>(
    0,
    (a,x)=>a+((x['balance'] as num?)?.toDouble()??0),
  );

  Future<void> shareSupplier(Map<String,Object?> supplier) async {
    try {
      await WhatsAppShare.shareSupplierCredit(supplier);
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('WhatsApp: $e')),
      );
    }
  }

  Future<void> supplierPayment(Map<String,Object?> supplier) async {
    String type='payment';
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
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              Text(
                '${supplier['name']} — Payment',
                style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight:FontWeight.w900,
                ),
              ),
              const SizedBox(height:4),
              Text(
                'Current payable balance: ${QamvioUi.money(supplier['balance'])}',
              ),
              const SizedBox(height:16),
              DropdownButtonFormField<String>(
                initialValue:type,
                decoration:const InputDecoration(
                  labelText:'Transaction type',
                  prefixIcon:Icon(Icons.swap_vert_rounded),
                ),
                items:const [
                  DropdownMenuItem(
                    value:'payment',
                    child:Text('Paid to supplier'),
                  ),
                  DropdownMenuItem(
                    value:'received',
                    child:Text('Received from supplier'),
                  ),
                ],
                onChanged:(v)=>setLocal(()=>type=v!),
              ),
              const SizedBox(height:10),
              TextField(
                controller:amount,
                autofocus:true,
                keyboardType:const TextInputType.numberWithOptions(decimal:true),
                decoration:const InputDecoration(
                  labelText:'Amount',
                  prefixIcon:Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height:10),
              TextField(
                controller:note,
                decoration:const InputDecoration(
                  labelText:'Note',
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
    );

    if(ok==true) {
      final value=double.tryParse(amount.text.trim())??0;
      if(value>0) {
        await AppDatabase.instance.saveSupplierTransaction(
          id:DateTime.now().microsecondsSinceEpoch.toString(),
          supplierId:supplier['id'].toString(),
          amount:value,
          type:type,
          note:note.text.trim(),
        );
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

  Future<void> add() async {
    final name=TextEditingController();
    final phone=TextEditingController();
    final address=TextEditingController();
    final ok=await showModalBottomSheet<bool>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>Padding(
        padding:EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom+20,
        ),
        child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Text(
              LanguageController.instance.strings.t(
                customer?'addCustomer':'addSupplier',
              ),
              style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                fontWeight:FontWeight.w900,
              ),
            ),
            const SizedBox(height:4),
            Text(
              customer
                ?'Create a customer account for invoices, credit and payments.'
                :'Create a supplier account for purchases and payable tracking.',
            ),
            const SizedBox(height:18),
            TextField(
              controller:name,
              autofocus:true,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('name'),
                prefixIcon:Icon(customer?Icons.person_outline:Icons.store_outlined),
              ),
            ),
            const SizedBox(height:10),
            TextField(
              controller:phone,
              keyboardType:TextInputType.phone,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('phone'),
                prefixIcon:const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height:10),
            TextField(
              controller:address,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('address'),
                prefixIcon:const Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height:18),
            FilledButton.icon(
              onPressed:()=>Navigator.pop(sheetContext,true),
              icon:const Icon(Icons.save_outlined),
              label:Text(customer?'Save Customer':'Save Supplier'),
            ),
            const SizedBox(height:8),
            TextButton(
              onPressed:()=>Navigator.pop(sheetContext,false),
              child:const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if(ok==true && name.text.trim().isNotEmpty) {
      final id=DateTime.now().microsecondsSinceEpoch.toString();
      if(customer) {
        await AppDatabase.instance.saveCustomer(
          id:id,
          name:name.text,
          phone:phone.text,
          address:address.text,
        );
      } else {
        await AppDatabase.instance.saveSupplier(
          id:id,
          name:name.text,
          phone:phone.text,
          address:address.text,
        );
      }
      await load();
    }

    name.dispose();
    phone.dispose();
    address.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s=LanguageController.instance.strings;
    final title=s.t(customer?'customers':'suppliers');
    return Scaffold(
      appBar:AppBar(title:Text(title)),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:add,
        icon:const Icon(Icons.person_add_alt_1_rounded),
        label:Text(s.t(customer?'addCustomer':'addSupplier')),
      ),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :RefreshIndicator(
          onRefresh:load,
          child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:QamvioUi.pagePadding,
            children:[
              QamvioPageIntro(
                title:title,
                subtitle:customer
                  ?'Manage receivables, contact details and customer accounts.'
                  :'Manage payables, supplier payments and purchase relationships.',
                icon:customer?Icons.groups_2_rounded:Icons.local_shipping_rounded,
              ),
              const SizedBox(height:18),
              Row(
                children:[
                  Expanded(
                    child:_summary(
                      context,
                      customer?'Customers':'Suppliers',
                      rows.length.toString(),
                      customer?Icons.people_outline:Icons.storefront_outlined,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_summary(
                      context,
                      customer?'Receivable':'Payable',
                      QamvioUi.money(totalBalance),
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              TextField(
                controller:search,
                decoration:InputDecoration(
                  hintText:'Search name, phone or address',
                  prefixIcon:const Icon(Icons.search_rounded),
                  suffixIcon:search.text.isEmpty
                    ?null
                    :IconButton(
                      onPressed:()=>search.clear(),
                      icon:const Icon(Icons.close_rounded),
                    ),
                ),
              ),
              const SizedBox(height:18),
              QamvioSectionTitle(
                customer?'Customer accounts':'Supplier accounts',
                subtitle:'${filtered.length} matching records',
              ),
              if(filtered.isEmpty)
                QamvioEmptyState(
                  icon:customer
                    ?Icons.person_outline_rounded
                    :Icons.local_shipping_outlined,
                  title:rows.isEmpty
                    ?(customer?'No customers yet':'No suppliers yet')
                    :'No matching account',
                  subtitle:rows.isEmpty
                    ?(customer
                      ?'Add your first customer to start invoices and credit tracking.'
                      :'Add your first supplier to start purchase and payable tracking.')
                    :'Try a different search term.',
                  actionLabel:rows.isEmpty
                    ?(customer?'Add Customer':'Add Supplier')
                    :null,
                  onAction:rows.isEmpty?add:null,
                )
              else
                ...filtered.map((x)=>Padding(
                  padding:const EdgeInsets.only(bottom:10),
                  child:_partyCard(context,x),
                )),
            ],
          ),
        ),
    );
  }

  Widget _summary(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  )=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Row(
        children:[
          Container(
            width:42,
            height:42,
            decoration:BoxDecoration(
              color:Theme.of(context).colorScheme.primaryContainer,
              borderRadius:BorderRadius.circular(13),
            ),
            child:Icon(
              icon,
              color:Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width:10),
          Expanded(
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(
                  value,
                  maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900),
                ),
                Text(
                  label,
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _partyCard(BuildContext context,Map<String,Object?> x) {
    final balance=(x['balance'] as num?)?.toDouble()??0;
    final phone=(x['phone']??'').toString();
    final address=(x['address']??'').toString();
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(
          children:[
            Row(
              children:[
                Container(
                  width:48,
                  height:48,
                  decoration:BoxDecoration(
                    color:Theme.of(context).colorScheme.primaryContainer,
                    borderRadius:BorderRadius.circular(16),
                  ),
                  child:Icon(
                    customer?Icons.person_rounded:Icons.storefront_rounded,
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
                      if(phone.isNotEmpty) ...[
                        const SizedBox(height:3),
                        Text(
                          phone,
                          style:Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment:CrossAxisAlignment.end,
                  children:[
                    Text(
                      QamvioUi.money(balance),
                      style:TextStyle(
                        fontWeight:FontWeight.w900,
                        fontSize:17,
                        color:balance>0
                          ?Theme.of(context).colorScheme.primary
                          :const Color(0xFF344054),
                      ),
                    ),
                    Text(
                      customer?'Receivable':'Payable',
                      style:Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if(address.isNotEmpty) ...[
              const SizedBox(height:10),
              Row(
                children:[
                  const Icon(Icons.location_on_outlined,size:16,color:Color(0xFF667085)),
                  const SizedBox(width:5),
                  Expanded(
                    child:Text(
                      address,
                      maxLines:1,
                      overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:const Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if(!customer) ...[
              const Divider(height:22),
              Row(
                children:[
                  Expanded(
                    child:OutlinedButton.icon(
                      onPressed:()=>supplierPayment(x),
                      icon:const Icon(Icons.payments_outlined),
                      label:const Text('Payment'),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:FilledButton.tonalIcon(
                      onPressed:()=>shareSupplier(x),
                      icon:const Icon(Icons.chat_rounded),
                      label:const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
