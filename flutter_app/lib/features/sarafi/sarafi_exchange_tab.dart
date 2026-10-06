// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/database/sarafi_repository.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import 'sarafi_common.dart';

class SarafiExchangeTab extends StatefulWidget {
  final ValueNotifier<int> tick;
  const SarafiExchangeTab({required this.tick,super.key});

  @override
  State<SarafiExchangeTab> createState()=>_SarafiExchangeTabState();
}

class _SarafiExchangeTabState extends State<SarafiExchangeTab> {
  List<String> codes=const [];
  Map<String,FxRate> rates=const {};
  List<Map<String,Object?>> clients=const [];
  List<Map<String,Object?>> recent=const [];
  bool loading=true;

  String fromCur='USD';
  String toCur='AFN';
  String clientId='';
  final fromAmount=TextEditingController();
  final rate=TextEditingController();
  final note=TextEditingController();

  bool get canWrite=>LocalAuthService.instance.canSell;
  bool get canDelete=>LocalAuthService.instance.canDelete;

  @override
  void initState() {
    super.initState();
    widget.tick.addListener(load);
    load();
  }

  @override
  void dispose() {
    widget.tick.removeListener(load);
    fromAmount.dispose();
    rate.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final repo=SarafiRepository.instance;
    final c=await repo.currencies();
    final r=await repo.rates();
    final p=await repo.parties('client');
    final e=await repo.exchanges(limit:60);
    if(!mounted) return;
    setState(() {
      codes=[for(final x in c) x['code'].toString()];
      rates=r;
      clients=p;
      recent=e;
      if(!codes.contains(fromCur)&&codes.isNotEmpty) fromCur=codes.first;
      if(!codes.contains(toCur)&&codes.isNotEmpty) toCur=codes.first;
      loading=false;
    });
    if(rate.text.isEmpty) applySuggestion();
  }

  void applySuggestion() {
    final s=FxQuote.suggest(fromCur,toCur,rates);
    setState(()=>rate.text=s==null?'':s.toString());
  }

  double get receives {
    final a=fxParse(fromAmount.text)??0;
    final r=fxParse(rate.text)??0;
    return FxQuote.toAmount(from:fromCur,to:toCur,fromAmount:a,rate:r);
  }

  void swap() {
    setState(() {
      final t=fromCur;
      fromCur=toCur;
      toCur=t;
    });
    applySuggestion();
  }

  Future<void> save() async {
    if(!canWrite) return;
    final a=fxParse(fromAmount.text)??0;
    final r=fxParse(rate.text)??0;
    final out=receives;
    if(fromCur==toCur) {
      fxSnack(context,fxTr('Choose two different currencies.','دوه بېلابېل اسعار وټاکئ.'));
      return;
    }
    if(a<=0||r<=0||out<=0) {
      fxSnack(context,fxTr('Enter the amount and the rate.','مبلغ او نرخ داخل کړئ.'));
      return;
    }
    final ok=await fxConfirm(
      context,
      fxTr('Confirm exchange','د تبادلې تایید'),
      fxTr('Customer gives ${fxFmt(a)} $fromCur\nCustomer receives ${fxFmt(out)} $toCur\nRate: ${FxQuote.label(fromCur,toCur).replaceFirst('?',fxFmt(r))}','مشتري ورکوي ${fxFmt(a)} $fromCur\nمشتري اخلي ${fxFmt(out)} $toCur\nنرخ: ${FxQuote.label(fromCur,toCur).replaceFirst('?',fxFmt(r))}'),
      action:fxTr('Save','ثبت'),
    );
    if(!ok) return;
    try {
      await SarafiRepository.instance.saveExchange(
        date:DateTime.now(),
        partyId:clientId,
        fromCurrency:fromCur,
        fromAmount:a,
        toCurrency:toCur,
        toAmount:out,
        rate:r,
        note:note.text.trim(),
      );
      fromAmount.clear();
      note.clear();
      widget.tick.value++;
      fxSnack(context,fxTr('Exchange saved.','تبادله ثبت شوه.'));
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> remove(Map<String,Object?> x) async {
    if(!canDelete) return;
    final ok=await fxConfirm(
      context,
      fxTr('Delete exchange?','تبادله ړنګه شي؟'),
      fxTr('This removes the exchange and its cash movement. This cannot be undone.','دا تبادله او د هغې نغدي حرکت ړنګوي او بېرته نه راګرځي.'),
      action:fxTr('Delete','ړنګول'),
    );
    if(!ok) return;
    try {
      await SarafiRepository.instance.deleteExchange(x['id'].toString());
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Widget currencyDropdown(String label,String value,ValueChanged<String> onChanged) =>
    DropdownButtonFormField<String>(
      key:ValueKey('$label$value'),
      initialValue:codes.contains(value)?value:null,
      decoration:InputDecoration(labelText:label),
      items:[for(final c in codes) DropdownMenuItem(value:c,child:Text(c))],
      onChanged:(v) {
        if(v!=null) onChanged(v);
      },
    );

  @override
  Widget build(BuildContext context) {
    if(loading) return Center(child:CircularProgressIndicator());
    return ListView(
      padding:QamvioUi.pagePadding,
      children:[
        Text(fxTr('Currency exchange','د اسعارو تبادله'),style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
        SizedBox(height:10),
        if(canWrite)
          Card(
            child:Padding(
              padding:EdgeInsets.all(14),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Row(
                    children:[
                      Expanded(
                        child:currencyDropdown(fxTr('Customer gives','مشتري ورکوي'),fromCur,(v) {
                          setState(()=>fromCur=v);
                          applySuggestion();
                        }),
                      ),
                      IconButton(
                        tooltip:fxTr('Swap','بدلول'),
                        onPressed:swap,
                        icon:Icon(Icons.swap_horiz_rounded),
                      ),
                      Expanded(
                        child:currencyDropdown(fxTr('Customer receives','مشتري اخلي'),toCur,(v) {
                          setState(()=>toCur=v);
                          applySuggestion();
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height:10),
                  TextField(
                    controller:fromAmount,
                    onChanged:(_)=>setState(() {}),
                    keyboardType:TextInputType.numberWithOptions(decimal:true),
                    decoration:InputDecoration(labelText:'${fxTr('Amount customer gives','د مشتري ورکړی مبلغ')} ($fromCur)'),
                  ),
                  SizedBox(height:10),
                  TextField(
                    controller:rate,
                    onChanged:(_)=>setState(() {}),
                    keyboardType:TextInputType.numberWithOptions(decimal:true),
                    decoration:InputDecoration(
                      labelText:'${fxTr('Rate','نرخ')}: ${FxQuote.label(fromCur,toCur)}',
                      helperText:rates.isEmpty?fxTr('Set buy/sell rates in the Rates tab to get suggestions.','د وړاندیز لپاره په نرخونو برخه کې د اخیستلو/پلورلو نرخونه وټاکئ.'):null,
                    ),
                  ),
                  SizedBox(height:10),
                  Container(
                    width:double.infinity,
                    padding:EdgeInsets.all(14),
                    decoration:BoxDecoration(
                      color:Theme.of(context).colorScheme.primaryContainer,
                      borderRadius:BorderRadius.circular(14),
                    ),
                    child:Text(
                      '${fxTr('Customer receives','مشتري اخلي')}: ${fxFmt(receives)} $toCur',
                      style:TextStyle(fontSize:20,fontWeight:FontWeight.w900),
                    ),
                  ),
                  SizedBox(height:10),
                  DropdownButtonFormField<String>(
                    initialValue:clientId,
                    decoration:InputDecoration(labelText:fxTr('Customer (optional)','مشتري (اختیاري)')),
                    items:[
                      DropdownMenuItem(value:'',child:Text(fxTr('Walk-in customer','نغدي مشتری'))),
                      for(final c in clients) DropdownMenuItem(value:c['id'].toString(),child:Text(c['name'].toString())),
                    ],
                    onChanged:(v)=>clientId=v??'',
                  ),
                  SizedBox(height:10),
                  TextField(controller:note,decoration:InputDecoration(labelText:fxTr('Note (optional)','یادښت (اختیاري)'))),
                  SizedBox(height:12),
                  SizedBox(
                    width:double.infinity,
                    child:FilledButton.icon(
                      onPressed:save,
                      icon:Icon(Icons.currency_exchange_rounded),
                      label:Text(fxTr('Save exchange','تبادله ثبت کړئ')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height:14),
        Text(fxTr('Recent exchanges','وروستۍ تبادلې'),style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
        SizedBox(height:6),
        if(recent.isEmpty)
          Padding(padding:EdgeInsets.all(20),child:Center(child:Text(fxTr('No exchanges yet.','تر اوسه تبادله نشته.')))),
        for(final x in recent)
          Card(
            child:ListTile(
              title:Text('${fxFmt(x['from_amount'] as num)} ${x['from_currency']}  →  ${fxFmt(x['to_amount'] as num)} ${x['to_currency']}'),
              subtitle:Text(
                '${x['business_date']}  •  ${fxTr('rate','نرخ')} ${fxFmt(x['rate'] as num)}'
                '${x['party_name']==null?'':'  •  ${x['party_name']}'}',
              ),
              trailing:canDelete
                ?IconButton(
                    onPressed:()=>remove(x),
                    icon:Icon(Icons.delete_outline_rounded),
                  )
                :null,
            ),
          ),
      ],
    );
  }
}
