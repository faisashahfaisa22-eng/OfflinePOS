import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import '../expenses/expenses_page.dart';
import '../parties/party_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_page.dart';
import '../salesmen/salesmen_page.dart';
import '../v15/finance_pages.dart';

double _n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
String _m(dynamic v)=>QamvioUi.money(v);
String _day(DateTime d)=>DateFormat('yyyy-MM-dd').format(d);

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState()=>_FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  List<Map<String,Object?>> tanks=const [];
  List<Map<String,Object?>> nozzles=const [];
  List<Map<String,Object?>> products=const [];
  List<Map<String,Object?>> suppliers=const [];
  List<Map<String,Object?>> salesmen=const [];
  List<Map<String,Object?>> customers=const [];
  List<Map<String,Object?>> shifts=const [];
  List<Map<String,Object?>> deliveries=const [];
  bool loading=true;

  bool get admin=>LocalAuthService.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final t=await db.rawQuery(
      'SELECT t.*,p.name product_name FROM fuel_tanks t '
      'LEFT JOIN products p ON p.id=t.product_id ORDER BY t.name',
    );
    final n=await db.rawQuery(
      'SELECT n.*,t.name tank_name,p.name product_name FROM fuel_nozzles n '
      'JOIN fuel_tanks t ON t.id=n.tank_id '
      'LEFT JOIN products p ON p.id=t.product_id ORDER BY n.name',
    );
    final p=await db.query('products',orderBy:'name COLLATE NOCASE');
    final sup=await db.query('suppliers',orderBy:'name COLLATE NOCASE');
    final sm=await db.query('salesmen',orderBy:'name COLLATE NOCASE');
    final cust=await db.query('customers',orderBy:'name COLLATE NOCASE');
    final sh=await db.rawQuery(
      'SELECT f.*,n.name nozzle_name,t.name tank_name,sm.name salesman_name,c.name customer_name '
      'FROM fuel_shifts f JOIN fuel_nozzles n ON n.id=f.nozzle_id '
      'LEFT JOIN fuel_tanks t ON t.id=f.tank_id '
      'LEFT JOIN salesmen sm ON sm.id=f.salesman_id '
      'LEFT JOIN customers c ON c.id=f.customer_id '
      'ORDER BY f.started_at DESC LIMIT 100',
    );
    final d=await db.rawQuery(
      "SELECT p.*,s.name supplier_name,t.name tank_name,"
      "(SELECT COALESCE(SUM(pi.qty),0) FROM purchase_items pi WHERE pi.purchase_id=p.id) liters,"
      "(SELECT COALESCE(MAX(pi.cost),0) FROM purchase_items pi WHERE pi.purchase_id=p.id) cost_per_liter "
      "FROM purchases p LEFT JOIN suppliers s ON s.id=p.supplier_id "
      "LEFT JOIN fuel_tanks t ON t.id=p.fuel_tank_id "
      "WHERE p.source='fuel_delivery' ORDER BY p.created_at DESC LIMIT 100",
    );
    if(!mounted) return;
    setState(() {
      tanks=t;
      nozzles=n;
      products=p;
      suppliers=sup;
      salesmen=sm;
      customers=cust;
      shifts=sh;
      deliveries=d;
      loading=false;
    });
  }

  Future<void> seedFuelProducts() async {
    final db=await AppDatabase.instance.database;
    for(final name in ['Petrol','Diesel']) {
      final found=await db.query('products',where:'lower(name)=lower(?)',whereArgs:[name],limit:1);
      if(found.isEmpty) {
        await AppDatabase.instance.saveProduct(
          id:DateTime.now().microsecondsSinceEpoch.toString()+name,
          name:name,
          category:'Fuel',
          unit:'L',
        );
      }
    }
    await load();
  }

  Future<void> tankDialog([Map<String,Object?>? existing]) async {
    if(!admin) return;
    if(products.isEmpty) {
      await seedFuelProducts();
      if(!mounted) return;
      if(products.isEmpty) return;
    }
    final name=TextEditingController(text:existing?['name']?.toString()??'');
    final capacity=TextEditingController(text:_m(existing?['capacity']??0));
    final opening=TextEditingController(text:_m(existing?['opening_liters']??0));
    final note=TextEditingController(text:existing?['note']?.toString()??'');
    String productId=existing?['product_id']?.toString()??products.first['id'].toString();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:Text(existing==null?'Fuel Tanks':'Edit Fuel Tank'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                TextField(controller:name,decoration:const InputDecoration(labelText:'Tank Name')),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:productId,
                  decoration:const InputDecoration(labelText:'Fuel Product'),
                  items:[
                    for(final p in products)
                      DropdownMenuItem(value:p['id'].toString(),child:Text(p['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>productId=v??productId),
                ),
                const SizedBox(height:10),
                TextField(controller:capacity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Capacity (L)')),
                const SizedBox(height:10),
                TextField(controller:opening,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening Liters')),
                const SizedBox(height:10),
                TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(existing==null?'Save Tank':'Update Tank')),
          ],
        ),
      ),
    );
    if(ok==true&&name.text.trim().isNotEmpty) {
      await AppDatabase.instance.saveFuelTank(
        id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
        name:name.text.trim(),
        productId:productId,
        capacity:double.tryParse(capacity.text.trim())??0,
        openingLiters:double.tryParse(opening.text.trim())??0,
        note:note.text.trim(),
      );
      await load();
    }
    name.dispose();
    capacity.dispose();
    opening.dispose();
    note.dispose();
  }

  Future<void> nozzleDialog([Map<String,Object?>? existing]) async {
    if(!admin||tanks.isEmpty) return;
    final name=TextEditingController(text:existing?['name']?.toString()??'');
    final opening=TextEditingController(text:_m(existing?['opening_meter']??0));
    final note=TextEditingController(text:existing?['note']?.toString()??'');
    String tankId=existing?['tank_id']?.toString()??tanks.first['id'].toString();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:Text(existing==null?'Pumps / Nozzles':'Edit Nozzle'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                TextField(controller:name,decoration:const InputDecoration(labelText:'Nozzle / Pump Name')),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:tankId,
                  decoration:const InputDecoration(labelText:'Tank'),
                  items:[
                    for(final t in tanks)
                      DropdownMenuItem(value:t['id'].toString(),child:Text(t['name'].toString())),
                  ],
                  onChanged:(v)=>setLocal(()=>tankId=v??tankId),
                ),
                const SizedBox(height:10),
                TextField(controller:opening,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening Meter')),
                const SizedBox(height:10),
                TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(existing==null?'Save Nozzle':'Update Nozzle')),
          ],
        ),
      ),
    );
    if(ok==true&&name.text.trim().isNotEmpty) {
      await AppDatabase.instance.saveFuelNozzle(
        id:existing?['id']?.toString()??DateTime.now().microsecondsSinceEpoch.toString(),
        tankId:tankId,
        name:name.text.trim(),
        openingMeter:double.tryParse(opening.text.trim())??0,
        note:note.text.trim(),
      );
      await load();
    }
    name.dispose();
    opening.dispose();
    note.dispose();
  }

  Future<void> deliveryDialog() async {
    if(!admin||tanks.isEmpty||suppliers.isEmpty) return;
    DateTime date=DateTime.now();
    String supplierId=suppliers.first['id'].toString();
    String tankId=tanks.first['id'].toString();
    final invoice=TextEditingController();
    final liters=TextEditingController();
    final cost=TextEditingController();
    final paid=TextEditingController(text:'0');
    final note=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Fuel Purchase / Tank Delivery'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Date'),
                  subtitle:Text(_day(date)),
                  trailing:const Icon(Icons.calendar_month_outlined),
                  onTap:() async {
                    final d=await showDatePicker(context:ctx,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:date);
                    if(d!=null) setLocal(()=>date=d);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue:supplierId,
                  decoration:const InputDecoration(labelText:'Supplier'),
                  items:[for(final x in suppliers) DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString()))],
                  onChanged:(v)=>setLocal(()=>supplierId=v??supplierId),
                ),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:tankId,
                  decoration:const InputDecoration(labelText:'Tank'),
                  items:[for(final x in tanks) DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString()))],
                  onChanged:(v)=>setLocal(()=>tankId=v??tankId),
                ),
                const SizedBox(height:10),
                TextField(controller:invoice,decoration:const InputDecoration(labelText:'Invoice No')),
                const SizedBox(height:10),
                TextField(controller:liters,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Liters')),
                const SizedBox(height:10),
                TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cost / Liter')),
                const SizedBox(height:10),
                TextField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Paid')),
                const SizedBox(height:10),
                TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save Fuel Delivery')),
          ],
        ),
      ),
    );
    if(ok==true) {
      final l=double.tryParse(liters.text.trim())??0;
      final co=double.tryParse(cost.text.trim())??0;
      if(l>0) {
        await AppDatabase.instance.createFuelDelivery(
          id:DateTime.now().microsecondsSinceEpoch.toString(),
          supplierId:supplierId,
          tankId:tankId,
          liters:l,
          costPerLiter:co,
          paid:double.tryParse(paid.text.trim())??0,
          invoiceNo:invoice.text.trim(),
          note:note.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    invoice.dispose();
    liters.dispose();
    cost.dispose();
    paid.dispose();
    note.dispose();
  }

  Future<void> meterSaleDialog() async {
    if(nozzles.isEmpty) return;
    DateTime date=DateTime.now();
    String nozzleId=nozzles.first['id'].toString();
    String salesmanId='';
    String customerId='';
    final shift=TextEditingController();
    final invoice=TextEditingController();
    final opening=TextEditingController(text:_m(nozzles.first['meter_reading']));
    final closing=TextEditingController();
    final price=TextEditingController(text:_m(nozzles.first['price_per_unit']));
    final cash=TextEditingController(text:'0');
    final note=TextEditingController();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal) {
          final liters=(_n(closing.text)-_n(opening.text)).clamp(0,double.infinity).toDouble();
          final gross=liters*_n(price.text);
          final due=(gross-_n(cash.text)).clamp(0,double.infinity).toDouble();
          final recovery=(_n(cash.text)-gross).clamp(0,double.infinity).toDouble();
          return AlertDialog(
            title:const Text('Nozzle Meter Sale / Shift'),
            content:SingleChildScrollView(
              child:Column(
                mainAxisSize:MainAxisSize.min,
                children:[
                  ListTile(
                    contentPadding:EdgeInsets.zero,
                    title:const Text('Date'),
                    subtitle:Text(_day(date)),
                    trailing:const Icon(Icons.calendar_month_outlined),
                    onTap:() async {
                      final d=await showDatePicker(context:ctx,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:date);
                      if(d!=null) setLocal(()=>date=d);
                    },
                  ),
                  TextField(controller:shift,decoration:const InputDecoration(labelText:'Shift',hintText:'Morning / Evening / Night')),
                  const SizedBox(height:10),
                  DropdownButtonFormField<String>(
                    initialValue:nozzleId,
                    decoration:const InputDecoration(labelText:'Nozzle'),
                    items:[for(final x in nozzles) DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString()))],
                    onChanged:(v) {
                      nozzleId=v??nozzleId;
                      final n=nozzles.firstWhere((x)=>x['id'].toString()==nozzleId);
                      opening.text=_m(n['meter_reading']);
                      price.text=_m(n['price_per_unit']);
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(height:10),
                  TextField(controller:invoice,decoration:const InputDecoration(labelText:'Invoice No',hintText:'Auto if blank')),
                  const SizedBox(height:10),
                  DropdownButtonFormField<String>(
                    initialValue:salesmanId,
                    decoration:const InputDecoration(labelText:'Salesman'),
                    items:[
                      const DropdownMenuItem(value:'',child:Text('Select Salesman')),
                      for(final x in salesmen) DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                    ],
                    onChanged:(v)=>setLocal(()=>salesmanId=v??''),
                  ),
                  const SizedBox(height:10),
                  DropdownButtonFormField<String>(
                    initialValue:customerId,
                    decoration:const InputDecoration(labelText:'Customer'),
                    items:[
                      const DropdownMenuItem(value:'',child:Text('Select Customer')),
                      for(final x in customers.where((c)=>salesmanId.isEmpty||c['salesman_id']?.toString()==salesmanId))
                        DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString())),
                    ],
                    onChanged:(v)=>setLocal(()=>customerId=v??''),
                  ),
                  const SizedBox(height:10),
                  TextField(controller:opening,onChanged:(_)=>setLocal(() {}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening Meter')),
                  const SizedBox(height:10),
                  TextField(controller:closing,onChanged:(_)=>setLocal(() {}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Closing Meter')),
                  const SizedBox(height:10),
                  TextField(controller:price,onChanged:(_)=>setLocal(() {}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Price / Liter')),
                  const SizedBox(height:10),
                  TextField(controller:cash,onChanged:(_)=>setLocal(() {}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cash Received')),
                  const SizedBox(height:10),
                  TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
                  const SizedBox(height:12),
                  Wrap(
                    spacing:8,
                    runSpacing:8,
                    children:[
                      _small('Liters Sold',liters),
                      _small('Gross Amount',gross),
                      _small('Due',due),
                      _small('Recovery',recovery),
                    ],
                  ),
                  const SizedBox(height:10),
                  OutlinedButton(
                    onPressed:() {
                      cash.text=_m(gross);
                      setLocal(() {});
                    },
                    child:const Text('Cash = Total'),
                  ),
                ],
              ),
            ),
            actions:[
              TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
              FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save Meter Sale')),
            ],
          );
        },
      ),
    );
    if(ok==true) {
      final o=double.tryParse(opening.text.trim())??0;
      final cl=double.tryParse(closing.text.trim())??0;
      final gross=(cl-o)*_n(price.text);
      if((gross-_n(cash.text)).abs()>0.0001&&customerId.isEmpty&&salesmanId.isEmpty) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Select Customer or Salesman for due/recovery.')),
          );
        }
      } else {
        await AppDatabase.instance.createFuelShift(
          id:DateTime.now().microsecondsSinceEpoch.toString(),
          nozzleId:nozzleId,
          salesmanId:salesmanId.isEmpty?null:salesmanId,
          customerId:customerId.isEmpty?null:customerId,
          shiftName:shift.text.trim(),
          invoiceNo:invoice.text.trim(),
          openingMeter:o,
          closingMeter:cl,
          pricePerLiter:double.tryParse(price.text.trim())??0,
          cashReceived:double.tryParse(cash.text.trim())??0,
          note:note.text.trim(),
          businessDate:date,
        );
        await load();
      }
    }
    shift.dispose();
    invoice.dispose();
    opening.dispose();
    closing.dispose();
    price.dispose();
    cash.dispose();
    note.dispose();
  }

  Future<void> fuelClosing() async {
    if(!admin) return;
    final opening=TextEditingController(text:'0');
    final cashIn=TextEditingController(text:'0');
    final cashOut=TextEditingController(text:'0');
    final actual=TextEditingController(text:'0');
    final note=TextEditingController();
    DateTime date=DateTime.now();
    final ok=await showDialog<bool>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,setLocal)=>AlertDialog(
          title:const Text('Fuel Daily Closing'),
          content:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                ListTile(
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Date'),
                  subtitle:Text(_day(date)),
                  onTap:() async {
                    final d=await showDatePicker(context:ctx,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:date);
                    if(d!=null) setLocal(()=>date=d);
                  },
                ),
                TextField(controller:opening,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening Cash')),
                const SizedBox(height:10),
                TextField(controller:cashIn,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cash In')),
                const SizedBox(height:10),
                TextField(controller:cashOut,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cash Out')),
                const SizedBox(height:10),
                TextField(controller:actual,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Actual Cash')),
                const SizedBox(height:10),
                TextField(controller:note,decoration:const InputDecoration(labelText:'Note')),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save Closing')),
          ],
        ),
      ),
    );
    if(ok==true) {
      await AppDatabase.instance.saveFuelClosing(
        id:DateTime.now().microsecondsSinceEpoch.toString(),
        openingCash:_n(opening.text),
        cashIn:_n(cashIn.text),
        cashOut:_n(cashOut.text),
        actualCash:_n(actual.text),
        note:note.text.trim(),
        businessDate:date,
      );
    }
    opening.dispose();
    cashIn.dispose();
    cashOut.dispose();
    actual.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today=_day(DateTime.now());
    final todayShifts=shifts.where((x)=>x['business_date']?.toString()==today).toList();
    final liters=todayShifts.fold<double>(0,(a,x)=>a+_n(x['litres']));
    final sales=todayShifts.fold<double>(0,(a,x)=>a+_n(x['total']));
    final cash=todayShifts.fold<double>(0,(a,x)=>a+_n(x['cash_received']));
    final due=(sales-cash).clamp(0,double.infinity).toDouble();

    return Scaffold(
      appBar:AppBar(title:const Text('⛽ Fuel / Oil Pump Control')),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :ListView(
          padding:QamvioUi.pagePadding,
          children:[
            const Text('⛽ Fuel / Oil Pump Control',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:const Color(0xFFEFF6FF),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:const Color(0xFFBFDBFE)),
              ),
              child:const Text(
                'Fuel-pump mode connects meter sales, fuel deliveries, tank stock, customers, salesmen, '
                'suppliers, expenses, invoices and cash book. Use this page for nozzle meter sales so tank '
                'and product stock stay synchronized.',
              ),
            ),
            const SizedBox(height:8),
            Wrap(
              spacing:7,
              runSpacing:7,
              children:[
                FilledButton(onPressed:()=>_open(const SalesPage()),child:const Text('Sales Invoice')),
                OutlinedButton(onPressed:()=>_open(const PartyPage(type:PartyType.customer)),child:const Text('Customers')),
                OutlinedButton(onPressed:()=>_open(const SalesmenPage()),child:const Text('Salesmen')),
                if(admin) OutlinedButton(onPressed:()=>_open(const PartyPage(type:PartyType.supplier)),child:const Text('Suppliers')),
                if(admin) OutlinedButton(onPressed:()=>_open(const ExpensesPage()),child:const Text('Expenses')),
                if(admin) OutlinedButton(onPressed:()=>_open(const CashBookPage()),child:const Text('Cash Book')),
                if(admin) OutlinedButton(onPressed:()=>_open(const ReportsPage()),child:const Text('Reports')),
              ],
            ),
            const SizedBox(height:12),
            GridView.count(
              crossAxisCount:2,
              shrinkWrap:true,
              physics:const NeverScrollableScrollPhysics(),
              mainAxisSpacing:8,
              crossAxisSpacing:8,
              childAspectRatio:1.7,
              children:[
                QamvioStatCard(label:"Today's Liters Sold",value:_m(liters),icon:Icons.water_drop_outlined),
                QamvioStatCard(label:"Today's Fuel Sales",value:_m(sales),icon:Icons.local_gas_station_outlined),
                QamvioStatCard(label:"Today's Cash Received",value:_m(cash),icon:Icons.payments_outlined),
                QamvioStatCard(label:"Today's Credit / Due",value:_m(due),icon:Icons.account_balance_wallet_outlined),
              ],
            ),
            if(admin) ...[
              const SizedBox(height:14),
              _adminCard(
                title:'Fuel Tanks',
                notice:'Create fuel products first (Petrol, Diesel, etc.), then link each tank to one product. Product opening stock is synchronized from the opening liters of all linked tanks.',
                buttons:[
                  OutlinedButton(onPressed:seedFuelProducts,child:const Text('Create Default Fuel Products')),
                  FilledButton(onPressed:()=>tankDialog(),child:const Text('Save Tank')),
                ],
                table:_tankTable(),
              ),
              const SizedBox(height:12),
              _adminCard(
                title:'Pumps / Nozzles',
                buttons:[FilledButton(onPressed:()=>nozzleDialog(),child:const Text('Save Nozzle'))],
                table:_nozzleTable(),
              ),
              const SizedBox(height:12),
              _adminCard(
                title:'Fuel Purchase / Tank Delivery',
                buttons:[FilledButton(onPressed:deliveryDialog,child:const Text('Save Fuel Delivery'))],
                table:_deliveryTable(),
              ),
            ],
            const SizedBox(height:12),
            Card(
              child:Padding(
                padding:const EdgeInsets.all(14),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Text('Nozzle Meter Sale / Shift',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
                    const SizedBox(height:5),
                    const Text('Closing Meter − Opening Meter = Liters Sold. Saving creates a normal sales invoice automatically and updates stock, balances, reports and cash book.'),
                    const SizedBox(height:10),
                    FilledButton(onPressed:meterSaleDialog,child:const Text('Save Meter Sale')),
                    const SizedBox(height:10),
                    _shiftTable(),
                  ],
                ),
              ),
            ),
            if(admin) ...[
              const SizedBox(height:12),
              Card(
                child:Padding(
                  padding:const EdgeInsets.all(14),
                  child:Wrap(
                    spacing:8,
                    runSpacing:8,
                    children:[
                      FilledButton.icon(onPressed:fuelClosing,icon:const Icon(Icons.event_available_outlined),label:const Text('Fuel Daily Closing')),
                      OutlinedButton.icon(onPressed:()=>_open(const DailyClosingPage()),icon:const Icon(Icons.summarize_outlined),label:const Text('Business Daily Closing')),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
    );
  }

  void _open(Widget page)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>page));

  Widget _small(String label,double value)=>Container(
    width:125,
    padding:const EdgeInsets.all(8),
    decoration:BoxDecoration(
      color:const Color(0xFFF8FAFC),
      borderRadius:BorderRadius.circular(8),
      border:Border.all(color:const Color(0xFFE2E8F0)),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(_m(value),style:const TextStyle(fontWeight:FontWeight.w900)),
      Text(label,style:const TextStyle(fontSize:10)),
    ]),
  );

  Widget _adminCard({
    required String title,
    String? notice,
    required List<Widget> buttons,
    required Widget table,
  })=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
          if(notice!=null) ...[const SizedBox(height:5),Text(notice)],
          const SizedBox(height:10),
          Wrap(spacing:8,runSpacing:8,children:buttons),
          const SizedBox(height:10),
          table,
        ],
      ),
    ),
  );

  Widget _tankTable()=>SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    child:DataTable(
      columns:const [
        DataColumn(label:Text('Tank')),
        DataColumn(label:Text('Product')),
        DataColumn(label:Text('Capacity'),numeric:true),
        DataColumn(label:Text('Opening'),numeric:true),
        DataColumn(label:Text('Current Liters'),numeric:true),
        DataColumn(label:Text('Free Capacity'),numeric:true),
        DataColumn(label:Text('Status')),
        DataColumn(label:Text('')),
      ],
      rows:[
        for(final x in tanks)
          DataRow(cells:[
            DataCell(Text(x['name'].toString())),
            DataCell(Text(x['product_name']?.toString()??'')),
            DataCell(Text(_m(x['capacity']))),
            DataCell(Text(_m(x['opening_liters']))),
            DataCell(Text(_m(x['current_stock']))),
            DataCell(Text(_m((_n(x['capacity'])-_n(x['current_stock'])).clamp(0,double.infinity)))),
            DataCell(Text(_n(x['current_stock'])<=0?'EMPTY':'OK')),
            DataCell(IconButton(onPressed:()=>tankDialog(x),icon:const Icon(Icons.edit_outlined))),
          ]),
      ],
    ),
  );

  Widget _nozzleTable()=>SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    child:DataTable(
      columns:const [
        DataColumn(label:Text('Nozzle')),
        DataColumn(label:Text('Tank')),
        DataColumn(label:Text('Product')),
        DataColumn(label:Text('Last Meter'),numeric:true),
        DataColumn(label:Text('Note')),
        DataColumn(label:Text('')),
      ],
      rows:[
        for(final x in nozzles)
          DataRow(cells:[
            DataCell(Text(x['name'].toString())),
            DataCell(Text(x['tank_name']?.toString()??'')),
            DataCell(Text(x['product_name']?.toString()??'')),
            DataCell(Text(_m(x['meter_reading']))),
            DataCell(Text(x['note']?.toString()??'')),
            DataCell(IconButton(onPressed:()=>nozzleDialog(x),icon:const Icon(Icons.edit_outlined))),
          ]),
      ],
    ),
  );

  Widget _deliveryTable()=>SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    child:DataTable(
      columns:const [
        DataColumn(label:Text('Date')),
        DataColumn(label:Text('Supplier')),
        DataColumn(label:Text('Tank')),
        DataColumn(label:Text('Invoice')),
        DataColumn(label:Text('Liters'),numeric:true),
        DataColumn(label:Text('Cost/L'),numeric:true),
        DataColumn(label:Text('Total'),numeric:true),
        DataColumn(label:Text('Paid'),numeric:true),
      ],
      rows:[
        for(final x in deliveries)
          DataRow(cells:[
            DataCell(Text((x['business_date']??x['created_at']).toString().split('T').first)),
            DataCell(Text(x['supplier_name']?.toString()??'')),
            DataCell(Text(x['tank_name']?.toString()??'')),
            DataCell(Text(x['invoice_no']?.toString()??'')),
            DataCell(Text(_m(x['liters']))),
            DataCell(Text(_m(x['cost_per_liter']))),
            DataCell(Text(_m(x['total']))),
            DataCell(Text(_m(x['paid']))),
          ]),
      ],
    ),
  );

  Widget _shiftTable()=>SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    child:DataTable(
      columns:const [
        DataColumn(label:Text('Date')),
        DataColumn(label:Text('Shift')),
        DataColumn(label:Text('Nozzle')),
        DataColumn(label:Text('Invoice')),
        DataColumn(label:Text('Salesman')),
        DataColumn(label:Text('Customer')),
        DataColumn(label:Text('Opening'),numeric:true),
        DataColumn(label:Text('Closing'),numeric:true),
        DataColumn(label:Text('Liters'),numeric:true),
        DataColumn(label:Text('Price/L'),numeric:true),
        DataColumn(label:Text('Total'),numeric:true),
        DataColumn(label:Text('Cash'),numeric:true),
      ],
      rows:[
        for(final x in shifts)
          DataRow(cells:[
            DataCell(Text((x['business_date']??x['started_at']).toString().split('T').first)),
            DataCell(Text(x['shift_name']?.toString()??'')),
            DataCell(Text(x['nozzle_name']?.toString()??'')),
            DataCell(Text(x['invoice_no']?.toString()??'')),
            DataCell(Text(x['salesman_name']?.toString()??'')),
            DataCell(Text(x['customer_name']?.toString()??'')),
            DataCell(Text(_m(x['opening_meter']))),
            DataCell(Text(_m(x['closing_meter']))),
            DataCell(Text(_m(x['litres']))),
            DataCell(Text(_m(x['price_per_unit']))),
            DataCell(Text(_m(x['total']))),
            DataCell(Text(_m(x['cash_received']))),
          ]),
      ],
    ),
  );
}
