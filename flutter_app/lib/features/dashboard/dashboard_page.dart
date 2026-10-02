import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/cloud_backup_service.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/security/permissions.dart';
import '../../core/share/whatsapp_share.dart';
import '../../core/ui/qamvio_ui.dart';
import '../cloud/cloud_page.dart';
import '../expenses/expenses_page.dart';
import '../fuel/fuel_page.dart';
import '../parties/party_page.dart';
import '../products/products_page.dart';
import '../purchases/purchases_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_page.dart';
import '../salesmen/salesmen_page.dart';
import '../users/users_page.dart';
import '../v15/admin_pages.dart';
import '../v15/finance_pages.dart';
import '../v15/quick_stock_pages.dart';
import '../v15/statement_pages.dart';

double _d(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _m(dynamic v)=>QamvioUi.money(v);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState()=>_DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String,dynamic>> future;
  Timer? clock;
  DateTime now=DateTime.now();

  @override
  void initState() {
    super.initState();
    future=_load();
    clock=Timer.periodic(const Duration(seconds:1),(_) {
      if(mounted) setState(()=>now=DateTime.now());
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<Map<String,dynamic>> _load() async {
    final db=await AppDatabase.instance.database;
    Future<double> scalar(String sql,[List<Object?> args=const []]) async {
      final r=await db.rawQuery(sql,args);
      return r.isEmpty?0:_d(r.first.values.first);
    }
    final today=DateFormat('yyyy-MM-dd').format(DateTime.now());
    final thisMonday=DateTime.now().subtract(Duration(days:DateTime.now().weekday-1));
    final weekStart=DateFormat('yyyy-MM-dd').format(DateTime(thisMonday.year,thisMonday.month,thisMonday.day));
    final prevStart=DateFormat('yyyy-MM-dd').format(thisMonday.subtract(const Duration(days:7)));
    final prevEnd=DateFormat('yyyy-MM-dd').format(thisMonday.subtract(const Duration(days:1)));

    final stock=await scalar('SELECT COALESCE(SUM(stock*cost),0) FROM products');
    final receivable=await scalar('SELECT COALESCE(SUM(balance),0) FROM customers');
    final payable=await scalar('SELECT COALESCE(SUM(balance),0) FROM suppliers');
    final capital=await scalar('SELECT COALESCE(SUM(amount),0) FROM capital');
    final sales=await scalar('SELECT COALESCE(SUM(total),0) FROM sales');
    final discounts=await scalar('SELECT COALESCE(SUM(discount),0) FROM sales');
    final explicitExpenses=await scalar('SELECT COALESCE(SUM(amount),0) FROM expenses');
    final saleExpenses=await scalar('SELECT COALESCE(SUM(oil+other),0) FROM sales');
    final salesmanLoans=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN -amount ELSE amount END),0) "
      "FROM salesman_loans",
    );

    final cashSales=await scalar('SELECT COALESCE(SUM(paid-oil-other),0) FROM sales');
    final purchaseCash=await scalar('SELECT COALESCE(SUM(paid),0) FROM purchases');
    final supplierCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='received' THEN amount ELSE -amount END),0) "
      "FROM supplier_transactions",
    );
    final customerLoanCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE -amount END),0) "
      "FROM customer_loans",
    );
    final salesmanLoanCash=await scalar(
      "SELECT COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE -amount END),0) "
      "FROM salesman_loans WHERE COALESCE(source,'manual') NOT IN ('sale_due','sale_recovery')",
    );
    final cash=cashSales-purchaseCash+supplierCash+customerLoanCash+salesmanLoanCash-explicitExpenses;
    final position=receivable+stock+cash-payable-capital;

    final todaySales=await scalar('SELECT COALESCE(SUM(total),0) FROM sales WHERE business_date=?',[today]);
    final todayCash=await scalar('SELECT COALESCE(SUM(paid),0) FROM sales WHERE business_date=?',[today]);
    final todaySaleExp=await scalar('SELECT COALESCE(SUM(oil+other),0) FROM sales WHERE business_date=?',[today]);
    final todayExp=await scalar(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE substr(created_at,1,10)=?",
      [today],
    );
    final todayCogs=await scalar(
      'SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,0)),0) '
      'FROM sale_items si JOIN sales s ON s.id=si.sale_id WHERE s.business_date=?',
      [today],
    );
    final todayProfit=todaySales-todayCogs-todaySaleExp-todayExp;

    final weekSales=await scalar(
      'SELECT COALESCE(SUM(total),0) FROM sales WHERE business_date>=?',
      [weekStart],
    );
    final prevSales=await scalar(
      'SELECT COALESCE(SUM(total),0) FROM sales WHERE business_date BETWEEN ? AND ?',
      [prevStart,prevEnd],
    );
    Future<double> periodProfit(String from,String? to) async {
      final where=to==null?'s.business_date>=?':'s.business_date BETWEEN ? AND ?';
      final args=to==null?<Object?>[from]:<Object?>[from,to];
      final periodSales=await scalar('SELECT COALESCE(SUM(s.total),0) FROM sales s WHERE $where',args);
      final cogs=await scalar(
        'SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,0)),0) '
        'FROM sale_items si JOIN sales s ON s.id=si.sale_id WHERE $where',
        args,
      );
      final saleExp=await scalar('SELECT COALESCE(SUM(s.oil+s.other),0) FROM sales s WHERE $where',args);
      final expWhere=to==null
        ?'substr(created_at,1,10)>=?'
        :'substr(created_at,1,10) BETWEEN ? AND ?';
      final exp=await scalar('SELECT COALESCE(SUM(amount),0) FROM expenses WHERE $expWhere',args);
      return periodSales-cogs-saleExp-exp;
    }
    final weekProfit=await periodProfit(weekStart,null);
    final prevProfit=await periodProfit(prevStart,prevEnd);

    final lowStock=await db.rawQuery(
      'SELECT name,stock,reorder_level FROM products '
      'WHERE reorder_level>0 AND stock<=reorder_level '
      'ORDER BY stock ASC LIMIT 12',
    );
    final topCustomers=await db.rawQuery(
      'SELECT name,balance FROM customers WHERE balance>0 ORDER BY balance DESC LIMIT 5',
    );
    final topSalesmen=await db.rawQuery(
      "SELECT sm.name,"
      "COALESCE((SELECT SUM(s.due-s.recovery) FROM sales s WHERE s.salesman_id=sm.id AND s.customer_id IS NULL),0)+"
      "COALESCE((SELECT SUM(CASE WHEN l.type='payment' THEN -l.amount ELSE l.amount END) "
      "FROM salesman_loans l WHERE l.salesman_id=sm.id "
      "AND COALESCE(l.source,'manual') NOT IN ('sale_due','sale_recovery')),0) balance "
      "FROM salesmen sm ORDER BY balance DESC LIMIT 5",
    );
    final topProducts=await db.rawQuery(
      'SELECT si.product_name name,COALESCE(SUM(si.qty),0) qty '
      'FROM sale_items si GROUP BY si.product_name ORDER BY qty DESC LIMIT 5',
    );

    final recent=<Map<String,Object?>>[];
    final recentSales=await db.rawQuery(
      'SELECT created_at,invoice_no label,total amount FROM sales ORDER BY created_at DESC LIMIT 6',
    );
    for(final x in recentSales) {
      recent.add({'date':x['created_at'],'type':'Sale','label':x['label'],'amount':x['amount']});
    }
    final recentPurchases=await db.rawQuery(
      'SELECT p.created_at,COALESCE(s.name,\'Supplier\') label,p.total amount '
      'FROM purchases p LEFT JOIN suppliers s ON s.id=p.supplier_id '
      'ORDER BY p.created_at DESC LIMIT 4',
    );
    for(final x in recentPurchases) {
      recent.add({'date':x['created_at'],'type':'Purchase','label':x['label'],'amount':x['amount']});
    }
    final recentExpenses=await db.rawQuery(
      'SELECT created_at,name label,amount FROM expenses ORDER BY created_at DESC LIMIT 4',
    );
    for(final x in recentExpenses) {
      recent.add({'date':x['created_at'],'type':'Expense','label':x['label'],'amount':x['amount']});
    }
    recent.sort((a,b)=>b['date'].toString().compareTo(a['date'].toString()));
    final recentTrim=recent.take(8).toList();

    final todayActivity=await db.rawQuery(
      'SELECT invoice_no label,total amount,created_at FROM sales WHERE business_date=? '
      'ORDER BY created_at DESC LIMIT 8',
      [today],
    );

    final days=<Map<String,dynamic>>[];
    for(var i=6;i>=0;i--) {
      final day=DateTime.now().subtract(Duration(days:i));
      final key=DateFormat('yyyy-MM-dd').format(day);
      final s=await scalar('SELECT COALESCE(SUM(total),0) FROM sales WHERE business_date=?',[key]);
      final cogs=await scalar(
        'SELECT COALESCE(SUM(si.qty*COALESCE(si.cost,0)),0) '
        'FROM sale_items si JOIN sales x ON x.id=si.sale_id WHERE x.business_date=?',
        [key],
      );
      final ex=await scalar(
        "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE substr(created_at,1,10)=?",
        [key],
      );
      final se=await scalar('SELECT COALESCE(SUM(oil+other),0) FROM sales WHERE business_date=?',[key]);
      days.add({'label':DateFormat('EEE').format(day),'sales':s,'profit':s-cogs-ex-se});
    }

    final expenseMix=await db.rawQuery(
      'SELECT COALESCE(category,\'Uncategorized\') category,SUM(amount) amount '
      'FROM expenses GROUP BY category ORDER BY amount DESC LIMIT 6',
    );
    final oil=await scalar('SELECT COALESCE(SUM(oil),0) FROM sales');
    final other=await scalar('SELECT COALESCE(SUM(other),0) FROM sales');
    final mix=<Map<String,Object?>>[...expenseMix];
    if(oil>0) mix.add({'category':'Oil','amount':oil});
    if(other>0) mix.add({'category':'Extra','amount':other});

    return {
      'stock':stock,'cash':cash,'receivable':receivable,'payable':payable,
      'capital':capital,'position':position,'sales':sales,'discounts':discounts,
      'expenses':explicitExpenses+saleExpenses,'salesmanLoans':salesmanLoans,
      'todaySales':todaySales,'todayCash':todayCash,'todayExpenses':todayExp+todaySaleExp,
      'todayProfit':todayProfit,'weekSales':weekSales,'prevSales':prevSales,
      'weekProfit':weekProfit,'prevProfit':prevProfit,'lowStock':lowStock,
      'topCustomers':topCustomers,'topSalesmen':topSalesmen,'topProducts':topProducts,
      'recent':recentTrim,'todayActivity':todayActivity,'days':days,'expenseMix':mix,
    };
  }

  Future<void> refresh() async {
    setState(()=>future=_load());
    await future;
  }

  Future<void> shareBusinessReport() async {
    try {
      await WhatsAppShare.shareBusinessReport();
    } catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('WhatsApp: $e')));
    }
  }

  Future<void> _go(AppPage page,Widget widget) async {
    if(!Permissions.canOpen(page)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Your login role does not have access to this page.')),
      );
      return;
    }
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>widget));
    if(mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final strings=LanguageController.instance.strings;
    return Scaffold(
      drawer:V15NavigationDrawer(onNavigate:_go,strings:strings),
      appBar:AppBar(
        title:const Text('QAMVIO POS'),
        actions:[
          IconButton(
            tooltip:'WhatsApp all debts / report',
            onPressed:shareBusinessReport,
            icon:const Icon(Icons.chat_rounded),
          ),
          PopupMenuButton<AppLanguage>(
            tooltip:strings.t('language'),
            icon:const Icon(Icons.language_rounded),
            onSelected:LanguageController.instance.setLanguage,
            itemBuilder:(_)=>const [
              PopupMenuItem(value:AppLanguage.english,child:Text('English')),
              PopupMenuItem(value:AppLanguage.pashto,child:Text('پښتو')),
              PopupMenuItem(value:AppLanguage.dari,child:Text('دری')),
              PopupMenuItem(value:AppLanguage.urdu,child:Text('اردو')),
            ],
          ),
        ],
      ),
      body:FutureBuilder<Map<String,dynamic>>(
        future:future,
        builder:(context,snapshot) {
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          final x=snapshot.data!;
          return RefreshIndicator(
            onRefresh:refresh,
            child:ListView(
              physics:const AlwaysScrollableScrollPhysics(),
              padding:const EdgeInsets.fromLTRB(14,10,14,90),
              children:[
                _hero(context),
                const SizedBox(height:14),
                const _Section('Owner Summary'),
                _ownerSummary(context,x),
                const SizedBox(height:14),
                const _Section('Core Business Highlights'),
                _coreHighlights(context,x),
                const SizedBox(height:10),
                _secondaryHighlights(context,x),
                const SizedBox(height:14),
                _businessPosition(context,x),
                const SizedBox(height:14),
                const _Section("Today's Summary"),
                _today(context,x),
                const SizedBox(height:14),
                const _Section('This Week vs Last Week'),
                _week(context,x),
                const SizedBox(height:14),
                const _Section('Visual Analytics'),
                _analytics(context,x),
                const SizedBox(height:14),
                _lowStock(context,x),
                const SizedBox(height:14),
                const _Section("Today's Activity"),
                _activityTable(context,x['todayActivity'] as List<Map<String,Object?>>,today:true),
                const SizedBox(height:14),
                const _Section('Recent Activity'),
                _activityTable(context,x['recent'] as List<Map<String,Object?>>,today:false),
                const SizedBox(height:14),
                const _Section('Top Customer Dues'),
                _dueList(context,x['topCustomers'] as List<Map<String,Object?>>,'balance'),
                const SizedBox(height:14),
                const _Section('Top Salesman Dues'),
                _dueList(context,x['topSalesmen'] as List<Map<String,Object?>>,'balance'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context)=>Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(
      gradient:const LinearGradient(
        colors:[Color(0xFF111827),Color(0xFF3730A3)],
        begin:Alignment.topLeft,
        end:Alignment.bottomRight,
      ),
      borderRadius:BorderRadius.circular(16),
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Wrap(
          spacing:6,
          runSpacing:6,
          children:[
            _chip('⚡ Fast Overview'),
            _chip('🛡️ Safe Offline Work'),
            _chip('📊 Smart Accounts Control'),
            _chip('🔐 AES-GCM-256'),
          ],
        ),
        const SizedBox(height:14),
        const Text(
          'Business Command Dashboard',
          style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900),
        ),
        const SizedBox(height:5),
        const Text(
          'A clean and professional control center for sales, stock, cash, dues, expenses and profit.',
          style:TextStyle(color:Color(0xFFCBD5E1),height:1.35),
        ),
        const SizedBox(height:14),
        Wrap(
          spacing:7,
          runSpacing:7,
          children:[
            _quick('🛒','New Sale',AppPage.saleInvoice,const SalesPage()),
            _quick('📦','Add Product',AppPage.products,const ProductsPage()),
            _quick('👥','Add Customer',AppPage.customers,const PartyPage(type:PartyType.customer)),
            _quick('🧾','Add Expense',AppPage.expenses,const ExpensesPage()),
            _quick('📊','View Reports',AppPage.reports,const ReportsPage()),
            _quick('⚙️','Settings',AppPage.safetyCenter,const SafetyCenterPage()),
          ],
        ),
        const SizedBox(height:14),
        Row(
          children:[
            Expanded(child:_heroMini('Today',DateFormat('yyyy-MM-dd').format(now),'Live business date')),
            const SizedBox(width:8),
            Expanded(child:_heroMini('Current Time',DateFormat('HH:mm:ss').format(now),'Offline 24-hour clock')),
            const SizedBox(width:8),
            Expanded(child:_heroMini('System Status','OFFLINE READY','Local encrypted DB')),
          ],
        ),
      ],
    ),
  );

  Widget _chip(String text)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
    decoration:BoxDecoration(
      color:Colors.white.withValues(alpha:.10),
      borderRadius:BorderRadius.circular(999),
      border:Border.all(color:Colors.white.withValues(alpha:.12)),
    ),
    child:Text(text,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700)),
  );

  Widget _quick(String emoji,String label,AppPage page,Widget widget)=>FilledButton.tonal(
    onPressed:()=>_go(page,widget),
    style:FilledButton.styleFrom(
      minimumSize:const Size(0,40),
      backgroundColor:Colors.white.withValues(alpha:.12),
      foregroundColor:Colors.white,
    ),
    child:Text('$emoji  $label'),
  );

  Widget _heroMini(String label,String value,String note)=>Container(
    padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(
      color:Colors.white.withValues(alpha:.08),
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:Colors.white.withValues(alpha:.10)),
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text(label,maxLines:1,style:const TextStyle(color:Color(0xFF94A3B8),fontSize:9,fontWeight:FontWeight.w700)),
        const SizedBox(height:4),
        Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(note,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFF94A3B8),fontSize:8)),
      ],
    ),
  );

  Widget _ownerSummary(BuildContext context,Map<String,dynamic> x)=>GridView.count(
    crossAxisCount:2,
    shrinkWrap:true,
    physics:const NeverScrollableScrollPhysics(),
    mainAxisSpacing:8,
    crossAxisSpacing:8,
    childAspectRatio:1.65,
    children:[
      _kpi(context,'My Stock',x['stock'],Icons.inventory_2_outlined),
      _kpi(context,'My Cash',x['cash'],Icons.payments_outlined),
      _kpi(context,'Owed To Me',x['receivable'],Icons.call_received_rounded),
      _kpi(context,'I Owe',x['payable'],Icons.call_made_rounded),
      _kpi(context,'Net Business Worth',x['position'],Icons.account_balance_rounded),
      Card(
        child:InkWell(
          borderRadius:BorderRadius.circular(16),
          onTap:shareBusinessReport,
          child:const Padding(
            padding:EdgeInsets.all(12),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,
              children:[
                Icon(Icons.chat_rounded,color:Color(0xFF0D9488)),
                SizedBox(height:7),
                Text('WhatsApp All Debts',style:TextStyle(fontWeight:FontWeight.w900)),
                Text('Share business debt report',style:TextStyle(fontSize:10,color:Color(0xFF64748B))),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _coreHighlights(BuildContext context,Map<String,dynamic> x)=>GridView.count(
    crossAxisCount:2,
    shrinkWrap:true,
    physics:const NeverScrollableScrollPhysics(),
    mainAxisSpacing:8,
    crossAxisSpacing:8,
    childAspectRatio:1.55,
    children:[
      _kpi(context,'Total Net Sales',x['sales'],Icons.point_of_sale_rounded),
      _kpi(context,'Stock Value',x['stock'],Icons.inventory_rounded),
      _kpi(context,'Customer Receivable',x['receivable'],Icons.groups_rounded),
      _kpi(context,'Supplier Payable',x['payable'],Icons.local_shipping_rounded),
    ],
  );

  Widget _secondaryHighlights(BuildContext context,Map<String,dynamic> x)=>GridView.count(
    crossAxisCount:2,
    shrinkWrap:true,
    physics:const NeverScrollableScrollPhysics(),
    mainAxisSpacing:8,
    crossAxisSpacing:8,
    childAspectRatio:1.7,
    children:[
      _kpi(context,'Discounts',x['discounts'],Icons.discount_outlined),
      _kpi(context,'Expenses',x['expenses'],Icons.receipt_long_outlined),
      _kpi(context,'Salesman Loan Outstanding',x['salesmanLoans'],Icons.badge_outlined),
      _kpi(context,'Calculated Cash Balance',x['cash'],Icons.account_balance_wallet_outlined),
    ],
  );

  Widget _businessPosition(BuildContext context,Map<String,dynamic> x)=>Container(
    padding:const EdgeInsets.all(16),
    decoration:BoxDecoration(
      color:Theme.of(context).cardColor,
      borderRadius:BorderRadius.circular(16),
      border:Border.all(color:const Color(0xFFDFE4EE)),
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('Business Position',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
        const SizedBox(height:6),
        const Text('Customer Receivable + Stock + Cash − Supplier Payable − Owner / Partner Money'),
        const SizedBox(height:12),
        Text(
          _m(x['position']),
          style:TextStyle(
            fontSize:30,
            fontWeight:FontWeight.w900,
            color:_d(x['position'])>=0?QamvioUi.success:QamvioUi.danger,
          ),
        ),
      ],
    ),
  );

  Widget _today(BuildContext context,Map<String,dynamic> x)=>GridView.count(
    crossAxisCount:2,
    shrinkWrap:true,
    physics:const NeverScrollableScrollPhysics(),
    mainAxisSpacing:8,
    crossAxisSpacing:8,
    childAspectRatio:1.7,
    children:[
      _kpi(context,'Today Net Sales',x['todaySales'],Icons.shopping_cart_checkout_rounded),
      _kpi(context,'Today Cash Received',x['todayCash'],Icons.payments_rounded),
      _kpi(context,'Today Expenses',x['todayExpenses'],Icons.receipt_long_rounded),
      _kpi(context,'Today Estimated Net Profit',x['todayProfit'],Icons.trending_up_rounded),
    ],
  );

  Widget _week(BuildContext context,Map<String,dynamic> x)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        children:[
          _compare('Sales',_d(x['weekSales']),_d(x['prevSales'])),
          const Divider(height:22),
          _compare('Profit',_d(x['weekProfit']),_d(x['prevProfit'])),
        ],
      ),
    ),
  );

  Widget _compare(String label,double current,double previous) {
    final pct=previous==0?(current==0?0:100):((current-previous)/previous*100);
    return Row(
      children:[
        Expanded(child:Text(label,style:const TextStyle(fontWeight:FontWeight.w900))),
        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text('This week  ${_m(current)}',style:const TextStyle(fontWeight:FontWeight.w800)),
          Text('Last week  ${_m(previous)}',style:const TextStyle(fontSize:11,color:Color(0xFF64748B))),
        ]),
        const SizedBox(width:12),
        Text(
          '${pct>=0?'+':''}${pct.toStringAsFixed(1)}%',
          style:TextStyle(fontWeight:FontWeight.w900,color:pct>=0?QamvioUi.success:QamvioUi.danger),
        ),
      ],
    );
  }

  Widget _analytics(BuildContext context,Map<String,dynamic> x)=>Column(
    children:[
      _barCard(
        context,
        '7-day Sales & Profit Trend',
        [
          for(final d in (x['days'] as List<Map<String,dynamic>>))
            _BarItem(d['label'].toString(),_d(d['sales']),_d(d['profit'])),
        ],
        secondLabel:'Profit',
      ),
      const SizedBox(height:8),
      _singleBarCard(
        context,
        'Expense Mix',
        [
          for(final e in (x['expenseMix'] as List<Map<String,Object?>>))
            _OneBar(e['category'].toString(),_d(e['amount'])),
        ],
      ),
      const SizedBox(height:8),
      _singleBarCard(
        context,
        'Top Selling Products',
        [
          for(final e in (x['topProducts'] as List<Map<String,Object?>>))
            _OneBar(e['name'].toString(),_d(e['qty'])),
        ],
      ),
      const SizedBox(height:8),
      _singleBarCard(
        context,
        'Accounts Position',
        [
          _OneBar('Customer Receivable',_d(x['receivable'])),
          _OneBar('Supplier Payable',_d(x['payable'])),
          _OneBar('Salesman Outstanding',_d(x['salesmanLoans'])),
        ],
      ),
    ],
  );

  Widget _lowStock(BuildContext context,Map<String,dynamic> x) {
    final rows=x['lowStock'] as List<Map<String,Object?>>;
    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:rows.isEmpty?const Color(0xFFECFDF5):const Color(0xFFFFF7ED),
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:rows.isEmpty?const Color(0xFF86EFAC):const Color(0xFFFDBA74)),
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(
            rows.isEmpty?'✓ Low Stock Alert — All Good':'⚠ Low Stock Alert',
            style:TextStyle(
              fontWeight:FontWeight.w900,
              color:rows.isEmpty?const Color(0xFF166534):const Color(0xFF9A3412),
            ),
          ),
          if(rows.isNotEmpty) ...[
            const SizedBox(height:8),
            for(final r in rows)
              Padding(
                padding:const EdgeInsets.only(bottom:4),
                child:Row(
                  children:[
                    Expanded(child:Text(r['name'].toString())),
                    Text('Stock ${_m(r['stock'])} / Reorder ${_m(r['reorder_level'])}',style:const TextStyle(fontWeight:FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _activityTable(BuildContext context,List<Map<String,Object?>> rows,{required bool today})=>Card(
    child:rows.isEmpty
      ?const Padding(
        padding:EdgeInsets.all(18),
        child:Text('No activity found.'),
      )
      :Column(
        children:[
          for(var i=0;i<rows.length;i++) ...[
            ListTile(
              dense:true,
              leading:Icon(today?Icons.receipt_long_rounded:_activityIcon(rows[i]['type']?.toString()??'')),
              title:Text(
                rows[i]['label']?.toString()??'',
                style:const TextStyle(fontWeight:FontWeight.w800),
              ),
              subtitle:Text(rows[i]['date']?.toString()??rows[i]['created_at']?.toString()??''),
              trailing:Text(_m(rows[i]['amount']),style:const TextStyle(fontWeight:FontWeight.w900)),
            ),
            if(i<rows.length-1) const Divider(),
          ],
        ],
      ),
  );

  IconData _activityIcon(String type)=>switch(type){
    'Sale'=>Icons.point_of_sale_rounded,
    'Purchase'=>Icons.shopping_cart_checkout_rounded,
    'Expense'=>Icons.receipt_long_rounded,
    _=>Icons.history_rounded,
  };

  Widget _dueList(BuildContext context,List<Map<String,Object?>> rows,String valueKey)=>Card(
    child:rows.isEmpty
      ?const Padding(padding:EdgeInsets.all(18),child:Text('No outstanding dues.'))
      :Column(
        children:[
          for(var i=0;i<rows.length;i++) ...[
            ListTile(
              dense:true,
              title:Text(rows[i]['name']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w800)),
              trailing:Text(_m(rows[i][valueKey]),style:const TextStyle(fontWeight:FontWeight.w900,color:QamvioUi.danger)),
            ),
            if(i<rows.length-1) const Divider(),
          ],
        ],
      ),
  );

  Widget _kpi(BuildContext context,String label,dynamic value,IconData icon)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisAlignment:MainAxisAlignment.center,
        children:[
          Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:7),
          Text(
            _m(value),
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900),
          ),
          const SizedBox(height:2),
          Text(label,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
        ],
      ),
    ),
  );

  Widget _barCard(BuildContext context,String title,List<_BarItem> rows,{String secondLabel='Second'}) {
    final max=rows.fold<double>(0,(m,x)=>[m,x.a.abs(),x.b.abs()].reduce((a,b)=>a>b?a:b));
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            for(final r in rows)
              Padding(
                padding:const EdgeInsets.only(bottom:7),
                child:Row(
                  children:[
                    SizedBox(width:38,child:Text(r.label,style:const TextStyle(fontSize:10))),
                    Expanded(
                      child:Column(
                        children:[
                          LinearProgressIndicator(value:max==0?0:r.a.abs()/max,minHeight:7,borderRadius:BorderRadius.circular(8)),
                          const SizedBox(height:3),
                          LinearProgressIndicator(value:max==0?0:r.b.abs()/max,minHeight:4,borderRadius:BorderRadius.circular(8)),
                        ],
                      ),
                    ),
                    const SizedBox(width:7),
                    SizedBox(width:68,child:Text(_m(r.a),textAlign:TextAlign.end,style:const TextStyle(fontSize:9))),
                  ],
                ),
              ),
            Text('Primary = Sales • Secondary = $secondLabel',style:const TextStyle(fontSize:9,color:Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _singleBarCard(BuildContext context,String title,List<_OneBar> rows) {
    final max=rows.fold<double>(0,(m,x)=>x.value.abs()>m?x.value.abs():m);
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            if(rows.isEmpty)
              const Text('No data.')
            else
              for(final r in rows)
                Padding(
                  padding:const EdgeInsets.only(bottom:8),
                  child:Row(
                    children:[
                      SizedBox(
                        width:115,
                        child:Text(r.label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10)),
                      ),
                      Expanded(
                        child:LinearProgressIndicator(
                          value:max==0?0:r.value.abs()/max,
                          minHeight:7,
                          borderRadius:BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width:7),
                      SizedBox(width:62,child:Text(_m(r.value),textAlign:TextAlign.end,style:const TextStyle(fontSize:9))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double a;
  final double b;
  const _BarItem(this.label,this.a,this.b);
}

class _OneBar {
  final String label;
  final double value;
  const _OneBar(this.label,this.value);
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.only(bottom:8),
    child:Text(text,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
  );
}

class V15NavigationDrawer extends StatelessWidget {
  final Future<void> Function(AppPage,Widget) onNavigate;
  final AppStrings strings;

  const V15NavigationDrawer({
    required this.onNavigate,
    required this.strings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final auth=LocalAuthService.instance;
    final user=auth.current;
    final items=<({AppPage page,String label,IconData icon,Widget widget})>[
      (page:AppPage.quickSearch,label:'Quick Search',icon:Icons.manage_search_rounded,widget:const QuickSearchPage()),
      (page:AppPage.saleInvoice,label:'Sales / Cash Report',icon:Icons.point_of_sale_rounded,widget:const SalesPage()),
      (page:AppPage.fuelPump,label:'⛽ Fuel / Oil Pump',icon:Icons.local_gas_station_rounded,widget:const FuelPage()),
      (page:AppPage.stock,label:'Stock',icon:Icons.inventory_2_rounded,widget:const StockPage()),
      (page:AppPage.stockLedger,label:'Stock Ledger',icon:Icons.format_list_numbered_rounded,widget:const StockLedgerPage()),
      (page:AppPage.products,label:'Products',icon:Icons.widgets_rounded,widget:const ProductsPage()),
      (page:AppPage.purchases,label:'Purchases',icon:Icons.shopping_cart_checkout_rounded,widget:const PurchasesPage()),
      (page:AppPage.discounts,label:'Discount Report',icon:Icons.discount_rounded,widget:const DiscountReportPage()),
      (page:AppPage.salesmen,label:'Salesmen',icon:Icons.badge_rounded,widget:const SalesmenPage()),
      (page:AppPage.customers,label:'Customers',icon:Icons.groups_rounded,widget:const PartyPage(type:PartyType.customer)),
      (page:AppPage.customerLoans,label:'Customer Loans',icon:Icons.person_add_alt_1_rounded,widget:const CustomerLoansV15Page()),
      (page:AppPage.customerStatement,label:'Customer Statement',icon:Icons.receipt_long_rounded,widget:const CustomerStatementPage()),
      (page:AppPage.suppliers,label:'Suppliers',icon:Icons.local_shipping_rounded,widget:const PartyPage(type:PartyType.supplier)),
      (page:AppPage.supplierStatement,label:'Supplier Statement',icon:Icons.description_rounded,widget:const SupplierStatementPage()),
      (page:AppPage.expenses,label:'Expenses',icon:Icons.receipt_long_rounded,widget:const ExpensesPage()),
      (page:AppPage.salesmanLoans,label:'Salesman Loans',icon:Icons.credit_score_rounded,widget:const SalesmanLoansV15Page()),
      (page:AppPage.salesmanStatement,label:'Salesman Statement',icon:Icons.assignment_ind_rounded,widget:const SalesmanStatementPage()),
      (page:AppPage.capital,label:'Owner / Partner Money',icon:Icons.account_balance_rounded,widget:const CapitalPage()),
      (page:AppPage.dailyClosing,label:'Daily Closing',icon:Icons.event_available_rounded,widget:const DailyClosingPage()),
      (page:AppPage.cashBook,label:'Cash Book',icon:Icons.menu_book_rounded,widget:const CashBookPage()),
      (page:AppPage.reports,label:'Reports',icon:Icons.analytics_rounded,widget:const ReportsPage()),
      (page:AppPage.recycleBin,label:'Recycle Bin',icon:Icons.recycling_rounded,widget:const RecycleBinPage()),
      (page:AppPage.deleteEntry,label:'Delete Entry',icon:Icons.delete_sweep_rounded,widget:const DeleteEntryPage()),
      (page:AppPage.safetyCenter,label:'Safety Center',icon:Icons.shield_rounded,widget:const SafetyCenterPage()),
      (page:AppPage.userManagement,label:'Users / Login',icon:Icons.manage_accounts_rounded,widget:const UsersPage()),
      (page:AppPage.backup,label:'Backup / Restore',icon:Icons.cloud_sync_rounded,widget:const CloudPage()),
    ];

    return Drawer(
      backgroundColor:const Color(0xFF111827),
      child:SafeArea(
        child:ListView(
          padding:const EdgeInsets.fromLTRB(10,8,10,20),
          children:[
            const Padding(
              padding:EdgeInsets.fromLTRB(10,8,10,12),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('QAMVIO POS',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
                  SizedBox(height:3),
                  Text('Offline Point of Sale & Business Management',style:TextStyle(color:Color(0xFF94A3B8),fontSize:10)),
                ],
              ),
            ),
            _languageSwitch(context),
            const SizedBox(height:8),
            _clockBox(),
            const SizedBox(height:8),
            Container(
              margin:const EdgeInsets.symmetric(horizontal:4),
              padding:const EdgeInsets.all(9),
              decoration:BoxDecoration(
                color:const Color(0xFF1F2937),
                borderRadius:BorderRadius.circular(9),
                border:Border.all(color:const Color(0xFF334155)),
              ),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  const Text('SIGNED IN',style:TextStyle(color:Color(0xFF94A3B8),fontSize:10)),
                  const SizedBox(height:2),
                  Text(user?.loginId??'—',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),
                  Text(user?.role.label??'—',style:const TextStyle(color:Color(0xFFCBD5E1),fontSize:10)),
                  const SizedBox(height:7),
                  Row(
                    children:[
                      Expanded(
                        child:_smallAction(
                          'Lock',
                          ()async {
                            Navigator.pop(context);
                            try { await CloudBackupService.instance.prepareBackupFile(); } catch(_) {}
                            await LocalAuthService.instance.logout();
                          },
                        ),
                      ),
                      const SizedBox(width:5),
                      Expanded(
                        child:_smallAction(
                          'Logout',
                          ()async {
                            Navigator.pop(context);
                            try { await CloudBackupService.instance.prepareBackupFile(); } catch(_) {}
                            await LocalAuthService.instance.logout();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height:8),
            _navButton(
              context,
              'Dashboard',
              Icons.dashboard_rounded,
              true,
              ()=>Navigator.pop(context),
            ),
            for(final item in items)
              if(Permissions.canOpen(item.page))
                _navButton(
                  context,
                  item.label,
                  item.icon,
                  false,
                  () {
                    Navigator.pop(context);
                    onNavigate(item.page,item.widget);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _languageSwitch(BuildContext context) {
    final lc=LanguageController.instance;
    Widget button(String text,AppLanguage lang)=>Expanded(
      child:TextButton(
        style:TextButton.styleFrom(
          foregroundColor:lc.language==lang?Colors.white:const Color(0xFF94A3B8),
          backgroundColor:lc.language==lang?const Color(0xFF4F46E5):Colors.transparent,
          padding:const EdgeInsets.symmetric(vertical:6),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(6)),
        ),
        onPressed:()=>lc.setLanguage(lang),
        child:Text(text,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)),
      ),
    );
    return Container(
      margin:const EdgeInsets.symmetric(horizontal:4),
      padding:const EdgeInsets.all(4),
      decoration:BoxDecoration(
        color:const Color(0xFF1F2937),
        borderRadius:BorderRadius.circular(9),
        border:Border.all(color:const Color(0xFF334155)),
      ),
      child:Row(
        children:[
          button('EN',AppLanguage.english),
          button('PS',AppLanguage.pashto),
          button('FA',AppLanguage.dari),
          button('UR',AppLanguage.urdu),
        ],
      ),
    );
  }

  Widget _clockBox()=>Builder(
    builder:(context) {
      final t=DateTime.now();
      return Container(
        margin:const EdgeInsets.symmetric(horizontal:4),
        padding:const EdgeInsets.all(9),
        decoration:BoxDecoration(
          color:const Color(0xFF1F2937),
          borderRadius:BorderRadius.circular(9),
          border:Border.all(color:const Color(0xFF334155)),
        ),
        child:Column(
          children:[
            const Text('OFFLINE 24-HOUR CLOCK',style:TextStyle(color:Color(0xFF94A3B8),fontSize:9)),
            const SizedBox(height:2),
            Text(DateFormat('HH:mm:ss').format(t),style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
            Text(DateFormat('yyyy-MM-dd').format(t),style:const TextStyle(color:Color(0xFFCBD5E1),fontSize:9)),
          ],
        ),
      );
    },
  );

  Widget _smallAction(String label,VoidCallback action)=>TextButton(
    style:TextButton.styleFrom(
      backgroundColor:const Color(0xFF334155),
      foregroundColor:Colors.white,
      padding:const EdgeInsets.symmetric(vertical:5),
      minimumSize:const Size(0,30),
    ),
    onPressed:action,
    child:Text(label,style:const TextStyle(fontSize:10)),
  );

  Widget _navButton(
    BuildContext context,
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
  )=>Padding(
    padding:const EdgeInsets.only(bottom:2),
    child:ListTile(
      dense:true,
      minLeadingWidth:24,
      selected:active,
      selectedTileColor:const Color(0xFF1F2937),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),
      leading:Icon(icon,size:18,color:active?const Color(0xFF818CF8):const Color(0xFFCBD5E1)),
      title:Text(
        label,
        style:TextStyle(
          color:Colors.white,
          fontSize:12,
          fontWeight:active?FontWeight.w800:FontWeight.w600,
        ),
      ),
      onTap:onTap,
    ),
  );
}
