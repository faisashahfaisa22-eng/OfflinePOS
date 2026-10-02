import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

class SalesmenPage extends StatefulWidget {
  const SalesmenPage({super.key});

  @override
  State<SalesmenPage> createState()=>_SalesmenPageState();
}

class _SalesmenPageState extends State<SalesmenPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  final search=TextEditingController();

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
    final db=await AppDatabase.instance.database;
    final user=LocalAuthService.instance.current;
    var x=await db.rawQuery(
      "SELECT sm.*,"
      "COALESCE((SELECT SUM(s.due) FROM sales s WHERE s.salesman_id=sm.id),0) invoice_due,"
      "COALESCE((SELECT SUM(CASE WHEN l.type='payment' THEN -l.amount ELSE l.amount END) "
      "FROM salesman_loans l WHERE l.salesman_id=sm.id "
      "AND COALESCE(l.source,'manual') NOT IN ('sale_due','sale_recovery')),0) manual_loan_balance "
      "FROM salesmen sm ORDER BY sm.name COLLATE NOCASE",
    );
    if(user?.role==UserRole.salesman) {
      final linked=user?.salesmanId??'';
      x=linked.isEmpty
        ?<Map<String,Object?>>[]
        :x.where((row)=>row['id']?.toString()==linked).toList();
    }
    if(!mounted) return;
    setState(() {
      rows=x;
      loading=false;
    });
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((x)=>[
      x['name'],
      x['phone'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  int get activeCount=>rows.where((x)=>(x['active'] as num?)?.toInt()!=0).length;

  Future<void> edit([Map<String,Object?>? existing]) async {
    if(!LocalAuthService.instance.isAdmin) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Admin access is required to edit salesmen.')),
        );
      }
      return;
    }
    final name=TextEditingController(text:existing?['name']?.toString()??'');
    final phone=TextEditingController(text:existing?['phone']?.toString()??'');
    final commission=TextEditingController(
      text:QamvioUi.money(existing?['commission']??0),
    );
    bool active=((existing?['active'] as num?)?.toInt()??1)!=0;

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
                  existing==null?'Add Salesman':'Edit Salesman',
                  style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                    fontWeight:FontWeight.w900,
                  ),
                ),
                const SizedBox(height:4),
                const Text('Manage salesman assignment, phone and commission rate.'),
                const SizedBox(height:18),
                TextField(
                  controller:name,
                  autofocus:true,
                  decoration:const InputDecoration(
                    labelText:'Salesman name',
                    prefixIcon:Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:phone,
                  keyboardType:TextInputType.phone,
                  decoration:const InputDecoration(
                    labelText:'Phone',
                    prefixIcon:Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:commission,
                  keyboardType:const TextInputType.numberWithOptions(decimal:true),
                  decoration:const InputDecoration(
                    labelText:'Commission rate / amount',
                    prefixIcon:Icon(Icons.percent_rounded),
                  ),
                ),
                const SizedBox(height:8),
                SwitchListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text(
                    'Active salesman',
                    style:TextStyle(fontWeight:FontWeight.w700),
                  ),
                  subtitle:const Text('Inactive salesmen stay in history but are hidden from new invoice selection.'),
                  value:active,
                  onChanged:(v)=>setLocal(()=>active=v),
                ),
                const SizedBox(height:14),
                FilledButton.icon(
                  onPressed:()=>Navigator.pop(sheetContext,true),
                  icon:const Icon(Icons.save_outlined),
                  label:Text(existing==null?'Save Salesman':'Update Salesman'),
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

    if(ok==true && name.text.trim().isNotEmpty) {
      await AppDatabase.instance.saveSalesman(
        id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
        name:name.text,
        phone:phone.text,
        commission:double.tryParse(commission.text.trim())??0,
        active:active,
      );
      await load();
    }

    name.dispose();
    phone.dispose();
    commission.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth=LocalAuthService.instance;
    final canEdit=auth.isAdmin;
    final ownOnly=auth.current?.role==UserRole.salesman;
    return Scaffold(
    appBar:AppBar(title:Text(ownOnly?'My Salesman Account':'Salesmen')),
    floatingActionButton:canEdit
      ?FloatingActionButton.extended(
        onPressed:()=>edit(),
        icon:const Icon(Icons.person_add_alt_1_rounded),
        label:const Text('Add Salesman'),
      )
      :null,
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :RefreshIndicator(
        onRefresh:load,
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:QamvioUi.pagePadding,
          children:[
            QamvioPageIntro(
              title:ownOnly?'My Salesman Account':'Salesmen',
              subtitle:ownOnly
                ?'Your assigned invoices and outstanding salesman balance.'
                :'Assign invoices, track outstanding credit and keep salesman contact details.',
              icon:Icons.badge_rounded,
            ),
            const SizedBox(height:18),
            Row(
              children:[
                Expanded(
                  child:_summary(
                    context,
                    'Salesmen',
                    rows.length.toString(),
                    Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Active',
                    activeCount.toString(),
                    Icons.verified_user_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height:18),
            TextField(
              controller:search,
              decoration:InputDecoration(
                hintText:'Search salesman or phone',
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
              'Salesman accounts',
              subtitle:'${filtered.length} matching records',
            ),
            if(filtered.isEmpty)
              QamvioEmptyState(
                icon:Icons.badge_outlined,
                title:rows.isEmpty?'No salesmen yet':'No salesman found',
                subtitle:rows.isEmpty
                  ?'Add salesmen so invoices and credit can be assigned correctly.'
                  :'Try another search term.',
                actionLabel:rows.isEmpty&&canEdit?'Add Salesman':null,
                onAction:rows.isEmpty&&canEdit?()=>edit():null,
              )
            else
              ...filtered.map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_card(context,x),
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
                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
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

  Widget _card(BuildContext context,Map<String,Object?> x) {
    final active=((x['active'] as num?)?.toInt()??1)!=0;
    final canEdit=LocalAuthService.instance.isAdmin;
    final invoiceDue=(x['invoice_due'] as num?)?.toDouble()??0;
    final manualLoan=(x['manual_loan_balance'] as num?)?.toDouble()??0;
    final totalOutstanding=invoiceDue+manualLoan;
    return Card(
      child:InkWell(
        borderRadius:BorderRadius.circular(20),
        onTap:canEdit?()=>edit(x):null,
        child:Padding(
          padding:const EdgeInsets.all(14),
          child:Row(
            children:[
              Container(
                width:48,
                height:48,
                decoration:BoxDecoration(
                  color:active
                    ?Theme.of(context).colorScheme.primaryContainer
                    :const Color(0xFFF1F4F8),
                  borderRadius:BorderRadius.circular(16),
                ),
                child:Icon(
                  Icons.badge_rounded,
                  color:active
                    ?Theme.of(context).colorScheme.onPrimaryContainer
                    :const Color(0xFF98A2B3),
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
                    const SizedBox(height:7),
                    Wrap(
                      spacing:8,
                      runSpacing:8,
                      children:[
                        QamvioAmountPill(
                          label:'Invoice due',
                          amount:invoiceDue,
                          strong:invoiceDue>0,
                        ),
                        QamvioAmountPill(
                          label:'Manual loan',
                          amount:manualLoan,
                        ),
                        QamvioAmountPill(
                          label:'Outstanding',
                          amount:totalOutstanding,
                          strong:totalOutstanding>0,
                        ),
                        if(canEdit)
                          QamvioAmountPill(
                            label:'Commission',
                            amount:x['commission'],
                          ),
                        Container(
                          padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
                          decoration:BoxDecoration(
                            color:active
                              ?const Color(0xFFEAF7F1)
                              :const Color(0xFFF1F4F8),
                            borderRadius:BorderRadius.circular(999),
                          ),
                          child:Text(
                            active?'ACTIVE':'INACTIVE',
                            style:TextStyle(
                              fontSize:10,
                              fontWeight:FontWeight.w900,
                              color:active?QamvioUi.success:const Color(0xFF667085),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if(canEdit)
                const Icon(Icons.edit_outlined,color:Color(0xFF667085)),
            ],
          ),
        ),
      ),
    );
  }
}