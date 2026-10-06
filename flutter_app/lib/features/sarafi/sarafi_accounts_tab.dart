// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/database/sarafi_repository.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import 'sarafi_common.dart';

class SarafiAccountsTab extends StatefulWidget {
  final ValueNotifier<int> tick;
  const SarafiAccountsTab({required this.tick,super.key});

  @override
  State<SarafiAccountsTab> createState()=>_SarafiAccountsTabState();
}

class _SarafiAccountsTabState extends State<SarafiAccountsTab> {
  String kind='client';
  List<Map<String,Object?>> parties=const [];
  Map<String,Map<String,double>> balances={};
  bool loading=true;

  bool get canWrite=>LocalAuthService.instance.canSell;

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
    final p=await repo.parties(kind,onlyActive:false);
    final b=await repo.balances(kind);
    final map=<String,Map<String,double>>{};
    for(final r in b) {
      final id=r['party_id'].toString();
      map.putIfAbsent(id,()=><String,double>{})[r['currency'].toString()]=(r['balance'] as num).toDouble();
    }
    if(!mounted) return;
    setState(() {
      parties=p;
      balances=map;
      loading=false;
    });
  }

  Future<void> addParty() async {
    if(!canWrite) return;
    final name=TextEditingController();
    final phone=TextEditingController();
    final city=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(kind=='client'?'New customer account':'New partner sarafi'),
        content:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              TextField(controller:name,decoration:InputDecoration(labelText:'Name')),
              SizedBox(height:10),
              TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:'Phone')),
              SizedBox(height:10),
              TextField(controller:city,decoration:InputDecoration(labelText:'City')),
            ],
          ),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save')),
        ],
      ),
    );
    final n=name.text;
    final ph=phone.text;
    final ct=city.text;
    name.dispose();
    phone.dispose();
    city.dispose();
    if(ok!=true) return;
    try {
      await SarafiRepository.instance.saveParty(
        id:SarafiRepository.newId('pt'),
        kind:kind,
        name:n,
        phone:ph,
        city:ct,
      );
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  String balanceText(String id) {
    final b=balances[id];
    if(b==null||b.isEmpty) return 'No balance';
    final parts=<String>[];
    b.forEach((cur,v) {
      if(v>0) {
        parts.add(kind=='client'?'We hold ${fxFmt(v)} $cur':'We owe ${fxFmt(v)} $cur');
      } else if(v<0) {
        parts.add('Owes us ${fxFmt(-v)} $cur');
      }
    });
    return parts.isEmpty?'No balance':parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Center(child:CircularProgressIndicator());
    return Scaffold(
      floatingActionButton:canWrite
        ?FloatingActionButton.extended(
            onPressed:addParty,
            icon:Icon(Icons.person_add_alt_1_rounded),
            label:Text(kind=='client'?'Customer':'Partner'),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text('Accounts',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:10),
          SegmentedButton<String>(
            segments:[
              ButtonSegment(value:'client',label:Text('Customers'),icon:Icon(Icons.groups_rounded)),
              ButtonSegment(value:'partner',label:Text('Partners'),icon:Icon(Icons.handshake_rounded)),
            ],
            selected:{kind},
            onSelectionChanged:(s) {
              kind=s.first;
              load();
            },
          ),
          SizedBox(height:6),
          Text(
            kind=='client'
              ?'Customers who keep money with you in one or more currencies.'
              :'Other sarafs you send hawala to or receive hawala from. Settle your balance with them here.',
            style:TextStyle(fontSize:12),
          ),
          SizedBox(height:10),
          if(parties.isEmpty)
            Padding(padding:EdgeInsets.all(24),child:Center(child:Text('Nothing here yet.'))),
          for(final p in parties)
            Card(
              child:ListTile(
                title:Text(p['name'].toString()),
                subtitle:Text(
                  '${p['city']==null||p['city'].toString().isEmpty?'':'${p['city']}  •  '}${balanceText(p['id'].toString())}',
                ),
                trailing:Icon(Icons.chevron_right_rounded),
                onTap:() async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:(_)=>SarafiPartyPage(party:p,tick:widget.tick),
                    ),
                  );
                  widget.tick.value++;
                },
              ),
            ),
        ],
      ),
    );
  }
}

class SarafiPartyPage extends StatefulWidget {
  final Map<String,Object?> party;
  final ValueNotifier<int> tick;
  const SarafiPartyPage({required this.party,required this.tick,super.key});

  @override
  State<SarafiPartyPage> createState()=>_SarafiPartyPageState();
}

class _SarafiPartyPageState extends State<SarafiPartyPage> {
  Map<String,double> balances={};
  List<Map<String,Object?>> ledger=const [];
  List<String> codes=const [];
  bool loading=true;

  bool get isClient=>widget.party['kind']=='client';
  bool get canWrite=>LocalAuthService.instance.canSell;
  bool get canDelete=>LocalAuthService.instance.canDelete;
  String get id=>widget.party['id'].toString();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final repo=SarafiRepository.instance;
    final b=await repo.partyBalances(id);
    final l=await repo.ledger(id);
    final c=await repo.currencies();
    if(!mounted) return;
    setState(() {
      balances=b;
      ledger=l;
      codes=[for(final x in c) x['code'].toString()];
      loading=false;
    });
  }

  /// [incoming] = the party gives us money.
  Future<void> move(bool incoming) async {
    if(!canWrite||codes.isEmpty) return;
    var currency=codes.contains('AFN')?'AFN':codes.first;
    final amount=TextEditingController();
    final note=TextEditingController();
    final title=isClient
      ?(incoming?'Deposit (customer gives you money)':'Withdraw (you give customer money)')
      :(incoming?'Partner pays you':'You pay partner');
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(title),
        content:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              DropdownButtonFormField<String>(
                initialValue:currency,
                decoration:InputDecoration(labelText:'Currency'),
                items:[for(final c in codes) DropdownMenuItem(value:c,child:Text(c))],
                onChanged:(v)=>currency=v??currency,
              ),
              SizedBox(height:10),
              TextField(
                controller:amount,
                keyboardType:TextInputType.numberWithOptions(decimal:true),
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
    );
    final a=fxParse(amount.text)??0;
    final nt=note.text.trim();
    amount.dispose();
    note.dispose();
    if(ok!=true) return;
    if(!incoming&&isClient) {
      final have=balances[currency]??0;
      if(a>have+0.000001) {
        final go=await fxConfirm(
          context,
          'More than the balance',
          'The customer has ${fxFmt(have)} $currency with you. This withdrawal makes the customer owe you ${fxFmt(a-have)} $currency. Continue?',
          action:'Continue',
        );
        if(!go) return;
      }
    }
    try {
      await SarafiRepository.instance.saveMovement(
        date:DateTime.now(),
        partyId:id,
        currency:currency,
        amount:a,
        incoming:incoming,
        kind:isClient?(incoming?'deposit':'withdraw'):(incoming?'settle_in':'settle_out'),
        note:nt,
      );
      widget.tick.value++;
      await load();
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> removeRow(Map<String,Object?> row) async {
    if(!canDelete) return;
    final ref=row['ref_id']?.toString()??'';
    final kind=row['kind'].toString();
    if(kind.startsWith('hawala')||kind=='exchange') {
      fxSnack(context,'Cancel the hawala from the Hawala tab instead.');
      return;
    }
    final ok=await fxConfirm(
      context,
      'Delete this entry?',
      'The entry and its cash movement are removed.',
      action:'Delete',
    );
    if(!ok) return;
    try {
      await SarafiRepository.instance.deleteMovement(ref);
      widget.tick.value++;
      await load();
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  String kindLabel(String k) {
    switch(k) {
      case 'deposit': return 'Deposit';
      case 'withdraw': return 'Withdrawal';
      case 'settle_in': return 'Partner paid us';
      case 'settle_out': return 'We paid partner';
      case 'hawala_out': return 'Hawala sent';
      case 'hawala_in': return 'Hawala paid out';
      default: return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(title:Text(widget.party['name'].toString())),
      body:loading
        ?Center(child:CircularProgressIndicator())
        :ListView(
            padding:QamvioUi.pagePadding,
            children:[
              Card(
                child:Padding(
                  padding:EdgeInsets.all(14),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text('Balance',style:TextStyle(fontWeight:FontWeight.w800)),
                      SizedBox(height:6),
                      if(balances.values.every((v)=>v.abs()<0.000001))
                        Text('No balance'),
                      for(final e in balances.entries)
                        if(e.value.abs()>=0.000001)
                          Text(
                            e.value>0
                              ?'${isClient?'We hold':'We owe'} ${fxFmt(e.value)} ${e.key}'
                              :'Owes us ${fxFmt(-e.value)} ${e.key}',
                            style:TextStyle(fontSize:18,fontWeight:FontWeight.w900),
                          ),
                    ],
                  ),
                ),
              ),
              SizedBox(height:10),
              if(canWrite)
                Row(
                  children:[
                    Expanded(
                      child:FilledButton.icon(
                        onPressed:()=>move(true),
                        icon:Icon(Icons.south_west_rounded),
                        label:Text(isClient?'Deposit':'They pay us'),
                      ),
                    ),
                    SizedBox(width:10),
                    Expanded(
                      child:OutlinedButton.icon(
                        onPressed:()=>move(false),
                        icon:Icon(Icons.north_east_rounded),
                        label:Text(isClient?'Withdraw':'We pay them'),
                      ),
                    ),
                  ],
                ),
              SizedBox(height:14),
              Text('Statement',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
              if(ledger.isEmpty)
                Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No entries yet.'))),
              for(final r in ledger)
                Card(
                  child:ListTile(
                    title:Text('${kindLabel(r['kind'].toString())}   ${(r['amount'] as num)>0?'+':''}${fxFmt(r['amount'] as num)} ${r['currency']}'),
                    subtitle:Text('${r['business_date']}${r['note']==null||r['note'].toString().isEmpty?'':'  •  ${r['note']}'}'),
                    trailing:canDelete
                      ?IconButton(
                          onPressed:()=>removeRow(r),
                          icon:Icon(Icons.delete_outline_rounded),
                        )
                      :null,
                  ),
                ),
            ],
          ),
    );
  }
}
