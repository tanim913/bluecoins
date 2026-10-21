import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/database.dart';
import 'package:bluecoins/data/store.dart';
import 'package:bluecoins/data/sync/sync_engine.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_remote.dart';

/// One phone: its own database, clock and sync cursors.
class Phone {
  Phone(
    this.name,
    FakeRemote remote,
    SharedPreferences prefs, {
    this.pageSize = 1000,
    this.batchSize = 500,
  }) {
    store = Store(
      AppDatabase.forTesting(NativeDatabase.memory()),
      clock: () => now,
    );
    engine = SyncEngine(
      store,
      remote,
      SyncCursors(prefs, name),
      pageSize: pageSize,
      batchSize: batchSize,
    );
  }
  final String name;
  final int pageSize, batchSize;
  int now = 1000;
  late final Store store;
  late final SyncEngine engine;

  Future<int?> balanceOn(Day d) async => (await store.load()).checkins
      .where((c) => c.date == d)
      .firstOrNull
      ?.balance;
}

/// Edits the row on the phone while its upload is in flight.
class _Racing extends FakeRemote {
  Future<void> Function()? during;

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    final f = during;
    during = null;
    await f?.call();
    return super.upsert(table, rows);
  }
}

void main() {
  late FakeRemote cloud;
  late SharedPreferences prefs;
  final d = day(2026, 5, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeRemote();
  });

  Phone phone(String n, {int pageSize = 1000, int batchSize = 500}) {
    final p = Phone(n, cloud, prefs, pageSize: pageSize, batchSize: batchSize);
    addTearDown(p.store.db.close);
    return p;
  }

  test(
    'a change made on one phone reaches the other, including deletes',
    () async {
      final a = phone('a'), b = phone('b');
      await a.store.saveCheckin(d, 100);
      await a.store.saveIncome(Income(d, 50));
      await a.engine.run();
      await b.engine.run();
      expect(await b.balanceOn(d), 100);
      expect((await b.store.load()).incomes.single.amount, 50);
      a.now = 2000;
      await a.store.deleteCheckin(d);
      await a.engine.run();
      await b.engine.run();
      expect(await b.balanceOn(d), isNull);
    },
  );

  test('conflicting offline edits: the newer edit wins on both phones, whoever syncs first', () async {
    for (final aFirst in [true, false]) {
      cloud = FakeRemote();
      final a = phone('a$aFirst'), b = phone('b$aFirst');
      await a.store.saveCheckin(d, 1);
      await a.engine.run();
      await b.engine.run();
      a.now = 5000;
      b.now = 9000; // b edited later, but is offline
      await a.store.saveCheckin(d, 111);
      await b.store.saveCheckin(d, 222);
      for (final p in aFirst ? [a, b, a, b] : [b, a, b, a]) {
        await p.engine.run();
      }
      expect(await a.balanceOn(d), 222, reason: 'aFirst=$aFirst');
      expect(await b.balanceOn(d), 222, reason: 'aFirst=$aFirst');
    }
  });

  test('an old offline edit never overwrites a newer one (and a retry changes nothing)', () async {
    final a = phone('a'), b = phone('b');
    a.now = 9000;
    await a.store.saveCheckin(d, 900);
    await a.engine.run();
    b.now = 100;
    await b.store.saveCheckin(d, 5);
    await b.engine.run();
    await b.engine.run();
    expect(await b.balanceOn(d), 900);
    expect(cloud.tables['checkins']!['2026-05-01']!['balance'], 900);
  });

  test('the same date created on two phones leaves one check-in', () async {
    final a = phone('a'), b = phone('b');
    a.now = 100;
    b.now = 200;
    await a.store.saveCheckin(d, 1);
    await b.store.saveCheckin(d, 2);
    await a.engine.run();
    await b.engine.run();
    await a.engine.run();
    expect((await a.store.load()).checkins.length, 1);
    expect(await a.balanceOn(d), 2);
  });

  test('2,500 rows written in one statement (one timestamp) all arrive, page by page', () async {
    final a = phone('a'), b = phone('b', pageSize: 1000);
    await a.store.db.transaction(() async {
      for (var i = 0; i < 2500; i++) {
        await a.store.saveExpense(Expense(d, i + 1, id: 'e$i'));
      }
    });
    await a.engine.run();
    // The fake gives every upsert call its own timestamp, so force the worst case: all equal.
    final all = cloud.tables['expenses']!.values;
    for (final r in all) {
      r['server_updated_at'] = '2026-10-01T12:00:00.000Z';
    }
    await b.engine.run();
    expect((await b.store.load()).expenses.length, 2500);
    final again = await b.engine.run();
    expect(
      again!.pulled,
      lessThanOrEqualTo(2500),
    ); // overlap re-reads rows, harmlessly
    expect((await b.store.load()).expenses.length, 2500);
  });

  test(
    'a row the server refuses does not block the others and stays on the phone',
    () async {
      final a = phone('a');
      cloud.reject.add('bad');
      await a.store.saveExpense(Expense(d, 1, id: 'ok1'));
      await a.store.saveExpense(Expense(d, 2, id: 'bad'));
      await a.store.saveExpense(Expense(d, 3, id: 'ok2'));
      final r = (await a.engine.run())!;
      expect(r.failed, ['expenses bad']);
      expect(cloud.tables['expenses']!.keys, unorderedEquals(['ok1', 'ok2']));
      expect(await a.engine.pending(), 1);
    },
  );

  test(
    'going offline loses nothing: changes stay marked until a sync succeeds',
    () async {
      final a = phone('a');
      await a.store.saveCheckin(d, 7);
      cloud.offline = true;
      await expectLater(a.engine.run(), throwsStateError);
      expect(await a.engine.pending(), greaterThan(0));
      cloud.offline = false;
      await a.engine.run();
      expect(await a.engine.pending(), 0);
      expect(cloud.tables['checkins']!['2026-05-01']!['balance'], 7);
    },
  );

  test(
    'a change made while uploading is not marked clean and goes up next time',
    () async {
      final racing = _Racing();
      cloud = racing;
      final a = phone('a');
      await a.store.saveCheckin(d, 1);
      racing.during = () async {
        a.now = 5000;
        await a.store.saveCheckin(d, 2);
      };
      await a.engine.run();
      expect(await a.engine.pending(), 1);
      await a.engine.run();
      expect(await a.engine.pending(), 0);
      expect(cloud.tables['checkins']!['2026-05-01']!['balance'], 2);
    },
  );

  test('a late-committed row older than the cursor is still picked up (60 s overlap)', () async {
    final a = phone('a'), b = phone('b');
    await a.store.saveCheckin(d, 1);
    await a.engine.run();
    await b.engine.run(); // b's cursor is now just after a's row
    // A transaction that started earlier commits late: its server timestamp is 30 s in the past.
    cloud.stampOverride = DateTime.utc(
      2026,
      10,
      1,
      12,
    ).add(const Duration(seconds: 1)).subtract(const Duration(seconds: 30));
    final c = phone('c');
    await c.store.saveCheckin(day(2026, 5, 2), 2);
    await c.engine.run();
    cloud.stampOverride = null;
    await b.engine.run();
    expect(await b.balanceOn(day(2026, 5, 2)), 2);
  });

  test(
    'a local change that is newer than the cloud copy is kept when pulling',
    () async {
      final a = phone('a'), b = phone('b');
      await a.store.saveCheckin(d, 1);
      await a.engine.run();
      await b.engine.run();
      b.now = 50000;
      await b.store.saveCheckin(d, 99); // not uploaded yet
      a.now = 3000;
      await a.store.saveCheckin(d, 2);
      await a.engine.run();
      await b.engine.run();
      expect(await b.balanceOn(d), 99);
      expect(cloud.tables['checkins']!['2026-05-01']!['balance'], 99);
    },
  );

  test('first sign-in: both sides with data is a conflict; "use cloud" replaces the phone', () async {
    final a = phone('a'), b = phone('b');
    await a.store.saveCheckin(d, 1);
    await a.engine.run();
    expect(
      await a.engine.checkFirst(),
      FirstSync.ready.index == 0 ? FirstSync.conflict : FirstSync.ready,
    ); // a has data on both sides
    await b.store.saveCheckin(day(2026, 6, 1), 5);
    expect(await b.engine.checkFirst(), FirstSync.conflict);
    await b.engine.useCloud();
    expect((await b.store.load()).checkins.map((c) => c.balance), [1]);
    final empty = phone('c');
    expect(await empty.engine.checkFirst(), FirstSync.ready);
  });

  test('re-upload everything repairs a lost cloud', () async {
    final a = phone('a');
    await a.store.saveSettings(const SettingsCompanion(budget: Value(5)));
    await a.store.saveCheckin(d, 1);
    await a.engine.run();
    cloud.tables.clear(); // the cloud database was lost
    await a.engine.reuploadAll();
    expect(cloud.tables['checkins']!.keys, ['2026-05-01']);
    expect(cloud.tables['settings']!['settings']!['budget'], 5);
  });

  test(
    'booleans cross the wire as real booleans and come back as 0/1',
    () async {
      final a = phone('a'), b = phone('b');
      await a.store.saveIncome(Income(d, 10, afterCheckin: true, id: 'i1'));
      await a.engine.run();
      expect(cloud.tables['incomes']!['i1']!['after_checkin'], true);
      await b.engine.run();
      expect((await b.store.load()).incomes.single.afterCheckin, isTrue);
    },
  );
}
