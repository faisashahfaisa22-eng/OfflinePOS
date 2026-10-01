import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Map<String, Object?>> rows = const [];
  bool loading = true;

  Future<void> load() async {
    final data = await AppDatabase.instance.products();
    if (mounted) setState(() { rows = data; loading = false; });
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> addProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LanguageController.instance.strings.t('addProduct')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: LanguageController.instance.strings.t('productName'))),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: LanguageController.instance.strings.t('salePrice'))),
          TextField(controller: stock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: LanguageController.instance.strings.t('openingStock'))),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: Text(LanguageController.instance.strings.t('cancel'))),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: Text(LanguageController.instance.strings.t('save'))),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await AppDatabase.instance.saveProduct(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text,
      price: double.tryParse(price.text) ?? 0,
      stock: double.tryParse(stock.text) ?? 0,
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(LanguageController.instance.strings.t('inventory'))),
    floatingActionButton: FloatingActionButton.extended(onPressed: addProduct, icon: const Icon(Icons.add), label: Text(LanguageController.instance.strings.t('addProduct'))),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      rows.isEmpty ? Center(child: Text(LanguageController.instance.strings.t('noProducts'))) :
      ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_,__)=>const Divider(height:1),
        itemBuilder: (_,i) {
          final p=rows[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
            title: Text('${p['name']}'),
            subtitle: Text('${LanguageController.instance.strings.t('stock')}: ${p['stock']}'),
            trailing: Text('${p['price']}'),
          );
        },
      ),
  );
}
