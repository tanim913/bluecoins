import 'dart:io';
import 'dart:ui' as ui;

import 'package:bluecoins/app/app.dart';
import 'package:bluecoins/app/profile.dart';
import 'package:bluecoins/app/providers.dart';
import 'package:bluecoins/app/updates.dart';
import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/database.dart';
import 'package:bluecoins/data/store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_profile.dart';

/// A phone-sized app on an in-memory database, with a fixed "today".
class Harness {
  Harness(this.tester, {Day? today}) : today = today ?? day(2026, 4, 27);
  final WidgetTester tester;
  final Day today;
  late final AppDatabase db;
  late final Store store;
  late final SharedPreferences sharedPrefs;
  final _shot = GlobalKey();

  Future<void> start({
    bool seeded = true,
    bool dark = true,
    double textScale = 1,
    Future<void> Function(Harness)? seeder,
    Map<String, Object> prefs = const {},
    List<Override> overrides = const [],
    FakeUpdateChecker? updates,
    FakePhotoStore? photos,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'theme': dark ? 'dark' : 'light',
      ...prefs,
    });
    final sp = sharedPrefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = Store(db);
    if (seeded) {
      await tester.runAsync(() => seeder == null ? seed() : seeder(this));
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shot,
        child: ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            prefsProvider.overrideWithValue(sp),
            // Never reach the network or the camera from a test.
            installedVersionProvider.overrideWith((_) async => '1.0.0'),
            updateCheckerProvider.overrideWithValue(
              updates ?? FakeUpdateChecker(),
            ),
            photoStoreProvider.overrideWithValue(photos ?? FakePhotoStore()),
            ...overrides,
            todayProvider.overrideWithValue(today),
          ],
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: const BluecoinsApp(),
          ),
        ),
      ),
    );
    await settle();
  }

  /// The spec's sample: start 25 Apr with 125,000, spent 4,670 then 3,330; budget 60,000.
  Future<void> seed() async {
    await store.saveSettings(
      const SettingsCompanion(
        payday: Value(25),
        budget: Value(6000000),
        baseSalary: Value(8500000),
      ),
    );
    await store.addCycleStart(day(2026, 4, 25));
    await store.saveCheckin(
      day(2026, 4, 24),
      12500000,
      note: 'Starting balance',
    );
    await store.saveCheckin(day(2026, 4, 26), 12033000);
    await store.saveCheckin(day(2026, 4, 27), 11700000);
  }

  /// Lets the database stream, router redirect and animations finish.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  }

  Future<void> tap(Finder f) async {
    await tester.tap(f);
    await settle();
  }

  Future<void> writeScreenshot(String path) async {
    final boundary =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.625);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes.buffer.asUint8List());
    });
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }
}
