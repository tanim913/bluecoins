import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth.dart';
import '../data/database.dart';
import '../data/files.dart';
import '../data/sync/supabase_remote.dart';
import '../data/sync/sync_engine.dart';
import 'env.dart';
import 'providers.dart';

/// Null when this build has no cloud settings; tests override these with fakes.
final authServiceProvider = Provider<AuthService?>(
  (ref) => Env.cloud
      ? SupabaseAuthService(
          Supabase.instance.client,
          webClientId: Env.googleWebClientId,
        )
      : null,
);
final remoteProvider = Provider<RemoteStore?>(
  (ref) => Env.cloud ? SupabaseRemote(Supabase.instance.client) : null,
);

/// Saves a copy of the phone's data inside the app before anything destructive.
final safetyCopyProvider = Provider<Future<void> Function(AppDatabase)>(
  (ref) => (db) async {
    await writeSafetyCopy(db);
  },
);

final userProvider = StreamProvider<CloudUser?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  if (auth == null) {
    yield null;
    return;
  }
  yield auth.current;
  yield* auth.changes;
});

class SyncState {
  const SyncState({
    this.busy = false,
    this.lastSync,
    this.error,
    this.failed = const [],
  });
  final bool busy;
  final DateTime? lastSync;

  /// A message for the user, or null.
  final String? error;
  final List<String> failed;

  SyncState copyWith({
    bool? busy,
    DateTime? lastSync,
    String? error,
    List<String>? failed,
    bool clearError = false,
  }) => SyncState(
    busy: busy ?? this.busy,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : error ?? this.error,
    failed: failed ?? this.failed,
  );
}

enum SignInOutcome { ready, conflict }

/// Everything the account screen does. The engine itself is plain Dart (see sync_engine.dart).
class SyncController extends Notifier<SyncState> {
  Timer? _timer;
  SyncEngine? _engine;
  String? _engineUid;

  @override
  SyncState build() {
    ref.onDispose(() => _timer?.cancel());
    final ms = ref.read(prefsProvider).getInt('lastSync');
    return SyncState(
      lastSync: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  AuthService? get _auth => ref.read(authServiceProvider);

  SyncEngine? get _engineOrNull {
    final user = _auth?.current;
    final remote = ref.read(remoteProvider);
    if (user == null || remote == null) return null;
    if (_engineUid != user.id) {
      _engine = SyncEngine(
        ref.read(storeProvider),
        remote,
        SyncCursors(ref.read(prefsProvider), user.id),
      );
      _engineUid = user.id;
    }
    return _engine;
  }

  String _explain(Object e) => e is AuthException
      ? 'Please sign in again.'
      : 'Could not reach the cloud. Your data is safe on this phone and will upload later.';

  /// Uploads and downloads changes. True when it finished.
  Future<bool> sync() async {
    final engine = _engineOrNull;
    if (engine == null || engine.running) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final r = await engine.run();
      final now = DateTime.now();
      await ref
          .read(prefsProvider)
          .setInt('lastSync', now.millisecondsSinceEpoch);
      state = state.copyWith(
        busy: false,
        lastSync: now,
        failed: r?.failed ?? const [],
      );
      return true;
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: _explain(e));
      return false;
    }
  }

  /// After local writes: sync a few seconds later, only if something is waiting.
  void schedule() {
    if (_auth?.current == null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () async {
      if (await pendingChanges(ref.read(storeProvider)) > 0) await sync();
    });
  }

  Future<SignInOutcome> signIn() async {
    await _auth!.signIn();
    ref.invalidate(userProvider);
    final engine = _engineOrNull!;
    if (await engine.checkFirst() == FirstSync.conflict) {
      return SignInOutcome.conflict;
    }
    await sync();
    return SignInOutcome.ready;
  }

  /// "Use the account's data": keeps a safety copy of the phone's data, then replaces it.
  Future<void> useCloud() async {
    await ref.read(safetyCopyProvider)(ref.read(databaseProvider));
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _engineOrNull!.useCloud();
      state = state.copyWith(busy: false, lastSync: DateTime.now());
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: _explain(e));
    }
  }

  Future<void> cancelSignIn() async {
    await _auth!.signOut();
    ref.invalidate(userProvider);
  }

  /// Uploads what is waiting, keeps a safety copy, signs out and empties the phone. Returns
  /// false (and does nothing) if changes could not be uploaded and [force] is not set.
  Future<bool> signOut({bool force = false}) async {
    if (!force &&
        (!await sync() || await pendingChanges(ref.read(storeProvider)) > 0)) {
      return false;
    }
    final db = ref.read(databaseProvider);
    await ref.read(safetyCopyProvider)(db);
    final uid = _auth?.current?.id;
    await _auth!.signOut();
    await ref.read(storeProvider).wipe();
    if (uid != null) await SyncCursors(ref.read(prefsProvider), uid).clear();
    ref.invalidate(userProvider);
    return true;
  }

  Future<void> deleteAccount() async {
    await ref.read(safetyCopyProvider)(ref.read(databaseProvider));
    final uid = _auth!.current!.id;
    await _auth!.deleteAccount();
    await ref.read(storeProvider).wipe();
    await SyncCursors(ref.read(prefsProvider), uid).clear();
    ref.invalidate(userProvider);
  }

  Future<void> reuploadAll() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _engineOrNull!.reuploadAll();
      state = state.copyWith(busy: false, lastSync: DateTime.now());
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: _explain(e));
    }
  }
}

final syncProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Rows waiting to be uploaded; refreshes after every write and every sync.
final pendingProvider = FutureProvider<int>((ref) {
  ref.watch(snapshotProvider);
  ref.watch(syncProvider);
  return pendingChanges(ref.read(storeProvider));
});
