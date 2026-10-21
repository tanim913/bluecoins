import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day.dart';
import '../core/format.dart';
import '../data/database.dart';
import '../data/reminder.dart';
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

/// Platform pieces behind functions so tests can replace them.
final authProvider = Provider<Future<bool> Function(String reason)>(
  (ref) => (reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  },
);

final secureWindowProvider = Provider<Future<void> Function(bool)>(
  (ref) => (secure) async {
    try {
      await const MethodChannel('com.tanimaziz.bluecoins/window')
          .invokeMethod<void>('setSecure', {'secure': secure});
    } on Object {
      // Not Android, or the channel is missing: the lock screen still hides the content.
    }
  },
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// "HH:mm" while the daily reminder is on, null when off.
class ReminderNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(prefsProvider).getString('reminder');

  Future<bool> set(String? hhmm) async {
    final svc = ref.read(reminderServiceProvider);
    if (hhmm == null) {
      await svc.disable();
    } else {
      final p = hhmm.split(':');
      if (!await svc.enable(int.parse(p[0]), int.parse(p[1]))) return false;
    }
    state = hhmm;
    final prefs = ref.read(prefsProvider);
    hhmm == null
        ? await prefs.remove('reminder')
        : await prefs.setString('reminder', hhmm);
    return true;
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, String?>(
  ReminderNotifier.new,
);

class LockNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool('lock') ?? false;

  /// Turning it on asks the system for a fingerprint or PIN first, so it cannot lock you out.
  Future<bool> set(bool on) async {
    if (on && !await ref.read(authProvider)('Turn on the app lock')) {
      return false;
    }
    state = on;
    await ref.read(prefsProvider).setBool('lock', on);
    await ref.read(secureWindowProvider)(on);
    return true;
  }
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);

/// When the last successful backup file was shared (ms since epoch), or null.
final lastBackupProvider = Provider<int?>(
  (ref) => ref.watch(prefsProvider).getInt('lastBackup'),
);
