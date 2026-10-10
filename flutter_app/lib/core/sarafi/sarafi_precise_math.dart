/// Opt-in, side-effect-free exact arithmetic for future Sarafi integration.
/// Existing ledger and database formats are intentionally unchanged.
enum SarafiRound { down, up, nearest }

class SarafiPreciseMath {
  SarafiPreciseMath._();

  static BigInt powerOfTen(int decimals) {
    if (decimals < 0 || decimals > 18) {
      throw RangeError.range(decimals, 0, 18, 'decimals');
    }
    return BigInt.from(10).pow(decimals);
  }

  /// Parse non-negative decimal amounts into exact minor units.
  /// No floating point or implicit rounding is used.
  static BigInt? parseAmount(String input, int decimals) {
    final scale = powerOfTen(decimals);
    final normalized = input.trim()
        .replaceAll(RegExp(r'[,\u066C\s]'), '')
        .replaceAll('\u066B', '.')
        .replaceAllMapped(RegExp(r'[\u0660-\u0669]'),
            (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0x0660 + 48))
        .replaceAllMapped(RegExp(r'[\u06F0-\u06F9]'),
            (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0x06F0 + 48));
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final fractional = parts.length == 2 ? parts[1] : '';
    if (fractional.length > decimals &&
        fractional.substring(decimals).contains(RegExp(r'[1-9]'))) {
      return null;
    }
    final padded = fractional.padRight(decimals, '0').substring(0, decimals);
    return BigInt.parse(parts[0]) * scale +
        (padded.isEmpty ? BigInt.zero : BigInt.parse(padded));
  }

  static BigInt divide(BigInt numerator, BigInt denominator, SarafiRound mode) {
    if (numerator < BigInt.zero || denominator <= BigInt.zero) {
      throw ArgumentError('Expected non-negative numerator and positive denominator');
    }
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    if (mode == SarafiRound.down || remainder == BigInt.zero) return quotient;
    if (mode == SarafiRound.up || remainder * BigInt.two >= denominator) {
      return quotient + BigInt.one;
    }
    return quotient;
  }
}
