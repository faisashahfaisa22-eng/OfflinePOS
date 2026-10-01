import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

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
        title: const Text('Add Product'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price')),
          TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening stock')),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Save')),
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
    appBar: AppBar(title: const Text('Products & Inventory')),
    floatingActionButton: FloatingActionButton.extended(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('Add Product')),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      rows.isEmpty ? const Center(child: Text('No products yet. Add your first product.')) :
      ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_,__)=>const Divider(height:1),
        itemBuilder: (_,i) {
          final p=rows[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
            title: Text('${p['name']}'),
            subtitle: Text('Stock: ${p['stock']}'),
            trailing: Text('${p['price']}'),
          );
        },
      ),
  );
}
