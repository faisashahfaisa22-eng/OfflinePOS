import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'language_controller.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  static const Map<AppLanguage, String> labels = {
    AppLanguage.english: 'English',
    AppLanguage.pashto: 'پښتو',
    AppLanguage.dari: 'دری',
    AppLanguage.urdu: 'اردو',
    AppLanguage.arabic: 'العربية',
    AppLanguage.hindi: 'हिन्दी',
    AppLanguage.spanish: 'Español',
    AppLanguage.french: 'Français',
    AppLanguage.turkish: 'Türkçe',
  };

  @override
  Widget build(BuildContext context) {
    final controller = LanguageController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return DropdownButtonFormField<AppLanguage>(
          initialValue: controller.language,
          decoration: const InputDecoration(
            labelText: 'Language',
            border: OutlineInputBorder(),
          ),
          items: AppLanguage.values
              .map((language) => DropdownMenuItem(
                    value: language,
                    child: Text(labels[language] ?? language.name),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              controller.setLanguage(value);
            }
          },
        );
      },
    );
  }
}
