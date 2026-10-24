import 'package:bluecoins/app/cloud.dart';
import 'package:bluecoins/app/updates.dart';
import 'package:bluecoins/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_profile.dart';
import '../support/harness.dart';

const _release = 'https://github.com/tanim913/bluecoins/releases/tag/v1.0.1';

Future<void> _openProfile(Harness h) async {
  await h.tap(find.text('More').last);
  await h.tap(find.text('Profile'));
}

void main() {
  test('isNewer compares versions number by number', () {
    expect(isNewer('1.0.1', '1.0.0'), isTrue);
    expect(isNewer('v1.0.10', '1.0.9'), isTrue);
    expect(isNewer('1.1', '1.0.9'), isTrue);
    expect(isNewer('1.0.0', '1.0.0'), isFalse);
    expect(isNewer('1.0.0', '1.0.1'), isFalse);
    expect(isNewer('2.0.0-beta+3', '1.9.9'), isTrue);
    expect(isNewer('garbage', '1.0.0'), isFalse);
  });

  test(
    'a phone on the old schema gains the profile columns and keeps its data',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('''
          CREATE TABLE settings (id TEXT NOT NULL PRIMARY KEY, currency TEXT NOT NULL DEFAULT 'BDT',
            lakh INTEGER NOT NULL DEFAULT 1, payday INTEGER NULL, every_days INTEGER NULL,
            budget INTEGER NOT NULL DEFAULT 0, base_salary INTEGER NOT NULL DEFAULT 0,
            tracking TEXT NOT NULL DEFAULT 'balance', updated_at INTEGER NOT NULL DEFAULT 0,
            deleted_at INTEGER NULL, dirty INTEGER NOT NULL DEFAULT 0);
          INSERT INTO settings (id, currency) VALUES ('settings', 'INR');
          PRAGMA user_version = 1;
        '''),
        ),
      );
      final s = await db.select(db.settings).getSingle();
      expect(s.currency, 'INR');
      expect(s.displayName, isNull);
      expect(s.gender, isNull);
      await db.close();
    },
  );

  testWidgets('name and gender are saved, and Home greets by first name', (
    tester,
  ) async {
    final h = Harness(tester);
    await h.start();
    expect(find.text('Enough'), findsOneWidget); // no name yet
    await _openProfile(h);
    await tester.enterText(find.byType(TextField).first, 'Tanim Aziz');
    await h.tap(find.text('Male'));
    await h.tap(find.text('Save profile'));
    final s = (await tester.runAsync(h.store.load))!.settings!;
    expect(s.displayName, 'Tanim Aziz');
    expect(s.gender, 'male');
    expect(s.dirty, isTrue, reason: 'queued for the cloud');
    await tester.pageBack();
    await h.settle();
    await h.tap(find.text('Home'));
    expect(find.textContaining(', Tanim'), findsOneWidget);
    expect(find.textContaining('Aziz'), findsNothing);
    await h.dispose();
  });

  testWidgets('the photo stays on the phone and Reset the app removes it', (
    tester,
  ) async {
    final photos = FakePhotoStore();
    final h = Harness(tester);
    await h.start(
      photos: photos,
      overrides: [safetyCopyProvider.overrideWithValue((_) async {})],
    );
    await _openProfile(h);
    await h.tap(find.bySemanticsLabel('Change profile photo'));
    await h.tap(find.text('Choose from gallery'));
    expect(photos.picked, 1);
    final path = h.sharedPrefs.getString('profilePhoto');
    expect(path, isNotNull);
    await tester.pageBack();
    await h.settle();
    await h.tap(find.text('Backup and export'));
    await h.tap(find.text('Reset the app'));
    await h.tap(find.text('Reset'));
    expect(photos.deleted, contains(path));
    expect(h.sharedPrefs.getString('profilePhoto'), isNull);
    await h.dispose();
  });

  testWidgets('a newer release shows a banner that Later hides', (
    tester,
  ) async {
    final checker = FakeUpdateChecker(const UpdateInfo('1.0.1', _release));
    final h = Harness(tester);
    await h.start(updates: checker);
    expect(find.text('Version 1.0.1 is available'), findsOneWidget);
    await h.tap(find.text('Later'));
    expect(find.text('Version 1.0.1 is available'), findsNothing);
    await h.dispose();
  });

  testWidgets('no banner when up to date, and none when the switch is off', (
    tester,
  ) async {
    final same = FakeUpdateChecker(const UpdateInfo('1.0.0', _release));
    final h = Harness(tester);
    await h.start(updates: same);
    expect(find.textContaining('is available'), findsNothing);
    expect(same.calls, 1);
    await h.dispose();

    final off = FakeUpdateChecker(const UpdateInfo('9.0.0', _release));
    final h2 = Harness(tester);
    await h2.start(prefs: {'updateCheck': false}, updates: off);
    expect(find.textContaining('is available'), findsNothing);
    expect(off.calls, 0, reason: 'switched off: GitHub is never asked');
    await h2.dispose();
  });
}
