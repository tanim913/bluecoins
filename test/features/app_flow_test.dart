import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets(
    'first run: onboarding leads to a Home with the starting balance',
    (tester) async {
      final h = Harness(tester);
      await h.start(seeded: false);
      expect(find.text('Know what you can spend today'), findsOneWidget);
      await h.tap(find.text('Get started'));
      await tester.enterText(find.byType(TextField).first, '125000');
      await h.tap(find.text('Continue'));
      await h.tap(find.text('Start tracking'));
      expect(find.text('Bluecoins'), findsWidgets);
      final snap = await tester.runAsync(h.store.load);
      expect(snap!.checkins.single.balance, 12500000);
      expect(snap.settings!.payday, 1);
      await h.dispose();
    },
  );

  testWidgets('Home shows the allowance from the spec sample', (tester) async {
    final h = Harness(tester);
    await h.start();
    expect(find.text('You can spend'), findsOneWidget);
    expect(find.text('৳1,926'), findsOneWidget); // (60,000 - 8,000) / 27 days
    expect(find.textContaining('a day for the next 27 days'), findsOneWidget);
    expect(find.text('Day 3 of 30  ·  25 Apr – 24 May'), findsOneWidget);
    expect(
      find.text('৳2,000 ahead of pace'),
      findsOneWidget,
    ); // 8,000 spent vs 6,000 expected after 3 of 30 days
    await h.dispose();
  });

  testWidgets('saving today balance from Home updates spending', (
    tester,
  ) async {
    final h = Harness(
      tester,
      today: day(2026, 4, 28),
    ); // the day after the last seeded balance
    await h.start();
    await tester.enterText(find.byType(TextField).first, '113000');
    await h.tap(find.text('Save balance'));
    expect(
      find.textContaining('Spent ৳4,000'),
      findsOneWidget,
    ); // 117,000 -> 113,000
    expect(find.text("Today's balance is logged"), findsOneWidget);
    await h.dispose();
  });

  testWidgets('add an expense and see it in History, then delete with undo', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.start();
    await h.tap(find.text('Add'));
    await h.tap(find.text('Expense'));
    await tester.enterText(find.byType(TextField).first, '450');
    await h.tap(find.text('Food'));
    await h.tap(find.text('Save'));
    await h.tap(find.text('History'));
    expect(find.textContaining('−৳450'), findsOneWidget);
    await tester.drag(find.textContaining('−৳450'), const Offset(-600, 0));
    await h.settle();
    expect(find.textContaining('−৳450'), findsNothing);
    await h.tap(find.text('Undo'));
    expect((await tester.runAsync(h.store.load))!.expenses.length, 1);
    await h.dispose();
  });

  testWidgets('typing a date in the amount field sets the date', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.start();
    await h.tap(find.text('Add'));
    await tester.enterText(find.byType(TextField).first, '26 april 120330');
    await h.settle();
    expect(find.textContaining('on 26 Apr'), findsOneWidget);
    expect(find.text('26 Apr 2026'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('a salary on the same day asks whether the balance includes it', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.start();
    await tester.runAsync(() => h.store.saveIncome(Income(h.today, 8500000)));
    await h.settle();
    await h.tap(find.text('Add'));
    expect(find.textContaining('already includes'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('every main screen renders without errors', (tester) async {
    final h = Harness(tester);
    await h.start();
    for (final tab in ['History', 'Insights', 'More', 'Home']) {
      await h.tap(find.text(tab).last);
    }
    await h.tap(find.text('More').last);
    for (final item in ['What if', 'Bills', 'Settings']) {
      await h.tap(find.text(item));
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await h.settle();
    }
    await h.dispose();
  });
}
