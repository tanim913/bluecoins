import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_engine.dart';

/// The cloud over Supabase's REST API. Row Level Security keeps every query to the signed-in
/// user's own rows; user_id is still sent explicitly so a bulk upsert never inserts NULLs.
class SupabaseRemote implements RemoteStore {
  SupabaseRemote(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    try {
      await _client
          .from(table)
          .upsert(
            [
              for (final r in rows) {...r, 'user_id': _uid},
            ],
            onConflict: 'user_id,id',
            defaultToNull: false,
          );
    } on PostgrestException catch (e) {
      // 23xxx: a check or key constraint; 22xxx: bad data; 42501: row-level security.
      final c = e.code ?? '';
      if (c.startsWith('23') ||
          c.startsWith('22') ||
          c == '42501' ||
          c == 'PGRST102') {
        throw RemoteRejected(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required String sinceTs,
    required String sinceId,
    required int limit,
  }) async {
    final rows = await _client
        .from(table)
        .select()
        .or(
          'server_updated_at.gt."$sinceTs",and(server_updated_at.eq."$sinceTs",id.gt."$sinceId")',
        )
        .order('server_updated_at')
        .order('id')
        .limit(limit);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<bool> hasData() async {
    for (final t in const ['checkins', 'incomes']) {
      final r = await _client
          .from(t)
          .select('id')
          .isFilter('deleted_at', null)
          .limit(1);
      if (r.isNotEmpty) return true;
    }
    return false;
  }
}
