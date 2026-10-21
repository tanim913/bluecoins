import '../../core/day.dart';
import '../../core/money.dart';

class ParsedEntry {
  const ParsedEntry({this.day, this.amount});

  /// Null: the user gave no date, so the caller must ask. Never guessed.
  final Day? day;

  /// Null with a date: "nothing spent", carry the balance forward.
  final int? amount;
}

const _mon =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
final _monthDay = RegExp(
  '(?<![a-z])$_mon\\.?\\s*,?\\s*(\\d{1,2})(?:st|nd|rd|th)?(?!\\d)',
);
final _dayMonth = RegExp(
  '(?<!\\d)(\\d{1,2})(?:st|nd|rd|th)?\\s*,?\\s*$_mon(?![a-z])',
);
const _names = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// Reads one date and one amount in any order: "26 april, 123720", "May 3 106500",
/// "199500 jul 30", "197600+4000+10 jul 28". Null when the text is not understood.
/// shortcut: "5 may 12" is read as May 12; no explicit year (a missing year means the
/// most recent past date); use the date picker for anything else.
ParsedEntry? parseEntry(String text, Day today) {
  final t = text.toLowerCase().trim();
  var rest = t;
  Day? date;
  final a = _monthDay.firstMatch(t);
  final b = a == null ? _dayMonth.firstMatch(t) : null;
  final m = a ?? b;
  if (m != null) {
    final mon = _names.indexOf(m.group(a != null ? 1 : 2)!.substring(0, 3)) + 1;
    final d = int.parse(m.group(a != null ? 2 : 1)!);
    var c = DateTime.utc(today.year, mon, d);
    if (c.month != mon || c.day != d) return null;
    if (c.isAfter(today)) c = DateTime.utc(today.year - 1, mon, d);
    if (c.month != mon || c.day != d) return null; // 29 Feb in a non-leap year
    date = c;
    rest = t.replaceRange(m.start, m.end, ' ');
  }
  if (rest.replaceAll(RegExp(r'[\s,]'), '').isEmpty) {
    return date == null ? null : ParsedEntry(day: date);
  }
  final amount = parseMoney(rest);
  return amount == null ? null : ParsedEntry(day: date, amount: amount);
}
