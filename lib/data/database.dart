import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Settings,
    Checkins,
    Incomes,
    Expenses,
    Categories,
    Bills,
    CycleStarts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bluecoins'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  // Never drop data: add a step per version here, e.g. if (from < 2) await m.addColumn(...).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(settings, settings.displayName);
        await m.addColumn(settings, settings.gender);
      }
    },
  );

  /// Defaults have updatedAt 0 and are not dirty, so they never overwrite a user's rename.
  Future<void> seedCategories() async {
    const defaults = {
      'food': ('Food', 0xFFE8A24B),
      'transport': ('Transport', 0xFF73B7F1),
      'bills': ('Bills', 0xFF8E9BD6),
      'shopping': ('Shopping', 0xFFD679B5),
      'health': ('Health', 0xFF5FC9A0),
      'fun': ('Fun', 0xFFB48CF2),
      'other': ('Other', 0xFF9AA5C4),
    };
    var i = 0;
    for (final e in defaults.entries) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: e.key,
          name: e.value.$1,
          color: e.value.$2,
          sort: Value(i++),
        ),
      );
    }
  }
}
