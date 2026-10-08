import 'package:flutter/material.dart' as m;

import 'app_strings.dart';
import 'language_controller.dart';
import 'localized_text_ui_1.dart';
import 'localized_text_ui_2.dart';
import 'localized_text_ui_3.dart';
import 'localized_text_words.dart';
import 'localized_text_ui_10.dart';
import 'localized_text_ui_11.dart';
import 'localized_text_ui_12.dart';
import 'localized_text_ui_9.dart';
import 'localized_text_ui_8.dart';
import 'localized_text_ui_7.dart';
import 'localized_text_ui_6.dart';
import 'localized_text_ui_5.dart';
import 'localized_text_ui_4.dart';

const Map<String, List<String>> _ui = {
  ...ui1,
  ...ui2,
  ...ui3,
  ...ui4,
  ...ui5,
  ...ui6,
  ...ui7,
  ...ui8,
  ...ui9,
  ...ui10,
  ...ui11,
  ...ui12,
};

String tr(String value) {
  final language = LanguageController.instance.language;
  if (language == AppLanguage.english || value.isEmpty) return value;

  final exact = _ui[value];
  if (exact != null && language.index < exact.length) {
    return exact[language.index];
  }

  final dynamicPrefix = RegExp(
    r'^(Date|Stock|Reorder|Balance|Total|Due|Customer|Supplier|Salesman|Invoice|'
    r'Opening|Current|Paid|Received|Amount|Note|From|To|Type|Reference|Cash|'
    r'Phone|Status|Product|Qty|Cost|Price|Discount|Recovery|Expense|Payment|'
    r'Account|Loan|Report|Business|Fuel|Tank|Nozzle|Medicine|Section|Record)(\b|:)',
    caseSensitive: false,
  );

  final words = <String, String>{};
  for (final entry in (wordMap[language] ?? const <String, String>{}).entries) {
    words[entry.key.toLowerCase()] = entry.value;
  }
  for (final entry in _ui.entries) {
    if (RegExp(r'^[A-Za-z]+$').hasMatch(entry.key) &&
        language.index < entry.value.length) {
      words.putIfAbsent(entry.key.toLowerCase(), () => entry.value[language.index]);
    }
  }

  var matchCount = 0;
  for (final word in words.keys) {
    if (RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false)
        .hasMatch(value)) {
      matchCount++;
    }
  }

  if (dynamicPrefix.hasMatch(value) || matchCount >= 2) {
    var out = value;
    final ordered = words.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in ordered) {
      out = out.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        words[word]!,
      );
    }
    return out;
  }

  return value;
}

class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  m.Widget build(m.BuildContext context) => m.Text(
        tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}
