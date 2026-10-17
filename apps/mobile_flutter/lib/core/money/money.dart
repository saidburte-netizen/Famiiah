import 'package:intl/intl.dart';

/// Minor-unit digits per currency. Defaults to 2.
const _currencyDecimals = <String, int>{
  'ETB': 2,
  'USD': 2,
  'GBP': 2,
  'EUR': 2,
  'KES': 2,
  'JPY': 0,
};

final _formatters = <String, NumberFormat>{};

NumberFormat _formatter(String currency, int decimals) {
  return _formatters.putIfAbsent(
    '$currency:$decimals',
    // 'en' is always bundled with intl; using it avoids locale-data loading.
    () => NumberFormat.currency(
      locale: 'en',
      symbol: '$currency ',
      decimalDigits: decimals,
    ),
  );
}

/// Format a PostgreSQL `numeric` (comes as number/string from JSON) to a
/// human-readable string. Mirrors `formatMoney` in `@fam/shared`.
String formatMoney(Object? value, {String currency = 'ETB', int? decimals}) {
  final d = decimals ?? _currencyDecimals[currency] ?? 2;
  return _formatter(currency, d).format(_toNum(value));
}

double _toNum(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.replaceAll(',', '').trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }
  return 0;
}
