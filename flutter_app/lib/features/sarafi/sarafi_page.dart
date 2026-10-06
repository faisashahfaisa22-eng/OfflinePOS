// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import 'sarafi_accounts_tab.dart';
import 'sarafi_common.dart';
import 'sarafi_exchange_tab.dart';
import 'sarafi_hawala_tab.dart';
import 'sarafi_rates_tab.dart';
import 'sarafi_report_tab.dart';

/// Sarafi (money exchange + hawala) home. Every tab shares [tick]; a tab that
/// changes data increments it so the others reload.
class SarafiPage extends StatefulWidget {
  const SarafiPage({super.key});

  @override
  State<SarafiPage> createState()=>_SarafiPageState();
}

class _SarafiPageState extends State<SarafiPage> {
  final ValueNotifier<int> tick=ValueNotifier<int>(0);

  @override
  void dispose() {
    tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>DefaultTabController(
    length:5,
    child:Scaffold(
      appBar:AppBar(
        title:Text(fxTr('Sarafi','صرافي',dari:'صرافی',urdu:'صرافی')),
        bottom:TabBar(
          isScrollable:true,
          tabs:[
            Tab(text:fxTr('Exchange','تبادله',dari:'تبدیل ارز',urdu:'تبادلہ')),
            Tab(text:fxTr('Hawala','حواله',dari:'حواله',urdu:'حوالہ')),
            Tab(text:fxTr('Accounts','حسابونه',dari:'حساب‌ها',urdu:'اکاؤنٹس')),
            Tab(text:fxTr('Rates','نرخونه',dari:'نرخ‌ها',urdu:'ریٹس')),
            Tab(text:fxTr('Daily Report','ورځنی راپور',dari:'گزارش روزانه',urdu:'روزانہ رپورٹ')),
          ],
        ),
      ),
      body:TabBarView(
        children:[
          SarafiExchangeTab(tick:tick),
          SarafiHawalaTab(tick:tick),
          SarafiAccountsTab(tick:tick),
          SarafiRatesTab(tick:tick),
          SarafiReportTab(tick:tick),
        ],
      ),
    ),
  );
}
