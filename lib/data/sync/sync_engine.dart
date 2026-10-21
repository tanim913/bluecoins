import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store.dart';

/// Tables in the order they are pushed.
const syncTables = [
  'settings',
  'categories',
  'checkins',
  'incomes',
  'expenses',
  'bills',
  'cycle_starts',
];

/// SQLite stores these as 0/1; the cloud has real booleans.
const _boolColumns = {
  'lakh',
  'after_checkin',
  'counts_in_previous',
  'archived',
};

/// The cloud, as the sync engine sees it. Rows are maps of column name to value, shaped like
/// the local table minus `dirty`; pulled rows also carry `server_updated_at` (an ISO string).
abstract interface class RemoteStore {
  /// Insert-or-update by id. The server ignores a row that is not newer than the stored one.
  Future<void> upsert(String table, List<Map<String, Object?>> rows);

  /// Rows strictly after (sinceTs, sinceId) ordered by (server_updated_at, id).
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required String sinceTs,
    required String sinceId,
    required int limit,
  });

  /// Does the account already hold any balances or incomes?
  Future<bool> hasData();
}

/// The server refused this data (a 4xx): retrying the same rows will not help.
class RemoteRejected implements Exception {
  const RemoteRejected(this.message);
  final String message;
  @override
  String toString() => 'RemoteRejected: $message';
}

/// Where each table's last pulled position is kept, per signed-in user.
class SyncCursors {
  SyncCursors(this._prefs, this._uid);
  final SharedPreferences _prefs;
  final String _uid;

  String _key(String t) => 'sync.$_uid.$t';

  ({String ts, String id})? get(String table) {
    final v = _prefs.getString(_key(table));
    if (v == null) return null;
    final i = v.indexOf('|');
    return (ts: v.substring(0, i), id: v.substring(i + 1));
  }

  Future<void> set(String table, String ts, String id) =>
      _prefs.setString(_key(table), '$ts|$id');

  Future<void> clear() async {
    for (final t in syncTables) {
      await _prefs.remove(_key(t));
    }
  }
}

class SyncReport {
  int pushed = 0;
  int pulled = 0;

  /// Rows the server refused, as "table id". They stay on the phone and are retried.
  final failed = <String>[];
}

enum FirstSync { ready, conflict }

class SyncEngine {
  SyncEngine(
    this.store,
    this.remote,
    this.cursors, {
    this.pageSize = 1000,
    this.batchSize = 500,
  });

  final Store store;
  final RemoteStore remote;
  final SyncCursors cursors;
  final int pageSize, batchSize;
  bool _running = false;

  bool get running => _running;

  /// One sync: upload local changes, then download the cloud's. Null when one is already
  /// running. Network and sign-in errors propagate and leave every local change marked, so
  /// nothing is lost and the next run retries.
  Future<SyncReport?> run() async {
    if (_running) return null;
    _running = true;
    try {
      final report = SyncReport();
      for (final t in syncTables) {
        await _push(t, report);
      }
      for (final t in syncTables) {
        await _pull(t, report);
      }
      return report;
    } finally {
      _running = false;
    }
  }

  Future<void> _push(String table, SyncReport report) async {
    final db = store.db;
    final rows = await db
        .customSelect('SELECT * FROM $table WHERE dirty = 1')
        .get();
    for (var i = 0; i < rows.length; i += batchSize) {
      final chunk = rows
          .sublist(i, i + batchSize > rows.length ? rows.length : i + batchSize)
          .map((r) => r.data)
          .toList();
      try {
        await remote.upsert(table, [for (final r in chunk) _toRemote(r)]);
        await _markClean(table, chunk);
        report.pushed += chunk.length;
      } on RemoteRejected {
        // One bad row must not block the rest: retry them one at a time.
        for (final r in chunk) {
          try {
            await remote.upsert(table, [_toRemote(r)]);
            await _markClean(table, [r]);
            report.pushed++;
          } on RemoteRejected {
            report.failed.add('$table ${r['id']}');
          }
        }
      }
    }
  }

  Map<String, Object?> _toRemote(Map<String, Object?> r) => {
    for (final e in r.entries)
      if (e.key != 'dirty')
        e.key: _boolColumns.contains(e.key) ? e.value == 1 : e.value,
  };

  /// Clears the dirty mark only if the row did not change while it was being uploaded.
  Future<void> _markClean(String table, List<Map<String, Object?>> sent) async {
    final t = store.db.allTables.firstWhere((x) => x.actualTableName == table);
    await store.db.transaction(() async {
      for (final r in sent) {
        await store.db.customUpdate(
          'UPDATE $table SET dirty = 0 WHERE id = ? AND updated_at = ?',
          variables: [
            Variable.withString(r['id']! as String),
            Variable.withInt(r['updated_at']! as int),
          ],
          updates: {t},
        );
      }
    });
  }

  Future<void> _pull(String table, SyncReport report) async {
    final cur = cursors.get(table);
    // Overlap one minute once per run, so a transaction that committed late is not missed.
    var ts = cur == null
        ? '1970-01-01T00:00:00Z'
        : DateTime.parse(cur.ts)
              .toUtc()
              .subtract(const Duration(seconds: 60))
              .toIso8601String();
    var id = '';
    String? lastTs, lastId;
    while (true) {
      final page = await remote.pull(
        table,
        sinceTs: ts,
        sinceId: id,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      for (final r in page) {
        if (await _apply(table, r)) report.pulled++;
      }
      lastTs = ts = page.last['server_updated_at']! as String;
      lastId = id = page.last['id']! as String;
      if (page.length < pageSize) break;
    }
    if (lastTs != null) await cursors.set(table, lastTs, lastId!);
  }

  /// Last write wins by updated_at; a local change not yet uploaded is kept if it is newer.
  Future<bool> _apply(String table, Map<String, Object?> r) async {
    final db = store.db;
    final t = db.allTables.firstWhere((x) => x.actualTableName == table);
    final remoteUpdated = r['updated_at']! as int;
    store.seen(remoteUpdated);
    final local = await db
        .customSelect(
          'SELECT updated_at, dirty FROM $table WHERE id = ?',
          variables: [Variable.withString(r['id']! as String)],
        )
        .getSingleOrNull();
    if (local != null &&
        local.read<int>('dirty') == 1 &&
        local.read<int>('updated_at') >= remoteUpdated) {
      return false;
    }
    final known = {for (final c in t.$columns) c.name};
    final row = {
      for (final e in r.entries)
        if (known.contains(e.key))
          e.key: e.value is bool ? ((e.value! as bool) ? 1 : 0) : e.value,
      'dirty': 0,
    };
    final cols = row.keys.toList();
    await db.customUpdate(
      'INSERT OR REPLACE INTO $table (${cols.join(',')}) VALUES (${List.filled(cols.length, '?').join(',')})',
      variables: [for (final c in cols) _variable(row[c])],
      updates: {t},
    );
    return true;
  }

  Variable _variable(Object? v) => switch (v) {
    null => const Variable<Object>(null),
    final int i => Variable.withInt(i),
    final double d => Variable.withReal(d),
    _ => Variable.withString('$v'),
  };

  /// Called right after signing in. Both sides holding data is a conflict the user must settle.
  Future<FirstSync> checkFirst() async {
    final local = await store.db
        .customSelect(
          'SELECT (SELECT count(*) FROM checkins WHERE deleted_at IS NULL) + (SELECT count(*) FROM incomes WHERE deleted_at IS NULL) AS n',
        )
        .getSingle();
    return local.read<int>('n') > 0 && await remote.hasData()
        ? FirstSync.conflict
        : FirstSync.ready;
  }

  /// Replaces this phone's data with the cloud's. The caller makes a safety copy first.
  Future<SyncReport?> useCloud() async {
    await store.wipe();
    await cursors.clear();
    return run();
  }

  /// Marks everything for upload again and starts from the beginning. Repairs a cloud
  /// database that was lost or restored from an old backup.
  Future<SyncReport?> reuploadAll() async {
    await store.db.transaction(() async {
      for (final t in store.db.allTables) {
        await store.db.customUpdate(
          'UPDATE ${t.actualTableName} SET dirty = 1',
          updates: {t},
        );
      }
    });
    await cursors.clear();
    return run();
  }

  /// Rows waiting to be uploaded.
  Future<int> pending() => pendingChanges(store);
}

Future<int> pendingChanges(Store store) async {
  var n = 0;
  for (final t in syncTables) {
    n +=
        (await store.db
                .customSelect('SELECT count(*) AS n FROM $t WHERE dirty = 1')
                .getSingle())
            .read<int>('n');
  }
  return n;
}
