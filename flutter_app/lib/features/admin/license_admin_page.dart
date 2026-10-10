import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authorized license administration.
/// A local POS admin role is not sufficient: the signed-in Supabase user
/// must also be included in QAMVIO_LICENSE_ADMIN_UIDS on the server.
class LicenseAdminPage extends StatefulWidget {
  const LicenseAdminPage({super.key});
  @override
  State<LicenseAdminPage> createState() => _LicenseAdminPageState();
}

class _LicenseAdminPageState extends State<LicenseAdminPage> {
  final customer = TextEditingController();
  final devices = TextEditingController(text: '1');
  bool loading = false;
  String? error;
  String? issuedCode;
  List<dynamic> licenses = [];
  List<dynamic> deviceRows = [];
  List<dynamic> attempts = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    customer.dispose();
    devices.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> body) async {
    final auth = Supabase.instance.client.auth.currentSession;
    if (auth == null) {
      throw StateError('Sign in to your Supabase administrator account first.');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'qamvio-license-admin',
      body: body,
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );
    if (response.status < 200 || response.status >= 300 ||
        response.data is! Map) {
      throw StateError('Server rejected request (HTTP ${response.status}).');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> refresh() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await request({'action': 'list'});
      if (!mounted) return;
      setState(() {
        licenses = (result['licenses'] as List?) ?? [];
        deviceRows = (result['devices'] as List?) ?? [];
        attempts = (result['attempts'] as List?) ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final name = customer.text.trim();
    final limit = int.tryParse(devices.text.trim());
    if (name.length < 2 || limit == null || limit < 1 || limit > 100) {
      setState(() => error = 'Enter a customer name and 1–100 devices.');
      return;
    }
    setState(() { loading = true; error = null; issuedCode = null; });
    try {
      final result = await request({
        'action': 'create',
        'customer_name': name,
        'max_devices': limit,
      });
      if (!mounted) return;
      setState(() => issuedCode = result['activation_code'] as String?);
      customer.clear();
      await request({'action': 'list'}).then((result) {
        if (mounted) setState(() {
          licenses = (result['licenses'] as List?) ?? [];
          deviceRows = (result['devices'] as List?) ?? [];
          attempts = (result['attempts'] as List?) ?? [];
        });
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> perform(String action, String id, String idKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm administrative action'),
        content: Text('Proceed with $action? This may prevent a customer from renewing their license.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() { loading = true; error = null; });
    try {
      await request({'action': action, idKey: id});
      final result = await request({'action': 'list'});
      if (mounted) setState(() {
        licenses = (result['licenses'] as List?) ?? [];
        deviceRows = (result['devices'] as List?) ?? [];
        attempts = (result['attempts'] as List?) ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('QAMVIO Licenses'),
      actions: [IconButton(onPressed: loading ? null : refresh,
        icon: const Icon(Icons.refresh))],
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(error!, style: TextStyle(
          color: Theme.of(context).colorScheme.error)),
      ),
      Text('Create customer license',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      TextField(controller: customer, enabled: !loading,
        decoration: const InputDecoration(labelText: 'Customer name')),
      const SizedBox(height: 8),
      TextField(controller: devices, enabled: !loading,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Maximum devices')),
      const SizedBox(height: 8),
      FilledButton(onPressed: loading ? null : create,
        child: const Text('Create activation code')),
      if (issuedCode != null) Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Copy this code now. It is shown only once.'),
          SelectableText(issuedCode!),
          TextButton.icon(onPressed: () =>
            Clipboard.setData(ClipboardData(text: issuedCode!)),
            icon: const Icon(Icons.copy), label: const Text('Copy code')),
        ]),
      )),
      const Divider(height: 32),
      Text('Licenses (${licenses.length})',
        style: Theme.of(context).textTheme.titleLarge),
      for (final entry in licenses)
        if (entry is Map)
          Card(child: ListTile(
            title: Text('${entry['customer_name']}'),
            subtitle: Text('Devices allowed: ${entry['max_devices']} • ${entry['status']}'),
            trailing: entry['status'] == 'active'
              ? IconButton(
                  tooltip: 'Block license',
                  onPressed: loading ? null : () => perform(
                    'block', '${entry['id']}', 'license_id'),
                  icon: const Icon(Icons.block))
              : null,
          )),
      const Divider(height: 32),
      Text('Activated devices (${deviceRows.length})',
        style: Theme.of(context).textTheme.titleLarge),
      for (final entry in deviceRows)
        if (entry is Map)
          ListTile(
            title: Text('Device ${entry['id']}'),
            subtitle: Text('Last seen: ${entry['last_seen_at'] ?? 'Never'}'),
            trailing: entry['revoked_at'] == null
              ? IconButton(
                  tooltip: 'Revoke device',
                  onPressed: loading ? null : () => perform(
                    'revoke_device', '${entry['id']}', 'device_id'),
                  icon: const Icon(Icons.phonelink_erase))
              : const Icon(Icons.block),
          ),
      const Divider(height: 32),
      Text('Recent attempts (${attempts.length})',
        style: Theme.of(context).textTheme.titleLarge),
      for (final entry in attempts)
        if (entry is Map)
          ListTile(
            dense: true,
            title: Text('${entry['outcome']}'),
            subtitle: Text('${entry['created_at']}'),
          ),
    ]),
  );
