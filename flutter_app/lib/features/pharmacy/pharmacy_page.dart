import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/ui/qamvio_ui.dart';

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({super.key});

  @override
  State<PharmacyPage> createState()=>_PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
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
    final x=await db.rawQuery(
      "SELECT * FROM products WHERE category='Pharmacy' OR expiry_date IS NOT NULL ORDER BY name",
    );
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
      x['batch_no'],
      x['expiry_date'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  int get expiringSoon {
    final now=DateTime.now();
    final limit=now.add(const Duration(days:60));
    var count=0;
    for(final x in rows) {
      final d=DateTime.tryParse(x['expiry_date']?.toString()??'');
      if(d!=null && !d.isBefore(now) && d.isBefore(limit)) count++;
    }
    return count;
  }

  Future<void> add() async {
    final name=TextEditingController();
    final batch=TextEditingController();
    final expiry=TextEditingController();
    final price=TextEditingController(text:'0');
    final stock=TextEditingController(text:'0');

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
        child:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              Text(
                'Add Medicine',
                style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight:FontWeight.w900,
                ),
              ),
              const SizedBox(height:4),
              const Text('Record medicine stock, batch and expiry information.'),
              const SizedBox(height:18),
              TextField(
                controller:name,
                autofocus:true,
                decoration:const InputDecoration(
                  labelText:'Medicine name',
                  prefixIcon:Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height:10),
              TextField(
                controller:batch,
                decoration:const InputDecoration(
                  labelText:'Batch number',
                  prefixIcon:Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height:10),
              TextField(
                controller:expiry,
                decoration:const InputDecoration(
                  labelText:'Expiry date',
                  hintText:'YYYY-MM-DD',
                  prefixIcon:Icon(Icons.event_outlined),
                ),
              ),
              const SizedBox(height:10),
              Row(
                children:[
                  Expanded(
                    child:TextField(
                      controller:price,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(labelText:'Sale price'),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:TextField(
                      controller:stock,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(labelText:'Stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:()=>Navigator.pop(sheetContext,true),
                icon:const Icon(Icons.save_outlined),
                label:const Text('Save Medicine'),
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

    if(ok==true && name.text.trim().isNotEmpty) {
      await AppDatabase.instance.saveMedicine(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        name:name.text,
        batchNo:batch.text,
        expiryDate:expiry.text,
        price:double.tryParse(price.text)??0,
        stock:double.tryParse(stock.text)??0,
      );
      await load();
    }

    name.dispose();
    batch.dispose();
    expiry.dispose();
    price.dispose();
    stock.dispose();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Pharmacy')),
    floatingActionButton:FloatingActionButton.extended(
      onPressed:add,
      icon:const Icon(Icons.add_rounded),
      label:const Text('Add Medicine'),
    ),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :RefreshIndicator(
        onRefresh:load,
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:QamvioUi.pagePadding,
          children:[
            const QamvioPageIntro(
              title:'Pharmacy',
              subtitle:'Medicine stock with batch and expiry visibility.',
              icon:Icons.local_pharmacy_rounded,
            ),
            const SizedBox(height:18),
            Row(
              children:[
                Expanded(
                  child:_summary(
                    context,
                    'Medicines',
                    rows.length.toString(),
                    Icons.medication_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Expiring ≤60d',
                    expiringSoon.toString(),
                    Icons.event_busy_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height:18),
            TextField(
              controller:search,
              decoration:InputDecoration(
                hintText:'Search medicine, batch or expiry',
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
              'Medicine inventory',
              subtitle:'${filtered.length} matching medicines',
            ),
            if(filtered.isEmpty)
              QamvioEmptyState(
                icon:Icons.medication_outlined,
                title:rows.isEmpty?'No medicines yet':'No medicine found',
                subtitle:rows.isEmpty
                  ?'Add medicine stock with batch and expiry information.'
                  :'Try a different search term.',
                actionLabel:rows.isEmpty?'Add Medicine':null,
                onAction:rows.isEmpty?add:null,
              )
            else
              ...filtered.map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_medicineCard(context,x),
              )),
          ],
        ),
      ),
  );

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
                  maxLines:1,
                  overflow:TextOverflow.ellipsis,
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

  Widget _medicineCard(BuildContext context,Map<String,Object?> x) {
    final expiry=DateTime.tryParse(x['expiry_date']?.toString()??'');
    final now=DateTime.now();
    final expired=expiry!=null && expiry.isBefore(now);
    final soon=expiry!=null &&
      !expired &&
      expiry.isBefore(now.add(const Duration(days:60)));
    final status=expired?'EXPIRED':soon?'EXPIRING SOON':'OK';
    final statusColor=expired
      ?QamvioUi.danger
      :soon
        ?QamvioUi.warning
        :QamvioUi.success;
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Row(
          children:[
            Container(
              width:50,
              height:50,
              decoration:BoxDecoration(
                color:statusColor.withValues(alpha:.10),
                borderRadius:BorderRadius.circular(16),
              ),
              child:Icon(Icons.medication_rounded,color:statusColor),
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
                    'Batch ${x['batch_no']??'-'} • Expiry ${x['expiry_date']??'-'}',
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height:8),
                  Wrap(
                    spacing:8,
                    children:[
                      QamvioAmountPill(label:'Price',amount:x['price'],strong:true),
                      Container(
                        padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
                        decoration:BoxDecoration(
                          color:statusColor.withValues(alpha:.10),
                          borderRadius:BorderRadius.circular(999),
                        ),
                        child:Text(
                          status,
                          style:TextStyle(
                            fontSize:10,
                            fontWeight:FontWeight.w900,
                            color:statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width:10),
            Column(
              children:[
                Text(
                  QamvioUi.money(x['stock']),
                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18),
                ),
                const Text('Stock',style:TextStyle(fontSize:11,color:Color(0xFF667085))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
