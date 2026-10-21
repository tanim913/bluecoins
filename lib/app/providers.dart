import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../data/database.dart';
import '../data/store.dart';

/// Overridden in tests with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final storeProvider = Provider<Store>(
  (ref) => Store(ref.watch(databaseProvider)),
);

final snapshotProvider = StreamProvider<Snapshot>(
  (ref) => ref.watch(storeProvider).watch(),
);

/// Today's local calendar date. Overridden in tests.
final todayProvider = Provider<Day>((ref) => dayOf(DateTime.now()));
