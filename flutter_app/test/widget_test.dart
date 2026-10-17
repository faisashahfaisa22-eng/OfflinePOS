import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/localization/app_strings.dart';

void main() {
  test('QAMVIO localization core is available', () {
    final strings = AppStrings(AppLanguage.english);
    expect(strings.t('dashboard'), isNotEmpty);
    expect(strings.t('sales'), isNotEmpty);
  });
}
