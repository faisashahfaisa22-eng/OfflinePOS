import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState()=>_ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  String editingId='';

  final name=TextEditingController();
  final salePrice=TextEditingController();
  final costPrice=TextEditingController();
  final openingQty=TextEditingController(text:'0');
  final reorderLevel=TextEditingController(text:'0');

  bool get canEdit=>LocalAuthService.instance.canEdit;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    salePrice.dispose();
    costPrice.dispose();
    openingQty.dispose();
    reorderLevel.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final data=await AppDatabase.instance.products();
    if(!mounted) return;
    setState(() {
      rows=data;
      loading=false;
    });
  }

  void resetForm() {
    setState(() {
      editingId='';
      name.clear();
      salePrice.clear();
      costPrice.clear();
      openingQty.text='0';
      reorderLevel.text='0';
    });
  }

  void edit(Map<String,Object?> x) {
    if(!canEdit) return;
    setState(() {
      editingId=x['id'].toString();
      name.text=x['name'].toString();
      salePrice.text=QamvioUi.money(x['price']);
      costPrice.text=QamvioUi.money(x['cost']);
      openingQty.text=QamvioUi.money(x['opening_qty']);
      reorderLevel.text=QamvioUi.money(x['reorder_level']);
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> save() async {
    if(!canEdit) return;
    if(name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Product name required.')),
      );
      return;
    }
    Map<String,Object?>? old;
    if(editingId.isNotEmpty) {
      for(final x in rows) {
        if(x['id'].toString()==editingId) {
          old=x;
          break;
        }
      }
    }
    final opening=double.tryParse(openingQty.text.trim())??0;
    var currentStock=opening;
    if(old!=null) {
      final oldOpening=(old['opening_qty'] as num?)?.toDouble()??0;
      final oldStock=(old['stock'] as num?)?.toDouble()??0;
      currentStock=oldStock+(opening-oldOpening);
    }
    await AppDatabase.instance.saveProduct(
      id:editingId.isEmpty?DateTime.now().microsecondsSinceEpoch.toString():editingId,
      name:name.text.trim(),
      cost:double.tryParse(costPrice.text.trim())??0,
      price:double.tryParse(salePrice.text.trim())??0,
      stock:currentStock,
      openingQty:opening,
      reorderLevel:double.tryParse(reorderLevel.text.trim())??0,
      unit:'pcs',
    );
    resetForm();
    await load();
  }

  Future<void> remove(Map<String,Object?> x) async {
    if(!LocalAuthService.instance.canDelete) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Delete Product?'),
        content:Text('Move "${x['name']}" to Recycle Bin? Products with stock history cannot be deleted until linked entries are removed.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
        ],
      ),
    )??false;
    if(!ok) return;
    try {
      await AppDatabase.instance.softDeleteById('products',x['id'].toString());
      await load();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Products')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const Text('Products',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:12),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(14),
              child:Wrap(
                spacing:10,
                runSpacing:10,
                crossAxisAlignment:WrapCrossAlignment.end,
                children:[
                  SizedBox(
                    width:260,
                    child:TextField(
                      controller:name,
                      enabled:canEdit,
                      decoration:InputDecoration(labelText:tr('Product Name')),
                    ),
                  ),
                  SizedBox(
                    width:145,
                    child:TextField(
                      controller:salePrice,
                      enabled:canEdit,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(labelText:tr('Sale Price')),
                    ),
                  ),
                  SizedBox(
                    width:145,
                    child:TextField(
                      controller:costPrice,
                      enabled:canEdit,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(labelText:tr('Cost Price')),
                    ),
                  ),
                  SizedBox(
                    width:145,
                    child:TextField(
                      controller:openingQty,
                      enabled:canEdit,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(labelText:tr('Opening Qty')),
                    ),
                  ),
                  SizedBox(
                    width:145,
                    child:TextField(
                      controller:reorderLevel,
                      enabled:canEdit,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:InputDecoration(labelText:tr('Reorder Level')),
                    ),
                  ),
                  if(canEdit)
                    FilledButton(
                      onPressed:save,
                      child:Text(editingId.isEmpty?'Add Product':'Update Product'),
                    ),
                  if(canEdit&&editingId.isNotEmpty)
                    OutlinedButton(
                      onPressed:resetForm,
                      child:const Text('Cancel Edit'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height:12),
          Card(
            child:SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:DataTable(
                columns:const [
                  DataColumn(label:Text('Product')),
                  DataColumn(label:Text('Sale Price'),numeric:true),
                  DataColumn(label:Text('Cost Price'),numeric:true),
                  DataColumn(label:Text('Opening Qty'),numeric:true),
                  DataColumn(label:Text('Reorder Level'),numeric:true),
                  DataColumn(label:Text('Current Stock'),numeric:true),
                  DataColumn(label:Text('')),
                ],
                rows:[
                  for(final x in rows)
                    DataRow(cells:[
                      DataCell(Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),
                      DataCell(Text(QamvioUi.money(x['price']))),
                      DataCell(Text(QamvioUi.money(x['cost']))),
                      DataCell(Text(QamvioUi.money(x['opening_qty']))),
                      DataCell(Text(QamvioUi.money(x['reorder_level']))),
                      DataCell(Text(QamvioUi.money(x['stock']))),
                      DataCell(
                        canEdit
                          ?Row(
                            mainAxisSize:MainAxisSize.min,
                            children:[
                              IconButton(
                                tooltip:tr('Edit'),
                                onPressed:()=>edit(x),
                                icon:const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip:tr('Delete'),
                                onPressed:()=>remove(x),
                                icon:const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          )
                          :const SizedBox.shrink(),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
  );
}
