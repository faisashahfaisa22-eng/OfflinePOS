import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import '../auth/login_page.dart';

/// Admin-only user management (v15 "Users / Login").
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState()=>_UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final auth=LocalAuthService.instance;
  final loginId=TextEditingController();
  final password=TextEditingController();
  UserRole role=UserRole.cashier;
  String salesmanId='';
  List<Map<String,Object?>> salesmen=[];
  String message='';
  bool busy=false;

  @override
  void initState() {
    super.initState();
    _loadSalesmen();
  }

  @override
  void dispose() {
    loginId.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _loadSalesmen() async {
    final db=await AppDatabase.instance.database;
    final rows=await db.query('salesmen',columns:['id','name'],where:'active=1',orderBy:'name');
    if(mounted) setState(()=>salesmen=rows);
  }

  Future<void> _create() async {
    setState(()=>busy=true);
    try {
      final code=await auth.createUser(
        loginRaw:loginId.text,
        password:password.text,
        role:role,
        salesmanId:salesmanId,
      );
      loginId.clear();
      password.clear();
      if(mounted) {
        setState(()=>message='User created.');
        await showDialog<void>(
          context:context,
          barrierDismissible:false,
          builder:(_)=>RecoveryCodeDialog(code:code),
        );
      }
    } on AuthException catch(e) {
      if(mounted) setState(()=>message=e.message);
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on AuthException catch(e) {
      if(mounted) setState(()=>message=e.message);
    }
  }

  @override
  Widget build(BuildContext context)=>ListenableBuilder(
    listenable:auth,
    builder:(context,_)=>Scaffold(
      appBar:AppBar(title:const Text('Users / Login')),
      body:ListView(
        padding:QamvioUi.pagePadding,
        children:[
          const QamvioSectionTitle('Add user',subtitle:'Each user gets their own password and recovery code'),
          Card(
            child:Padding(
              padding:const EdgeInsets.all(16),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  TextField(controller:loginId,decoration:const InputDecoration(labelText:'Email or mobile (+93...)')),
                  const SizedBox(height:10),
                  TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
                  const SizedBox(height:10),
                  DropdownButtonFormField<UserRole>(
                    value:role,
                    decoration:const InputDecoration(labelText:'Role'),
                    items:[for(final r in UserRole.values) DropdownMenuItem(value:r,child:Text(r.label))],
                    onChanged:(v)=>setState(()=>role=v??UserRole.cashier),
                  ),
                  if(role==UserRole.salesman) ...[
                    const SizedBox(height:10),
                    DropdownButtonFormField<String>(
                      value:salesmanId.isEmpty?null:salesmanId,
                      decoration:const InputDecoration(labelText:'Linked salesman'),
                      items:[for(final s in salesmen) DropdownMenuItem(value:s['id'] as String,child:Text('${s['name']}'))],
                      onChanged:(v)=>setState(()=>salesmanId=v??''),
                    ),
                  ],
                  const SizedBox(height:12),
                  FilledButton(onPressed:busy?null:_create,child:const Text('Create user')),
                  if(message.isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text(message)),
                ],
              ),
            ),
          ),
          const SizedBox(height:18),
          const QamvioSectionTitle('Users'),
          for(final u in auth.users)
            Card(
              child:ListTile(
                leading:Icon(u.role==UserRole.admin?Icons.admin_panel_settings_rounded:Icons.person_rounded),
                title:Text(u.loginId),
                subtitle:Text('${u.role.label}${u.active?'':' • disabled'}'),
                trailing:u.id==auth.current?.id
                  ?const Text('You')
                  :PopupMenuButton<String>(
                    onSelected:(v)=>_run(()=>v=='toggle'?auth.setActive(u.id,!u.active):auth.deleteUser(u.id)),
                    itemBuilder:(_)=>[
                      PopupMenuItem(value:'toggle',child:Text(u.active?'Disable':'Enable')),
                      const PopupMenuItem(value:'delete',child:Text('Delete')),
                    ],
                  ),
              ),
            ),
        ],
      ),
    ),
  );
}
