import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day.dart';
import '../core/format.dart';
import '../data/database.dart';
import '../data/store.dart';
import 'overview.dart';

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

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main'),
);

/// Dark first, as designed.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values.asNameMap()[ref
          .watch(prefsProvider)
          .getString('theme')] ??
      ThemeMode.dark;

  void set(ThemeMode m) {
    state = m;
    ref.read(prefsProvider).setString('theme', m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Null until the data has loaded and onboarding is done.
final overviewProvider = Provider<Overview?>((ref) {
  final s = ref.watch(snapshotProvider).value;
  if (s == null || !s.onboarded) return null;
  return Overview(s, ref.watch(todayProvider));
});

final fmtProvider = Provider<Fmt>((ref) {
  final s = ref.watch(snapshotProvider).value?.settings;
  return s == null ? const Fmt() : Fmt(currency: s.currency, lakh: s.lakh);
});
