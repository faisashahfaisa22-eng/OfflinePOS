// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/sarafi_repository.dart';

final NumberFormat _fmt=NumberFormat('#,##0.00');

String fxFmt(num value)=>_fmt.format(value);

double? fxParse(String text) {
  final t=text.trim().replaceAll(',','');
  if(t.isEmpty) return null;
  return double.tryParse(t);
}

void fxSnack(BuildContext context,String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
}

String fxErr(Object e) {
  final t=e.toString();
  return t
      .replaceFirst('Invalid argument(s): ','')
      .replaceFirst('Bad state: ','')
      .replaceFirst('Exception: ','');
}

Future<bool> fxConfirm(BuildContext context,String title,String message,{String action='Confirm'}) async {
  final ok=await showDialog<bool>(
    context:context,
    builder:(ctx)=>AlertDialog(
      title:Text(title),
      content:Text(message),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(action)),
      ],
    ),
  );
  return ok==true;
}

/// Rate logic for the exchange form (pure, no database).
///
/// One side is AFN: the rate is "AFN per 1 foreign unit" (1 USD = 70 AFN).
/// Neither side is AFN: the rate is "units of the received currency per 1 unit
/// of the given currency".
class FxQuote {
  FxQuote._();

  static const base=SarafiSchema.baseCurrency;

  static String label(String from,String to) {
    if(from==base) return '1 $to = ? $base';
    if(to==base) return '1 $from = ? $base';
    return '1 $from = ? $to';
  }

  /// Amount the customer receives for [fromAmount] at [rate]. Returns 0 when
  /// the input is not usable.
  static double toAmount({
    required String from,
    required String to,
    required double fromAmount,
    required double rate,
  }) {
    if(from==to||fromAmount<=0||rate<=0) return 0;
    final raw=from==base?fromAmount/rate:fromAmount*rate;
    return (raw*100).roundToDouble()/100;
  }

  /// Suggested rate from the saved buy/sell table, or null when unknown.
  /// The customer gives a foreign currency: we BUY it (buy rate). The customer
  /// receives a foreign currency: we SELL it (sell rate).
  static double? suggest(String from,String to,Map<String,FxRate> rates) {
    if(from==to) return null;
    if(from==base) {
      final s=rates[to]?.sell??0;
      return s>0?s:null;
    }
    if(to==base) {
      final b=rates[from]?.buy??0;
      return b>0?b:null;
    }
    final b=rates[from]?.buy??0;
    final s=rates[to]?.sell??0;
    if(b>0&&s>0) return b/s;
    return null;
  }
}
