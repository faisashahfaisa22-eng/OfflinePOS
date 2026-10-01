import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/main.dart';

void main() {
  testWidgets('QAMVIO app starts', (tester) async {
    await tester.pumpWidget(const QamvioApp());
    expect(find.text('QAMVIO POS'), findsWidgets);
  });
}
