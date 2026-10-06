// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/database/sarafi_repository.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import 'sarafi_common.dart';

class SarafiRatesTab extends StatefulWidget {
  final ValueNotifier<int> tick;
  const SarafiRatesTab({required this.tick,super.key});

  @override
  State<SarafiRatesTab> createState()=>_SarafiRatesTabState();
}

class _SarafiRatesTabState extends State<SarafiRatesTab> {
  List<Map<String,Object?>> currencies=const [];
  Map<String,FxRate> rates=const {};
  bool loading=true;

  bool get canEdit=>LocalAuthService.instance.canEdit;

  @override
  void initState() {
    super.initState();
    widget.tick.addListener(load);
    load();
  }

  @override
  void dispose() {
    widget.tick.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final c=await SarafiRepository.instance.currencies(onlyActive:false);
    final r=await SarafiRepository.instance.rates();
    if(!mounted) return;
    setState(() {
      currencies=c;
      rates=r;
      loading=false;
    });
  }

  Future<void> editRate(String code) async {
    if(!canEdit) return;
    final old=rates[code];
    final buy=TextEditingController(text:old==null||old.buy==0?'':old.buy.toString());
    final sell=TextEditingController(text:old==null||old.sell==0?'':old.sell.toString());
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('$code rate (AFN per 1 $code)'),
        content:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            TextField(
              controller:buy,
              keyboardType:TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:'We BUY at (customer gives $code)'),
            ),
            SizedBox(height:10),
            TextField(
              controller:sell,
              keyboardType:TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:'We SELL at (customer receives $code)'),
            ),
          ],
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save')),
        ],
      ),
    );
    final b=fxParse(buy.text)??0;
    final s=fxParse(sell.text)??0;
    buy.dispose();
    sell.dispose();
    if(ok!=true) return;
    try {
      await SarafiRepository.instance.setRate(code,b,s);
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> addCurrency() async {
    if(!canEdit) return;
    final code=TextEditingController();
    final name=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text('Add currency'),
        content:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            TextField(
              controller:code,
              textCapitalization:TextCapitalization.characters,
              decoration:InputDecoration(labelText:'Code (for example GBP)'),
            ),
            SizedBox(height:10),
            TextField(controller:name,decoration:InputDecoration(labelText:'Name')),
          ],
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Add')),
        ],
      ),
    );
    final c=code.text;
    final n=name.text;
    code.dispose();
    name.dispose();
    if(ok!=true) return;
    try {
      await SarafiRepository.instance.saveCurrency(code:c,name:n,symbol:c.trim().toUpperCase());
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> toggle(Map<String,Object?> row) async {
    if(!canEdit) return;
    final active=(row['active'] as num?)==1;
    try {
      await SarafiRepository.instance.saveCurrency(
        code:row['code'].toString(),
        name:row['name'].toString(),
        symbol:row['symbol']?.toString(),
        active:!active,
      );
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Center(child:CircularProgressIndicator());
    return Scaffold(
      floatingActionButton:canEdit
        ?FloatingActionButton.extended(
            onPressed:addCurrency,
            icon:Icon(Icons.add),
            label:Text('Currency'),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text('Exchange rates',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:4),
          Text('Rates are AFN for 1 unit of the currency. Buy = what you pay a customer who gives you the currency. Sell = what you charge a customer who takes it.'),
          SizedBox(height:12),
          for(final c in currencies)
            Card(
              child:ListTile(
                title:Text('${c['code']}  ${c['name']}'),
                subtitle:Text(
                  c['code']==SarafiSchema.baseCurrency
                    ?'Base currency'
                    :(rates[c['code']]==null
                        ?'No rate yet. Tap to set.'
                        :'Buy ${fxFmt(rates[c['code']]!.buy)}   Sell ${fxFmt(rates[c['code']]!.sell)}'),
                ),
                trailing:c['code']==SarafiSchema.baseCurrency
                  ?null
                  :Switch(
                      value:(c['active'] as num?)==1,
                      onChanged:canEdit?(_)=>toggle(c):null,
                    ),
                onTap:c['code']==SarafiSchema.baseCurrency?null:()=>editRate(c['code'].toString()),
              ),
            ),
        ],
      ),
    );
  }
}
