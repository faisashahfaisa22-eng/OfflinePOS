// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/database/sarafi_repository.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import 'sarafi_common.dart';

class SarafiReportTab extends StatefulWidget {
  final ValueNotifier<int> tick;
  const SarafiReportTab({required this.tick,super.key});

  @override
  State<SarafiReportTab> createState()=>_SarafiReportTabState();
}

class _SarafiReportTabState extends State<SarafiReportTab> {
  DateTime date=DateTime.now();
  SarafiDayReport? report;
  Map<String,double> cashNow={};
  List<String> codes=const [];
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
    final repo=SarafiRepository.instance;
    final r=await repo.dailyReport(date);
    final c=await repo.cashBalances();
    final cur=await repo.currencies();
    if(!mounted) return;
    setState(() {
      report=r;
      cashNow=c;
      codes=[for(final x in cur) x['code'].toString()];
      loading=false;
    });
  }

  Future<void> pickDate() async {
    final d=await showDatePicker(
      context:context,
      firstDate:DateTime(2000),
      lastDate:DateTime(2100),
      initialDate:date,
    );
    if(d!=null) {
      date=d;
      await load();
    }
  }

  void shift(int days) {
    date=date.add(Duration(days:days));
    load();
  }

  Future<void> adjust() async {
    if(!canEdit||codes.isEmpty) return;
    var currency=codes.contains('AFN')?'AFN':codes.first;
    var kind='opening';
    final amount=TextEditingController();
    final note=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:Text('Cash adjustment'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                SegmentedButton<String>(
                  segments:[
                    ButtonSegment(value:'opening',label:Text('Opening cash')),
                    ButtonSegment(value:'adjust',label:Text('Correction')),
                  ],
                  selected:{kind},
                  onSelectionChanged:(s)=>setLocal(()=>kind=s.first),
                ),
                SizedBox(height:6),
                Text(
                  kind=='opening'
                    ?'Cash you already have in the box. Enter a positive amount.'
                    :'Counting difference. Use + for extra cash found, - for missing cash.',
                  style:TextStyle(fontSize:12),
                ),
                SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:currency,
                  decoration:InputDecoration(labelText:'Currency'),
                  items:[for(final c in codes) DropdownMenuItem(value:c,child:Text(c))],
                  onChanged:(v)=>currency=v??currency,
                ),
                SizedBox(height:10),
                TextField(
                  controller:amount,
                  keyboardType:TextInputType.numberWithOptions(decimal:true,signed:true),
                  decoration:InputDecoration(labelText:'Amount'),
                ),
                SizedBox(height:10),
                TextField(controller:note,decoration:InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save')),
          ],
        ),
      ),
    );
    final a=fxParse(amount.text)??0;
    final nt=note.text.trim();
    amount.dispose();
    note.dispose();
    if(ok!=true) return;
    if(kind=='opening'&&a<=0) {
      fxSnack(context,'Opening cash must be greater than zero.');
      return;
    }
    try {
      await SarafiRepository.instance.saveCashAdjustment(
        date:date,
        currency:currency,
        amount:a,
        kind:kind,
        note:nt,
      );
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r=report;
    if(loading||r==null) return Center(child:CircularProgressIndicator());
    return Scaffold(
      floatingActionButton:canEdit
        ?FloatingActionButton.extended(
            onPressed:adjust,
            icon:Icon(Icons.account_balance_wallet_rounded),
            label:Text('Cash adjust'),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text('Daily report',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:8),
          Row(
            children:[
              IconButton(onPressed:()=>shift(-1),icon:Icon(Icons.chevron_left_rounded)),
              Expanded(
                child:OutlinedButton.icon(
                  onPressed:pickDate,
                  icon:Icon(Icons.event_rounded),
                  label:Text(r.day),
                ),
              ),
              IconButton(onPressed:()=>shift(1),icon:Icon(Icons.chevron_right_rounded)),
            ],
          ),
          SizedBox(height:10),
          Text('Cash box by currency',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
          if(r.cash.isEmpty)
            Padding(padding:EdgeInsets.all(20),child:Center(child:Text('No cash movement up to this day.'))),
          for(final c in r.cash)
            Card(
              child:Padding(
                padding:EdgeInsets.all(12),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(c.currency,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
                    SizedBox(height:6),
                    Text('Opening:  ${fxFmt(c.opening)}'),
                    Text('Money in:  ${fxFmt(c.inflow)}'),
                    Text('Money out:  ${fxFmt(-c.outflow)}'),
                    Divider(),
                    Text('Closing:  ${fxFmt(c.closing)}',style:TextStyle(fontWeight:FontWeight.w900)),
                  ],
                ),
              ),
            ),
          SizedBox(height:10),
          Text('Profit and commission',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
          Card(
            child:Padding(
              padding:EdgeInsets.all(12),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('Exchanges: ${r.exchangeCount}'),
                  Text(
                    'Estimated exchange profit: ${fxFmt(r.exchangeProfitAfn)} ${SarafiSchema.baseCurrency}',
                    style:TextStyle(fontWeight:FontWeight.w800),
                  ),
                  Text(
                    'Estimated against the mid rate (average of buy and sell). Set today\'s rates in the Rates tab first.',
                    style:TextStyle(fontSize:12),
                  ),
                  SizedBox(height:8),
                  Text('Hawala: ${r.hawalaCount}'),
                  if(r.commissions.isEmpty) Text('Commission: 0'),
                  for(final e in r.commissions.entries)
                    Text('Commission ${e.key}: ${fxFmt(e.value)}',style:TextStyle(fontWeight:FontWeight.w800)),
                ],
              ),
            ),
          ),
          SizedBox(height:10),
          Text('Cash in the box now (all days)',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
          Card(
            child:Padding(
              padding:EdgeInsets.all(12),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  if(cashNow.isEmpty) Text('Empty'),
                  for(final e in cashNow.entries)
                    Text('${e.key}: ${fxFmt(e.value)}',style:TextStyle(fontWeight:FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
