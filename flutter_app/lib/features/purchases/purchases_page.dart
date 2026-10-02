import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/ui/qamvio_ui.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState()=>_PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
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
      'SELECT p.*,s.name supplier_name,s.phone supplier_phone '
      'FROM purchases p '
      'LEFT JOIN suppliers s ON s.id=p.supplier_id '
      'ORDER BY p.created_at DESC',
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
      x['supplier_name'],
      x['created_at'],
      x['id'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  double get totalPurchases=>rows.fold<double>(
    0,
    (a,x)=>a+((x['total'] as num?)?.toDouble()??0),
  );

  double get totalDue=>rows.fold<double>(
    0,
    (a,x)=>a+((x['due'] as num?)?.toDouble()??0),
  );

  Future<void> add() async {
    final saved=await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder:(_)=>const NewPurchasePage()),
    );
    if(saved==true) await load();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Purchases')),
    floatingActionButton:FloatingActionButton.extended(
      onPressed:add,
      icon:const Icon(Icons.add_shopping_cart_rounded),
      label:const Text('New Purchase'),
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
              title:'Purchases',
              subtitle:'Receive stock, track supplier payments and manage purchase credit.',
              icon:Icons.shopping_cart_checkout_rounded,
            ),
            const SizedBox(height:18),
            Row(
              children:[
                Expanded(
                  child:_summary(
                    context,
                    'Purchases',
                    rows.length.toString(),
                    Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Total',
                    QamvioUi.money(totalPurchases),
                    Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Due',
                    QamvioUi.money(totalDue),
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height:18),
            TextField(
              controller:search,
              decoration:InputDecoration(
                hintText:'Search supplier or date',
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
              'Purchase history',
              subtitle:'${filtered.length} matching records',
            ),
            if(filtered.isEmpty)
              QamvioEmptyState(
                icon:Icons.shopping_cart_outlined,
                title:rows.isEmpty?'No purchases yet':'No matching purchase',
                subtitle:rows.isEmpty
                  ?'Create your first purchase to receive stock from a supplier.'
                  :'Try a different search term.',
                actionLabel:rows.isEmpty?'New Purchase':null,
                onAction:rows.isEmpty?add:null,
              )
            else
              ...filtered.map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_purchaseCard(context,x),
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
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:8),
          Text(
            value,
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
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
  );

  Widget _purchaseCard(BuildContext context,Map<String,Object?> x)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
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
                  Icons.local_shipping_outlined,
                  color:Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width:12),
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(
                      (x['supplier_name']??'Supplier').toString(),
                      style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                    ),
                    const SizedBox(height:3),
                    Text(
                      x['created_at'].toString(),
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
          const SizedBox(height:12),
          Wrap(
            spacing:8,
            runSpacing:8,
            children:[
              QamvioAmountPill(label:'Total',amount:x['total'],strong:true),
              QamvioAmountPill(label:'Paid',amount:x['paid']),
              QamvioAmountPill(label:'Due',amount:x['due']),
            ],
          ),
        ],
      ),
    ),
  );
}

class NewPurchasePage extends StatefulWidget {
  const NewPurchasePage({super.key});

  @override
  State<NewPurchasePage> createState()=>_NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  List<Map<String,Object?>> suppliers=const [];
  List<Map<String,Object?>> products=const [];
  final cart=<String,Map<String,Object?>>{};
  final search=TextEditingController();
  final paid=TextEditingController(text:'0');
  String supplierId='';
  bool loading=true;
  bool saving=false;

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
    paid.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    search.removeListener(_refresh);
    paid.removeListener(_refresh);
    search.dispose();
    paid.dispose();
    super.dispose();
  }

  void _refresh()=>setState(() {});

  Future<void> _load() async {
    final db=await AppDatabase.instance.database;
    final ss=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    final ps=await db.query('products',orderBy:'name COLLATE NOCASE');
    if(!mounted) return;
    setState(() {
      suppliers=ss;
      products=ps;
      supplierId=ss.isEmpty?'':ss.first['id'].toString();
      loading=false;
    });
  }

  List<Map<String,Object?>> get visibleProducts {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return products;
    return products.where((p)=>[
      p['name'],
      p['barcode'],
      p['category'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  double get total=>cart.values.fold<double>(
    0,
    (a,x)=>a+
      (((x['qty'] as num?)?.toDouble()??0)*
      ((x['cost'] as num?)?.toDouble()??0)),
  );

  double get paidValue=>double.tryParse(paid.text.trim())??0;
  double get due=>(total-paidValue).clamp(0,double.infinity).toDouble();

  void _add(Map<String,Object?> p) {
    final id=p['id'].toString();
    final old=cart[id];
    final qty=((old?['qty'] as num?)?.toDouble()??0)+1;
    cart[id]={
      'product_id':id,
      'product_name':p['name'],
      'qty':qty,
      'cost':(p['cost'] as num?)?.toDouble()??0,
    };
    setState(() {});
  }

  void _qty(String id,double delta) {
    final item=cart[id];
    if(item==null) return;
    final qty=((item['qty'] as num?)?.toDouble()??0)+delta;
    if(qty<=0) {
      cart.remove(id);
    } else {
      item['qty']=qty;
    }
    setState(() {});
  }

  Future<void> _editCost(String id) async {
    final item=cart[id];
    if(item==null) return;
    final controller=TextEditingController(text:QamvioUi.money(item['cost']));
    final ok=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:Text('Edit cost — ${item['product_name']}'),
        content:TextField(
          controller:controller,
          autofocus:true,
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(
            labelText:'Unit cost',
            prefixIcon:Icon(Icons.price_change_outlined),
          ),
        ),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(dialogContext,false),
            child:const Text('Cancel'),
          ),
          FilledButton(
            onPressed:()=>Navigator.pop(dialogContext,true),
            child:const Text('Apply'),
          ),
        ],
      ),
    );
    if(ok==true) {
      final value=double.tryParse(controller.text.trim());
      if(value!=null && value>=0) {
        item['cost']=value;
        setState(() {});
      }
    }
    controller.dispose();
  }

  Future<void> _save() async {
    if(supplierId.isEmpty || cart.isEmpty || saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Select a supplier and add at least one product.')),
      );
      return;
    }
    if(paidValue<0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Paid amount cannot be negative.')),
      );
      return;
    }
    setState(()=>saving=true);
    try {
      await AppDatabase.instance.createPurchase(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        supplierId:supplierId,
        items:cart.values.toList(),
        paid:paidValue,
      );
      if(!mounted) return;
      Navigator.pop(context,true);
    } catch(e) {
      if(!mounted) return;
      setState(()=>saving=false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Could not save purchase: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('New Purchase'),
      actions:[
        if(cart.isNotEmpty)
          TextButton(
            onPressed:saving?null:_save,
            child:const Text('SAVE'),
          ),
      ],
    ),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :suppliers.isEmpty||products.isEmpty
        ?QamvioEmptyState(
          icon:Icons.shopping_cart_outlined,
          title:'Setup required',
          subtitle:'Add at least one supplier and one product before creating a purchase.',
        )
        :ListView(
          padding:QamvioUi.pagePadding,
          children:[
            const QamvioPageIntro(
              title:'Receive Stock',
              subtitle:'Choose a supplier, add products, set costs and record the amount paid.',
              icon:Icons.inventory_rounded,
            ),
            const SizedBox(height:18),
            const QamvioSectionTitle(
              'Supplier',
              subtitle:'This purchase and any outstanding due will be linked to this account',
            ),
            DropdownButtonFormField<String>(
              initialValue:supplierId,
              decoration:const InputDecoration(
                labelText:'Supplier',
                prefixIcon:Icon(Icons.local_shipping_outlined),
              ),
              items:suppliers.map(
                (x)=>DropdownMenuItem(
                  value:x['id'].toString(),
                  child:Text(x['name'].toString()),
                ),
              ).toList(),
              onChanged:(v)=>setState(()=>supplierId=v??''),
            ),
            const SizedBox(height:18),
            QamvioSectionTitle(
              'Add products',
              subtitle:'${visibleProducts.length} products available',
            ),
            TextField(
              controller:search,
              decoration:InputDecoration(
                hintText:'Search product or barcode',
                prefixIcon:const Icon(Icons.search_rounded),
                suffixIcon:search.text.isEmpty
                  ?null
                  :IconButton(
                    onPressed:()=>search.clear(),
                    icon:const Icon(Icons.close_rounded),
                  ),
              ),
            ),
            const SizedBox(height:10),
            ...visibleProducts.take(20).map((p)=>Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:_product(context,p),
            )),
            const SizedBox(height:14),
            QamvioSectionTitle(
              'Purchase items',
              subtitle:'${cart.length} selected products',
            ),
            if(cart.isEmpty)
              const QamvioEmptyState(
                icon:Icons.add_shopping_cart_rounded,
                title:'No purchase items',
                subtitle:'Tap Add on products above to receive stock.',
              )
            else
              ...cart.entries.map((entry)=>Padding(
                padding:const EdgeInsets.only(bottom:8),
                child:_item(context,entry.key,entry.value),
              )),
            const SizedBox(height:14),
            const QamvioSectionTitle(
              'Payment',
              subtitle:'Record cash paid now; the remaining amount becomes supplier payable',
            ),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  children:[
                    _line('Purchase total',total,strong:true),
                    const SizedBox(height:12),
                    TextField(
                      controller:paid,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(
                        labelText:'Paid now',
                        prefixIcon:Icon(Icons.payments_outlined),
                      ),
                    ),
                    const Divider(height:28),
                    _line('Supplier due',due,strong:due>0),
                  ],
                ),
              ),
            ),
            const SizedBox(height:18),
            FilledButton.icon(
              onPressed:cart.isEmpty||saving?null:_save,
              icon:saving
                ?const SizedBox(
                  width:18,
                  height:18,
                  child:CircularProgressIndicator(strokeWidth:2),
                )
                :const Icon(Icons.check_circle_outline_rounded),
              label:Text(saving?'Saving purchase…':'Save Purchase'),
            ),
          ],
        ),
  );

  Widget _product(BuildContext context,Map<String,Object?> p) {
    final id=p['id'].toString();
    final selected=cart[id];
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(13),
        child:Row(
          children:[
            Container(
              width:44,
              height:44,
              decoration:BoxDecoration(
                color:Theme.of(context).colorScheme.primaryContainer,
                borderRadius:BorderRadius.circular(14),
              ),
              child:Icon(
                Icons.inventory_2_outlined,
                color:Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width:12),
            Expanded(
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(
                    p['name'].toString(),
                    style:const TextStyle(fontWeight:FontWeight.w800),
                  ),
                  const SizedBox(height:3),
                  Text(
                    'Stock ${QamvioUi.money(p['stock'])} • Current cost ${QamvioUi.money(p['cost'])}',
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            if(selected!=null)
              Padding(
                padding:const EdgeInsets.only(right:6),
                child:CircleAvatar(
                  radius:14,
                  child:Text(
                    '${((selected['qty'] as num?)?.toDouble()??0).toStringAsFixed(0)}',
                    style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800),
                  ),
                ),
              ),
            IconButton.filledTonal(
              onPressed:()=>_add(p),
              icon:const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String id,
    Map<String,Object?> item,
  ) {
    final qty=(item['qty'] as num?)?.toDouble()??0;
    final cost=(item['cost'] as num?)?.toDouble()??0;
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(13),
        child:Column(
          children:[
            Row(
              children:[
                Expanded(
                  child:Text(
                    item['product_name'].toString(),
                    style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                  ),
                ),
                IconButton(
                  onPressed:()=>setState(()=>cart.remove(id)),
                  icon:const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Row(
              children:[
                IconButton.filledTonal(
                  onPressed:()=>_qty(id,-1),
                  icon:const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding:const EdgeInsets.symmetric(horizontal:12),
                  child:Text(
                    QamvioUi.money(qty),
                    style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed:()=>_qty(id,1),
                  icon:const Icon(Icons.add_rounded),
                ),
                const Spacer(),
                InkWell(
                  borderRadius:BorderRadius.circular(12),
                  onTap:()=>_editCost(id),
                  child:Padding(
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.end,
                      children:[
                        Text(
                          'Cost ${QamvioUi.money(cost)}',
                          style:const TextStyle(fontWeight:FontWeight.w700),
                        ),
                        Text(
                          'Total ${QamvioUi.money(qty*cost)}',
                          style:TextStyle(
                            fontWeight:FontWeight.w900,
                            color:Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label,double value,{bool strong=false})=>Row(
    children:[
      Expanded(
        child:Text(
          label,
          style:TextStyle(
            fontWeight:strong?FontWeight.w900:FontWeight.w600,
            fontSize:strong?17:15,
          ),
        ),
      ),
      Text(
        QamvioUi.money(value),
        style:TextStyle(
          fontWeight:FontWeight.w900,
          fontSize:strong?20:16,
          color:strong?Theme.of(context).colorScheme.primary:null,
        ),
      ),
    ],
  );
}
