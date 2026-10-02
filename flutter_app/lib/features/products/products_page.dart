import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';
import '../../core/ui/qamvio_ui.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState()=>_ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
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
    final data=await AppDatabase.instance.products();
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((p)=>[
      p['name'],
      p['sku'],
      p['barcode'],
      p['category'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  double get retailValue=>rows.fold<double>(
    0,
    (a,p)=>a+
      (((p['stock'] as num?)?.toDouble()??0)*
      ((p['price'] as num?)?.toDouble()??0)),
  );

  double get costValue=>rows.fold<double>(
    0,
    (a,p)=>a+
      (((p['stock'] as num?)?.toDouble()??0)*
      ((p['cost'] as num?)?.toDouble()??0)),
  );

  Future<void> addProduct() async {
    final name=TextEditingController();
    final barcode=TextEditingController();
    final category=TextEditingController();
    final cost=TextEditingController(text:'0');
    final price=TextEditingController(text:'0');
    final stock=TextEditingController(text:'0');
    final unit=TextEditingController(text:'pcs');

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
                LanguageController.instance.strings.t('addProduct'),
                style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight:FontWeight.w900,
                ),
              ),
              const SizedBox(height:4),
              const Text('Create a complete inventory item with pricing and stock.'),
              const SizedBox(height:18),
              TextField(
                controller:name,
                autofocus:true,
                decoration:InputDecoration(
                  labelText:LanguageController.instance.strings.t('productName'),
                  prefixIcon:const Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height:10),
              Row(
                children:[
                  Expanded(
                    child:TextField(
                      controller:cost,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(labelText:'Cost price'),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:TextField(
                      controller:price,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(
                        labelText:LanguageController.instance.strings.t('salePrice'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height:10),
              Row(
                children:[
                  Expanded(
                    child:TextField(
                      controller:stock,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(
                        labelText:LanguageController.instance.strings.t('openingStock'),
                      ),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:TextField(
                      controller:unit,
                      decoration:const InputDecoration(labelText:'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height:10),
              TextField(
                controller:category,
                decoration:const InputDecoration(
                  labelText:'Category',
                  prefixIcon:Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height:10),
              TextField(
                controller:barcode,
                decoration:const InputDecoration(
                  labelText:'Barcode',
                  prefixIcon:Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:()=>Navigator.pop(sheetContext,true),
                icon:const Icon(Icons.save_outlined),
                label:const Text('Save Product'),
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
      await AppDatabase.instance.saveProduct(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        name:name.text,
        barcode:barcode.text.trim().isEmpty?null:barcode.text.trim(),
        category:category.text.trim().isEmpty?null:category.text.trim(),
        cost:double.tryParse(cost.text)??0,
        price:double.tryParse(price.text)??0,
        stock:double.tryParse(stock.text)??0,
        unit:unit.text.trim().isEmpty?'pcs':unit.text.trim(),
      );
      await load();
    }

    name.dispose();
    barcode.dispose();
    category.dispose();
    cost.dispose();
    price.dispose();
    stock.dispose();
    unit.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s=LanguageController.instance.strings;
    return Scaffold(
      appBar:AppBar(title:Text(s.t('inventory'))),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:addProduct,
        icon:const Icon(Icons.add_rounded),
        label:Text(s.t('addProduct')),
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
                title:s.t('inventory'),
                subtitle:'Stock, cost, selling price and product availability in one place.',
                icon:Icons.inventory_2_rounded,
              ),
              const SizedBox(height:18),
              Row(
                children:[
                  Expanded(
                    child:_summary(
                      context,
                      'Products',
                      rows.length.toString(),
                      Icons.widgets_outlined,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_summary(
                      context,
                      'Cost value',
                      QamvioUi.money(costValue),
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_summary(
                      context,
                      'Retail value',
                      QamvioUi.money(retailValue),
                      Icons.sell_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              TextField(
                controller:search,
                decoration:InputDecoration(
                  hintText:'Search name, barcode or category',
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
                'Inventory items',
                subtitle:'${filtered.length} matching products',
              ),
              if(filtered.isEmpty)
                QamvioEmptyState(
                  icon:Icons.inventory_2_outlined,
                  title:rows.isEmpty?'No products yet':'No product found',
                  subtitle:rows.isEmpty
                    ?'Add your first product with cost, price and opening stock.'
                    :'Try a different search term.',
                  actionLabel:rows.isEmpty?'Add Product':null,
                  onAction:rows.isEmpty?addProduct:null,
                )
              else
                ...filtered.map((p)=>Padding(
                  padding:const EdgeInsets.only(bottom:10),
                  child:_productCard(context,p),
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

  Widget _productCard(BuildContext context,Map<String,Object?> p) {
    final stock=(p['stock'] as num?)?.toDouble()??0;
    final unit=(p['unit']??'pcs').toString();
    final category=(p['category']??'Uncategorized').toString();
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Row(
          children:[
            Container(
              width:50,
              height:50,
              decoration:BoxDecoration(
                color:stock<=0
                  ?const Color(0xFFFCE8E6)
                  :Theme.of(context).colorScheme.primaryContainer,
                borderRadius:BorderRadius.circular(16),
              ),
              child:Icon(
                stock<=0?Icons.inventory_2_outlined:Icons.inventory_rounded,
                color:stock<=0
                  ?QamvioUi.danger
                  :Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width:12),
            Expanded(
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(
                    p['name'].toString(),
                    style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                  ),
                  const SizedBox(height:3),
                  Text(
                    category,
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height:8),
                  Wrap(
                    spacing:7,
                    runSpacing:7,
                    children:[
                      QamvioAmountPill(label:'Cost',amount:p['cost']),
                      QamvioAmountPill(label:'Price',amount:p['price'],strong:true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width:10),
            Column(
              crossAxisAlignment:CrossAxisAlignment.end,
              children:[
                Text(
                  QamvioUi.money(stock),
                  style:TextStyle(
                    fontSize:18,
                    fontWeight:FontWeight.w900,
                    color:stock<=0?QamvioUi.danger:null,
                  ),
                ),
                Text(
                  unit,
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height:6),
                Text(
                  stock<=0?'OUT OF STOCK':'IN STOCK',
                  style:TextStyle(
                    fontSize:10,
                    fontWeight:FontWeight.w900,
                    color:stock<=0?QamvioUi.danger:QamvioUi.success,
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
