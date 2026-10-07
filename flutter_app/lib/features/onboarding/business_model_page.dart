import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';

import '../../core/business/business_model_controller.dart';
import '../../core/security/local_auth_service.dart';
import '../../core/ui/qamvio_ui.dart';

class BusinessModelPage extends StatelessWidget {
  const BusinessModelPage({super.key});

  Future<void> _choose(
    BuildContext context,
    BusinessModelType type,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Use ${type.label}?'),
        content: Text(
          'QAMVIO will tailor the dashboard and menu for this business model. '
          'Your core sales, stock and accounts data stay in the same encrypted database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await BusinessModelController.instance.select(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = LocalAuthService.instance;

    if (!auth.isAdmin) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 54),
                    const SizedBox(height: 16),
                    const Text(
                      'Business setup requires Admin access',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with the Admin account and choose the business model once for this device.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => auth.logout(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Setup'),
        actions: [
          TextButton(
            onPressed: () => auth.logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: QamvioUi.pagePadding,
          children: [
            const QamvioPageIntro(
              title: 'Choose your business model',
              subtitle:
                  'QAMVIO will show the tools that match your business. You can keep one simple app while each business gets its own workflow.',
              icon: Icons.storefront_rounded,
            ),
            const SizedBox(height: 18),
            _BusinessModelCard(
              type: BusinessModelType.retailStore,
              icon: Icons.storefront_rounded,
              onTap: () => _choose(context, BusinessModelType.retailStore),
            ),
            const SizedBox(height: 10),
            _BusinessModelCard(
              type: BusinessModelType.fuelStation,
              icon: Icons.local_gas_station_rounded,
              onTap: () => _choose(context, BusinessModelType.fuelStation),
            ),
            const SizedBox(height: 10),
            _BusinessModelCard(
              type: BusinessModelType.restaurant,
              icon: Icons.restaurant_rounded,
              onTap: () => _choose(context, BusinessModelType.restaurant),
            ),
            const SizedBox(height: 10),
            _BusinessModelCard(
              type: BusinessModelType.pharmacy,
              icon: Icons.local_pharmacy_rounded,
              onTap: () => _choose(context, BusinessModelType.pharmacy),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Retail will not show Fuel tools. Oil / Fuel enables the fuel module. '
                        'Pharmacy enables medicine and expiry tools. Restaurant currently uses '
                        'QAMVIO core POS while restaurant-specific tables and kitchen workflow '
                        'can be added as a separate module.',
                      ),
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
}

class _BusinessModelCard extends StatelessWidget {
  final BusinessModelType type;
  final IconData icon;
  final VoidCallback onTap;

  const _BusinessModelCard({
    required this.type,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        type.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF667085),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}
