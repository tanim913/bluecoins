import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file. Loads the bundled fonts (Noto Sans, Noto Sans
/// Bengali, Material Icons) so golden images show real glyphs instead of the
/// Ahem test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();
  await testMain();
}

Future<void> _loadAppFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(manifest) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final family in families) {
    final loader = FontLoader(family['family'] as String);
    for (final font
        in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
