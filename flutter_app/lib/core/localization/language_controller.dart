import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._();
  static final instance = LanguageController._();

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings(_language);

  Locale get locale => switch (_language) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.pashto => const Locale('ps'),
    AppLanguage.dari => const Locale('fa'),
    AppLanguage.urdu => const Locale('ur'),
    AppLanguage.arabic => const Locale('ar'),
    AppLanguage.hindi => const Locale('hi'),
    AppLanguage.spanish => const Locale('es'),
    AppLanguage.french => const Locale('fr'),
    AppLanguage.turkish => const Locale('tr'),
  };

  static const supportedLanguages = <AppLanguage>[
    AppLanguage.english,
    AppLanguage.pashto,
    AppLanguage.dari,
    AppLanguage.urdu,
    AppLanguage.arabic,
    AppLanguage.hindi,
    AppLanguage.spanish,
    AppLanguage.french,
    AppLanguage.turkish,
  ];

  String languageName(AppLanguage value) => switch (value) {
    AppLanguage.english => 'English',
    AppLanguage.pashto => 'پښتو',
    AppLanguage.dari => 'دری',
    AppLanguage.urdu => 'اردو',
    AppLanguage.arabic => 'العربية',
    AppLanguage.hindi => 'हिन्दी',
    AppLanguage.spanish => 'Español',
    AppLanguage.french => 'Français',
    AppLanguage.turkish => 'Türkçe',
  };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final value = p.getString('qamvio_language') ?? 'english';
    _language = AppLanguage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppLanguage.english,
    );
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('qamvio_language', value.name);
    notifyListeners();
  }
}
