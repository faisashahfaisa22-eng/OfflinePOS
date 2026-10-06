// ignore_for_file: prefer_const_constructors, prefer_const_declarations, prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qamvio_pos/core/cloud/cloud_backup_service.dart';
import 'package:qamvio_pos/core/database/app_database.dart';
import 'package:qamvio_pos/core/database/sarafi_repository.dart';
import 'package:qamvio_pos/features/sarafi/sarafi_common.dart';

/// Sarafi (money exchange / hawala) ledger tests on the real encrypted
/// database. Cash is global, so most tests compare cash BEFORE and AFTER.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final app=AppDatabase.instance;
  final repo=SarafiRepository.instance;

  Future<double> cash(String cur) async =>(await repo.cashBalances())[cur]??0;
  Future<double> bal(String partyId,String cur) async =>(await repo.partyBalances(partyId))[cur]??0;

  Future<String> party(String kind) async {
    final id=SarafiRepository.newId('pt');
    await repo.saveParty(id:id,kind:kind,name:'T $kind $id');
    return id;
  }

  setUpAll(() async {
    await app.deleteFile();
    await app.unlock(List<int>.generate(32,(i)=>i+7));
    await repo.setRate('USD',69,71);
  });

  tearDownAll(() async {
    await app.lock();
  });

  group('Rate math (no database)',() {
    test('AFN to USD divides by the rate',() {
      expect(FxQuote.toAmount(from:'AFN',to:'USD',fromAmount:7000,rate:70),100);
    });
    test('USD to AFN multiplies by the rate',() {
      expect(FxQuote.toAmount(from:'USD',to:'AFN',fromAmount:100,rate:70),7000);
    });
    test('cross currency multiplies by the rate',() {
      expect(FxQuote.toAmount(from:'USD',to:'EUR',fromAmount:100,rate:0.9),90);
    });
    test('unusable input gives zero',() {
      expect(FxQuote.toAmount(from:'USD',to:'USD',fromAmount:100,rate:1),0);
      expect(FxQuote.toAmount(from:'USD',to:'AFN',fromAmount:0,rate:70),0);
      expect(FxQuote.toAmount(from:'USD',to:'AFN',fromAmount:5,rate:0),0);
    });
    test('suggested rate: we buy when customer gives, sell when customer takes',() {
      const rates={'USD':FxRate(69,71)};
      expect(FxQuote.suggest('USD','AFN',rates),69);
      expect(FxQuote.suggest('AFN','USD',rates),71);
      expect(FxQuote.suggest('AFN','EUR',rates),null);
    });
    test('profit estimate is value received minus value given at mid',() {
      final p=SarafiRepository.estimateProfitAfn(
        fromCurrency:'USD',fromAmount:100,toCurrency:'AFN',toAmount:6900,
        mid:const {'AFN':1,'USD':70},
      );
      expect(p,closeTo(100,0.0001));
    });
  });

  group('Exchange',() {
    test('moves cash in both currencies and records profit',() async {
      final usd0=await cash('USD');
      final afn0=await cash('AFN');
      final id=await repo.saveExchange(
        date:DateTime.now(),fromCurrency:'USD',fromAmount:100,
        toCurrency:'AFN',toAmount:6900,rate:69,
      );
      expect(await cash('USD')-usd0,100);
      expect(await cash('AFN')-afn0,-6900);
      final rows=await repo.exchanges();
      final row=rows.firstWhere((r)=>r['id']==id);
      expect((row['profit_afn'] as num).toDouble(),closeTo(100,0.0001));
    });

    test('editing replaces the old postings exactly',() async {
      final usd0=await cash('USD');
      final afn0=await cash('AFN');
      final id=await repo.saveExchange(
        date:DateTime.now(),fromCurrency:'USD',fromAmount:100,
        toCurrency:'AFN',toAmount:6900,rate:69,
      );
      await repo.saveExchange(
        id:id,date:DateTime.now(),fromCurrency:'USD',fromAmount:50,
        toCurrency:'AFN',toAmount:3450,rate:69,
      );
      expect(await cash('USD')-usd0,50);
      expect(await cash('AFN')-afn0,-3450);
    });

    test('deleting sends exchange to recycle bin and restore replays cash',() async {
      final usd0=await cash('USD');
      final afn0=await cash('AFN');
      final id=await repo.saveExchange(
        date:DateTime.now(),fromCurrency:'USD',fromAmount:100,
        toCurrency:'AFN',toAmount:6900,rate:69,
      );
      await repo.deleteExchange(id);
      expect(await cash('USD')-usd0,0);
      expect(await cash('AFN')-afn0,0);

      final db=await app.database;
      final bin=await db.query(
        'recycle_bin',
        where:'section=?',
        whereArgs:['sarafiExchange'],
        orderBy:'deleted_at DESC',
        limit:1,
      );
      expect(bin,isNotEmpty);
      await app.restoreRecycle(bin.first['id'].toString());
      expect(await cash('USD')-usd0,100);
      expect(await cash('AFN')-afn0,-6900);
      expect((await repo.exchanges()).any((x)=>x['id']==id),true);

      await repo.deleteExchange(id);
      expect(await cash('USD')-usd0,0);
      expect(await cash('AFN')-afn0,0);
    });

    test('same currency, zero amount or zero rate are rejected and change nothing',() async {
      final afn0=await cash('AFN');
      await expectLater(
        repo.saveExchange(date:DateTime.now(),fromCurrency:'USD',fromAmount:1,toCurrency:'USD',toAmount:1,rate:1),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveExchange(date:DateTime.now(),fromCurrency:'USD',fromAmount:0,toCurrency:'AFN',toAmount:1,rate:1),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveExchange(date:DateTime.now(),fromCurrency:'USD',fromAmount:1,toCurrency:'AFN',toAmount:1,rate:0),
        throwsArgumentError,
      );
      expect(await cash('AFN')-afn0,0);
    });
  });

  group('Customer account',() {
    test('deposit and withdraw keep balance and cash in step',() async {
      final c=await party('client');
      final afn0=await cash('AFN');
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'AFN',amount:1000,incoming:true,kind:'deposit');
      expect(await bal(c,'AFN'),1000);
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'AFN',amount:400,incoming:false,kind:'withdraw');
      expect(await bal(c,'AFN'),600);
      expect(await cash('AFN')-afn0,600);
    });

    test('withdrawing more than the balance leaves a negative balance (customer owes)',() async {
      final c=await party('client');
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'USD',amount:100,incoming:true,kind:'deposit');
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'USD',amount:130,incoming:false,kind:'withdraw');
      expect(await bal(c,'USD'),-30);
    });

    test('balances are kept per currency',() async {
      final c=await party('client');
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'AFN',amount:500,incoming:true,kind:'deposit');
      await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'USD',amount:20,incoming:true,kind:'deposit');
      final b=await repo.partyBalances(c);
      expect(b['AFN'],500);
      expect(b['USD'],20);
    });

    test('deleting a movement recycles it and restore returns cash and balance',() async {
      final c=await party('client');
      final afn0=await cash('AFN');
      final id=await repo.saveMovement(date:DateTime.now(),partyId:c,currency:'AFN',amount:300,incoming:true,kind:'deposit');
      await repo.deleteMovement(id);
      expect(await bal(c,'AFN'),0);
      expect(await cash('AFN')-afn0,0);

      final db=await app.database;
      final bin=await db.query(
        'recycle_bin',
        where:'section=?',
        whereArgs:['sarafiMovement'],
        orderBy:'deleted_at DESC',
        limit:1,
      );
      expect(bin,isNotEmpty);
      await app.restoreRecycle(bin.first['id'].toString());
      expect(await bal(c,'AFN'),300);
      expect(await cash('AFN')-afn0,300);

      await repo.deleteMovement(id);
      expect(await bal(c,'AFN'),0);
      expect(await cash('AFN')-afn0,0);
    });

    test('invalid input is rejected',() async {
      final c=await party('client');
      await expectLater(
        repo.saveMovement(date:DateTime.now(),partyId:c,currency:'AFN',amount:0,incoming:true,kind:'deposit'),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveParty(id:'x',kind:'robot',name:'Bad'),
        throwsArgumentError,
      );
    });
  });

  group('Hawala',() {
    test('outgoing: cash up by amount+commission, we owe the partner the amount',() async {
      final p=await party('partner');
      final usd0=await cash('USD');
      final id=await repo.createHawala(
        date:DateTime.now(),direction:'out',partnerId:p,
        receiverName:'R',currency:'USD',amount:500,commission:10,
      );
      expect(await cash('USD')-usd0,510);
      expect(await bal(p,'USD'),500);
      await repo.markHawalaPaid(id);
      expect(await cash('USD')-usd0,510);
      final h=(await repo.hawalas()).firstWhere((r)=>r['id']==id);
      expect(h['status'],'paid');
    });

    test('cancelling an outgoing hawala reverses everything; second cancel fails',() async {
      final p=await party('partner');
      final usd0=await cash('USD');
      final id=await repo.createHawala(
        date:DateTime.now(),direction:'out',partnerId:p,
        currency:'USD',amount:200,commission:5,
      );
      await repo.cancelHawala(id);
      expect(await cash('USD')-usd0,0);
      expect(await bal(p,'USD'),0);
      await expectLater(repo.cancelHawala(id),throwsStateError);
    });

    test('incoming: nothing posts until paid out',() async {
      final p=await party('partner');
      final usd0=await cash('USD');
      final id=await repo.createHawala(
        date:DateTime.now(),direction:'in',partnerId:p,
        currency:'USD',amount:300,commission:5,
      );
      expect(await cash('USD')-usd0,0);
      expect(await bal(p,'USD'),0);
      await repo.markHawalaPaid(id);
      expect(await cash('USD')-usd0,-300);
      expect(await bal(p,'USD'),-305);
      await expectLater(repo.markHawalaPaid(id),throwsStateError);
    });

    test('cancelling a paid incoming hawala puts the cash back',() async {
      final p=await party('partner');
      final usd0=await cash('USD');
      final id=await repo.createHawala(
        date:DateTime.now(),direction:'in',partnerId:p,
        currency:'USD',amount:300,
      );
      await repo.markHawalaPaid(id);
      await repo.cancelHawala(id);
      expect(await cash('USD')-usd0,0);
      expect(await bal(p,'USD'),0);
    });

    test('settling with the partner brings the balance to zero',() async {
      final p=await party('partner');
      final usd0=await cash('USD');
      await repo.createHawala(
        date:DateTime.now(),direction:'out',partnerId:p,
        currency:'USD',amount:500,
      );
      await repo.saveMovement(
        date:DateTime.now(),partyId:p,currency:'USD',amount:500,
        incoming:false,kind:'settle_out',
      );
      expect(await bal(p,'USD'),0);
      expect(await cash('USD')-usd0,0);
    });

    test('hawala codes are unique and invalid input is rejected',() async {
      final p=await party('partner');
      final a=await repo.createHawala(date:DateTime.now(),direction:'out',partnerId:p,currency:'USD',amount:1);
      final b=await repo.createHawala(date:DateTime.now(),direction:'out',partnerId:p,currency:'USD',amount:1);
      final rows=await repo.hawalas();
      final ca=rows.firstWhere((r)=>r['id']==a)['code'];
      final cb=rows.firstWhere((r)=>r['id']==b)['code'];
      expect(ca==cb,false);
      await expectLater(
        repo.createHawala(date:DateTime.now(),direction:'sideways',partnerId:p,currency:'USD',amount:1),
        throwsArgumentError,
      );
      await expectLater(
        repo.createHawala(date:DateTime.now(),direction:'out',partnerId:p,currency:'USD',amount:0),
        throwsArgumentError,
      );
      await expectLater(
        repo.createHawala(date:DateTime.now(),direction:'out',partnerId:'',currency:'USD',amount:1),
        throwsArgumentError,
      );
    });
  });

  group('Daily report',() {
    test('opening, in, out, closing, profit and commission for one day',() async {
      // Dates far in the past so no other test touches them.
      final d0=DateTime(2000,12,31);
      final d1=DateTime(2001,1,1);
      await repo.saveCashAdjustment(date:d0,currency:'AFN',amount:1000,kind:'opening');
      await repo.saveExchange(
        date:d1,fromCurrency:'USD',fromAmount:100,
        toCurrency:'AFN',toAmount:6900,rate:69,
      );
      final p=await party('partner');
      await repo.createHawala(
        date:d1,direction:'out',partnerId:p,
        currency:'USD',amount:200,commission:4,
      );
      final r=await repo.dailyReport(d1);
      final afn=r.cash.firstWhere((c)=>c.currency=='AFN');
      expect(afn.opening,1000);
      expect(afn.inflow,0);
      expect(afn.outflow,-6900);
      expect(afn.closing,-5900);
      final usd=r.cash.firstWhere((c)=>c.currency=='USD');
      expect(usd.opening,0);
      expect(usd.inflow,304);
      expect(r.exchangeCount,1);
      expect(r.exchangeProfitAfn,closeTo(100,0.0001));
      expect(r.hawalaCount,1);
      expect(r.commissions['USD'],4);
    });
  });

  group('Backup',() {
    test('snapshot includes every Sarafi table',() async {
      final snap=await CloudBackupService.instance.snapshot();
      final data=snap['data'] as Map<String,dynamic>;
      for(final t in ['fx_currencies','fx_rates','fx_parties','fx_exchanges','fx_hawala','fx_ledger','fx_cash']) {
        expect(data.containsKey(t),true,reason:'missing $t');
      }
      expect((data['fx_cash'] as List).isNotEmpty,true);
    });

    test('default currencies are created and AFN is the base',() async {
      final c=await repo.currencies(onlyActive:false);
      expect(c.any((x)=>x['code']=='AFN'&&x['is_base']==1),true);
      expect(c.any((x)=>x['code']=='USD'),true);
    });
  });
}
