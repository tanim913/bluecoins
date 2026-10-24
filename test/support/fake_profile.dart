import 'dart:io';

import 'package:bluecoins/app/profile.dart';
import 'package:bluecoins/app/updates.dart';

/// "Picks" a tiny real PNG so image widgets can load it; remembers what was deleted.
class FakePhotoStore implements PhotoStore {
  final deleted = <String>[];
  int picked = 0;

  static const _png = [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    248,
    255,
    255,
    63,
    0,
    5,
    254,
    2,
    254,
    167,
    53,
    129,
    132,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130, //
  ];

  @override
  Future<String?> pick({required bool camera}) async {
    final f = File(
      '${Directory.systemTemp.path}/bc-test-photo-${picked++}.png',
    );
    await f.writeAsBytes(_png);
    return f.path;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

class FakeUpdateChecker implements UpdateChecker {
  FakeUpdateChecker([this.info]);
  final UpdateInfo? info;
  int calls = 0;

  @override
  Future<UpdateInfo?> latest() async {
    calls++;
    return info;
  }
}
