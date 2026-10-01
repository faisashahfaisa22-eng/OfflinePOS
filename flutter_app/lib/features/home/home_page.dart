import 'package:flutter/material.dart';
import '../purchases/purchases_page.dart';
import '../accounts/accounts_page.dart';
import '../loans/loans_page.dart';
import '../reports/reports_page.dart';
import '../oil/oil_pump_page.dart';
import '../pharmacy/pharmacy_page.dart';
import '../settings/settings_page.dart';
import '../printing/invoice_preview_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = <Map<String, dynamic>>[
      {'title':'Purchases','icon':Icons.shopping_cart_checkout,'page':const PurchasesPage()},
      {'title':'Accounts / Cash','icon':Icons.account_balance_wallet,'page':const AccountsPage()},
      {'title':'Loans','icon':Icons.handshake,'page':const LoansPage()},
      {'title':'Reports','icon':Icons.analytics,'page':const ReportsPage()},
      {'title':'Oil Pump','icon':Icons.local_gas_station,'page':const OilPumpPage()},
      {'title':'Pharmacy','icon':Icons.medication,'page':const PharmacyPage()},
      {'title':'Invoice / Printing','icon':Icons.receipt_long,'page':const InvoicePreviewPage()},
      {'title':'Settings / Business','icon':Icons.settings,'page':const SettingsPage()},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('QAMVIO POS • Flutter')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25),
        itemCount: modules.length,
        itemBuilder: (context, i) {
          final m=modules[i];
          return Card(child:InkWell(
            borderRadius:BorderRadius.circular(12),
            onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>m['page'] as Widget)),
            child:Padding(padding:const EdgeInsets.all(16),child:Column(
              mainAxisAlignment:MainAxisAlignment.center,
              children:[Icon(m['icon'] as IconData,size:38),const SizedBox(height:10),
                Text(m['title'] as String,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700))]
            )),
          ));
        },
      ),
    );
  }
}
