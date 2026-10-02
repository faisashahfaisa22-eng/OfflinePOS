import 'package:flutter/material.dart';

import '../../core/security/local_auth_service.dart';
import '../../core/security/permissions.dart';
import '../fuel/fuel_page.dart';
import '../parties/party_page.dart';
import '../products/products_page.dart';
import '../sales/sales_page.dart';
import '../salesmen/salesmen_page.dart';

/// Landing page for Cashier / Salesman users (v15 opens these roles on the sales invoice).
class RoleHomePage extends StatelessWidget {
  const RoleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user=LocalAuthService.instance.current;
    final items=<(AppPage,IconData,String,Widget)>[
      (AppPage.sales,Icons.receipt_long_rounded,'Sales invoice',const SalesPage()),
      (AppPage.fuel,Icons.local_gas_station_rounded,'Fuel pump',const FuelPage()),
      (AppPage.products,Icons.inventory_2_rounded,'Stock',const ProductsPage()),
      (AppPage.customers,Icons.people_rounded,'Customers',const PartyPage(type:PartyType.customer)),
      (AppPage.salesmen,Icons.badge_rounded,'Salesman statement',const SalesmenPage()),
    ];
    return Scaffold(
      appBar:AppBar(
        title:Text('QAMVIO • ${user?.role.label ?? ''}'),
        actions:[
          IconButton(
            tooltip:'Sign out',
            icon:const Icon(Icons.logout_rounded),
            onPressed:()=>LocalAuthService.instance.logout(),
          ),
        ],
      ),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          for(final it in items.where((e)=>Permissions.canOpen(e.$1)))
            Card(
              child:ListTile(
                leading:Icon(it.$2),
                title:Text(it.$3,style:const TextStyle(fontWeight:FontWeight.w700)),
                trailing:const Icon(Icons.chevron_right_rounded),
                onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>it.$4)),
              ),
            ),
        ],
      ),
    );
  }
}
