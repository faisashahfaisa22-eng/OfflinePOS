import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BusinessModelType {
  retailStore,
  fuelStation,
  restaurant,
  pharmacy,
}

extension BusinessModelTypeX on BusinessModelType {
  String get label => switch (this) {
        BusinessModelType.retailStore => 'Retail Store',
        BusinessModelType.fuelStation => 'Oil / Fuel',
        BusinessModelType.restaurant => 'Restaurant',
        BusinessModelType.pharmacy => 'Pharmacy',
      };

  String get description => switch (this) {
        BusinessModelType.retailStore =>
          'General shop, supermarket, wholesale or everyday retail.',
        BusinessModelType.fuelStation =>
          'Fuel station with tanks, nozzles, meter sales and fuel stock.',
        BusinessModelType.restaurant =>
          'Restaurant POS using the core sales, stock and customer tools.',
        BusinessModelType.pharmacy =>
          'Medicine sales with batch, stock and expiry tracking.',
      };
}

class BusinessModelController extends ChangeNotifier {
  BusinessModelController._();
  static final BusinessModelController instance = BusinessModelController._();

  static const _storageKey = 'qamvio_business_model_v1';

  BusinessModelType? _type;
  bool _loaded = false;

  BusinessModelType? get type => _type;
  bool get loaded => _loaded;
  bool get configured => _type != null;
  String get label => _type?.label ?? 'Business';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      for (final value in BusinessModelType.values) {
        if (value.name == raw) {
          _type = value;
          break;
        }
      }
    }
    _loaded = true;
  }

  Future<void> select(BusinessModelType value) async {
    _type = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
    notifyListeners();
  }

  Future<void> clear() async {
    _type = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }
}
