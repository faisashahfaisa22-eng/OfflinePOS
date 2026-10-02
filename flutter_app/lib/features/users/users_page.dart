import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';
import '../auth/login_page.dart';

/// Admin-only user management (v15 "Users / Login").
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final auth = LocalAuthService.instance;
  final loginId = TextEditingController();
  final password = TextEditingController();

  UserRole role = UserRole.cashier;
  String salesmanId = '';
  List<Map<String, Object?>> salesmen = [];
  String message = '';
  bool busy = false;
  bool obscurePassword = true;

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
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'salesmen',
        columns: ['id', 'name'],
        where: 'active=1',
        orderBy: 'name',
      );
      if (mounted) setState(() => salesmen = rows);
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Could not load salesmen: $e');
      }
    }
  }

  Future<void> _create() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });

    try {
      final code = await auth.createUser(
        loginRaw: loginId.text,
        password: password.text,
        role: role,
        salesmanId: salesmanId,
      );

      loginId.clear();
      password.clear();

      if (!mounted) return;
      setState(() {
        message = 'User created.';
        role = UserRole.cashier;
        salesmanId = '';
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RecoveryCodeDialog(code: code),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (e) {
      if (mounted) setState(() => message = 'Error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });

    try {
      await action();
      if (mounted && successMessage != null) {
        setState(() => message = successMessage);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (e) {
      if (mounted) setState(() => message = 'Error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String body,
    String actionLabel,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleUserAction(AuthUser user, String action) async {
    if (action == 'toggle') {
      final disabling = user.active;
      if (disabling) {
        final ok = await _confirm(
          'Disable user?',
          'This user will not be able to sign in until the account is enabled again.',
          'Disable',
        );
        if (!ok) return;
      }

      await _run(
        () => auth.setActive(user.id, !user.active),
        successMessage: user.active ? 'User disabled.' : 'User enabled.',
      );
      return;
    }

    if (action == 'delete') {
      final ok = await _confirm(
        'Delete user?',
        'This removes the local login account. This action cannot be undone.',
        'Delete',
      );
      if (!ok) return;

      await _run(
        () => auth.deleteUser(user.id),
        successMessage: 'User deleted.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: auth,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Users / Login')),
          body: ListView(
            padding: QamvioUi.pagePadding,
            children: [
              const QamvioSectionTitle(
                'Add user',
                subtitle:
                    'Each user gets their own password and recovery code',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: loginId,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email or mobile (+93...)',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: password,
                        enabled: !busy,
                        obscureText: obscurePassword,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText:
                              'Min 8 characters, with a letter and a number',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: busy
                                ? null
                                : () => setState(
                                      () => obscurePassword =
                                          !obscurePassword,
                                    ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                  role = v ?? UserRole.cashier;
                                  if (role != UserRole.salesman) {
                                    salesmanId = '';
                                  }
                                }),
                      ),
                      if (role == UserRole.salesman) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue:
                              salesmanId.isEmpty ? null : salesmanId,
                          decoration: const InputDecoration(
                            labelText: 'Linked salesman',
                          ),
                          items: [
                            for (final s in salesmen)
                              DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text('${s['name']}'),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) =>
                                  setState(() => salesmanId = v ?? ''),
                        ),
                        if (salesmen.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'No active salesman is available. Create a salesman first.',
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: busy ? null : _create,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(busy ? 'Please wait...' : 'Create user'),
                      ),
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            message,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: message == 'User created.' ||
                                      message == 'User enabled.' ||
                                      message == 'User disabled.' ||
                                      message == 'User deleted.'
                                  ? QamvioUi.success
                                  : QamvioUi.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const QamvioSectionTitle('Users'),
              for (final u in auth.users)
                Card(
                  child: ListTile(
                    leading: Icon(
                      u.role == UserRole.admin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                    ),
                    title: Text(u.loginId),
                    subtitle: Text(
                      '${u.role.label}${u.active ? '' : ' • disabled'}',
                    ),
                    trailing: u.id == auth.current?.id
                        ? const Text(
                            'You',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          )
                        : PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (v) => _handleUserAction(u, v),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(u.active ? 'Disable' : 'Enable'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      );
}
