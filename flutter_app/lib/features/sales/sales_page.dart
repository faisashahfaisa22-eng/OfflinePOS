import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override State<SalesPage> createState()=>_SalesPageState();
}
class _SalesPageState extends State<SalesPage>{
  List<Map<String,Object?>> rows=const[]; bool loading=true;
  Future<void> load()async{final x=await AppDatabase.instance.sales();if(mounted)setState((){rows=x;loading=false;});}
  @override void initState(){super.initState();load();}
  Future<void> newSale()async{
    final products=await AppDatabase.instance.products();
    if(!mounted)return;
    if(products.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add a product first.')));return;}
    final cart=<String,Map<String,Object?>>{};
    final paid=TextEditingController(),discount=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      title:const Text('New Sales Invoice'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Align(alignment:Alignment.centerLeft,child:Text('Tap a product to add it to the invoice')),
        const SizedBox(height:8),
        ...products.map((p)=>ListTile(title:Text('${p['name']}'),subtitle:Text('Stock: ${p['stock']} • Price: ${p['price']}'),
          trailing:IconButton(icon:const Icon(Icons.add_circle),onPressed:(){
            final id='${p['id']}'; final old=cart[id]; final q=((old?['qty'] as num?)?.toDouble()??0)+1;
            cart[id]={'product_id':id,'product_name':p['name'],'qty':q,'price':(p['price'] as num?)?.toDouble()??0};setLocal((){});
          })),
        const Divider(),
        if(cart.isEmpty) const Padding(padding:EdgeInsets.all(12),child:Text('Add items — invoice table will appear here.')),
        if(cart.isNotEmpty) Table(border:TableBorder.all(),children:[
          const TableRow(children:[Padding(padding:EdgeInsets.all(6),child:Text('Product')),Padding(padding:EdgeInsets.all(6),child:Text('Qty')),Padding(padding:EdgeInsets.all(6),child:Text('Price')),Padding(padding:EdgeInsets.all(6),child:Text('Total'))]),
          ...cart.values.map((x)=>TableRow(children:[
            Padding(padding:const EdgeInsets.all(6),child:Text('${x['product_name']}')),
            Padding(padding:const EdgeInsets.all(6),child:Text('${x['qty']}')),
            Padding(padding:const EdgeInsets.all(6),child:Text('${x['price']}')),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                (((x['qty'] as num?)?.toDouble() ?? 0) *
                        ((x['price'] as num?)?.toDouble() ?? 0))
                    .toStringAsFixed(2),
              ),
            ),
          ]))
        ]),
        TextField(controller:discount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Discount')),
        TextField(controller:paid,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Paid')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:cart.isEmpty?null:()=>Navigator.pop(context,true),child:const Text('Save Invoice'))],
    )));
    if(ok!=true)return;
    final id=DateTime.now().microsecondsSinceEpoch.toString();
    await AppDatabase.instance.createSale(id:id,invoiceNo:'INV-${DateTime.now().millisecondsSinceEpoch}',items:cart.values.toList(),
      discount:double.tryParse(discount.text)??0,paid:double.tryParse(paid.text)??0);
    await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Sales & Invoices')),
    floatingActionButton:FloatingActionButton.extended(onPressed:newSale,icon:const Icon(Icons.add_shopping_cart),label:const Text('New Invoice')),
    body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('No sales yet.')):
    ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=rows[i];return ListTile(
      leading:const CircleAvatar(child:Icon(Icons.receipt)),title:Text('${x['invoice_no']}'),subtitle:Text('${x['created_at']}'),
      trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('Total: ${x['total']}'),Text('Due: ${x['due']}')])) ;}));
}
