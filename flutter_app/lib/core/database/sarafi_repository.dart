import 'package:sqflite_sqlcipher/sqflite.dart';

import 'app_database.dart';

/// Tables for the Sarafi (money exchange / hawala) module.
///
/// Design rule: balances are NEVER stored. Cash per currency is
/// SUM(fx_cash.amount) and what we owe / are owed is SUM(fx_ledger.amount), so
/// editing or deleting a transaction cannot drift a counter. Every posting row
/// carries the id of the transaction it belongs to in `ref_id`.
class SarafiSchema {
  SarafiSchema._();

  static const baseCurrency='AFN';

  static const _currencies=<List<String>>[
    ['AFN','Afghani','AFN'],
    ['USD','US Dollar','USD'],
    ['EUR','Euro','EUR'],
    ['PKR','Pakistani Rupee','PKR'],
    ['IRR','Iranian Toman/Rial','IRR'],
    ['SAR','Saudi Riyal','SAR'],
    ['AED','UAE Dirham','AED'],
    ['INR','Indian Rupee','INR'],
    ['TRY','Turkish Lira','TRY'],
  ];

  static const _statements=<String>[
    'CREATE TABLE IF NOT EXISTS fx_currencies(code TEXT PRIMARY KEY,name TEXT NOT NULL,symbol TEXT,is_base INTEGER NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1,sort INTEGER NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_rates(currency TEXT PRIMARY KEY,buy REAL NOT NULL DEFAULT 0,sell REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_parties(id TEXT PRIMARY KEY,kind TEXT NOT NULL,name TEXT NOT NULL,phone TEXT,city TEXT,note TEXT,active INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_ledger(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,party_id TEXT NOT NULL,currency TEXT NOT NULL,amount REAL NOT NULL,kind TEXT NOT NULL,ref_id TEXT,note TEXT,created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_cash(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,currency TEXT NOT NULL,amount REAL NOT NULL,kind TEXT NOT NULL,ref_id TEXT,note TEXT,created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_exchanges(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,party_id TEXT,from_currency TEXT NOT NULL,from_amount REAL NOT NULL,to_currency TEXT NOT NULL,to_amount REAL NOT NULL,rate REAL NOT NULL,profit_afn REAL NOT NULL DEFAULT 0,note TEXT,created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS fx_hawala(id TEXT PRIMARY KEY,business_date TEXT NOT NULL,code TEXT NOT NULL,direction TEXT NOT NULL,partner_id TEXT NOT NULL,sender_name TEXT,receiver_name TEXT,receiver_phone TEXT,city TEXT,currency TEXT NOT NULL,amount REAL NOT NULL,commission REAL NOT NULL DEFAULT 0,status TEXT NOT NULL DEFAULT \'pending\',note TEXT,created_at TEXT NOT NULL,paid_at TEXT)',
    'CREATE INDEX IF NOT EXISTS idx_fx_cash_date ON fx_cash(business_date,currency)',
    'CREATE INDEX IF NOT EXISTS idx_fx_cash_ref ON fx_cash(ref_id)',
    'CREATE INDEX IF NOT EXISTS idx_fx_ledger_party ON fx_ledger(party_id,currency)',
    'CREATE INDEX IF NOT EXISTS idx_fx_ledger_ref ON fx_ledger(ref_id)',
  ];

  /// Creates every Sarafi table (safe to call many times) and the default
  /// currency list.
  static Future<void> create(dynamic db) async {
    for(final sql in _statements) {
      await db.execute(sql);
    }
    await seedIfEmpty(db);
  }

  static Future<void> seedIfEmpty(dynamic db) async {
    final count=Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM fx_currencies'),
    )??0;
    if(count>0) return;
    final now=DateTime.now().toUtc().toIso8601String();
    var i=0;
    for(final c in _currencies) {
      await db.insert('fx_currencies',{
        'code':c[0],
        'name':c[1],
        'symbol':c[2],
        'is_base':c[0]==baseCurrency?1:0,
        'active':1,
        'sort':i,
        'updated_at':now,
      },conflictAlgorithm:ConflictAlgorithm.ignore);
      i++;
    }
  }
}

class FxRate {
  final double buy;
  final double sell;
  const FxRate(this.buy,this.sell);
  double get mid=>(buy>0&&sell>0)?(buy+sell)/2:(buy>0?buy:sell);
}

class CurrencyDay {
  final String currency;
  final double opening;
  final double inflow;
  final double outflow;
  const CurrencyDay(this.currency,this.opening,this.inflow,this.outflow);
  double get closing=>opening+inflow+outflow;
}

class SarafiDayReport {
  final String day;
  final List<CurrencyDay> cash;
  final double exchangeProfitAfn;
  final int exchangeCount;
  final int hawalaCount;
  final Map<String,double> commissions;
  const SarafiDayReport({
    required this.day,
    required this.cash,
    required this.exchangeProfitAfn,
    required this.exchangeCount,
    required this.hawalaCount,
    required this.commissions,
  });
}

class SarafiRepository {
  SarafiRepository._();
  static final SarafiRepository instance=SarafiRepository._();

  static int _seq=0;

  static String newId([String prefix='fx']) {
    _seq++;
    return '$prefix${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  static String dayOf(DateTime d)=>d.toIso8601String().split('T').first;
  static String _now()=>DateTime.now().toUtc().toIso8601String();
  static double _d(Object? v)=>(v as num?)?.toDouble()??0;

  Future<Database> get _db=>AppDatabase.instance.database;

  // ---------------------------------------------------------------- currencies

  Future<List<Map<String,Object?>>> currencies({bool onlyActive=true}) async {
    final db=await _db;
    await SarafiSchema.seedIfEmpty(db);
    return db.query(
      'fx_currencies',
      where:onlyActive?'active=1':null,
      orderBy:'sort, code',
    );
  }

  Future<void> saveCurrency({
    required String code,
    required String name,
    String? symbol,
    bool active=true,
  }) async {
    final c=code.trim().toUpperCase();
    if(c.length<2||c.length>5) throw ArgumentError.value(code,'code','Use a short currency code, for example USD.');
    if(name.trim().isEmpty) throw ArgumentError.value(name,'name','Name is required.');
    final db=await _db;
    final old=await db.query('fx_currencies',where:'code=?',whereArgs:[c],limit:1);
    final isBase=c==SarafiSchema.baseCurrency;
    await db.insert('fx_currencies',{
      'code':c,
      'name':name.trim(),
      'symbol':symbol?.trim(),
      'is_base':isBase?1:0,
      'active':(isBase||active)?1:0,
      'sort':old.isEmpty?100:(old.first['sort'] as num?)?.toInt()??100,
      'updated_at':_now(),
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  // --------------------------------------------------------------------- rates

  Future<Map<String,FxRate>> rates() async {
    final db=await _db;
    final rows=await db.query('fx_rates');
    final out=<String,FxRate>{};
    for(final r in rows) {
      out[r['currency'].toString()]=FxRate(_d(r['buy']),_d(r['sell']));
    }
    return out;
  }

  /// AFN value of 1 unit of each currency, at the mid rate (AFN itself = 1).
  Future<Map<String,double>> midRates() async {
    final r=await rates();
    final out=<String,double>{SarafiSchema.baseCurrency:1};
    r.forEach((k,v) {
      if(v.mid>0) out[k]=v.mid;
    });
    return out;
  }

  /// [buy]/[sell] = how many AFN for 1 unit of [currency].
  Future<void> setRate(String currency,double buy,double sell) async {
    if(currency==SarafiSchema.baseCurrency) throw ArgumentError('The base currency has no rate.');
    if(buy<0||sell<0) throw ArgumentError('Rates cannot be negative.');
    final db=await _db;
    await db.insert('fx_rates',{
      'currency':currency,
      'buy':buy,
      'sell':sell,
      'updated_at':_now(),
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  /// Estimated profit in AFN: value received minus value given, both valued at
  /// the mid rate. It is an estimate against the market mid, not accounting
  /// profit of a closed position.
  static double estimateProfitAfn({
    required String fromCurrency,
    required double fromAmount,
    required String toCurrency,
    required double toAmount,
    required Map<String,double> mid,
  }) {
    final a=mid[fromCurrency];
    final b=mid[toCurrency];
    if(a==null||b==null||a<=0||b<=0) return 0;
    return fromAmount*a-toAmount*b;
  }

  // ------------------------------------------------------------------- parties

  Future<List<Map<String,Object?>>> parties(String kind,{bool onlyActive=true}) async {
    final db=await _db;
    return db.query(
      'fx_parties',
      where:onlyActive?'kind=? AND active=1':'kind=?',
      whereArgs:[kind],
      orderBy:'name COLLATE NOCASE',
    );
  }

  Future<void> saveParty({
    required String id,
    required String kind,
    required String name,
    String? phone,
    String? city,
    String? note,
    bool active=true,
  }) async {
    if(kind!='client'&&kind!='partner') throw ArgumentError.value(kind,'kind','Use client or partner.');
    if(name.trim().isEmpty) throw ArgumentError.value(name,'name','Name is required.');
    final db=await _db;
    final old=await db.query('fx_parties',where:'id=?',whereArgs:[id],limit:1);
    final now=_now();
    await db.insert('fx_parties',{
      'id':id,
      'kind':kind,
      'name':name.trim(),
      'phone':phone?.trim(),
      'city':city?.trim(),
      'note':note,
      'active':active?1:0,
      'created_at':old.isEmpty?now:old.first['created_at'],
      'updated_at':now,
    },conflictAlgorithm:ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------------ postings

  Future<void> _clearRef(dynamic txn,String id) async {
    await txn.delete('fx_cash',where:'ref_id=?',whereArgs:[id]);
    await txn.delete('fx_ledger',where:'ref_id=?',whereArgs:[id]);
  }

  Future<void> _cash(
    dynamic txn, {
    required String id,
    required String day,
    required String currency,
    required double amount,
    required String kind,
    required String refId,
    String? note,
  }) async {
    await txn.insert('fx_cash',{
      'id':id,
      'business_date':day,
      'currency':currency,
      'amount':amount,
      'kind':kind,
      'ref_id':refId,
      'note':note,
      'created_at':_now(),
    });
  }

  Future<void> _ledger(
    dynamic txn, {
    required String id,
    required String day,
    required String partyId,
    required String currency,
    required double amount,
    required String kind,
    required String refId,
    String? note,
  }) async {
    await txn.insert('fx_ledger',{
      'id':id,
      'business_date':day,
      'party_id':partyId,
      'currency':currency,
      'amount':amount,
      'kind':kind,
      'ref_id':refId,
      'note':note,
      'created_at':_now(),
    });
  }

  // ----------------------------------------------------------------- exchanges

  /// Customer gives [fromAmount] of [fromCurrency] and receives [toAmount] of
  /// [toCurrency] in cash. Saving again with the same [id] replaces the old
  /// entry exactly.
  Future<String> saveExchange({
    String? id,
    required DateTime date,
    String? partyId,
    required String fromCurrency,
    required double fromAmount,
    required String toCurrency,
    required double toAmount,
    required double rate,
    String? note,
  }) async {
    if(fromCurrency==toCurrency) throw ArgumentError('Choose two different currencies.');
    if(fromAmount<=0||toAmount<=0) throw ArgumentError('Amounts must be greater than zero.');
    if(rate<=0) throw ArgumentError('Rate must be greater than zero.');
    final xid=id??newId('ex');
    final day=dayOf(date);
    final mid=await midRates();
    final profit=estimateProfitAfn(
      fromCurrency:fromCurrency,
      fromAmount:fromAmount,
      toCurrency:toCurrency,
      toAmount:toAmount,
      mid:mid,
    );
    final db=await _db;
    await db.transaction((txn) async {
      await _clearRef(txn,xid);
      await txn.delete('fx_exchanges',where:'id=?',whereArgs:[xid]);
      await txn.insert('fx_exchanges',{
        'id':xid,
        'business_date':day,
        'party_id':(partyId==null||partyId.isEmpty)?null:partyId,
        'from_currency':fromCurrency,
        'from_amount':fromAmount,
        'to_currency':toCurrency,
        'to_amount':toAmount,
        'rate':rate,
        'profit_afn':profit,
        'note':note,
        'created_at':_now(),
      });
      await _cash(txn,id:'${xid}_in',day:day,currency:fromCurrency,amount:fromAmount,kind:'exchange',refId:xid,note:note);
      await _cash(txn,id:'${xid}_out',day:day,currency:toCurrency,amount:-toAmount,kind:'exchange',refId:xid,note:note);
    });
    return xid;
  }

  Future<void> deleteExchange(String id) async {
    final db=await _db;
    await db.transaction((txn) async {
      await _clearRef(txn,id);
      await txn.delete('fx_exchanges',where:'id=?',whereArgs:[id]);
    });
  }

  Future<List<Map<String,Object?>>> exchanges({String? day,int limit=200}) async {
    final db=await _db;
    return db.rawQuery(
      'SELECT e.*,p.name party_name FROM fx_exchanges e '
      'LEFT JOIN fx_parties p ON p.id=e.party_id '
      '${day==null?"":"WHERE e.business_date=? "}'
      'ORDER BY e.business_date DESC,e.created_at DESC LIMIT $limit',
      day==null?null:[day],
    );
  }

  // ------------------------------------------------------------ cash movements

  /// Money moving between the shop cash box and a client or partner account.
  ///
  /// [incoming]=true: the party gives us money. Cash goes up and the party's
  /// credit goes up (we owe them more / they owe us less).
  /// [incoming]=false: we give the party money. Cash goes down and the party's
  /// credit goes down (a negative balance means they owe us).
  ///
  /// [kind] is a label: deposit, withdraw, settle_in or settle_out.
  Future<String> saveMovement({
    String? id,
    required DateTime date,
    required String partyId,
    required String currency,
    required double amount,
    required bool incoming,
    required String kind,
    String? note,
  }) async {
    if(amount<=0) throw ArgumentError('Amount must be greater than zero.');
    if(partyId.isEmpty) throw ArgumentError('Choose an account.');
    final mid=id??newId('mv');
    final day=dayOf(date);
    final signed=incoming?amount:-amount;
    final db=await _db;
    await db.transaction((txn) async {
      await _clearRef(txn,mid);
      await _cash(txn,id:'${mid}_c',day:day,currency:currency,amount:signed,kind:kind,refId:mid,note:note);
      await _ledger(txn,id:'${mid}_l',day:day,partyId:partyId,currency:currency,amount:signed,kind:kind,refId:mid,note:note);
    });
    return mid;
  }

  Future<void> deleteMovement(String id) async {
    final db=await _db;
    await _clearRef(db,id);
  }

  /// Own cash correction (opening cash, counting difference). [amount] is
  /// signed and may not be zero.
  Future<String> saveCashAdjustment({
    String? id,
    required DateTime date,
    required String currency,
    required double amount,
    String kind='adjust',
    String? note,
  }) async {
    if(amount==0) throw ArgumentError('Amount cannot be zero.');
    final aid=id??newId('ca');
    final db=await _db;
    await db.transaction((txn) async {
      await _clearRef(txn,aid);
      await _cash(txn,id:'${aid}_c',day:dayOf(date),currency:currency,amount:amount,kind:kind,refId:aid,note:note);
    });
    return aid;
  }

  // ------------------------------------------------------------------- hawala

  /// direction 'out': a customer pays us here, [partnerId] pays the receiver
  /// elsewhere. Cash +(amount+commission), we owe the partner +amount.
  /// direction 'in': [partnerId] asks us to pay a receiver here. Nothing is
  /// posted until [payIncomingHawala]; then cash -amount and the partner owes
  /// us amount+commission.
  Future<String> createHawala({
    String? id,
    required DateTime date,
    required String direction,
    required String partnerId,
    String? senderName,
    String? receiverName,
    String? receiverPhone,
    String? city,
    required String currency,
    required double amount,
    double commission=0,
    String? note,
  }) async {
    if(direction!='out'&&direction!='in') throw ArgumentError.value(direction,'direction','Use out or in.');
    if(amount<=0) throw ArgumentError('Amount must be greater than zero.');
    if(commission<0) throw ArgumentError('Commission cannot be negative.');
    if(partnerId.isEmpty) throw ArgumentError('Choose a partner.');
    final hid=id??newId('hw');
    final day=dayOf(date);
    final db=await _db;
    await db.transaction((txn) async {
      final count=Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM fx_hawala'),
      )??0;
      final code='HW-${(count+1).toString().padLeft(5,'0')}';
      await txn.insert('fx_hawala',{
        'id':hid,
        'business_date':day,
        'code':code,
        'direction':direction,
        'partner_id':partnerId,
        'sender_name':senderName?.trim(),
        'receiver_name':receiverName?.trim(),
        'receiver_phone':receiverPhone?.trim(),
        'city':city?.trim(),
        'currency':currency,
        'amount':amount,
        'commission':commission,
        'status':'pending',
        'note':note,
        'created_at':_now(),
      });
      if(direction=='out') {
        await _postHawala(txn,hid,day,direction,partnerId,currency,amount,commission);
      }
    });
    return hid;
  }

  Future<void> _postHawala(
    dynamic txn,
    String hid,
    String day,
    String direction,
    String partnerId,
    String currency,
    double amount,
    double commission,
  ) async {
    if(direction=='out') {
      await _cash(txn,id:'${hid}_c',day:day,currency:currency,amount:amount+commission,kind:'hawala_out',refId:hid);
      await _ledger(txn,id:'${hid}_l',day:day,partyId:partnerId,currency:currency,amount:amount,kind:'hawala_out',refId:hid);
    } else {
      await _cash(txn,id:'${hid}_c',day:day,currency:currency,amount:-amount,kind:'hawala_in',refId:hid);
      await _ledger(txn,id:'${hid}_l',day:day,partyId:partnerId,currency:currency,amount:-(amount+commission),kind:'hawala_in',refId:hid);
    }
  }

  /// Marks a hawala as paid. For an incoming hawala this is the moment we hand
  /// out the cash, so the postings are created here.
  Future<void> markHawalaPaid(String id,{DateTime? date}) async {
    final db=await _db;
    await db.transaction((txn) async {
      final rows=await txn.query('fx_hawala',where:'id=?',whereArgs:[id],limit:1);
      if(rows.isEmpty) throw StateError('Hawala not found.');
      final h=rows.first;
      if(h['status']!='pending') throw StateError('Only a pending hawala can be marked paid.');
      final when=date??DateTime.now();
      if(h['direction']=='in') {
        await _postHawala(
          txn,
          id,
          dayOf(when),
          'in',
          h['partner_id'].toString(),
          h['currency'].toString(),
          _d(h['amount']),
          _d(h['commission']),
        );
      }
      await txn.update('fx_hawala',{'status':'paid','paid_at':_now()},where:'id=?',whereArgs:[id]);
    });
  }

  /// Cancels a hawala and removes everything it posted.
  Future<void> cancelHawala(String id) async {
    final db=await _db;
    await db.transaction((txn) async {
      final rows=await txn.query('fx_hawala',where:'id=?',whereArgs:[id],limit:1);
      if(rows.isEmpty) throw StateError('Hawala not found.');
      if(rows.first['status']=='cancelled') throw StateError('Hawala is already cancelled.');
      await _clearRef(txn,id);
      await txn.update('fx_hawala',{'status':'cancelled'},where:'id=?',whereArgs:[id]);
    });
  }

  Future<List<Map<String,Object?>>> hawalas({String? status,int limit=200}) async {
    final db=await _db;
    return db.rawQuery(
      'SELECT h.*,p.name partner_name FROM fx_hawala h '
      'LEFT JOIN fx_parties p ON p.id=h.partner_id '
      '${status==null?"":"WHERE h.status=? "}'
      'ORDER BY h.business_date DESC,h.created_at DESC LIMIT $limit',
      status==null?null:[status],
    );
  }

  // ------------------------------------------------------------------ balances

  /// Balance of one party per currency. Positive = we hold their money (we owe
  /// them). Negative = they owe us.
  Future<Map<String,double>> partyBalances(String partyId) async {
    final db=await _db;
    final rows=await db.rawQuery(
      'SELECT currency,SUM(amount) s FROM fx_ledger WHERE party_id=? GROUP BY currency',
      [partyId],
    );
    final out=<String,double>{};
    for(final r in rows) {
      out[r['currency'].toString()]=_d(r['s']);
    }
    return out;
  }

  /// One row per party and currency: party_id, name, phone, city, currency,
  /// balance. Parties without postings are not listed here.
  Future<List<Map<String,Object?>>> balances(String kind) async {
    final db=await _db;
    return db.rawQuery(
      'SELECT p.id party_id,p.name name,p.phone phone,p.city city,l.currency currency,SUM(l.amount) balance '
      'FROM fx_parties p JOIN fx_ledger l ON l.party_id=p.id '
      'WHERE p.kind=? GROUP BY p.id,l.currency '
      'HAVING ABS(SUM(l.amount))>0.000001 '
      'ORDER BY p.name COLLATE NOCASE,l.currency',
      [kind],
    );
  }

  Future<List<Map<String,Object?>>> ledger(String partyId) async {
    final db=await _db;
    return db.query(
      'fx_ledger',
      where:'party_id=?',
      whereArgs:[partyId],
      orderBy:'business_date DESC,created_at DESC',
    );
  }

  Future<Map<String,double>> cashBalances() async {
    final db=await _db;
    final rows=await db.rawQuery('SELECT currency,SUM(amount) s FROM fx_cash GROUP BY currency');
    final out=<String,double>{};
    for(final r in rows) {
      out[r['currency'].toString()]=_d(r['s']);
    }
    return out;
  }

  // -------------------------------------------------------------------- report

  Future<SarafiDayReport> dailyReport(DateTime date) async {
    final day=dayOf(date);
    final db=await _db;
    final cashRows=await db.rawQuery(
      'SELECT currency,'
      'SUM(CASE WHEN business_date<? THEN amount ELSE 0 END) opening,'
      'SUM(CASE WHEN business_date=? AND amount>0 THEN amount ELSE 0 END) inflow,'
      'SUM(CASE WHEN business_date=? AND amount<0 THEN amount ELSE 0 END) outflow '
      'FROM fx_cash WHERE business_date<=? GROUP BY currency ORDER BY currency',
      [day,day,day,day],
    );
    final cash=<CurrencyDay>[
      for(final r in cashRows)
        CurrencyDay(r['currency'].toString(),_d(r['opening']),_d(r['inflow']),_d(r['outflow'])),
    ];
    final ex=await db.rawQuery(
      'SELECT COUNT(*) n,COALESCE(SUM(profit_afn),0) p FROM fx_exchanges WHERE business_date=?',
      [day],
    );
    final hw=await db.rawQuery(
      "SELECT currency,COUNT(*) n,COALESCE(SUM(commission),0) c FROM fx_hawala "
      "WHERE business_date=? AND status<>'cancelled' GROUP BY currency",
      [day],
    );
    final commissions=<String,double>{};
    var hawalaCount=0;
    for(final r in hw) {
      hawalaCount+=(r['n'] as num?)?.toInt()??0;
      commissions[r['currency'].toString()]=_d(r['c']);
    }
    return SarafiDayReport(
      day:day,
      cash:cash,
      exchangeProfitAfn:_d(ex.first['p']),
      exchangeCount:(ex.first['n'] as num?)?.toInt()??0,
      hawalaCount:hawalaCount,
      commissions:commissions,
    );
  }
}
