import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'providers.dart';

const _repo = 'tanim913/bluecoins';
const _day = Duration(days: 1);

class UpdateInfo {
  const UpdateInfo(this.version, this.url);
  final String version, url;
}

/// True when [latest] is a higher version than [installed] ("1.0.10" > "1.0.9"; a leading "v"
/// and anything after "-" or "+" are ignored).
bool isNewer(String latest, String installed) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp('^v'), '')
      .split(RegExp('[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final a = parts(latest), b = parts(installed);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The newest published release, or null if it cannot be read (offline, rate-limited...).
abstract interface class UpdateChecker {
  Future<UpdateInfo?> latest();
}

class GithubUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateInfo?> latest() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await c.getUrl(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      );
      req.headers
        ..set('Accept', 'application/vnd.github+json')
        ..set('User-Agent', 'bluecoins-app');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(
        await res.transform(utf8.decoder).join(),
      ) as Map<String, Object?>;
      final tag = j['tag_name'];
      final url = j['html_url'];
      // Only ever send people to this project's own release page.
      if (tag is! String || url is! String) return null;
      if (!url.startsWith('https://github.com/$_repo/')) return null;
      return UpdateInfo(tag.replaceFirst(RegExp('^v'), ''), url);
    } on Object {
      return null;
    } finally {
      c.close(force: true);
    }
  }
}

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => GithubUpdateChecker(),
);

final installedVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Settings switch: look for new versions. On by default.
class UpdateCheckNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool('updateCheck') ?? true;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider).setBool('updateCheck', on);
  }
}

final updateCheckProvider = NotifierProvider<UpdateCheckNotifier, bool>(
  UpdateCheckNotifier.new,
);

/// The version the user said "Later" to.
class UpdateDismissedNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(prefsProvider).getString('updateDismissed');

  void dismiss(String version) {
    state = version;
    ref.read(prefsProvider).setString('updateDismissed', version);
  }
}

final updateDismissedProvider =
    NotifierProvider<UpdateDismissedNotifier, String?>(
      UpdateDismissedNotifier.new,
    );

/// A newer release than the one installed, or null. Asks GitHub at most once a day; the answer
/// is kept so the banner stays up between checks.
final updateProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (!ref.watch(updateCheckProvider)) return null;
  final prefs = ref.read(prefsProvider);
  final installed = await ref.watch(installedVersionProvider.future);
  final now = DateTime.now().millisecondsSinceEpoch;
  var version = prefs.getString('update.version');
  var url = prefs.getString('update.url');
  if (now - (prefs.getInt('update.at') ?? 0) >= _day.inMilliseconds) {
    final info = await ref.read(updateCheckerProvider).latest();
    if (info == null) return null; // try again next launch
    version = info.version;
    url = info.url;
    await prefs.setInt('update.at', now);
    await prefs.setString('update.version', version);
    await prefs.setString('update.url', url);
  }
  return version != null && url != null && isNewer(version, installed)
      ? UpdateInfo(version, url)
      : null;
});
