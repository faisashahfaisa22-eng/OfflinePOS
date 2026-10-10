import 'package:flutter/material.dart';
import '../../core/security/license_verifier.dart';
import 'license_activation_page.dart';

/// Optional licensing gate. Enable only after provisioning the server's
/// signing key and the matching public key via --dart-define.
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.child});
  final Widget child;
  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  static const publicKey = String.fromEnvironment(
    'QAMVIO_LICENSE_PUBLIC_KEY',
    defaultValue: 'XQPGDm8ImKiHBZBux7lz2NfAZbDZ2SKT97ZTuOUJoUI',
  );
  late Future<bool> _valid;

  @override
  void initState() {
    super.initState();
    _valid = LicenseVerifier(publicKey).hasValidLicense();
  }

  void _recheck() {
    setState(() {
      _valid = LicenseVerifier(publicKey).hasValidLicense();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _valid,
    builder: (context, result) {
      if (result.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (result.data == true) return widget.child;
      return LicenseActivationPage(
        publicKey: publicKey,
        onActivated: _recheck,
      );
    },
  );
}
