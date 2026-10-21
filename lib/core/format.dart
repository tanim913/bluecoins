import 'day.dart';
import 'money.dart';

const currencies = {
  'BDT': '৳',
  'INR': '₹',
  'PKR': 'Rs ',
  'LKR': 'Rs ',
  'NPR': 'Rs ',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'MYR': 'RM ',
  'SGD': r'S$',
  'CAD': r'C$',
  'AUD': r'A$',
  'JPY': '¥',
  'KES': 'KSh ',
  'NGN': '₦',
  'ZAR': 'R ',
};

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats money and dates for the chosen currency. Lakh grouping (1,91,410) is a setting.
class Fmt {
  const Fmt({this.currency = 'BDT', this.lakh = true});
  final String currency;
  final bool lakh;

  String get symbol => currencies[currency] ?? '$currency ';
  String money(int minor) => formatMoney(minor, symbol: symbol, lakh: lakh);
  String signed(int minor) => minor > 0 ? '+${money(minor)}' : money(minor);

  /// Whole units, for headline figures where cents are noise.
  String whole(int minor) => money(roundDiv(minor, 100) * 100);
  String plain(int minor) => formatMoney(minor, lakh: lakh);

  /// Short axis label: 1.2k, 45k, 2.5M.
  static String compact(int minor) {
    final v = minor.abs() / 100;
    final sign = minor < 0 ? '-' : '';
    if (v >= 1e6) return '$sign${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)}M';
    if (v >= 1e3) return '$sign${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)}k';
    return '$sign${v.round()}';
  }

  static String date(Day d) => '${d.day} ${_months[d.month - 1]}';
  static String dateY(Day d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  static String range(Day a, Day b) => '${date(a)} – ${date(b)}';
}
