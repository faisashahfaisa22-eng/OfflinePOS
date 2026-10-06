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
        title:Text(kind=='client'?fxTr('New customer account','نوی د مشتري حساب'):fxTr('New partner sarafi','نوی شریک صراف')),
        content:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              TextField(controller:name,decoration:InputDecoration(labelText:fxTr('Name','نوم'))),
              SizedBox(height:10),
              TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:fxTr('Phone','موبایل'))),
              SizedBox(height:10),
              TextField(controller:city,decoration:InputDecoration(labelText:fxTr('City','ښار'))),
            ],
          ),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(fxTr('Cancel','لغوه'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(fxTr('Save','ثبت'))),
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
    if(b==null||b.isEmpty) return fxTr('No balance','بیلانس نشته');
    final parts=<String>[];
    b.forEach((cur,v) {
      if(v>0) {
        parts.add(kind=='client'?'${fxTr('We hold','موږ سره شته')} ${fxFmt(v)} $cur':'${fxTr('We owe','موږ پوروړي یو')} ${fxFmt(v)} $cur');
      } else if(v<0) {
        parts.add('${fxTr('Owes us','موږ ته پوروړی دی')} ${fxFmt(-v)} $cur');
      }
    });
    return parts.isEmpty?fxTr('No balance','بیلانس نشته'):parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Center(child:CircularProgressIndicator());
    return Scaffold(
      floatingActionButton:canWrite
        ?FloatingActionButton.extended(
            onPressed:addParty,
            icon:Icon(Icons.person_add_alt_1_rounded),
            label:Text(kind=='client'?fxTr('Customer','مشتري'):fxTr('Partner','شریک')),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text(fxTr('Accounts','حسابونه'),style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:10),
          SegmentedButton<String>(
            segments:[
              ButtonSegment(value:'client',label:Text(fxTr('Customers','مشتریان')),icon:Icon(Icons.groups_rounded)),
              ButtonSegment(value:'partner',label:Text(fxTr('Partners','شریک صرافان')),icon:Icon(Icons.handshake_rounded)),
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
              ?fxTr('Customers who keep money with you in one or more currencies.','هغه مشتریان چې په یو یا څو اسعارو کې پیسې درسره ساتي.')
              :fxTr('Other sarafs you send hawala to or receive hawala from. Settle your balance with them here.','هغه صرافان چې حوالې ورته لېږئ یا ترې اخلئ؛ حساب یې دلته تصفیه کړئ.'),
            style:TextStyle(fontSize:12),
          ),
          SizedBox(height:10),
          if(parties.isEmpty)
            Padding(padding:EdgeInsets.all(24),child:Center(child:Text(fxTr('Nothing here yet.','تر اوسه څه نشته.')))),
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
      ?(incoming?fxTr('Deposit (customer gives you money)','جمع (مشتري تاسې ته پیسې درکوي)'):fxTr('Withdraw (you give customer money)','ایستل (تاسې مشتري ته پیسې ورکوئ)'))
      :(incoming?fxTr('Partner pays you','شریک تاسې ته پیسې درکوي'):fxTr('You pay partner','تاسې شریک ته پیسې ورکوئ'));
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
                decoration:InputDecoration(labelText:fxTr('Currency','اسعار')),
                items:[for(final c in codes) DropdownMenuItem(value:c,child:Text(c))],
                onChanged:(v)=>currency=v??currency,
              ),
              SizedBox(height:10),
              TextField(
                controller:amount,
                keyboardType:TextInputType.numberWithOptions(decimal:true),
                decoration:InputDecoration(labelText:fxTr('Amount','مبلغ')),
              ),
              SizedBox(height:10),
              TextField(controller:note,decoration:InputDecoration(labelText:fxTr('Note','یادښت'))),
            ],
          ),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(fxTr('Cancel','لغوه'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(fxTr('Save','ثبت'))),
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
          fxTr('More than the balance','له بیلانس څخه زیات'),
          fxTr('The customer has ${fxFmt(have)} $currency with you. This withdrawal makes the customer owe you ${fxFmt(a-have)} $currency. Continue?','مشتري له تاسې سره ${fxFmt(have)} $currency لري. په دې ایستلو سره مشتري ${fxFmt(a-have)} $currency درباندې پوروړی کېږي. دوام ورکړو؟'),
          action:fxTr('Continue','دوام'),
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
      fxSnack(context,fxTr('Cancel the hawala from the Hawala tab instead.','حواله د حوالو له برخې څخه لغوه کړئ.'));
      return;
    }
    final ok=await fxConfirm(
      context,
      fxTr('Delete this entry?','دا ثبت ړنګ شي؟'),
      fxTr('The entry and its cash movement are removed.','ثبت او د هغه نغدي حرکت به ړنګ شي.'),
      action:fxTr('Delete','ړنګول'),
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
      case 'deposit': return fxTr('Deposit','جمع');
      case 'withdraw': return fxTr('Withdrawal','ایستل');
      case 'settle_in': return fxTr('Partner paid us','شریک موږ ته راکړل');
      case 'settle_out': return fxTr('We paid partner','موږ شریک ته ورکړل');
      case 'hawala_out': return fxTr('Hawala sent','حواله ولېږل شوه');
      case 'hawala_in': return fxTr('Hawala paid out','حواله ورکړل شوه');
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
                      Text(fxTr('Balance','بیلانس'),style:TextStyle(fontWeight:FontWeight.w800)),
                      SizedBox(height:6),
                      if(balances.values.every((v)=>v.abs()<0.000001))
                        Text(fxTr('No balance','بیلانس نشته')),
                      for(final e in balances.entries)
                        if(e.value.abs()>=0.000001)
                          Text(
                            e.value>0
                              ?'${isClient?fxTr('We hold','موږ سره شته'):fxTr('We owe','موږ پوروړي یو')} ${fxFmt(e.value)} ${e.key}'
                              :'${fxTr('Owes us','موږ ته پوروړی دی')} ${fxFmt(-e.value)} ${e.key}',
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
                        label:Text(isClient?fxTr('Deposit','جمع'):fxTr('They pay us','هغوی موږ ته راکوي')),
                      ),
                    ),
                    SizedBox(width:10),
                    Expanded(
                      child:OutlinedButton.icon(
                        onPressed:()=>move(false),
                        icon:Icon(Icons.north_east_rounded),
                        label:Text(isClient?fxTr('Withdraw','ایستل'):fxTr('We pay them','موږ هغوی ته ورکوو')),
                      ),
                    ),
                  ],
                ),
              SizedBox(height:14),
              Text(fxTr('Statement','صورت حساب'),style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
              if(ledger.isEmpty)
                Padding(padding:EdgeInsets.all(24),child:Center(child:Text(fxTr('No entries yet.','تر اوسه ثبت نشته.')))),
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
