import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/day.dart';
import '../domain/ledger/ledger.dart';
import '../domain/ledger/models.dart';
import 'database.dart';

/// Everything the screens need, read in one go. Data is tiny, so one snapshot is simpler
/// than a stream per table.
class Snapshot {
  const Snapshot({
    required this.settings,
    required this.checkins,
    required this.incomes,
    required this.expenses,
    required this.cycleStarts,
    required this.categories,
    required this.bills,
  });

  final Setting? settings;
  final List<Checkin> checkins;
  final List<Income> incomes;
  final List<Expense> expenses;
  final List<Day> cycleStarts;
  final List<Category> categories;
  final List<Bill> bills;

  bool get onboarded =>
      settings != null && cycleStarts.isNotEmpty && checkins.isNotEmpty;
  Ledger get ledger => Ledger(checkins, incomes, expenses);
  Tracking get tracking =>
      settings?.tracking == 'expenses' ? Tracking.expenses : Tracking.balance;
  CycleRule get rule => settings?.payday != null
      ? CycleRule.monthly(settings!.payday!)
      : CycleRule.every(settings?.everyDays ?? 30);
}

/// The only place that writes. Every write stamps updatedAt and sets dirty so a later
/// sync knows what to upload; deletes are soft.
class Store {
  Store(this.db, {int Function()? clock})
    : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase db;
  final int Function() _clock;
  final _uuid = const Uuid();
  int _last = 0;

  /// Hybrid clock: never goes backwards, and moves past any stamp seen from the cloud.
  int stamp() => _last = math.max(_clock(), _last + 1);
  void seen(int ts) => _last = math.max(_last, ts);

  Future<Snapshot> load() async {
    final settings = await (db.select(
      db.settings,
    )..where((t) => t.deletedAt.isNull())).getSingleOrNull();
    final cks = await (db.select(
      db.checkins,
    )..where((t) => t.deletedAt.isNull())).get();
    final incs = await (db.select(
      db.incomes,
    )..where((t) => t.deletedAt.isNull())).get();
    final exps = await (db.select(
      db.expenses,
    )..where((t) => t.deletedAt.isNull())).get();
    final starts = await (db.select(
      db.cycleStarts,
    )..where((t) => t.deletedAt.isNull())).get();
    final cats = await (db.select(
      db.categories,
    )..where((t) => t.deletedAt.isNull())).get();
    final bills = await (db.select(
      db.bills,
    )..where((t) => t.deletedAt.isNull())).get();
    return Snapshot(
      settings: settings,
      checkins: [
        for (final r in cks)
          Checkin(parseDayKey(r.id), r.balance, note: r.note),
      ],
      incomes: [
        for (final r in incs)
          Income(
            parseDayKey(r.date),
            r.amount,
            afterCheckin: r.afterCheckin,
            countsInPrevious: r.countsInPrevious,
            source: r.source,
            note: r.note,
            id: r.id,
          ),
      ],
      expenses: [
        for (final r in exps)
          Expense(
            parseDayKey(r.date),
            r.amount,
            categoryId: r.categoryId,
            note: r.note,
            id: r.id,
          ),
      ],
      cycleStarts: [for (final r in starts) parseDayKey(r.id)]..sort(),
      categories: cats..sort((a, b) => a.sort.compareTo(b.sort)),
      bills: bills,
    );
  }

  /// Emits now and after every write to any table.
  Stream<Snapshot> watch() => db
      .customSelect('SELECT 1', readsFrom: db.allTables.toSet())
      .watch()
      .asyncMap((_) => load());

  Future<void> saveSettings(SettingsCompanion s) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        s.copyWith(
          id: const Value('settings'),
          updatedAt: Value(stamp()),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );

  Future<void> saveCheckin(Day d, int? balance, {String note = ''}) => db
      .into(db.checkins)
      .insertOnConflictUpdate(
        CheckinsCompanion(
          id: Value(dayKey(d)),
          balance: Value(balance),
          note: Value(note),
          updatedAt: Value(stamp()),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );

  Future<void> deleteCheckin(Day d) => _softDelete(db.checkins, dayKey(d));

  Future<void> saveIncome(Income i) => db
      .into(db.incomes)
      .insertOnConflictUpdate(
        IncomesCompanion(
          id: Value(i.id.isEmpty ? _uuid.v4() : i.id),
          date: Value(dayKey(i.date)),
          amount: Value(i.amount),
          source: Value(i.source),
          note: Value(i.note),
          afterCheckin: Value(i.afterCheckin),
          countsInPrevious: Value(i.countsInPrevious),
          updatedAt: Value(stamp()),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );

  Future<void> deleteIncome(String id) => _softDelete(db.incomes, id);

  Future<void> saveExpense(Expense e) => db
      .into(db.expenses)
      .insertOnConflictUpdate(
        ExpensesCompanion(
          id: Value(e.id.isEmpty ? _uuid.v4() : e.id),
          date: Value(dayKey(e.date)),
          amount: Value(e.amount),
          categoryId: Value(e.categoryId),
          note: Value(e.note),
          updatedAt: Value(stamp()),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );

  Future<void> deleteExpense(String id) => _softDelete(db.expenses, id);

  Future<void> saveBill({
    String id = '',
    required String name,
    required int amount,
    bool archived = false,
    String? paidForCycle,
  }) => db
      .into(db.bills)
      .insertOnConflictUpdate(
        BillsCompanion(
          id: Value(id.isEmpty ? _uuid.v4() : id),
          name: Value(name),
          amount: Value(amount),
          archived: Value(archived),
          paidForCycle: Value(paidForCycle),
          updatedAt: Value(stamp()),
          deletedAt: const Value(null),
          dirty: const Value(true),
        ),
      );

  Future<void> deleteBill(String id) => _softDelete(db.bills, id);

  /// Inserts the boundary if it is not already stored (also used to persist generated starts).
  Future<void> addCycleStart(Day d) async {
    final id = dayKey(d);
    final row = await (db.select(
      db.cycleStarts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null && row.deletedAt == null) return;
    await db
        .into(db.cycleStarts)
        .insertOnConflictUpdate(
          CycleStartsCompanion(
            id: Value(id),
            updatedAt: Value(stamp()),
            deletedAt: const Value(null),
            dirty: const Value(true),
          ),
        );
  }

  Future<void> removeCycleStart(Day d) =>
      _softDelete(db.cycleStarts, dayKey(d));

  Future<void> _softDelete(TableInfo<Table, dynamic> t, String id) {
    final s = stamp();
    return db.customUpdate(
      'UPDATE ${t.actualTableName} SET deleted_at = ?1, updated_at = ?1, dirty = 1 WHERE id = ?2',
      variables: [Variable.withInt(s), Variable.withString(id)],
      updates: {t},
    );
  }

  /// Empties the phone (sign-out, restore from cloud). Defaults come back.
  Future<void> wipe() => db.transaction(() async {
    for (final t in db.allTables) {
      await db.delete(t).go();
    }
    await db.seedCategories();
  });
}
