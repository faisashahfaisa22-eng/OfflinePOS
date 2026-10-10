import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/security/license_verifier.dart';

/// Activation UI. Call this from a license gate after the signing public key
/// and the server function have been provisioned and tested.
class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({super.key, required this.publicKey});
  final String publicKey;
  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final code = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> activate() async {
    if (busy || code.text.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final verifier = LicenseVerifier(widget.publicKey);
      final deviceId = await verifier.installationId();
      final response = await Supabase.instance.client.functions.invoke(
        'qamvio-license-activate',
        body: {'code': code.text.trim(), 'device_id': deviceId},
      );
      if (response.status != 200) {
        throw StateError('Activation rejected (HTTP ${response.status})');
      }
      final data = response.data;
      if (data is! Map || data['token'] is! String) {
        throw const FormatException('Invalid server response');
      }
      await verifier.saveToken(data['token'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
          'Activation failed. Check your code and internet connection.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activate QAMVIO')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_user_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('Enter your QAMVIO activation code. Internet is required only for activation and periodic renewal.'),
          const SizedBox(height: 16),
          TextField(controller: code, enabled: !busy,
            decoration: const InputDecoration(labelText: 'Activation code'),
            onSubmitted: (_) => activate()),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : activate,
            child: Text(busy ? 'Activating...' : 'Activate')),
        ]),
      ),
    )),
  );
