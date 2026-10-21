import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/database.dart';
import 'package:bluecoins/data/store.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Store store;
  var now = 1000;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = 1000;
    store = Store(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('fresh database has default categories and is not onboarded', () async {
    final s = await store.load();
    expect(s.categories.map((c) => c.id), contains('food'));
    expect(s.onboarded, isFalse);
  });

  test('onboarding data feeds the ledger', () async {
    await store.saveSettings(
      const SettingsCompanion(payday: Value(25), budget: Value(6000000)),
    );
    await store.addCycleStart(day(2026, 4, 25));
    await store.saveCheckin(day(2026, 4, 24), 12500000);
    await store.saveCheckin(day(2026, 4, 27), 11700000);
    final s = await store.load();
    expect(s.onboarded, isTrue);
    expect(s.rule.payday, 25);
    expect(s.ledger.segments.single.spent, 800000);
  });

  test('one check-in per date: saving again replaces it', () async {
    await store.saveCheckin(day(2026, 5, 1), 100);
    await store.saveCheckin(day(2026, 5, 1), 200, note: 'fixed');
    final s = await store.load();
    expect(
      (s.checkins.length, s.checkins.single.balance, s.checkins.single.note),
      (1, 200, 'fixed'),
    );
  });

  test('deleted rows are hidden from every read, marked dirty, and come back when re-saved', () async {
    await store.saveCheckin(day(2026, 5, 1), 100);
    await store.saveIncome(Income(day(2026, 5, 1), 50));
    await store.saveExpense(Expense(day(2026, 5, 1), 5));
    await store.saveBill(name: 'Gym', amount: 250000);
    var s = await store.load();
    await store.deleteIncome(s.incomes.single.id);
    await store.deleteExpense(s.expenses.single.id);
    await store.deleteBill(s.bills.single.id);
    await store.deleteCheckin(day(2026, 5, 1));
    s = await store.load();
    expect(
      [s.checkins, s.incomes, s.expenses, s.bills].every((l) => l.isEmpty),
      isTrue,
    );
    final raw = await db.select(db.checkins).get();
    expect(raw.single.deletedAt, isNotNull);
    expect(raw.single.dirty, isTrue);
    await store.saveCheckin(day(2026, 5, 1), 300);
    expect((await store.load()).checkins.single.balance, 300);
  });

  test(
    'stamps only increase, even if the clock stands still or goes back',
    () async {
      final a = store.stamp();
      final b = store.stamp();
      now = 10;
      final c = store.stamp();
      expect(b, greaterThan(a));
      expect(c, greaterThan(b));
      store.seen(5000);
      expect(store.stamp(), greaterThan(5000));
    },
  );

  test('persisting a generated cycle start twice keeps one row', () async {
    await store.addCycleStart(day(2026, 5, 25));
    final before = (await db.select(db.cycleStarts).get()).single.updatedAt;
    await store.addCycleStart(day(2026, 5, 25));
    expect((await db.select(db.cycleStarts).get()).single.updatedAt, before);
  });

  test('wipe empties the phone and restores defaults', () async {
    await store.saveCheckin(day(2026, 5, 1), 100);
    await store.wipe();
    final s = await store.load();
    expect(s.checkins, isEmpty);
    expect(s.settings, isNull);
    expect(s.categories, isNotEmpty);
  });

  test('watch emits after a write', () async {
    final seen = <int>[];
    final sub = store.watch().listen((s) => seen.add(s.checkins.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await store.saveCheckin(day(2026, 5, 1), 100);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });
}
