import 'package:flutter/material.dart';

/// Read-only operational dashboard for license deployment readiness.
/// Customer/device administration must be backed by an authenticated admin API,
/// never by a service-role key embedded in the Android application.
class LicenseAdminPage extends StatelessWidget {
  const LicenseAdminPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QAMVIO License Administration')),
    body: ListView(padding: const EdgeInsets.all(20), children: const [
      ListTile(
        leading: Icon(Icons.verified_user_outlined),
        title: Text('License management'),
        subtitle: Text('Admin-only server authentication is required before customer licenses can be created or edited.'),
      ),
      ListTile(
        leading: Icon(Icons.devices_outlined),
        title: Text('Device management'),
        subtitle: Text('Device activation and revocation must be validated on the server.'),
      ),
      ListTile(
        leading: Icon(Icons.security_outlined),
        title: Text('Security'),
        subtitle: Text('Never put a service-role key or signing private key in the mobile app.'),
      ),
    ]),
  );
}
