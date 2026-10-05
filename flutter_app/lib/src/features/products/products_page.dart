import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Future<List<Map<String, Object?>>> load() async {
    final db = await AppDatabase.instance.database;
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await AppDatabase.instance.database;
    await db.insert('products', {
      'id': 'p_${DateTime.now().microsecondsSinceEpoch}',
      'name': name.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'stock': double.tryParse(stock.text) ?? 0,
      'created_at': now,
      'updated_at': now,
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Products')),
    floatingActionButton: FloatingActionButton.extended(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('Add Product')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: load(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.isEmpty) return const Center(child: Text('No products yet'));
        return ListView.separated(
          itemCount: snap.data!.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = snap.data![i];
            return ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text('${p['name']}'),
              subtitle: Text('Stock: ${p['stock']}'),
              trailing: Text('${p['price']}'),
            );
          },
        );
      },
    ),
  );
}
