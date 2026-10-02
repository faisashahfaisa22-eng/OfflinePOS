import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState()=>_ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String,num>> data;

  @override
  void initState() {
    super.initState();
    data=AppDatabase.instance.extendedReportTotals();
  }

  void reload()=>setState(()=>data=AppDatabase.instance.extendedReportTotals());

  Future<void> share() async {
    try {
      await WhatsAppShare.shareBusinessReport();
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('WhatsApp: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('Reports'),
      actions:[
        IconButton(
          tooltip:'Share business report',
          onPressed:share,
          icon:const Icon(Icons.chat_rounded),
        ),
      ],
    ),
    body:FutureBuilder<Map<String,num>>(
      future:data,
      builder:(context,snapshot) {
        if(snapshot.connectionState==ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child:CircularProgressIndicator());
        }
        final x=snapshot.data??const {};
        final sales=(x['sales']??0).toDouble();
        final purchases=(x['purchases']??0).toDouble();
        final expenses=(x['expenses']??0).toDouble();
        final profit=(x['profit']??0).toDouble();
        return RefreshIndicator(
          onRefresh:() async =>reload(),
          child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:QamvioUi.pagePadding,
            children:[
              QamvioPageIntro(
                title:'Business Reports',
                subtitle:'A financial snapshot of sales, cost, expenses, receivables and inventory.',
                icon:Icons.analytics_rounded,
                trailing:IconButton.filledTonal(
                  tooltip:'WhatsApp report',
                  onPressed:share,
                  icon:const Icon(Icons.ios_share_rounded),
                ),
              ),
              const SizedBox(height:20),
              const QamvioSectionTitle(
                'Performance',
                subtitle:'Core business movement and estimated profit',
              ),
              LayoutBuilder(
                builder:(context,constraints) {
                  final columns=constraints.maxWidth>=700?4:2;
                  return GridView.count(
                    crossAxisCount:columns,
                    shrinkWrap:true,
                    physics:const NeverScrollableScrollPhysics(),
                    mainAxisSpacing:12,
                    crossAxisSpacing:12,
                    childAspectRatio:1.08,
                    children:[
                      QamvioStatCard(
                        label:'Sales',
                        value:QamvioUi.money(sales),
                        icon:Icons.payments_rounded,
                      ),
                      QamvioStatCard(
                        label:'Purchases',
                        value:QamvioUi.money(purchases),
                        icon:Icons.shopping_cart_checkout_rounded,
                      ),
                      QamvioStatCard(
                        label:'Expenses',
                        value:QamvioUi.money(expenses),
                        icon:Icons.receipt_long_rounded,
                      ),
                      QamvioStatCard(
                        label:'Profit estimate',
                        value:QamvioUi.money(profit),
                        icon:profit>=0
                          ?Icons.trending_up_rounded
                          :Icons.trending_down_rounded,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height:22),
              const QamvioSectionTitle(
                'Credit position',
                subtitle:'Outstanding amounts that still need collection or payment',
              ),
              Card(
                child:Padding(
                  padding:const EdgeInsets.all(16),
                  child:Column(
                    children:[
                      _line(
                        context,
                        icon:Icons.account_balance_wallet_outlined,
                        label:'Sales receivable / due',
                        value:x['due']??0,
                      ),
                      const Divider(height:24),
                      _line(
                        context,
                        icon:Icons.local_shipping_outlined,
                        label:'Supplier purchase due',
                        value:x['supplierDue']??0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height:22),
              const QamvioSectionTitle(
                'Inventory valuation',
                subtitle:'Current stock valued at cost and selling price',
              ),
              Card(
                child:Padding(
                  padding:const EdgeInsets.all(16),
                  child:Column(
                    children:[
                      _line(
                        context,
                        icon:Icons.inventory_2_outlined,
                        label:'Inventory cost value',
                        value:x['stockCost']??0,
                      ),
                      const Divider(height:24),
                      _line(
                        context,
                        icon:Icons.sell_outlined,
                        label:'Inventory sale value',
                        value:x['stockRetail']??0,
                      ),
                      const Divider(height:24),
                      _line(
                        context,
                        icon:Icons.auto_graph_rounded,
                        label:'Potential gross stock margin',
                        value:(x['stockRetail']??0)-(x['stockCost']??0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:share,
                icon:const Icon(Icons.chat_rounded),
                label:const Text('Share Full Report on WhatsApp'),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required String label,
    required num value,
  })=>Row(
    children:[
      Container(
        width:44,
        height:44,
        decoration:BoxDecoration(
          color:Theme.of(context).colorScheme.primaryContainer,
          borderRadius:BorderRadius.circular(14),
        ),
        child:Icon(
          icon,
          color:Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(width:12),
      Expanded(
        child:Text(
          label,
          style:const TextStyle(fontWeight:FontWeight.w700),
        ),
      ),
      Text(
        QamvioUi.money(value),
        style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
      ),
    ],
  );
}
