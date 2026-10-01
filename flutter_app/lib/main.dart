import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/cloud/cloud_service.dart';
import 'core/database/app_database.dart';

const supabaseUrl = 'https://noosoaxtwiacbmrjaugh.supabase.co';
const supabaseAnonKey = 'sb_publishable_ZVWWnnhsabhe-LwZPQwffg_Gz1QMxDy';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await AppDatabase.instance.database;
  runApp(const QamvioApp());
}

class QamvioApp extends StatelessWidget {
  const QamvioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'QAMVIO POS',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF174EA6)),
    home: Supabase.instance.client.auth.currentSession == null ? const AuthPage() : const Dashboard(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final id = TextEditingController(), pw = TextEditingController();
  bool busy = false; String message = '';
  CloudService get cloud => CloudService(Supabase.instance.client);

  Future<void> auth(bool signup) async {
    if (id.text.trim().isEmpty || pw.text.length < 8) {
      setState(() => message = 'Enter email/mobile and a password of at least 8 characters.'); return;
    }
    setState(() { busy = true; message = ''; });
    try {
      if (signup) {
        await cloud.signUp(identifier: id.text, password: pw.text);
        setState(() => message = 'Account created. Verify email/SMS if requested, then login.');
      } else {
        await cloud.signIn(identifier: id.text, password: pw.text);
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Dashboard()));
      }
    } catch (e) { setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.point_of_sale, size: 72), const SizedBox(height: 16),
          const Text('QAMVIO POS', textAlign: TextAlign.center, style: TextStyle(fontSize: 30,fontWeight: FontWeight.w800)),
          const Text('Flutter + SQLite • Offline First', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(controller: id, decoration: const InputDecoration(labelText: 'Email or mobile number',border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password',border: OutlineInputBorder())),
          if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message)),
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : () => auth(false), child: const Text('Login')),
          OutlinedButton(onPressed: busy ? null : () => auth(true), child: const Text('Create Account')),
        ]))))),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String,int>? counts;
  bool busy=false;
  String cloudStatus='';

  CloudService get cloud => CloudService(Supabase.instance.client);

  @override void initState(){ super.initState(); load(); }

  Future<void> load() async {
    final c=await cloud.localCounts();
    if(mounted) setState(()=>counts=c);
  }

  Future<void> backup() async {
    setState((){busy=true;cloudStatus='Uploading full cloud backup...';});
    try {
      await cloud.backupNow();
      setState(()=>cloudStatus='Cloud backup completed.');
    } catch(e) {
      setState(()=>cloudStatus='Backup failed: $e');
    } finally { if(mounted) setState(()=>busy=false); }
  }

  Future<void> restore() async {
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Restore from Cloud?'),
      content:const Text('This replaces the local Flutter database with your latest cloud backup.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Restore')),
      ])) ?? false;
    if(!ok) return;
    setState((){busy=true;cloudStatus='Restoring cloud backup...';});
    try {
      final restored=await cloud.restoreLatest();
      await load();
      setState(()=>cloudStatus=restored?'Cloud data restored to SQLite.':'No cloud backup exists yet.');
    } catch(e) {
      setState(()=>cloudStatus='Restore failed: $e');
    } finally { if(mounted) setState(()=>busy=false); }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('QAMVIO POS'),actions:[
      IconButton(onPressed:busy?null:backup,tooltip:'Backup',icon:const Icon(Icons.cloud_upload)),
      IconButton(onPressed:busy?null:restore,tooltip:'Restore',icon:const Icon(Icons.cloud_download)),
    ]),
    body:counts==null?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,
      child:ListView(padding:const EdgeInsets.all(16),children:[
        Text('Native Flutter + SQLite core is active',style:Theme.of(context).textTheme.titleLarge),
        if(cloudStatus.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(cloudStatus)),
        const SizedBox(height:8),
        card('Products',counts!['products']!,Icons.inventory_2),
        card('Sales / Invoices',counts!['sales']!,Icons.receipt_long),
        card('Purchases',counts!['purchases']!,Icons.shopping_cart),
        card('Customers',counts!['customers']!,Icons.people),
        card('Suppliers',counts!['suppliers']!,Icons.local_shipping),
        card('Expenses',counts!['expenses']!,Icons.payments),
        card('Loans',counts!['loans']!,Icons.account_balance_wallet),
        card('Oil Pump Sales',counts!['fuel_sales']!,Icons.local_gas_station),
      ])));
  Widget card(String title,int count,IconData icon)=>Card(child:ListTile(leading:Icon(icon),title:Text(title),trailing:Text('$count',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))));
}
