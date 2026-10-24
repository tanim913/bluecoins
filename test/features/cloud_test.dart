import 'package:bluecoins/app/cloud.dart';
import 'package:bluecoins/core/day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth.dart';
import '../support/fake_remote.dart';
import '../support/harness.dart';

/// What an existing account holds: the spec's sample (start 25 Apr, 125,000, budget 60,000).
FakeRemote _accountWithData() {
  final r = FakeRemote();
  const ts = '2026-10-01T12:00:00.000Z';
  Map<String, Object?> row(String id, Map<String, Object?> extra) => {
    'id': id,
    'updated_at': 1000,
    'deleted_at': null,
    'server_updated_at': ts,
    ...extra,
  };
  r.tables['settings'] = {
    'settings': row('settings', {
      'currency': 'BDT',
      'lakh': true,
      'payday': 25,
      'every_days': null,
      'budget': 6000000,
      'base_salary': 0,
      'tracking': 'balance',
    }),
  };
  r.tables['cycle_starts'] = {'2026-04-25': row('2026-04-25', {})};
  r.tables['checkins'] = {
    '2026-04-24': row('2026-04-24', {
      'balance': 12500000,
      'note': 'Starting balance',
    }),
    '2026-04-27': row('2026-04-27', {'balance': 11700000, 'note': ''}),
  };
  return r;
}

void main() {
  testWidgets(
    'Continue with Google signs in and fetches the account data in one step',
    (tester) async {
      final auth = FakeAuth();
      final h = Harness(tester, today: day(2026, 4, 27));
      await h.start(
        seeded: false,
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          remoteProvider.overrideWithValue(_accountWithData()),
          safetyCopyProvider.overrideWithValue((_) async {}),
        ],
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      await h.tap(find.text('Continue with Google'));
      // Straight to Home with the cloud data, no setup questions.
      expect(find.text('You can spend'), findsOneWidget);
      expect(find.text('Know what you can spend today'), findsNothing);
      expect((await tester.runAsync(h.store.load))!.checkins.length, 2);
      await h.dispose();
    },
  );

  testWidgets('a new account carries on to setup, and its data then uploads', (
    tester,
  ) async {
    final cloud = FakeRemote();
    final h = Harness(tester);
    await h.start(
      seeded: false,
      overrides: [
        authServiceProvider.overrideWithValue(FakeAuth()),
        remoteProvider.overrideWithValue(cloud),
        safetyCopyProvider.overrideWithValue((_) async {}),
      ],
    );
    await h.tap(find.text('Continue with Google'));
    expect(find.text('Your money'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '5000');
    await h.tap(find.text('Continue'));
    await h.tap(find.text('Start tracking'));
    await tester.pump(const Duration(seconds: 4)); // the 3 s sync timer fires
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    ); // its database work
    await h.settle();
    expect(cloud.tables['checkins']?.values.single['balance'], 500000);
    await h.dispose();
  });

  testWidgets('a failed sign-in says why and changes nothing', (tester) async {
    final h = Harness(tester);
    await h.start(
      seeded: false,
      overrides: [
        authServiceProvider.overrideWithValue(
          FakeAuth(fail: 'Sign-in cancelled.'),
        ),
        remoteProvider.overrideWithValue(FakeRemote()),
      ],
    );
    await h.tap(find.text('Continue with Google'));
    expect(find.text('Sign-in cancelled.'), findsOneWidget);
    expect(find.text('Know what you can spend today'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('signing out uploads first, then empties the phone', (
    tester,
  ) async {
    final cloud = FakeRemote();
    final auth = FakeAuth();
    await auth.signIn();
    final h = Harness(tester);
    await h.start(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        remoteProvider.overrideWithValue(cloud),
        safetyCopyProvider.overrideWithValue((_) async {}),
      ],
    );
    await h.tap(find.text('More').last);
    await h.tap(find.text('Account and sync'));
    expect(find.text('me@example.com'), findsOneWidget);
    await h.tap(find.text('Sign out').first);
    await h.tap(find.text('Sign out').last);
    expect(
      cloud.tables['checkins']!.length,
      3,
      reason: 'everything was uploaded before the wipe',
    );
    expect(
      find.text('Know what you can spend today'),
      findsOneWidget,
    ); // phone is empty again
    await h.dispose();
  });

  testWidgets(
    'Reset the app empties the phone and returns to the welcome page',
    (tester) async {
      final h = Harness(tester);
      var copies = 0;
      await h.start(
        overrides: [
          safetyCopyProvider.overrideWithValue((_) async => copies++),
        ],
      );
      await h.tap(find.text('More').last);
      await h.tap(find.text('Backup and export'));
      await h.tap(find.text('Reset the app'));
      await h.tap(find.text('Reset'));
      expect(find.text('Know what you can spend today'), findsOneWidget);
      expect(copies, 1);
      expect((await tester.runAsync(h.store.load))!.checkins, isEmpty);
      await h.dispose();
    },
  );

  testWidgets(
    'without cloud settings the account screen explains and the welcome page has one button',
    (tester) async {
      final h = Harness(tester);
      await h.start(seeded: false);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      await h.dispose();
    },
  );
}
