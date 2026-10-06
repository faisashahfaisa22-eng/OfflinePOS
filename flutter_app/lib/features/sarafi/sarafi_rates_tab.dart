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
        title:Text('$code ${fxTr('rate','نرخ')} (AFN / 1 $code)'),
        content:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            TextField(
              controller:buy,
              keyboardType:TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:fxTr('We BUY at (customer gives $code)','موږ په دې نرخ اخلو (مشتري $code راکوي)')),
            ),
            SizedBox(height:10),
            TextField(
              controller:sell,
              keyboardType:TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:fxTr('We SELL at (customer receives $code)','موږ په دې نرخ پلورو (مشتري $code اخلي)')),
            ),
          ],
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(fxTr('Cancel','لغوه'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(fxTr('Save','ثبت'))),
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
        title:Text(fxTr('Add currency','اسعار اضافه کړئ')),
        content:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            TextField(
              controller:code,
              textCapitalization:TextCapitalization.characters,
              decoration:InputDecoration(labelText:fxTr('Code (for example GBP)','کوډ (لکه GBP)')),
            ),
            SizedBox(height:10),
            TextField(controller:name,decoration:InputDecoration(labelText:fxTr('Name','نوم'))),
          ],
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(fxTr('Cancel','لغوه'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(fxTr('Add','اضافه کول'))),
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
            label:Text(fxTr('Currency','اسعار')),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text(fxTr('Exchange rates','د اسعارو نرخونه'),style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:4),
          Text(fxTr('Rates are AFN for 1 unit of the currency. Buy = what you pay a customer who gives you the currency. Sell = what you charge a customer who takes it.','نرخ د هر اسعار د ۱ واحد په بدل کې افغانۍ دي. اخیستل = هغه نرخ چې له مشتري څخه اسعار اخلئ؛ پلورل = هغه نرخ چې مشتري ته اسعار ورکوئ.')),
          SizedBox(height:12),
          for(final c in currencies)
            Card(
              child:ListTile(
                title:Text('${c['code']}  ${c['name']}'),
                subtitle:Text(
                  c['code']==SarafiSchema.baseCurrency
                    ?fxTr('Base currency','اصلي اسعار')
                    :(rates[c['code']]==null
                        ?fxTr('No rate yet. Tap to set.','تر اوسه نرخ نشته؛ د ټاکلو لپاره یې کېکاږئ.')
                         :'${fxTr('Buy','اخیستل')} ${fxFmt(rates[c['code']]!.buy)}   ${fxTr('Sell','پلورل')} ${fxFmt(rates[c['code']]!.sell)}'),
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
