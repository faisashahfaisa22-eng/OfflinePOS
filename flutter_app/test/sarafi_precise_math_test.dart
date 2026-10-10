import 'package:flutter_test/flutter_test.dart';
import 'package:qamvio_pos/core/sarafi/sarafi_precise_math.dart';

void main() {
  test('decimal parsing never uses floating point', () {
    expect(SarafiPreciseMath.parseAmount('1,234.56', 2), BigInt.from(123456));
    expect(SarafiPreciseMath.parseAmount('۱۲۳٫۵', 2), BigInt.from(12350));
    expect(SarafiPreciseMath.parseAmount('٥٠٠', 2), BigInt.from(50000));
    expect(SarafiPreciseMath.parseAmount('1.500', 2), BigInt.from(150));
    expect(SarafiPreciseMath.parseAmount('1.505', 2), isNull);
    expect(SarafiPreciseMath.parseAmount('-1', 2), isNull);
  });
  test('rounding is explicit', () {
    expect(SarafiPreciseMath.divide(BigInt.from(10), BigInt.from(4), SarafiRound.down), BigInt.from(2));
    expect(SarafiPreciseMath.divide(BigInt.from(10), BigInt.from(4), SarafiRound.up), BigInt.from(3));
    expect(SarafiPreciseMath.divide(BigInt.from(10), BigInt.from(4), SarafiRound.nearest), BigInt.from(3));
  });
}
