// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

import '../../core/database/sarafi_repository.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import 'sarafi_common.dart';

class SarafiHawalaTab extends StatefulWidget {
  final ValueNotifier<int> tick;
  const SarafiHawalaTab({required this.tick,super.key});

  @override
  State<SarafiHawalaTab> createState()=>_SarafiHawalaTabState();
}

class _SarafiHawalaTabState extends State<SarafiHawalaTab> {
  List<Map<String,Object?>> rows=const [];
  List<Map<String,Object?>> partners=const [];
  List<String> codes=const [];
  String filter='pending';
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
    final h=await repo.hawalas(status:filter=='all'?null:filter);
    final p=await repo.parties('partner');
    final c=await repo.currencies();
    if(!mounted) return;
    setState(() {
      rows=h;
      partners=p;
      codes=[for(final x in c) x['code'].toString()];
      loading=false;
    });
  }

  Future<void> create() async {
    if(!canWrite) return;
    if(partners.isEmpty) {
      fxSnack(context,'Add a partner first: Accounts tab, Partners.');
      return;
    }
    var direction='out';
    var partnerId=partners.first['id'].toString();
    var currency=codes.contains('USD')?'USD':codes.first;
    final sender=TextEditingController();
    final receiver=TextEditingController();
    final phone=TextEditingController();
    final city=TextEditingController();
    final amount=TextEditingController();
    final commission=TextEditingController();
    final note=TextEditingController();

    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:Text('New hawala'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                SegmentedButton<String>(
                  segments:[
                    ButtonSegment(value:'out',label:Text('We send')),
                    ButtonSegment(value:'in',label:Text('We pay out')),
                  ],
                  selected:{direction},
                  onSelectionChanged:(s)=>setLocal(()=>direction=s.first),
                ),
                SizedBox(height:6),
                Text(
                  direction=='out'
                    ?'Customer pays you here. Your partner pays the receiver there.'
                    :'Your partner sent this. You pay the receiver here when they come.',
                  style:TextStyle(fontSize:12),
                ),
                SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:partnerId,
                  decoration:InputDecoration(labelText:'Partner sarafi'),
                  items:[for(final p in partners) DropdownMenuItem(value:p['id'].toString(),child:Text('${p['name']}${p['city']==null||p['city'].toString().isEmpty?'':' (${p['city']})'}'))],
                  onChanged:(v)=>partnerId=v??partnerId,
                ),
                SizedBox(height:10),
                TextField(controller:sender,decoration:InputDecoration(labelText:'Sender name')),
                SizedBox(height:10),
                TextField(controller:receiver,decoration:InputDecoration(labelText:'Receiver name')),
                SizedBox(height:10),
                TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:'Receiver phone')),
                SizedBox(height:10),
                TextField(controller:city,decoration:InputDecoration(labelText:'City')),
                SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:currency,
                  decoration:InputDecoration(labelText:'Currency'),
                  items:[for(final c in codes) DropdownMenuItem(value:c,child:Text(c))],
                  onChanged:(v)=>currency=v??currency,
                ),
                SizedBox(height:10),
                TextField(controller:amount,keyboardType:TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Amount')),
                SizedBox(height:10),
                TextField(
                  controller:commission,
                  keyboardType:TextInputType.numberWithOptions(decimal:true),
                  decoration:InputDecoration(
                    labelText:'Commission (same currency)',
                    helperText:direction=='out'?'Customer pays amount + commission.':'Charged to the partner.',
                  ),
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
    final cm=fxParse(commission.text)??0;
    final s=sender.text;
    final r=receiver.text;
    final ph=phone.text;
    final ct=city.text;
    final nt=note.text;
    for(final c in [sender,receiver,phone,city,amount,commission,note]) {
      c.dispose();
    }
    if(ok!=true) return;
    try {
      await SarafiRepository.instance.createHawala(
        date:DateTime.now(),
        direction:direction,
        partnerId:partnerId,
        senderName:s,
        receiverName:r,
        receiverPhone:ph,
        city:ct,
        currency:currency,
        amount:a,
        commission:cm,
        note:nt,
      );
      widget.tick.value++;
      fxSnack(context,'Hawala saved.');
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> markPaid(Map<String,Object?> h) async {
    final isIn=h['direction']=='in';
    final ok=await fxConfirm(
      context,
      isIn?'Pay out this hawala?':'Mark as delivered?',
      isIn
        ?'You hand ${fxFmt(h['amount'] as num)} ${h['currency']} to ${h['receiver_name']??'the receiver'}. Cash goes down and the partner owes you.'
        :'The partner delivered the money to the receiver. No cash changes.',
      action:isIn?'Pay out':'Delivered',
    );
    if(!ok) return;
    try {
      await SarafiRepository.instance.markHawalaPaid(h['id'].toString());
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Future<void> cancel(Map<String,Object?> h) async {
    final ok=await fxConfirm(
      context,
      'Cancel hawala ${h['code']}?',
      'Everything this hawala posted (cash and partner account) is reversed.',
      action:'Cancel hawala',
    );
    if(!ok) return;
    try {
      await SarafiRepository.instance.cancelHawala(h['id'].toString());
      widget.tick.value++;
    } catch(e) {
      fxSnack(context,fxErr(e));
    }
  }

  Color statusColor(String s) {
    if(s=='paid') return QamvioUi.success;
    if(s=='cancelled') return QamvioUi.danger;
    return QamvioUi.warning;
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Center(child:CircularProgressIndicator());
    return Scaffold(
      floatingActionButton:canWrite
        ?FloatingActionButton.extended(
            onPressed:create,
            icon:Icon(Icons.add),
            label:Text('Hawala'),
          )
        :null,
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          Text('Hawala',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:10),
          SegmentedButton<String>(
            segments:[
              ButtonSegment(value:'pending',label:Text('Pending')),
              ButtonSegment(value:'paid',label:Text('Paid')),
              ButtonSegment(value:'cancelled',label:Text('Cancelled')),
              ButtonSegment(value:'all',label:Text('All')),
            ],
            selected:{filter},
            onSelectionChanged:(s) {
              filter=s.first;
              load();
            },
          ),
          SizedBox(height:10),
          if(rows.isEmpty)
            Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No hawala here.'))),
          for(final h in rows)
            Card(
              child:Padding(
                padding:EdgeInsets.all(12),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Row(
                      children:[
                        Expanded(
                          child:Text(
                            '${h['code']}  •  ${h['direction']=='out'?'We send':'We pay out'}',
                            style:TextStyle(fontWeight:FontWeight.w800),
                          ),
                        ),
                        Text(
                          h['status'].toString().toUpperCase(),
                          style:TextStyle(fontWeight:FontWeight.w800,color:statusColor(h['status'].toString())),
                        ),
                      ],
                    ),
                    SizedBox(height:4),
                    Text(
                      '${fxFmt(h['amount'] as num)} ${h['currency']}'
                      '${(h['commission'] as num)>0?'  (+${fxFmt(h['commission'] as num)} commission)':''}',
                      style:TextStyle(fontSize:18,fontWeight:FontWeight.w900),
                    ),
                    Text('Partner: ${h['partner_name']??'-'}${h['city']==null||h['city'].toString().isEmpty?'':'  •  ${h['city']}'}'),
                    Text('From: ${h['sender_name']??'-'}   To: ${h['receiver_name']??'-'} ${h['receiver_phone']??''}'),
                    Text('${h['business_date']}'),
                    if(canWrite&&h['status']!='cancelled')
                      Wrap(
                        spacing:8,
                        children:[
                          if(h['status']=='pending')
                            TextButton.icon(
                              onPressed:()=>markPaid(h),
                              icon:Icon(Icons.check_circle_outline),
                              label:Text(h['direction']=='in'?'Pay out':'Delivered'),
                            ),
                          TextButton.icon(
                            onPressed:()=>cancel(h),
                            icon:Icon(Icons.cancel_outlined),
                            label:Text('Cancel'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
