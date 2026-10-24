import 'package:bluecoins/app/providers.dart';
import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

class _FakeReminder extends ReminderService {
  final calls = <String>[];
  @override
  Future<bool> enable(int hour, int minute) async {
    calls.add('on $hour:$minute');
    return true;
  }

  @override
  Future<void> disable() async => calls.add('off');
}

void main() {
  testWidgets('app lock covers the app until the system prompt succeeds', (
    tester,
  ) async {
    var allow = false;
    final h = Harness(tester);
    await h.start(
      prefs: {'lock': true},
      overrides: [
        authProvider.overrideWithValue((_) async => allow),
        secureWindowProvider.overrideWithValue((_) async {}),
      ],
    );
    expect(find.text('Enough is locked'), findsOneWidget);
    await h.tap(find.text('Unlock')); // refused
    expect(find.text('Enough is locked'), findsOneWidget);
    allow = true;
    await h.tap(find.text('Unlock'));
    expect(find.text('Enough is locked'), findsNothing);
    expect(find.text('You can spend'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('turning the lock on needs the system prompt to pass', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.start(
      overrides: [
        authProvider.overrideWithValue((_) async => false),
        secureWindowProvider.overrideWithValue((_) async {}),
      ],
    );
    await h.tap(find.text('More').last);
    await h.tap(find.text('Settings'));
    await tester.scrollUntilVisible(
      find.text('Lock the app'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await h.tap(find.text('Lock the app'));
    expect(find.textContaining('lock stays off'), findsOneWidget);
    await h.dispose();
  });

  testWidgets(
    'the daily reminder is scheduled and cancelled through the service',
    (tester) async {
      final fake = _FakeReminder();
      final h = Harness(tester);
      await h.start(
        overrides: [reminderServiceProvider.overrideWithValue(fake)],
      );
      await h.tap(find.text('More').last);
      await h.tap(find.text('Settings'));
      await tester.scrollUntilVisible(
        find.text('Daily reminder'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await h.tap(find.text('Daily reminder'));
      await h.tap(find.text('OK'));
      expect(fake.calls.single, 'on 21:0');
      await h.tap(find.text('Daily reminder'));
      expect(fake.calls.last, 'off');
      await h.dispose();
    },
  );

  testWidgets('pasted text becomes balance entries', (tester) async {
    final h = Harness(tester, today: day(2026, 9, 8));
    await h.start();
    await h.tap(find.text('More').last);
    await h.tap(find.text('Backup and export'));
    await h.tap(find.text('Import from text'));
    await tester.enterText(
      find.byType(TextField),
      '5 may, 140000\n6 may 138500\nnonsense',
    );
    await h.settle();
    expect(find.text('2 ready to import'), findsOneWidget);
    expect(find.textContaining('1 lines skipped'), findsOneWidget);
    await h.tap(find.text('Import 2 entries'));
    final snap = await tester.runAsync(h.store.load);
    expect(
      snap!.checkins.map((c) => c.balance),
      containsAll([14000000, 13850000]),
    );
    await h.dispose();
  });
}
