import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/core/money.dart';
import 'package:bluecoins/domain/parse/entry_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseMoney', () {
    const cases = {
      '123720': 12372000,
      '1,91,410.32': 19141032,
      '197600+4000+10': 19760000 + 400000 + 1000,
      '4.35': 435, // a double would give 434
      '100-25.5': 7450,
      '-50': -5000,
    };
    cases.forEach((k, v) => expect(parseMoney(k), v, reason: k));
    for (final bad in ['', 'abc', '1.234,56', '12.345', '5+', '+', '1..2']) {
      expect(parseMoney(bad), isNull, reason: bad);
    }
  });

  test('formatMoney', () {
    expect(formatMoney(19141032, lakh: true), '1,91,410.32');
    expect(formatMoney(19141000, lakh: true), '1,91,410');
    expect(formatMoney(19141000), '191,410');
    expect(formatMoney(-500, symbol: '৳'), '-৳5');
  });

  final today = day(2026, 9, 8);
  test('parseEntry reads one date and one amount in any order', () {
    final cases = {
      '26 april, 123720': (day(2026, 4, 26), 12372000),
      'May 3 106500': (day(2026, 5, 3), 10650000),
      '14th June 139000': (day(2026, 6, 14), 13900000),
      '199500 jul 30': (day(2026, 7, 30), 19950000),
      '197600+4000+10 jul 28': (day(2026, 7, 28), 20161000),
      '1,91,410.32 aug 4': (day(2026, 8, 4), 19141032),
    };
    cases.forEach((text, want) {
      final r = parseEntry(text, today)!;
      expect((r.day, r.amount), want, reason: text);
    });
  });

  test('parseEntry edge cases', () {
    expect(parseEntry('5000', today)!.day, isNull); // no date: caller must ask
    expect(parseEntry('5000', today)!.amount, 500000);
    final onlyDate = parseEntry('26 april', today)!;
    expect((onlyDate.day, onlyDate.amount), (day(2026, 4, 26), null));
    expect(
      parseEntry('dec 31 5000', day(2026, 1, 5))!.day,
      day(2025, 12, 31),
    ); // most recent past
    for (final bad in ['', 'hello', '31 april 100', '1.234,56 aug 4']) {
      expect(parseEntry(bad, today), isNull, reason: bad);
    }
  });
}
