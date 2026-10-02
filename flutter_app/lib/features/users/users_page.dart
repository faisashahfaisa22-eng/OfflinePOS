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
  final confirmPassword = TextEditingController();

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
    confirmPassword.dispose();
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
      if (mounted) {
        setState(() => salesmen = rows);
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Could not load salesmen: $e');
      }
    }
  }

  Future<void> _create() async {
    if (password.text != confirmPassword.text) {
      setState(() => message = 'Passwords do not match.');
      return;
    }

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
      confirmPassword.clear();

      if (mounted) {
        setState(() {
          message = 'User created successfully.';
          role = UserRole.cashier;
          salesmanId = '';
        });

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RecoveryCodeDialog(code: code),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => message = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Could not create user: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _toggleUser(AuthUser user) async {
    final action = user.active ? 'Disable' : 'Enable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action user?'),
        content: Text(
          user.active
              ? 'This user will no longer be able to sign in until re-enabled.'
              : 'This user will be allowed to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _run(() => auth.setActive(user.id, !user.active));
  }

  Future<void> _deleteUser(AuthUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'Delete ${user.loginId}? This removes the local login account. '
          'Business records are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _run(() => auth.deleteUser(user.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = '';
    });

    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => message = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Operation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
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
                    'Each user gets their own password and one-time recovery code',
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
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText:
                              'Minimum 8 characters, with a letter and a number',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: busy
                                ? null
                                : () => setState(
                                      () => obscurePassword = !obscurePassword,
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
                      TextField(
                        controller: confirmPassword,
                        enabled: !busy,
                        obscureText: obscurePassword,
                        onSubmitted: (_) {
                          if (!busy) _create();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon:
                              Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                setState(() {
                                  role = v ?? UserRole.cashier;
                                  if (role != UserRole.salesman) {
                                    salesmanId = '';
                                  }
                                });
                              },
                      ),
                      if (role == UserRole.salesman) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: salesmanId.isEmpty ? null : salesmanId,
                          decoration: const InputDecoration(
                            labelText: 'Linked salesman',
                            prefixIcon: Icon(Icons.badge_outlined),
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
                              'Create an active salesman first, then link the login here.',
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: busy ? null : _create,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create user'),
                      ),
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: message.toLowerCase().contains('success')
                                  ? Colors.green
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              QamvioSectionTitle(
                'Users',
                subtitle: '${auth.users.length} local login account(s)',
              ),
              for (final u in auth.users)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        u.role == UserRole.admin
                            ? Icons.admin_panel_settings_rounded
                            : u.role == UserRole.salesman
                                ? Icons.badge_rounded
                                : Icons.person_rounded,
                      ),
                    ),
                    title: Text(u.loginId),
                    subtitle: Text(
                      '${u.role.label}${u.active ? ' • active' : ' • disabled'}',
                    ),
                    trailing: u.id == auth.current?.id
                        ? const Chip(label: Text('You'))
                        : PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (v) {
                              if (v == 'toggle') {
                                _toggleUser(u);
                              } else if (v == 'delete') {
                                _deleteUser(u);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  u.active ? 'Disable' : 'Enable',
                                ),
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
