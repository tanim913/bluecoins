// Renders review screenshots into .impeccable/review/ (gitignored).
// Run: SCREENSHOTS=1 flutter test test/screenshots
import 'dart:io';

import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

Future<void> _richSeed(Harness h) async {
  final s = h.store;
  await h.seed();
  await s.saveCheckin(day(2026, 5, 6), 14730000);
  await s.saveIncome(Income(day(2026, 5, 6), 5100000, source: 'bonus'));
  await s.saveCheckin(day(2026, 5, 12), 12800000);
  await s.saveExpense(
    Expense(day(2026, 5, 12), 45000, categoryId: 'food', note: 'Lunch'),
  );
  await s.saveExpense(
    Expense(day(2026, 5, 13), 120000, categoryId: 'transport'),
  );
  await s.saveBill(name: 'Gym', amount: 250000);
  await s.saveBill(name: 'Maid', amount: 500000);
  await s.saveBill(name: 'Internet', amount: 60000);
}

void main() {
  final skip =
      Platform.environment['SCREENSHOTS'] ==
      null; // set SCREENSHOTS=1 to render
  const out = '.impeccable/review';

  for (final (name, dark, scale) in [
    ('dark', true, 1.0),
    ('light', false, 1.0),
    ('dark-font130', true, 1.3),
  ]) {
    testWidgets('screens $name', skip: skip, (tester) async {
      final h = Harness(tester, today: day(2026, 5, 14));
      await h.start(dark: dark, textScale: scale, seeder: _richSeed);

      await h.writeScreenshot('$out/phone-$name-home.png');
      await h.tap(find.text('Add'));
      await h.writeScreenshot('$out/phone-$name-add.png');
      await tester.tapAt(const Offset(10, 10));
      await h.settle();
      await h.tap(find.text('History'));
      await h.writeScreenshot('$out/phone-$name-history.png');
      await h.tap(find.text('Insights'));
      await h.writeScreenshot('$out/phone-$name-insights.png');
      await h.tap(find.text('More').last);
      await h.writeScreenshot('$out/phone-$name-more.png');
      await h.dispose();
    });
  }
}
