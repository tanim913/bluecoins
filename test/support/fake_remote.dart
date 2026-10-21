import 'package:bluecoins/data/sync/sync_engine.dart';

/// Behaves like the Supabase tables: every upsert call shares one server timestamp (like
/// now() in a statement), and a write that is not newer than the stored row is ignored.
class FakeRemote implements RemoteStore {
  final tables = <String, Map<String, Map<String, Object?>>>{};
  final reject = <String>{};
  bool offline = false;
  int calls = 0;
  DateTime? stampOverride;

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    if (offline) throw StateError('network down');
    calls++;
    if (rows.any((r) => reject.contains(r['id']))) {
      throw const RemoteRejected('check constraint');
    }
    final ts =
        (stampOverride ??
                DateTime.utc(2026, 10, 1, 12).add(Duration(seconds: calls)))
            .toIso8601String();
    final t = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      final old = t[r['id']];
      if (old != null &&
          (r['updated_at']! as int) <= (old['updated_at']! as int)) {
        continue;
      }
      t[r['id']! as String] = {...r, 'server_updated_at': ts};
    }
  }

  @override
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required String sinceTs,
    required String sinceId,
    required int limit,
  }) async {
    if (offline) throw StateError('network down');
    final all = (tables[table]?.values.toList() ?? [])
      ..sort((a, b) {
        final c = (a['server_updated_at']! as String).compareTo(
          b['server_updated_at']! as String,
        );
        return c != 0 ? c : (a['id']! as String).compareTo(b['id']! as String);
      });
    return all
        .where((r) {
          final ts = r['server_updated_at']! as String;
          return ts.compareTo(sinceTs) > 0 ||
              (ts == sinceTs && (r['id']! as String).compareTo(sinceId) > 0);
        })
        .take(limit)
        .toList();
  }

  @override
  Future<bool> hasData() async => [
    ...?tables['checkins']?.values,
    ...?tables['incomes']?.values,
  ].any((r) => r['deleted_at'] == null);
}
