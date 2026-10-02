import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState()=>_SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
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
      'SELECT s.*,c.name customer_name,sm.name salesman_name '
      'FROM sales s '
      'LEFT JOIN customers c ON c.id=s.customer_id '
      'LEFT JOIN salesmen sm ON sm.id=s.salesman_id '
      'ORDER BY s.created_at DESC',
    );
    if(!mounted) return;
    setState(() {
      rows=x;
      loading=false;
    });
  }

  Future<void> shareInvoice(Map<String,Object?> sale) async {
    try {
      await WhatsAppShare.shareInvoice(sale);
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('WhatsApp: $e')),
      );
    }
  }

  Future<void> newSale() async {
    final saved=await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder:(_)=>const NewSalePage()),
    );
    if(saved==true) await load();
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((x) {
      final hay=[
        x['invoice_no'],
        x['customer_name'],
        x['salesman_name'],
        x['created_at'],
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  double get totalSales=>rows.fold<double>(
    0,
    (a,x)=>a+((x['total'] as num?)?.toDouble()??0),
  );

  double get totalDue=>rows.fold<double>(
    0,
    (a,x)=>a+((x['due'] as num?)?.toDouble()??0),
  );

  @override
  Widget build(BuildContext context) {
    final s=LanguageController.instance.strings;
    return Scaffold(
      appBar:AppBar(
        title:Text(s.t('salesInvoice')),
      ),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:newSale,
        icon:const Icon(Icons.add_shopping_cart_rounded),
        label:Text(s.t('newInvoice')),
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
                title:'Sales & Invoices',
                subtitle:'Create professional invoices, track collections and share receipts.',
                icon:Icons.receipt_long_rounded,
                trailing:IconButton.filledTonal(
                  tooltip:'New invoice',
                  onPressed:newSale,
                  icon:const Icon(Icons.add_rounded),
                ),
              ),
              const SizedBox(height:18),
              Row(
                children:[
                  Expanded(
                    child:_miniStat(
                      context,
                      label:'Invoices',
                      value:'${rows.length}',
                      icon:Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_miniStat(
                      context,
                      label:'Sales',
                      value:QamvioUi.money(totalSales),
                      icon:Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_miniStat(
                      context,
                      label:'Due',
                      value:QamvioUi.money(totalDue),
                      icon:Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              TextField(
                controller:search,
                decoration:InputDecoration(
                  hintText:'Search invoice, customer or salesman',
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
                'Recent invoices',
                subtitle:'${filtered.length} invoice records',
              ),
              if(filtered.isEmpty)
                QamvioEmptyState(
                  icon:Icons.receipt_long_outlined,
                  title:rows.isEmpty?'No invoices yet':'No matching invoice',
                  subtitle:rows.isEmpty
                    ?'Create your first invoice with products, payment and due tracking.'
                    :'Try a different search term.',
                  actionLabel:rows.isEmpty?'Create Invoice':null,
                  onAction:rows.isEmpty?newSale:null,
                )
              else
                ...filtered.map((x)=>Padding(
                  padding:const EdgeInsets.only(bottom:10),
                  child:_invoiceCard(context,x),
                )),
            ],
          ),
        ),
    );
  }

  Widget _miniStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  })=>Card(
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
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
          ),
          const SizedBox(height:2),
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

  Widget _invoiceCard(BuildContext context,Map<String,Object?> x) {
    final customer=(x['customer_name']??'Walk-in customer').toString();
    final salesman=x['salesman_name']?.toString();
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(
              children:[
                Container(
                  width:44,
                  height:44,
                  decoration:BoxDecoration(
                    color:Theme.of(context).colorScheme.primaryContainer,
                    borderRadius:BorderRadius.circular(14),
                  ),
                  child:Icon(
                    Icons.receipt_rounded,
                    color:Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width:12),
                Expanded(
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(
                        x['invoice_no'].toString(),
                        style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                      ),
                      const SizedBox(height:2),
                      Text(
                        customer,
                        maxLines:1,
                        overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontWeight:FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:'Share invoice on WhatsApp',
                  onPressed:()=>shareInvoice(x),
                  icon:const Icon(Icons.chat_rounded),
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
            const SizedBox(height:10),
            Row(
              children:[
                const Icon(Icons.schedule_rounded,size:16,color:Color(0xFF667085)),
                const SizedBox(width:5),
                Expanded(
                  child:Text(
                    x['created_at'].toString(),
                    maxLines:1,
                    overflow:TextOverflow.ellipsis,
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                ),
                if(salesman!=null && salesman.isNotEmpty)
                  Text(
                    'Salesman: $salesman',
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight:FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState()=>_NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  List<Map<String,Object?>> products=const [];
  List<Map<String,Object?>> customers=const [];
  List<Map<String,Object?>> salesmen=const [];
  final cart=<String,Map<String,Object?>>{};
  final search=TextEditingController();
  final discount=TextEditingController(text:'0');
  final paid=TextEditingController(text:'0');
  bool loading=true;
  bool saving=false;
  String customerId='';
  String salesmanId='';
  late final String invoiceNo;

  @override
  void initState() {
    super.initState();
    invoiceNo=_makeInvoiceNo();
    search.addListener(_rebuild);
    discount.addListener(_rebuild);
    paid.addListener(_rebuild);
    _load();
  }

  @override
  void dispose() {
    search.removeListener(_rebuild);
    discount.removeListener(_rebuild);
    paid.removeListener(_rebuild);
    search.dispose();
    discount.dispose();
    paid.dispose();
    super.dispose();
  }

  void _rebuild()=>setState(() {});

  String _makeInvoiceNo() {
    final d=DateTime.now();
    String two(int v)=>v.toString().padLeft(2,'0');
    return 'INV-${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  Future<void> _load() async {
    final db=await AppDatabase.instance.database;
    final p=await db.query('products',orderBy:'name COLLATE NOCASE');
    final c=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final sm=await db.query(
      'salesmen',
      where:'active=1',
      orderBy:'name COLLATE NOCASE',
    );
    if(!mounted) return;
    setState(() {
      products=p;
      customers=c;
      salesmen=sm;
      loading=false;
    });
  }

  List<Map<String,Object?>> get visibleProducts {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return products;
    return products.where((p) {
      return [
        p['name'],
        p['barcode'],
        p['sku'],
        p['category'],
      ].join(' ').toLowerCase().contains(q);
    }).toList();
  }

  double get subtotal=>cart.values.fold<double>(
    0,
    (a,x)=>a+
      (((x['qty'] as num?)?.toDouble()??0)*
      ((x['price'] as num?)?.toDouble()??0)),
  );

  double get discountValue=>double.tryParse(discount.text.trim())??0;
  double get paidValue=>double.tryParse(paid.text.trim())??0;
  double get total=>(subtotal-discountValue).clamp(0,double.infinity).toDouble();
  double get due=>(total-paidValue).clamp(0,double.infinity).toDouble();
  double get change=>(paidValue-total).clamp(0,double.infinity).toDouble();

  void _add(Map<String,Object?> p) {
    final id=p['id'].toString();
    final old=cart[id];
    final qty=((old?['qty'] as num?)?.toDouble()??0)+1;
    cart[id]={
      'product_id':id,
      'product_name':p['name'],
      'qty':qty,
      'price':(p['price'] as num?)?.toDouble()??0,
      'cost':(p['cost'] as num?)?.toDouble()??0,
    };
    setState(() {});
  }

  void _changeQty(String id,double delta) {
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

  Future<void> _editPrice(String id) async {
    final item=cart[id];
    if(item==null) return;
    final controller=TextEditingController(text:QamvioUi.money(item['price']));
    final ok=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:Text('Edit price — ${item['product_name']}'),
        content:TextField(
          controller:controller,
          autofocus:true,
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(
            labelText:'Unit price',
            prefixIcon:Icon(Icons.sell_outlined),
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
        item['price']=value;
        setState(() {});
      }
    }
    controller.dispose();
  }

  Future<void> _save() async {
    if(cart.isEmpty || saving) return;
    if(discountValue<0 || paidValue<0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Discount and paid amount cannot be negative.')),
      );
      return;
    }
    setState(()=>saving=true);
    try {
      final id=DateTime.now().microsecondsSinceEpoch.toString();
      await AppDatabase.instance.createSale(
        id:id,
        invoiceNo:invoiceNo,
        customerId:customerId.isEmpty?null:customerId,
        salesmanId:salesmanId.isEmpty?null:salesmanId,
        items:cart.values.toList(),
        discount:discountValue,
        paid:paidValue,
      );
      if(!mounted) return;
      Navigator.pop(context,true);
    } catch(e) {
      if(!mounted) return;
      setState(()=>saving=false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Could not save invoice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('New Sales Invoice'),
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
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          QamvioPageIntro(
            title:invoiceNo,
            subtitle:'${DateTime.now().toLocal()}',
            icon:Icons.point_of_sale_rounded,
          ),
          const SizedBox(height:18),
          const QamvioSectionTitle(
            'Invoice parties',
            subtitle:'Assign this invoice to a customer or salesman when needed',
          ),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Column(
                children:[
                  DropdownButtonFormField<String>(
                    initialValue:customerId,
                    decoration:const InputDecoration(
                      labelText:'Customer',
                      prefixIcon:Icon(Icons.person_outline_rounded),
                    ),
                    items:[
                      const DropdownMenuItem(
                        value:'',
                        child:Text('Walk-in customer'),
                      ),
                      ...customers.map(
                        (x)=>DropdownMenuItem(
                          value:x['id'].toString(),
                          child:Text(x['name'].toString()),
                        ),
                      ),
                    ],
                    onChanged:(v)=>setState(()=>customerId=v??''),
                  ),
                  const SizedBox(height:10),
                  DropdownButtonFormField<String>(
                    initialValue:salesmanId,
                    decoration:const InputDecoration(
                      labelText:'Salesman',
                      prefixIcon:Icon(Icons.badge_outlined),
                    ),
                    items:[
                      const DropdownMenuItem(
                        value:'',
                        child:Text('No salesman'),
                      ),
                      ...salesmen.map(
                        (x)=>DropdownMenuItem(
                          value:x['id'].toString(),
                          child:Text(x['name'].toString()),
                        ),
                      ),
                    ],
                    onChanged:(v)=>setState(()=>salesmanId=v??''),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height:18),
          QamvioSectionTitle(
            'Add products',
            subtitle:'${visibleProducts.length} products available',
          ),
          TextField(
            controller:search,
            decoration:InputDecoration(
              hintText:'Search product, SKU or barcode',
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
          if(visibleProducts.isEmpty)
            const QamvioEmptyState(
              icon:Icons.inventory_2_outlined,
              title:'No products found',
              subtitle:'Try another search or add products from Inventory.',
            )
          else
            ...visibleProducts.take(20).map((p)=>Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:_productCard(context,p),
            )),
          if(visibleProducts.length>20)
            Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:Text(
                'Showing first 20 results. Refine search to find more.',
                textAlign:TextAlign.center,
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:const Color(0xFF667085),
                ),
              ),
            ),
          const SizedBox(height:14),
          QamvioSectionTitle(
            'Invoice items',
            subtitle:'${cart.length} selected products',
          ),
          if(cart.isEmpty)
            const QamvioEmptyState(
              icon:Icons.shopping_cart_outlined,
              title:'Invoice is empty',
              subtitle:'Tap Add on a product above to build this invoice.',
            )
          else
            ...cart.entries.map((entry)=>Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:_cartCard(context,entry.key,entry.value),
            )),
          const SizedBox(height:14),
          const QamvioSectionTitle(
            'Payment summary',
            subtitle:'Discount, collection and outstanding balance',
          ),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Column(
                children:[
                  _summaryRow('Subtotal',subtotal),
                  const SizedBox(height:10),
                  TextField(
                    controller:discount,
                    keyboardType:const TextInputType.numberWithOptions(decimal:true),
                    decoration:const InputDecoration(
                      labelText:'Discount',
                      prefixIcon:Icon(Icons.discount_outlined),
                    ),
                  ),
                  const SizedBox(height:10),
                  TextField(
                    controller:paid,
                    keyboardType:const TextInputType.numberWithOptions(decimal:true),
                    decoration:const InputDecoration(
                      labelText:'Paid / Received',
                      prefixIcon:Icon(Icons.payments_outlined),
                    ),
                  ),
                  const Divider(height:28),
                  _summaryRow('Grand total',total,strong:true),
                  const SizedBox(height:8),
                  _summaryRow('Due',due,strong:due>0),
                  if(change>0) ...[
                    const SizedBox(height:8),
                    _summaryRow('Change',change),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height:18),
          SizedBox(
            width:double.infinity,
            child:FilledButton.icon(
              onPressed:cart.isEmpty||saving?null:_save,
              icon:saving
                ?const SizedBox(
                  width:18,
                  height:18,
                  child:CircularProgressIndicator(strokeWidth:2),
                )
                :const Icon(Icons.check_circle_outline_rounded),
              label:Text(saving?'Saving invoice…':'Save Invoice'),
            ),
          ),
        ],
      ),
  );

  Widget _productCard(BuildContext context,Map<String,Object?> p) {
    final id=p['id'].toString();
    final inCart=cart[id];
    final stock=(p['stock'] as num?)?.toDouble()??0;
    return Card(
      child:InkWell(
        borderRadius:BorderRadius.circular(20),
        onTap:()=>_add(p),
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
                      'Stock ${QamvioUi.money(stock)} • Price ${QamvioUi.money(p['price'])}',
                      style:Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:stock<=0?QamvioUi.danger:const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              if(inCart!=null)
                Padding(
                  padding:const EdgeInsets.only(right:6),
                  child:CircleAvatar(
                    radius:14,
                    child:Text(
                      '${((inCart['qty'] as num?)?.toDouble()??0).toStringAsFixed(0)}',
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
      ),
    );
  }

  Widget _cartCard(
    BuildContext context,
    String id,
    Map<String,Object?> item,
  ) {
    final qty=(item['qty'] as num?)?.toDouble()??0;
    final price=(item['price'] as num?)?.toDouble()??0;
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
                  tooltip:'Remove item',
                  onPressed:()=>setState(()=>cart.remove(id)),
                  icon:const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height:6),
            Row(
              children:[
                IconButton.filledTonal(
                  onPressed:()=>_changeQty(id,-1),
                  icon:const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding:const EdgeInsets.symmetric(horizontal:12),
                  child:Column(
                    children:[
                      Text(
                        QamvioUi.money(qty),
                        style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900),
                      ),
                      const Text('Qty',style:TextStyle(fontSize:11)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed:()=>_changeQty(id,1),
                  icon:const Icon(Icons.add_rounded),
                ),
                const Spacer(),
                InkWell(
                  borderRadius:BorderRadius.circular(12),
                  onTap:()=>_editPrice(id),
                  child:Padding(
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.end,
                      children:[
                        Text(
                          'Price ${QamvioUi.money(price)}',
                          style:const TextStyle(fontWeight:FontWeight.w700),
                        ),
                        Text(
                          'Total ${QamvioUi.money(qty*price)}',
                          style:TextStyle(
                            color:Theme.of(context).colorScheme.primary,
                            fontWeight:FontWeight.w900,
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

  Widget _summaryRow(String label,double value,{bool strong=false})=>Row(
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
