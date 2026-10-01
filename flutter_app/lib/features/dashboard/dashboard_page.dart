import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../products/products_page.dart';
import '../sales/sales_page.dart';
import '../parties/party_page.dart';
import '../expenses/expenses_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, num>> totals;
  void reload() => setState(() => totals = AppDatabase.instance.dashboardTotals());
  @override
  void initState() { super.initState(); totals = AppDatabase.instance.dashboardTotals(); }

  @override
  Widget build(BuildContext context) {
    final lc=LanguageController.instance;
    return ListenableBuilder(listenable:lc,builder:(context,_){
      final s=lc.strings;
      return Scaffold(
        appBar: AppBar(
          title: const Text('QAMVIO POS'),
          actions:[PopupMenuButton<AppLanguage>(
            tooltip:s.t('language'),
            icon:const Icon(Icons.language),
            onSelected:lc.setLanguage,
            itemBuilder:(_)=>const[
              PopupMenuItem(value:AppLanguage.english,child:Text('English')),
              PopupMenuItem(value:AppLanguage.pashto,child:Text('پښتو')),
              PopupMenuItem(value:AppLanguage.dari,child:Text('دری')),
              PopupMenuItem(value:AppLanguage.urdu,child:Text('اردو')),
            ],
          )],
        ),
        drawer: QamvioDrawer(onReturn: reload, strings:s),
        body: FutureBuilder<Map<String, num>>(
          future: totals,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const {'sales':0,'expenses':0,'products':0,'customers':0,'due':0};
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(s.t('businessDashboard'), style: const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
                  const SizedBox(height:4),
                  Text(s.t('offlineFirst')),
                  const SizedBox(height:16),
                  Wrap(spacing:12,runSpacing:12,children:[
                    MetricCard(s.t('sales'),data['sales']??0,Icons.point_of_sale),
                    MetricCard(s.t('expenses'),data['expenses']??0,Icons.receipt_long),
                    MetricCard(s.t('products'),data['products']??0,Icons.inventory_2),
                    MetricCard(s.t('customers'),data['customers']??0,Icons.people),
                    MetricCard(s.t('due'),data['due']??0,Icons.account_balance_wallet),
                  ]),
                  const SizedBox(height:18),
                  Card(child:ListTile(
                    leading:const Icon(Icons.storage),
                    title:const Text('SQLite Offline Database'),
                    subtitle:Text(s.t('offlineFirst')),
                    trailing:const Icon(Icons.check_circle),
                  )),
                  Card(child:ListTile(
                    leading:const Icon(Icons.inventory_2),
                    title:Text(s.t('inventory')),
                    trailing:const Icon(Icons.chevron_right),
                    onTap:() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProductsPage()));reload();},
                  )),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

class MetricCard extends StatelessWidget {
  final String label; final num value; final IconData icon;
  const MetricCard(this.label,this.value,this.icon,{super.key});
  @override Widget build(BuildContext context)=>SizedBox(width:165,child:Card(child:Padding(
    padding:const EdgeInsets.all(16),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon),const SizedBox(height:12),Text(label),const SizedBox(height:4),
      Text('$value',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    ]),
  )));
}

class QamvioDrawer extends StatelessWidget {
  final VoidCallback onReturn; final AppStrings strings;
  const QamvioDrawer({required this.onReturn,required this.strings,super.key});
  @override Widget build(BuildContext context)=>Drawer(child:ListView(children:[
    const DrawerHeader(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.end,children:[
      Text('QAMVIO POS',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
      Text('Flutter • SQLite'),
    ])),
    ListTile(leading:const Icon(Icons.dashboard),title:Text(strings.t('dashboard'))),
    ListTile(leading:const Icon(Icons.inventory_2),title:Text(strings.t('inventory')),onTap:()async{
      Navigator.pop(context);await Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProductsPage()));onReturn();
    }),
    const Divider(),
    ListTile(leading:const Icon(Icons.point_of_sale),title:Text(strings.t('salesInvoice')),onTap:()async{Navigator.pop(context);await Navigator.push(context,MaterialPageRoute(builder:(_)=>const SalesPage()));onReturn();}),
    ListTile(leading:const Icon(Icons.people),title:Text(strings.t('customers')),onTap:()async{Navigator.pop(context);await Navigator.push(context,MaterialPageRoute(builder:(_)=>const PartyPage(type:PartyType.customer)));onReturn();}),
    ListTile(leading:const Icon(Icons.local_shipping),title:Text(strings.t('suppliers')),onTap:()async{Navigator.pop(context);await Navigator.push(context,MaterialPageRoute(builder:(_)=>const PartyPage(type:PartyType.supplier)));onReturn();}),
    ListTile(leading:const Icon(Icons.receipt_long),title:Text(strings.t('expenses')),onTap:()async{Navigator.pop(context);await Navigator.push(context,MaterialPageRoute(builder:(_)=>const ExpensesPage()));onReturn();}),
    ListTile(leading:const Icon(Icons.local_gas_station),title:Text(strings.t('oil'))),
    ListTile(leading:const Icon(Icons.local_pharmacy),title:Text(strings.t('pharmacy'))),
    ListTile(leading:const Icon(Icons.bar_chart),title:Text(strings.t('reports'))),
    ListTile(leading:const Icon(Icons.cloud),title:Text(strings.t('cloud'))),
  ]));
}
