import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';
import '../cloud/cloud_page.dart';
import '../expenses/expenses_page.dart';
import '../fuel/fuel_page.dart';
import '../loans/loans_page.dart';
import '../parties/party_page.dart';
import '../pharmacy/pharmacy_page.dart';
import '../products/products_page.dart';
import '../purchases/purchases_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_page.dart';
import '../salesmen/salesmen_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState()=>_DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String,num>> totals;

  @override
  void initState() {
    super.initState();
    totals=AppDatabase.instance.dashboardTotals();
  }

  void reload()=>setState(()=>totals=AppDatabase.instance.dashboardTotals());

  Future<void> shareBusinessReport() async {
    try {
      await WhatsAppShare.shareBusinessReport();
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('WhatsApp: $e')),
      );
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder:(_)=>page),
    );
    if(mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final lc=LanguageController.instance;
    return ListenableBuilder(
      listenable:lc,
      builder:(context,_) {
        final s=lc.strings;
        return Scaffold(
          appBar:AppBar(
            title:const Text('QAMVIO POS'),
            actions:[
              IconButton(
                tooltip:'WhatsApp business report',
                onPressed:shareBusinessReport,
                icon:const Icon(Icons.chat_bubble_outline_rounded),
              ),
              PopupMenuButton<AppLanguage>(
                tooltip:s.t('language'),
                icon:const Icon(Icons.language_rounded),
                onSelected:lc.setLanguage,
                itemBuilder:(_)=>const [
                  PopupMenuItem(value:AppLanguage.english,child:Text('English')),
                  PopupMenuItem(value:AppLanguage.pashto,child:Text('پښتو')),
                  PopupMenuItem(value:AppLanguage.dari,child:Text('دری')),
                  PopupMenuItem(value:AppLanguage.urdu,child:Text('اردو')),
                ],
              ),
            ],
          ),
          drawer:QamvioDrawer(onReturn:reload,strings:s),
          body:FutureBuilder<Map<String,num>>(
            future:totals,
            builder:(context,snapshot) {
              final x=snapshot.data??const {
                'sales':0,
                'expenses':0,
                'products':0,
                'customers':0,
                'due':0,
              };
              return RefreshIndicator(
                onRefresh:() async =>reload(),
                child:ListView(
                  physics:const AlwaysScrollableScrollPhysics(),
                  padding:QamvioUi.pagePadding,
                  children:[
                    QamvioPageIntro(
                      title:s.t('businessDashboard'),
                      subtitle:'Live offline overview of sales, receivables, stock and daily activity.',
                      icon:Icons.space_dashboard_rounded,
                      trailing:IconButton.filledTonal(
                        tooltip:'Share full report',
                        onPressed:shareBusinessReport,
                        icon:const Icon(Icons.ios_share_rounded),
                      ),
                    ),
                    const SizedBox(height:20),
                    const QamvioSectionTitle(
                      'Business snapshot',
                      subtitle:'Key numbers from your local SQLite database',
                    ),
                    LayoutBuilder(
                      builder:(context,constraints) {
                        final columns=constraints.maxWidth>=900
                          ?4
                          :constraints.maxWidth>=560
                            ?3
                            :2;
                        return GridView.count(
                          crossAxisCount:columns,
                          shrinkWrap:true,
                          physics:const NeverScrollableScrollPhysics(),
                          mainAxisSpacing:12,
                          crossAxisSpacing:12,
                          childAspectRatio:1.12,
                          children:[
                            QamvioStatCard(
                              label:s.t('sales'),
                              value:QamvioUi.money(x['sales']),
                              icon:Icons.payments_rounded,
                              caption:'Recorded sales',
                            ),
                            QamvioStatCard(
                              label:s.t('due'),
                              value:QamvioUi.money(x['due']),
                              icon:Icons.account_balance_wallet_rounded,
                              caption:'Outstanding invoices',
                            ),
                            QamvioStatCard(
                              label:s.t('expenses'),
                              value:QamvioUi.money(x['expenses']),
                              icon:Icons.receipt_long_rounded,
                              caption:'Business expenses',
                            ),
                            QamvioStatCard(
                              label:s.t('products'),
                              value:'${(x['products']??0).toInt()}',
                              icon:Icons.inventory_2_rounded,
                              caption:'Inventory items',
                            ),
                            QamvioStatCard(
                              label:s.t('customers'),
                              value:'${(x['customers']??0).toInt()}',
                              icon:Icons.groups_2_rounded,
                              caption:'Customer accounts',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height:22),
                    QamvioSectionTitle(
                      'Quick actions',
                      subtitle:'Open the most-used business tools',
                      trailing:TextButton.icon(
                        onPressed:shareBusinessReport,
                        icon:const Icon(Icons.chat_rounded),
                        label:const Text('WhatsApp report'),
                      ),
                    ),
                    LayoutBuilder(
                      builder:(context,constraints) {
                        final twoColumns=constraints.maxWidth>=700;
                        final width=twoColumns
                          ?(constraints.maxWidth-12)/2
                          :constraints.maxWidth;
                        final actions=<Widget>[
                          _action(
                            width:width,
                            icon:Icons.point_of_sale_rounded,
                            title:s.t('salesInvoice'),
                            subtitle:'Create invoice, collect payment and share receipt',
                            onTap:()=>_open(const SalesPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.inventory_2_rounded,
                            title:s.t('inventory'),
                            subtitle:'Products, stock levels and prices',
                            onTap:()=>_open(const ProductsPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.shopping_cart_checkout_rounded,
                            title:'Purchases',
                            subtitle:'Supplier purchases and stock receiving',
                            onTap:()=>_open(const PurchasesPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.people_alt_rounded,
                            title:s.t('customers'),
                            subtitle:'Balances and customer accounts',
                            onTap:()=>_open(const PartyPage(type:PartyType.customer)),
                          ),
                          _action(
                            width:width,
                            icon:Icons.local_shipping_rounded,
                            title:s.t('suppliers'),
                            subtitle:'Supplier balances, payments and WhatsApp',
                            onTap:()=>_open(const PartyPage(type:PartyType.supplier)),
                          ),
                          _action(
                            width:width,
                            icon:Icons.badge_rounded,
                            title:'Salesmen',
                            subtitle:'Salesman accounts, assignment and commission',
                            onTap:()=>_open(const SalesmenPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.account_balance_wallet_rounded,
                            title:'Loans / Credit',
                            subtitle:'Customer, salesman and supplier ledgers',
                            onTap:()=>_open(const LoansPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.analytics_rounded,
                            title:s.t('reports'),
                            subtitle:'Sales, profit, due and inventory valuation',
                            onTap:()=>_open(const ReportsPage()),
                          ),
                          _action(
                            width:width,
                            icon:Icons.cloud_done_rounded,
                            title:s.t('cloud'),
                            subtitle:'Backup, restore and legacy migration',
                            onTap:()=>_open(const CloudPage()),
                          ),
                        ];
                        return Wrap(
                          spacing:12,
                          runSpacing:12,
                          children:actions,
                        );
                      },
                    ),
                    const SizedBox(height:22),
                    const QamvioSectionTitle(
                      'System status',
                      subtitle:'Offline-first business data protection',
                    ),
                    Card(
                      child:Padding(
                        padding:const EdgeInsets.all(16),
                        child:Column(
                          children:[
                            _statusRow(
                              context,
                              icon:Icons.storage_rounded,
                              title:'Offline SQLite database',
                              subtitle:'Core business records work without internet.',
                              ok:true,
                            ),
                            const Divider(height:24),
                            _statusRow(
                              context,
                              icon:Icons.cloud_sync_rounded,
                              title:'Cloud backup ready',
                              subtitle:'Manual and scheduled cloud backup are available.',
                              ok:true,
                            ),
                            const Divider(height:24),
                            _statusRow(
                              context,
                              icon:Icons.shield_outlined,
                              title:'Legacy migration safety',
                              subtitle:'Existing Flutter business data is protected from overwrite.',
                              ok:true,
                            ),
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
      },
    );
  }

  Widget _action({
    required double width,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  })=>SizedBox(
    width:width,
    child:QamvioActionTile(
      icon:icon,
      title:title,
      subtitle:subtitle,
      onTap:onTap,
    ),
  );

  Widget _statusRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool ok,
  })=>Row(
    children:[
      Container(
        width:44,
        height:44,
        decoration:BoxDecoration(
          color:const Color(0xFFEAF7F1),
          borderRadius:BorderRadius.circular(14),
        ),
        child:Icon(icon,color:QamvioUi.success),
      ),
      const SizedBox(width:12),
      Expanded(
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),
            const SizedBox(height:2),
            Text(
              subtitle,
              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                color:const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
      Icon(
        ok?Icons.check_circle_rounded:Icons.error_outline_rounded,
        color:ok?QamvioUi.success:QamvioUi.danger,
      ),
    ],
  );
}

class QamvioDrawer extends StatelessWidget {
  final VoidCallback onReturn;
  final AppStrings strings;

  const QamvioDrawer({
    required this.onReturn,
    required this.strings,
    super.key,
  });

  Future<void> _go(BuildContext context,Widget page) async {
    Navigator.pop(context);
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>page));
    onReturn();
  }

  @override
  Widget build(BuildContext context)=>Drawer(
    child:SafeArea(
      child:ListView(
        padding:const EdgeInsets.fromLTRB(12,10,12,24),
        children:[
          Container(
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(
              gradient:const LinearGradient(
                colors:[Color(0xFF174EA6),Color(0xFF356FD2)],
                begin:Alignment.topLeft,
                end:Alignment.bottomRight,
              ),
              borderRadius:BorderRadius.circular(24),
            ),
            child:const Row(
              children:[
                CircleAvatar(
                  radius:24,
                  backgroundColor:Colors.white,
                  child:Icon(Icons.storefront_rounded,color:QamvioUi.brand),
                ),
                SizedBox(width:12),
                Expanded(
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(
                        'QAMVIO POS',
                        style:TextStyle(
                          color:Colors.white,
                          fontSize:22,
                          fontWeight:FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Offline business suite',
                        style:TextStyle(color:Color(0xFFDCE8FF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height:14),
          _item(
            context,
            icon:Icons.dashboard_rounded,
            title:strings.t('dashboard'),
            selected:true,
            onTap:()=>Navigator.pop(context),
          ),
          _item(
            context,
            icon:Icons.point_of_sale_rounded,
            title:strings.t('salesInvoice'),
            onTap:()=>_go(context,const SalesPage()),
          ),
          _item(
            context,
            icon:Icons.inventory_2_rounded,
            title:strings.t('inventory'),
            onTap:()=>_go(context,const ProductsPage()),
          ),
          _item(
            context,
            icon:Icons.shopping_cart_checkout_rounded,
            title:'Purchases',
            onTap:()=>_go(context,const PurchasesPage()),
          ),
          const Padding(
            padding:EdgeInsets.symmetric(vertical:8),
            child:Divider(),
          ),
          _item(
            context,
            icon:Icons.people_alt_rounded,
            title:strings.t('customers'),
            onTap:()=>_go(context,const PartyPage(type:PartyType.customer)),
          ),
          _item(
            context,
            icon:Icons.local_shipping_rounded,
            title:strings.t('suppliers'),
            onTap:()=>_go(context,const PartyPage(type:PartyType.supplier)),
          ),
          _item(
            context,
            icon:Icons.badge_rounded,
            title:'Salesmen',
            onTap:()=>_go(context,const SalesmenPage()),
          ),
          _item(
            context,
            icon:Icons.account_balance_wallet_rounded,
            title:'Loans / Credit',
            onTap:()=>_go(context,const LoansPage()),
          ),
          _item(
            context,
            icon:Icons.receipt_long_rounded,
            title:strings.t('expenses'),
            onTap:()=>_go(context,const ExpensesPage()),
          ),
          const Padding(
            padding:EdgeInsets.symmetric(vertical:8),
            child:Divider(),
          ),
          _item(
            context,
            icon:Icons.local_gas_station_rounded,
            title:strings.t('oil'),
            onTap:()=>_go(context,const FuelPage()),
          ),
          _item(
            context,
            icon:Icons.local_pharmacy_rounded,
            title:strings.t('pharmacy'),
            onTap:()=>_go(context,const PharmacyPage()),
          ),
          _item(
            context,
            icon:Icons.analytics_rounded,
            title:strings.t('reports'),
            onTap:()=>_go(context,const ReportsPage()),
          ),
          _item(
            context,
            icon:Icons.cloud_done_rounded,
            title:strings.t('cloud'),
            onTap:()=>_go(context,const CloudPage()),
          ),
        ],
      ),
    ),
  );

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected=false,
  })=>Padding(
    padding:const EdgeInsets.only(bottom:4),
    child:ListTile(
      selected:selected,
      selectedTileColor:Theme.of(context).colorScheme.primaryContainer,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
      leading:Icon(icon),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),
      trailing:const Icon(Icons.chevron_right_rounded,size:20),
      onTap:onTap,
    ),
  );
}
