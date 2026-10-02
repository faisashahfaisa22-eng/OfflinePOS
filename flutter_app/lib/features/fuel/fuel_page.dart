import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/ui/qamvio_ui.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState()=>_FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  List<Map<String,Object?>> tanks=const [];
  List<Map<String,Object?>> nozzles=const [];
  List<Map<String,Object?>> shifts=const [];
  bool loading=true;

  Future<void> load() async {
    final db=await AppDatabase.instance.database;
    final a=await db.query('fuel_tanks',orderBy:'name COLLATE NOCASE');
    final b=await db.rawQuery(
      'SELECT n.*,t.name tank_name,t.fuel_type '
      'FROM fuel_nozzles n JOIN fuel_tanks t ON t.id=n.tank_id '
      'ORDER BY n.name COLLATE NOCASE',
    );
    final c=await db.rawQuery(
      'SELECT f.*,n.name nozzle_name,sm.name salesman_name '
      'FROM fuel_shifts f '
      'JOIN fuel_nozzles n ON n.id=f.nozzle_id '
      'LEFT JOIN salesmen sm ON sm.id=f.salesman_id '
      'ORDER BY f.started_at DESC LIMIT 100',
    );
    if(!mounted) return;
    setState(() {
      tanks=a;
      nozzles=b;
      shifts=c;
      loading=false;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  double _n(dynamic v)=>v is num?v.toDouble():double.tryParse('$v')??0;

  double get totalFuel=>tanks.fold<double>(
    0,
    (a,x)=>a+_n(x['current_stock']),
  );

  Future<void> addTank() async {
    final name=TextEditingController();
    final type=TextEditingController(text:'Diesel');
    final capacity=TextEditingController();
    final stock=TextEditingController();

    final ok=await showModalBottomSheet<bool>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>Padding(
        padding:EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom+20,
        ),
        child:SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              Text(
                'Add Fuel Tank',
                style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight:FontWeight.w900,
                ),
              ),
              const SizedBox(height:4),
              const Text('Set tank identity, fuel type, capacity and current stock.'),
              const SizedBox(height:18),
              TextField(
                controller:name,
                autofocus:true,
                decoration:const InputDecoration(
                  labelText:'Tank name',
                  prefixIcon:Icon(Icons.oil_barrel_outlined),
                ),
              ),
              const SizedBox(height:10),
              TextField(
                controller:type,
                decoration:const InputDecoration(
                  labelText:'Fuel type',
                  prefixIcon:Icon(Icons.local_gas_station_outlined),
                ),
              ),
              const SizedBox(height:10),
              Row(
                children:[
                  Expanded(
                    child:TextField(
                      controller:capacity,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(labelText:'Capacity'),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:TextField(
                      controller:stock,
                      keyboardType:const TextInputType.numberWithOptions(decimal:true),
                      decoration:const InputDecoration(labelText:'Current stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:()=>Navigator.pop(sheetContext,true),
                icon:const Icon(Icons.save_outlined),
                label:const Text('Save Tank'),
              ),
              const SizedBox(height:8),
              TextButton(
                onPressed:()=>Navigator.pop(sheetContext,false),
                child:const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if(ok==true && name.text.trim().isNotEmpty) {
      final db=await AppDatabase.instance.database;
      final now=DateTime.now().toUtc().toIso8601String();
      await db.insert('fuel_tanks',{
        'id':DateTime.now().microsecondsSinceEpoch.toString(),
        'name':name.text.trim(),
        'fuel_type':type.text.trim().isEmpty?'Fuel':type.text.trim(),
        'capacity':double.tryParse(capacity.text)??0,
        'current_stock':double.tryParse(stock.text)??0,
        'updated_at':now,
        'sync_state':0,
      });
      await load();
    }

    name.dispose();
    type.dispose();
    capacity.dispose();
    stock.dispose();
  }

  Future<void> addNozzle() async {
    if(tanks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Add a fuel tank first.')),
      );
      return;
    }

    String tankId=tanks.first['id'].toString();
    final name=TextEditingController();
    final meter=TextEditingController(text:'0');
    final price=TextEditingController(text:'0');

    final ok=await showModalBottomSheet<bool>(
      context:context,
      isScrollControlled:true,
      builder:(sheetContext)=>StatefulBuilder(
        builder:(sheetContext,setLocal)=>Padding(
          padding:EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom+20,
          ),
          child:SingleChildScrollView(
            child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                Text(
                  'Add Fuel Nozzle',
                  style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                    fontWeight:FontWeight.w900,
                  ),
                ),
                const SizedBox(height:4),
                const Text('Link a nozzle to a tank and set meter and selling price.'),
                const SizedBox(height:18),
                DropdownButtonFormField<String>(
                  initialValue:tankId,
                  decoration:const InputDecoration(
                    labelText:'Fuel tank',
                    prefixIcon:Icon(Icons.oil_barrel_outlined),
                  ),
                  items:tanks.map(
                    (x)=>DropdownMenuItem(
                      value:x['id'].toString(),
                      child:Text('${x['name']} • ${x['fuel_type']}'),
                    ),
                  ).toList(),
                  onChanged:(v)=>setLocal(()=>tankId=v!),
                ),
                const SizedBox(height:10),
                TextField(
                  controller:name,
                  autofocus:true,
                  decoration:const InputDecoration(
                    labelText:'Nozzle name',
                    prefixIcon:Icon(Icons.local_gas_station_outlined),
                  ),
                ),
                const SizedBox(height:10),
                Row(
                  children:[
                    Expanded(
                      child:TextField(
                        controller:meter,
                        keyboardType:const TextInputType.numberWithOptions(decimal:true),
                        decoration:const InputDecoration(labelText:'Meter reading'),
                      ),
                    ),
                    const SizedBox(width:10),
                    Expanded(
                      child:TextField(
                        controller:price,
                        keyboardType:const TextInputType.numberWithOptions(decimal:true),
                        decoration:const InputDecoration(labelText:'Price / litre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height:18),
                FilledButton.icon(
                  onPressed:()=>Navigator.pop(sheetContext,true),
                  icon:const Icon(Icons.save_outlined),
                  label:const Text('Save Nozzle'),
                ),
                const SizedBox(height:8),
                TextButton(
                  onPressed:()=>Navigator.pop(sheetContext,false),
                  child:const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if(ok==true && name.text.trim().isNotEmpty) {
      final db=await AppDatabase.instance.database;
      final now=DateTime.now().toUtc().toIso8601String();
      await db.insert('fuel_nozzles',{
        'id':DateTime.now().microsecondsSinceEpoch.toString(),
        'tank_id':tankId,
        'name':name.text.trim(),
        'meter_reading':double.tryParse(meter.text)??0,
        'price_per_unit':double.tryParse(price.text)??0,
        'updated_at':now,
        'sync_state':0,
      });
      await load();
    }

    name.dispose();
    meter.dispose();
    price.dispose();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Oil / Fuel Pump')),
    body:loading
      ?const Center(child:CircularProgressIndicator())
      :RefreshIndicator(
        onRefresh:load,
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:QamvioUi.pagePadding,
          children:[
            const QamvioPageIntro(
              title:'Fuel / Oil Pump',
              subtitle:'Tank stock, nozzle meters, selling prices and recorded fuel shifts.',
              icon:Icons.local_gas_station_rounded,
            ),
            const SizedBox(height:18),
            Row(
              children:[
                Expanded(
                  child:_summary(
                    context,
                    'Tanks',
                    tanks.length.toString(),
                    Icons.oil_barrel_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Nozzles',
                    nozzles.length.toString(),
                    Icons.local_gas_station_outlined,
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:_summary(
                    context,
                    'Fuel stock',
                    QamvioUi.money(totalFuel),
                    Icons.water_drop_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height:18),
            Row(
              children:[
                Expanded(
                  child:FilledButton.icon(
                    onPressed:addTank,
                    icon:const Icon(Icons.add_rounded),
                    label:const Text('Add Tank'),
                  ),
                ),
                const SizedBox(width:10),
                Expanded(
                  child:OutlinedButton.icon(
                    onPressed:addNozzle,
                    icon:const Icon(Icons.local_gas_station_rounded),
                    label:const Text('Add Nozzle'),
                  ),
                ),
              ],
            ),
            const SizedBox(height:22),
            QamvioSectionTitle(
              'Fuel tanks',
              subtitle:'${tanks.length} configured tanks',
            ),
            if(tanks.isEmpty)
              const QamvioEmptyState(
                icon:Icons.oil_barrel_outlined,
                title:'No fuel tanks',
                subtitle:'Add a tank to start fuel stock management.',
              )
            else
              ...tanks.map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_tankCard(context,x),
              )),
            const SizedBox(height:18),
            QamvioSectionTitle(
              'Nozzles',
              subtitle:'${nozzles.length} active nozzle records',
            ),
            if(nozzles.isEmpty)
              const QamvioEmptyState(
                icon:Icons.local_gas_station_outlined,
                title:'No fuel nozzles',
                subtitle:'Link a nozzle to a tank and set meter and price.',
              )
            else
              ...nozzles.map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_nozzleCard(context,x),
              )),
            const SizedBox(height:18),
            QamvioSectionTitle(
              'Recent fuel shifts',
              subtitle:'${shifts.length} recorded shifts',
            ),
            if(shifts.isEmpty)
              const QamvioEmptyState(
                icon:Icons.history_rounded,
                title:'No fuel shifts yet',
                subtitle:'Recorded fuel shifts will appear here after meter closing.',
              )
            else
              ...shifts.take(20).map((x)=>Padding(
                padding:const EdgeInsets.only(bottom:10),
                child:_shiftCard(context,x),
              )),
          ],
        ),
      ),
  );

  Widget _summary(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  )=>Card(
    child:Padding(
      padding:const EdgeInsets.all(12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:8),
          Text(
            value,
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
          ),
          Text(
            label,
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.bodySmall?.copyWith(
              color:const Color(0xFF667085),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tankCard(BuildContext context,Map<String,Object?> x) {
    final capacity=_n(x['capacity']);
    final stock=_n(x['current_stock']);
    final ratio=capacity<=0?0.0:(stock/capacity).clamp(0.0,1.0);
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(
              children:[
                Container(
                  width:46,
                  height:46,
                  decoration:BoxDecoration(
                    color:Theme.of(context).colorScheme.primaryContainer,
                    borderRadius:BorderRadius.circular(15),
                  ),
                  child:Icon(
                    Icons.oil_barrel_rounded,
                    color:Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width:12),
                Expanded(
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(
                        x['name'].toString(),
                        style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                      ),
                      Text(
                        x['fuel_type'].toString(),
                        style:Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${QamvioUi.money(stock)} L',
                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
                ),
              ],
            ),
            const SizedBox(height:14),
            LinearProgressIndicator(
              value:ratio,
              minHeight:8,
              borderRadius:BorderRadius.circular(999),
            ),
            const SizedBox(height:7),
            Row(
              children:[
                Text(
                  '${(ratio*100).toStringAsFixed(0)}% full',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
                const Spacer(),
                Text(
                  'Capacity ${QamvioUi.money(capacity)} L',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nozzleCard(BuildContext context,Map<String,Object?> x)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Row(
        children:[
          Container(
            width:46,
            height:46,
            decoration:BoxDecoration(
              color:const Color(0xFFEAF7F1),
              borderRadius:BorderRadius.circular(15),
            ),
            child:const Icon(Icons.local_gas_station_rounded,color:QamvioUi.success),
          ),
          const SizedBox(width:12),
          Expanded(
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(
                  x['name'].toString(),
                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
                ),
                const SizedBox(height:3),
                Text(
                  '${x['tank_name']} • ${x['fuel_type']}',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment:CrossAxisAlignment.end,
            children:[
              Text(
                'Meter ${QamvioUi.money(x['meter_reading'])}',
                style:const TextStyle(fontWeight:FontWeight.w800),
              ),
              const SizedBox(height:3),
              Text(
                '${QamvioUi.money(x['price_per_unit'])} / L',
                style:TextStyle(
                  color:Theme.of(context).colorScheme.primary,
                  fontWeight:FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _shiftCard(BuildContext context,Map<String,Object?> x)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Row(
            children:[
              const Icon(Icons.history_rounded,color:Color(0xFF667085)),
              const SizedBox(width:8),
              Expanded(
                child:Text(
                  x['nozzle_name']?.toString()??'Nozzle',
                  style:const TextStyle(fontWeight:FontWeight.w900),
                ),
              ),
              Text(
                QamvioUi.money(x['total']),
                style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),
              ),
            ],
          ),
          const SizedBox(height:10),
          Wrap(
            spacing:8,
            runSpacing:8,
            children:[
              QamvioAmountPill(label:'Litres',amount:x['litres']),
              QamvioAmountPill(label:'Cash',amount:x['cash_received']),
              QamvioAmountPill(label:'Expense',amount:x['expense']),
            ],
          ),
          const SizedBox(height:8),
          Text(
            '${x['started_at']} • ${x['salesman_name']??'Unassigned'}',
            style:Theme.of(context).textTheme.bodySmall?.copyWith(
              color:const Color(0xFF667085),
            ),
          ),
        ],
      ),
    ),
  );
}
