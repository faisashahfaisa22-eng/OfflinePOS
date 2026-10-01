import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';
import '../../core/share/whatsapp_share.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String, Object?>> rows = const [];
  bool loading = true;

  Future<void> load() async {
    final x = await AppDatabase.instance.sales();
    if (mounted) {
      setState(() {
        rows = x;
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
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
    final products = await AppDatabase.instance.products();
    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageController.instance.strings.t('noProducts')),
        ),
      );
      return;
    }

    final cart = <String, Map<String, Object?>>{};
    final paid = TextEditingController();
    final discount = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(LanguageController.instance.strings.t('newSalesInvoice')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tap a product to add it to the invoice'),
                  ),
                  const SizedBox(height: 8),
                  ...products.map(
                    (p) => ListTile(
                      title: Text('${p['name']}'),
                      subtitle: Text(
                        'Stock: ${p['stock']} • Price: ${p['price']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          final id = '${p['id']}';
                          final old = cart[id];
                          final q =
                              ((old?['qty'] as num?)?.toDouble() ?? 0) + 1;
                          cart[id] = {
                            'product_id': id,
                            'product_name': p['name'],
                            'qty': q,
                            'price':
                                (p['price'] as num?)?.toDouble() ?? 0,
                          };
                          setLocal(() {});
                        },
                      ),
                    ),
                  ),
                  const Divider(),
                  if (cart.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        LanguageController.instance.strings.t('addItemsHint'),
                      ),
                    ),
                  if (cart.isNotEmpty)
                    Table(
                      border: TableBorder.all(),
                      children: [
                        const TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text('Product'),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text('Qty'),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text('Price'),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text('Total'),
                            ),
                          ],
                        ),
                        ...cart.values.map(
                          (x) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('${x['product_name']}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('${x['qty']}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('${x['price']}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  (((x['qty'] as num?)?.toDouble() ?? 0) *
                                          ((x['price'] as num?)?.toDouble() ??
                                              0))
                                      .toStringAsFixed(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          LanguageController.instance.strings.t('discount'),
                    ),
                  ),
                  TextField(
                    controller: paid,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LanguageController.instance.strings.t('paid'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LanguageController.instance.strings.t('cancel')),
            ),
            FilledButton(
              onPressed:
                  cart.isEmpty ? null : () => Navigator.pop(context, true),
              child: Text(LanguageController.instance.strings.t('save')),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await AppDatabase.instance.createSale(
      id: id,
      invoiceNo: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      items: cart.values.toList(),
      discount: double.tryParse(discount.text) ?? 0,
      paid: double.tryParse(paid.text) ?? 0,
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(LanguageController.instance.strings.t('salesInvoice')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: newSale,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(LanguageController.instance.strings.t('newInvoice')),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? Center(
                    child:
                        Text(LanguageController.instance.strings.t('noSales')),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final x = rows[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt),
                        ),
                        title: Text('${x['invoice_no']}'),
                        subtitle: Text('${x['created_at']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total: ${x['total']}'),
                                Text('Due: ${x['due']}'),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Share invoice on WhatsApp',
                              icon: const Icon(Icons.chat),
                              onPressed: () => shareInvoice(x),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      );
}
