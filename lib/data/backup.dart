import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';
import 'store.dart';

const backupVersion = 1;

/// Every live row of every table, as plain JSON. Column names are the database's own, so a
/// backup is readable with any SQLite tool and survives code renames.
Future<Map<String, Object?>> exportBackup(
  AppDatabase db, {
  DateTime? now,
}) async {
  final tables = <String, Object?>{};
  for (final t in db.allTables) {
    final rows = await db
        .customSelect(
          'SELECT * FROM ${t.actualTableName} WHERE deleted_at IS NULL',
        )
        .get();
    tables[t.actualTableName] = [for (final r in rows) r.data];
  }
  return {
    'app': 'bluecoins', // kept from the first name so older backup files still restore
    'version': backupVersion,
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'tables': tables,
  };
}

String encodeBackup(Map<String, Object?> b) =>
    const JsonEncoder.withIndent(' ').convert(b);

/// What a backup file holds, checked before anything is changed.
class BackupPreview {
  const BackupPreview(this.exportedAt, this.counts, this.tables);
  final String exportedAt;
  final Map<String, int> counts;
  final Map<String, List<Map<String, Object?>>> tables;

  int get checkins => counts['checkins'] ?? 0;
}

/// Throws [FormatException] with a message fit for the user.
BackupPreview parseBackup(AppDatabase db, String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('This file is not an Enough backup.');
  }
  if (json is! Map || json['app'] != 'bluecoins' || json['tables'] is! Map) {
    throw const FormatException('This file is not an Enough backup.');
  }
  final version = json['version'];
  if (version is! int || version > backupVersion) {
    throw const FormatException(
      'This backup was made by a newer version of Enough. Update the app first.',
    );
  }
  final raw = json['tables'] as Map;
  final tables = <String, List<Map<String, Object?>>>{};
  for (final t in db.allTables) {
    final name = t.actualTableName;
    final columns = {for (final c in t.$columns) c.name};
    final rows = raw[name];
    if (rows == null) {
      tables[name] = const [];
      continue;
    }
    if (rows is! List) throw FormatException('The $name data is damaged.');
    tables[name] = [
      for (final r in rows)
        if (r is Map &&
            r['id'] is String &&
            r.keys.every((k) => columns.contains(k)) &&
            r.values.every((v) => v == null || v is num || v is String))
          r.cast<String, Object?>()
        else
          throw FormatException('The $name data is damaged.'),
    ];
  }
  return BackupPreview('${json['exportedAt'] ?? ''}', {
    for (final e in tables.entries) e.key: e.value.length,
  }, tables);
}

/// Replaces everything on this phone with the backup. Rows that are not in the file are
/// soft-deleted (so the deletion can sync later) and every restored row is stamped fresh and
/// marked for upload. One transaction: it all happens or none of it does.
Future<void> restoreBackup(Store store, BackupPreview b) {
  final db = store.db;
  return db.transaction(() async {
    final stamp = store.stamp();
    for (final t in db.allTables) {
      final name = t.actualTableName;
      final rows = b.tables[name] ?? const [];
      final ids = [for (final r in rows) r['id']! as String];
      final marks = List.filled(ids.length, '?').join(',');
      await db.customUpdate(
        'UPDATE $name SET deleted_at = ?, updated_at = ?, dirty = 1 WHERE deleted_at IS NULL${ids.isEmpty ? '' : ' AND id NOT IN ($marks)'}',
        variables: [
          Variable.withInt(stamp),
          Variable.withInt(stamp),
          for (final i in ids) Variable.withString(i),
        ],
        updates: {t},
      );
      for (final r in rows) {
        final row = {...r, 'updated_at': stamp, 'deleted_at': null, 'dirty': 1};
        final cols = row.keys.toList();
        await db.customUpdate(
          'INSERT OR REPLACE INTO $name (${cols.join(',')}) VALUES (${List.filled(cols.length, '?').join(',')})',
          variables: [for (final c in cols) _variable(row[c])],
          updates: {t},
        );
      }
    }
    store.seen(stamp);
  });
}

Variable _variable(Object? v) => switch (v) {
  null => const Variable<Object>(null),
  final int i => Variable.withInt(i),
  final double d => Variable.withReal(d),
  _ => Variable.withString('$v'),
};
