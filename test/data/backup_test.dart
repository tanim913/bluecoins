import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/backup.dart';
import 'package:bluecoins/data/database.dart';
import 'package:bluecoins/data/store.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Store> _store([int Function()? clock]) async {
  final s = Store(
    AppDatabase.forTesting(NativeDatabase.memory()),
    clock: clock,
  );
  addTearDown(s.db.close);
  return s;
}

Future<void> _fill(Store s) async {
  await s.saveSettings(
    const SettingsCompanion(payday: Value(25), budget: Value(6000000)),
  );
  await s.addCycleStart(day(2026, 4, 25));
  await s.saveCheckin(day(2026, 4, 24), 12500000, note: 'Starting balance');
  await s.saveCheckin(day(2026, 4, 27), 11700000);
  await s.saveIncome(
    Income(day(2026, 4, 27), 100, note: "it's a note with 'quotes'"),
  );
  await s.saveExpense(Expense(day(2026, 4, 27), 250, categoryId: 'food'));
  await s.saveBill(name: 'Gym', amount: 250000);
}

void main() {
  test('backup round-trips into an empty phone with identical data', () async {
    final a = await _store();
    await _fill(a);
    final text = encodeBackup(await exportBackup(a.db));
    final b = await _store();
    await restoreBackup(b, parseBackup(b.db, text));
    final x = await a.load(), y = await b.load();
    expect(
      y.checkins.map((c) => (c.date, c.balance, c.note)),
      x.checkins.map((c) => (c.date, c.balance, c.note)),
    );
    expect(y.incomes.single.note, "it's a note with 'quotes'");
    expect(y.expenses.single.categoryId, 'food');
    expect((y.settings!.payday, y.settings!.budget), (25, 6000000));
    expect(y.bills.single.name, 'Gym');
    expect(y.cycleStarts, x.cycleStarts);
  });

  test(
    'restore soft-deletes what the file lacks and marks everything for upload',
    () async {
      final a = await _store();
      await _fill(a);
      final text = encodeBackup(await exportBackup(a.db));
      final b = await _store();
      await b.saveCheckin(day(2026, 1, 1), 999); // not in the backup
      await restoreBackup(b, parseBackup(b.db, text));
      final live = await b.load();
      expect(live.checkins.any((c) => c.date == day(2026, 1, 1)), isFalse);
      final raw = await b.db.select(b.db.checkins).get();
      expect(
        raw.firstWhere((r) => r.id == '2026-01-01').deletedAt,
        isNotNull,
      ); // the delete can sync
      expect(raw.every((r) => r.dirty), isTrue);
    },
  );

  test('a corrupt or hostile file changes nothing', () async {
    final s = await _store();
    await _fill(s);
    for (final bad in [
      'not json',
      '{"app":"other","tables":{}}',
      '{"app":"bluecoins","version":99,"tables":{}}',
      '{"app":"bluecoins","version":1,"tables":{"checkins":[{"id":"2026-01-01","balance); DROP TABLE checkins; --":1}]}}',
      '{"app":"bluecoins","version":1,"tables":{"checkins":[{"balance":5}]}}',
      '{"app":"bluecoins","version":1,"tables":{"checkins":"x"}}',
    ]) {
      expect(() => parseBackup(s.db, bad), throwsFormatException, reason: bad);
    }
    expect((await s.load()).checkins.length, 2);
  });

  test(
    'restoring an empty backup empties the phone but keeps it recoverable',
    () async {
      final s = await _store();
      await _fill(s);
      final empty = encodeBackup({
        'app': 'bluecoins',
        'version': 1,
        'exportedAt': '',
        'tables': {},
      });
      await restoreBackup(s, parseBackup(s.db, empty));
      expect((await s.load()).checkins, isEmpty);
      expect((await s.db.select(s.db.checkins).get()).length, 2);
    },
  );
}
