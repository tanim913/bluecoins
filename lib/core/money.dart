import 'package:intl/intl.dart';

/// Money is an int of minor units (cents, paisa). Never a double.
int roundDiv(int n, int d) => (n >= 0 ? (n * 2 + d) : (n * 2 - d)) ~/ (2 * d);

final _whole = RegExp(r'^[+-]?[^+-]+([+-][^+-]+)*$');
final _terms = RegExp(r'([+-]?)([^+-]+)');
final _term = RegExp(r'^(\d{1,11})(?:\.(\d{1,2}))?$');

/// Parses "1,91,410.32" or "197600+4000+10" into minor units. Null when invalid
/// (also rejects more than 2 decimals, which catches "1.234,56").
int? parseMoney(String input) {
  final s = input.replaceAll(RegExp(r'[,\s]'), '').replaceAll('−', '-');
  if (!_whole.hasMatch(s)) return null;
  var total = 0;
  for (final m in _terms.allMatches(s)) {
    final t = _term.firstMatch(m.group(2)!);
    if (t == null) return null;
    final v =
        int.parse(t.group(1)!) * 100 +
        int.parse((t.group(2) ?? '').padRight(2, '0'));
    total += m.group(1) == '-' ? -v : v;
  }
  return total;
}

/// "1,91,410" (lakh grouping) or "191,410"; decimals only when there are some.
String formatMoney(int minor, {String symbol = '', bool lakh = false}) {
  final f = NumberFormat.decimalPatternDigits(
    locale: lakh ? 'en_IN' : 'en_US',
    decimalDigits: minor % 100 == 0 ? 0 : 2,
  );
  final body = f.format(minor.abs() / 100);
  return '${minor < 0 ? '-' : ''}$symbol$body';
}
