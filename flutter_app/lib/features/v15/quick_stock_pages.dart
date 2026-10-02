import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/ui/qamvio_ui.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _money(dynamic v)=>QamvioUi.money(v);

class QuickSearchPage extends StatefulWidget {
  const QuickSearchPage({super.key});

  @override
  State<QuickSearchPage> createState()=>_QuickSearchPageState();
}

class _QuickSearchPageState extends State<QuickSearchPage> {
  final query=TextEditingController();
  List<Map<String,Object?>> results=const [];
  bool busy=false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final q=query.text.trim();
    if(q.isEmpty) {
      setState(()=>results=const []);
      return;
    }
    setState(()=>busy=true);
    final db=await AppDatabase.instance.database;
    final like='%$q%';
    final out=<Map<String,Object?>>[];

    final products=await db.rawQuery(
      'SELECT id,name,barcode,sku,stock,price FROM products '
      'WHERE name LIKE ? OR barcode LIKE ? OR sku LIKE ? LIMIT 30',
      [like,like,like],
    );
    for(final x in products) {
      out.add({
        'type':'Product',
        'title':x['name'],
        'meta':'Stock ${_money(x['stock'])} • Price ${_money(x['price'])}',
      });
    }

    final customers=await db.rawQuery(
      'SELECT id,name,phone,balance FROM customers '
      'WHERE name LIKE ? OR phone LIKE ? LIMIT 20',
      [like,like],
    );
    for(final x in customers) {
      out.add({
        'type':'Customer',
        'title':x['name'],
        'meta':'${x['phone']??''} • Balance ${_money(x['balance'])}',
      });
    }

    final suppliers=await db.rawQuery(
      'SELECT id,name,phone,balance FROM suppliers '
      'WHERE name LIKE ? OR phone LIKE ? LIMIT 20',
      [like,like],
    );
    for(final x in suppliers) {
      out.add({
        'type':'Supplier',
        'title':x['name'],
        'meta':'${x['phone']??''} • Balance ${_money(x['balance'])}',
      });
    }

    final salesmen=await db.rawQuery(
      'SELECT id,name,phone FROM salesmen '
      'WHERE name LIKE ? OR phone LIKE ? LIMIT 20',
      [like,like],
    );
    for(final x in salesmen) {
      out.add({
        'type':'Salesman',
        'title':x['name'],
        'meta':'${x['phone']??''}',
      });
    }

    final sales=await db.rawQuery(
      'SELECT s.invoice_no,s.business_date,s.total,s.due,c.name customer_name '
      'FROM sales s LEFT JOIN customers c ON c.id=s.customer_id '
      'WHERE s.invoice_no LIKE ? OR c.name LIKE ? '
      'ORDER BY s.created_at DESC LIMIT 30',
      [like,like],
    );
    for(final x in sales) {
      out.add({
        'type':'Invoice',
        'title':x['invoice_no'],
        'meta':'${x['business_date']??''} • ${x['customer_name']??'Walk-in'} • '
          'Total ${_money(x['total'])} • Due ${_money(x['due'])}',
      });
    }

    if(!mounted) return;
    setState(() {
      results=out;
      busy=false;
    });
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Quick Search')),
    body:ListView(
      padding:QamvioUi.pagePadding,
      children:[
        const QamvioPageIntro(
          title:'Quick Search',
          subtitle:'Search products, invoices, customers, suppliers and salesmen.',
          icon:Icons.manage_search_rounded,
        ),
        const SizedBox(height:16),
        TextField(
          controller:query,
          autofocus:true,
          textInputAction:TextInputAction.search,
          onSubmitted:(_)=>search(),
          decoration:InputDecoration(
            labelText:'Search',
            hintText:'Name, phone, barcode, SKU or invoice',
            prefixIcon:const Icon(Icons.search_rounded),
            suffixIcon:busy
              ?const Padding(
                padding:EdgeInsets.all(14),
                child:SizedBox(
                  width:18,
                  height:18,
                  child:CircularProgressIndicator(strokeWidth:2),
                ),
              )
              :IconButton(
                onPressed:search,
                icon:const Icon(Icons.arrow_forward_rounded),
              ),
          ),
        ),
        const SizedBox(height:16),
        if(results.isEmpty&&!busy)
          const QamvioEmptyState(
            icon:Icons.search_rounded,
            title:'Search business records',
            subtitle:'Matching records from the main v15 business sections appear here.',
          )
        else
          ...results.map((x)=>Card(
            margin:const EdgeInsets.only(bottom:8),
            child:ListTile(
              leading:CircleAvatar(
                child:Text(
                  x['type'].toString().characters.first,
                  style:const TextStyle(fontWeight:FontWeight.w900),
                ),
              ),
              title:Text(
                x['title']?.toString()??'',
                style:const TextStyle(fontWeight:FontWeight.w800),
              ),
              subtitle:Text(x['meta']?.toString()??''),
              trailing:Container(
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
                decoration:BoxDecoration(
                  color:Theme.of(context).colorScheme.primaryContainer,
                  borderRadius:BorderRadius.circular(999),
                ),
                child:Text(
                  x['type'].toString(),
                  style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800),
                ),
              ),
            ),
          )),
      ],
    ),
  );
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState()=>_StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<List<Map<String,Object?>>> future;

  @override
  void initState() {
    super.initState();
    future=_load();
  }

  Future<List<Map<String,Object?>>> _load() async {
    final db=await AppDatabase.instance.database;
    return db.rawQuery(
      'SELECT p.*,'
      'COALESCE((SELECT SUM(pi.qty) FROM purchase_items pi WHERE pi.product_id=p.id),0) purchased,'
      'COALESCE((SELECT SUM(si.qty) FROM sale_items si WHERE si.product_id=p.id),0) sold,'
      'COALESCE((SELECT SUM(sa.qty) FROM stock_adjustments sa WHERE sa.product_id=p.id),0) adjusted '
      'FROM products p ORDER BY p.name COLLATE NOCASE',
    );
  }

  Future<void> refresh() async {
    setState(()=>future=_load());
    await future;
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Stock')),
    body:FutureBuilder<List<Map<String,Object?>>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final rows=snapshot.data!;
        final totalCost=rows.fold<double>(
          0,
          (a,x)=>a+_n(x['stock'])*_n(x['cost']),
        );
        final totalRetail=rows.fold<double>(
          0,
          (a,x)=>a+_n(x['stock'])*_n(x['price']),
        );
        return RefreshIndicator(
          onRefresh:refresh,
          child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:QamvioUi.pagePadding,
            children:[
              const QamvioPageIntro(
                title:'Stock',
                subtitle:'Opening + Purchases + Adjustments − Sold quantity.',
                icon:Icons.inventory_2_rounded,
              ),
              const SizedBox(height:16),
              Row(
                children:[
                  Expanded(child:_mini(context,'Items','${rows.length}',Icons.widgets_outlined)),
                  const SizedBox(width:8),
                  Expanded(child:_mini(context,'Cost Value',_money(totalCost),Icons.account_balance_wallet_outlined)),
                  const SizedBox(width:8),
                  Expanded(child:_mini(context,'Sale Value',_money(totalRetail),Icons.sell_outlined)),
                ],
              ),
              const SizedBox(height:16),
              Card(
                child:SingleChildScrollView(
                  scrollDirection:Axis.horizontal,
                  child:DataTable(
                    columns:const [
                      DataColumn(label:Text('Product')),
                      DataColumn(label:Text('Opening'),numeric:true),
                      DataColumn(label:Text('Purchased'),numeric:true),
                      DataColumn(label:Text('Adjusted'),numeric:true),
                      DataColumn(label:Text('Sold'),numeric:true),
                      DataColumn(label:Text('Current'),numeric:true),
                      DataColumn(label:Text('Cost'),numeric:true),
                      DataColumn(label:Text('Value'),numeric:true),
                    ],
                    rows:[
                      for(final x in rows)
                        DataRow(cells:[
                          DataCell(Text(x['name'].toString())),
                          DataCell(Text(_money(x['opening_qty']))),
                          DataCell(Text(_money(x['purchased']))),
                          DataCell(Text(_money(x['adjusted']))),
                          DataCell(Text(_money(x['sold']))),
                          DataCell(Text(
                            _money(x['stock']),
                            style:TextStyle(
                              fontWeight:FontWeight.w900,
                              color:_n(x['stock'])<=_n(x['reorder_level'])
                                ?QamvioUi.danger
                                :null,
                            ),
                          )),
                          DataCell(Text(_money(x['cost']))),
                          DataCell(Text(_money(_n(x['stock'])*_n(x['cost'])))),
                        ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _mini(BuildContext context,String label,String value,IconData icon)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Icon(icon,size:18,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:7),
          Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900)),
          Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class StockLedgerPage extends StatefulWidget {
  const StockLedgerPage({super.key});

  @override
  State<StockLedgerPage> createState()=>_StockLedgerPageState();
}

class _StockLedgerPageState extends State<StockLedgerPage> {
  List<Map<String,Object?>> products=const [];
  List<Map<String,Object?>> rows=const [];
  String productId='';
  bool loading=true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db=await AppDatabase.instance.database;
    final p=await db.query('products',orderBy:'name COLLATE NOCASE');
    if(!mounted) return;
    productId=p.isEmpty?'':p.first['id'].toString();
    products=p;
    await loadLedger();
  }

  Future<void> loadLedger() async {
    if(productId.isEmpty) {
      if(mounted) setState(() { rows=const []; loading=false; });
      return;
    }
    setState(()=>loading=true);
    final db=await AppDatabase.instance.database;
    final p=products.firstWhere((x)=>x['id'].toString()==productId);
    final out=<Map<String,Object?>>[
      {
        'date':'Opening',
        'type':'Opening Stock',
        'qty':_n(p['opening_qty']),
        'note':'Opening quantity',
      }
    ];
    final purchases=await db.rawQuery(
      'SELECT pu.business_date date,pi.qty,pu.invoice_no '
      'FROM purchase_items pi JOIN purchases pu ON pu.id=pi.purchase_id '
      'WHERE pi.product_id=? ORDER BY pu.created_at',
      [productId],
    );
    for(final x in purchases) {
      out.add({
        'date':x['date']??'',
        'type':'Purchase',
        'qty':_n(x['qty']),
        'note':'Invoice ${x['invoice_no']??''}',
      });
    }
    final adjustments=await db.rawQuery(
      'SELECT business_date date,qty,note FROM stock_adjustments '
      'WHERE product_id=? ORDER BY created_at',
      [productId],
    );
    for(final x in adjustments) {
      out.add({
        'date':x['date']??'',
        'type':'Adjustment',
        'qty':_n(x['qty']),
        'note':x['note']??'',
      });
    }
    final sales=await db.rawQuery(
      'SELECT s.business_date date,si.qty,s.invoice_no '
      'FROM sale_items si JOIN sales s ON s.id=si.sale_id '
      'WHERE si.product_id=? ORDER BY s.created_at',
      [productId],
    );
    for(final x in sales) {
      out.add({
        'date':x['date']??'',
        'type':'Sale',
        'qty':-_n(x['qty']),
        'note':'Invoice ${x['invoice_no']??''}',
      });
    }
    out.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    double running=0;
    for(final x in out) {
      running+=_n(x['qty']);
      x['balance']=running;
    }
    if(!mounted) return;
    setState(() {
      rows=out;
      loading=false;
    });
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Stock Ledger')),
    body:ListView(
      padding:QamvioUi.pagePadding,
      children:[
        const QamvioPageIntro(
          title:'Stock Ledger',
          subtitle:'Opening, purchases, adjustments and sales movement by product.',
          icon:Icons.format_list_numbered_rounded,
        ),
        const SizedBox(height:16),
        if(products.isEmpty)
          const QamvioEmptyState(
            icon:Icons.inventory_2_outlined,
            title:'No products',
            subtitle:'Add products first.',
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue:productId,
            decoration:const InputDecoration(
              labelText:'Product',
              prefixIcon:Icon(Icons.inventory_2_outlined),
            ),
            items:[
              for(final p in products)
                DropdownMenuItem(
                  value:p['id'].toString(),
                  child:Text(p['name'].toString()),
                ),
            ],
            onChanged:(v) async {
              setState(()=>productId=v??'');
              await loadLedger();
            },
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
                    DataColumn(label:Text('Qty'),numeric:true),
                    DataColumn(label:Text('Balance'),numeric:true),
                    DataColumn(label:Text('Note')),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['date'].toString())),
                        DataCell(Text(x['type'].toString())),
                        DataCell(Text(
                          _money(x['qty']),
                          style:TextStyle(
                            fontWeight:FontWeight.w800,
                            color:_n(x['qty'])>=0?QamvioUi.success:QamvioUi.danger,
                          ),
                        )),
                        DataCell(Text(_money(x['balance']))),
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

class DiscountReportPage extends StatefulWidget {
  const DiscountReportPage({super.key});

  @override
  State<DiscountReportPage> createState()=>_DiscountReportPageState();
}

class _DiscountReportPageState extends State<DiscountReportPage> {
  late Future<List<Map<String,Object?>>> future;

  @override
  void initState() {
    super.initState();
    future=_load();
  }

  Future<List<Map<String,Object?>>> _load() async {
    final db=await AppDatabase.instance.database;
    return db.rawQuery(
      'SELECT s.invoice_no,s.business_date,s.discount,s.subtotal,s.total,'
      'c.name customer_name,sm.name salesman_name '
      'FROM sales s '
      'LEFT JOIN customers c ON c.id=s.customer_id '
      'LEFT JOIN salesmen sm ON sm.id=s.salesman_id '
      'WHERE s.discount>0 ORDER BY s.created_at DESC',
    );
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Discount Report')),
    body:FutureBuilder<List<Map<String,Object?>>>(
      future:future,
      builder:(context,snapshot) {
        if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
        final rows=snapshot.data!;
        final total=rows.fold<double>(0,(a,x)=>a+_n(x['discount']));
        return ListView(
          padding:QamvioUi.pagePadding,
          children:[
            QamvioPageIntro(
              title:'Discount Report',
              subtitle:'Invoice discount history exactly from saved sales.',
              icon:Icons.discount_rounded,
              trailing:Text(
                _money(total),
                style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:18),
              ),
            ),
            const SizedBox(height:16),
            Card(
              child:SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                child:DataTable(
                  columns:const [
                    DataColumn(label:Text('Date')),
                    DataColumn(label:Text('Invoice')),
                    DataColumn(label:Text('Customer')),
                    DataColumn(label:Text('Salesman')),
                    DataColumn(label:Text('Gross'),numeric:true),
                    DataColumn(label:Text('Discount'),numeric:true),
                    DataColumn(label:Text('Net'),numeric:true),
                  ],
                  rows:[
                    for(final x in rows)
                      DataRow(cells:[
                        DataCell(Text(x['business_date']?.toString()??'')),
                        DataCell(Text(x['invoice_no'].toString())),
                        DataCell(Text(x['customer_name']?.toString()??'')),
                        DataCell(Text(x['salesman_name']?.toString()??'')),
                        DataCell(Text(_money(x['subtotal']))),
                        DataCell(Text(_money(x['discount']))),
                        DataCell(Text(_money(x['total']))),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
