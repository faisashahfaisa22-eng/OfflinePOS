import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/language_controller.dart';
import '../../core/ui/qamvio_ui.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState()=>_ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String,Object?>> rows=const [];
  bool loading=true;
  final search=TextEditingController();

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
    load();
  }

  @override
  void dispose() {
    search.removeListener(_refresh);
    search.dispose();
    super.dispose();
  }

  void _refresh()=>setState(() {});

  Future<void> load() async {
    final x=await AppDatabase.instance.expenses();
    if(!mounted) return;
    setState(() {
      rows=x;
      loading=false;
    });
  }

  List<Map<String,Object?>> get filtered {
    final q=search.text.trim().toLowerCase();
    if(q.isEmpty) return rows;
    return rows.where((x)=>[
      x['name'],
      x['category'],
      x['note'],
      x['created_at'],
    ].join(' ').toLowerCase().contains(q)).toList();
  }

  double get total=>rows.fold<double>(
    0,
    (a,x)=>a+((x['amount'] as num?)?.toDouble()??0),
  );

  Future<void> add() async {
    final name=TextEditingController();
    final category=TextEditingController();
    final amount=TextEditingController();
    final note=TextEditingController();

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
        child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Text(
              LanguageController.instance.strings.t('addExpense'),
              style:Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                fontWeight:FontWeight.w900,
              ),
            ),
            const SizedBox(height:4),
            const Text('Record a business expense with category and note.'),
            const SizedBox(height:18),
            TextField(
              controller:name,
              autofocus:true,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('expenseName'),
                prefixIcon:const Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height:10),
            TextField(
              controller:category,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('category'),
                prefixIcon:const Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height:10),
            TextField(
              controller:amount,
              keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('amount'),
                prefixIcon:const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height:10),
            TextField(
              controller:note,
              maxLines:2,
              decoration:InputDecoration(
                labelText:LanguageController.instance.strings.t('note'),
                prefixIcon:const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height:18),
            FilledButton.icon(
              onPressed:()=>Navigator.pop(sheetContext,true),
              icon:const Icon(Icons.save_outlined),
              label:const Text('Save Expense'),
            ),
            const SizedBox(height:8),
            TextButton(
              onPressed:()=>Navigator.pop(sheetContext,false),
              child:const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if(ok==true && name.text.trim().isNotEmpty) {
      final value=double.tryParse(amount.text)??0;
      if(value>0) {
        await AppDatabase.instance.saveExpense(
          id:DateTime.now().microsecondsSinceEpoch.toString(),
          name:name.text,
          category:category.text,
          amount:value,
          note:note.text,
        );
        await load();
      } else if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Expense amount must be greater than zero.')),
        );
      }
    }

    name.dispose();
    category.dispose();
    amount.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s=LanguageController.instance.strings;
    return Scaffold(
      appBar:AppBar(title:Text(s.t('expenses'))),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:add,
        icon:const Icon(Icons.add_rounded),
        label:Text(s.t('addExpense')),
      ),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :RefreshIndicator(
          onRefresh:load,
          child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:QamvioUi.pagePadding,
            children:[
              QamvioPageIntro(
                title:s.t('expenses'),
                subtitle:'Track operating costs and keep profit reporting accurate.',
                icon:Icons.receipt_long_rounded,
              ),
              const SizedBox(height:18),
              Row(
                children:[
                  Expanded(
                    child:_summary(
                      context,
                      'Entries',
                      rows.length.toString(),
                      Icons.format_list_bulleted_rounded,
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:_summary(
                      context,
                      'Total expenses',
                      QamvioUi.money(total),
                      Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height:18),
              TextField(
                controller:search,
                decoration:InputDecoration(
                  hintText:'Search expense, category or note',
                  prefixIcon:const Icon(Icons.search_rounded),
                  suffixIcon:search.text.isEmpty
                    ?null
                    :IconButton(
                      onPressed:()=>search.clear(),
                      icon:const Icon(Icons.close_rounded),
                    ),
                ),
              ),
              const SizedBox(height:18),
              QamvioSectionTitle(
                'Expense history',
                subtitle:'${filtered.length} matching records',
              ),
              if(filtered.isEmpty)
                QamvioEmptyState(
                  icon:Icons.receipt_long_outlined,
                  title:rows.isEmpty?'No expenses yet':'No matching expense',
                  subtitle:rows.isEmpty
                    ?'Record your first business expense for accurate reporting.'
                    :'Try a different search term.',
                  actionLabel:rows.isEmpty?'Add Expense':null,
                  onAction:rows.isEmpty?add:null,
                )
              else
                ...filtered.map((x)=>Padding(
                  padding:const EdgeInsets.only(bottom:10),
                  child:_expenseCard(context,x),
                )),
            ],
          ),
        ),
    );
  }

  Widget _summary(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  )=>Card(
    child:Padding(
      padding:const EdgeInsets.all(14),
      child:Row(
        children:[
          Container(
            width:42,
            height:42,
            decoration:BoxDecoration(
              color:Theme.of(context).colorScheme.primaryContainer,
              borderRadius:BorderRadius.circular(13),
            ),
            child:Icon(
              icon,
              color:Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width:10),
          Expanded(
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(
                  value,
                  maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
                ),
                Text(
                  label,
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _expenseCard(BuildContext context,Map<String,Object?> x) {
    final category=(x['category']??'Uncategorized').toString();
    final note=(x['note']??'').toString();
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Row(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Container(
              width:46,
              height:46,
              decoration:BoxDecoration(
                color:const Color(0xFFFFF3E0),
                borderRadius:BorderRadius.circular(15),
              ),
              child:const Icon(
                Icons.receipt_long_rounded,
                color:QamvioUi.warning,
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
                  const SizedBox(height:3),
                  Text(
                    category,
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                  if(note.isNotEmpty) ...[
                    const SizedBox(height:6),
                    Text(
                      note,
                      maxLines:2,
                      overflow:TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height:7),
                  Text(
                    x['created_at'].toString(),
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width:10),
            Text(
              QamvioUi.money(x['amount']),
              style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17),
            ),
          ],
        ),
      ),
    );
  }
}
