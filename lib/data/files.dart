import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup.dart';
import 'database.dart';

/// Hands a file to the system share sheet. False when the user dismissed it.
Future<bool> shareBytes(String name, List<int> bytes, String mime) async {
  final dir = await getTemporaryDirectory();
  final file = await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
  final r = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      fileNameOverrides: [name],
      subject: name,
    ),
  );
  return r.status != ShareResultStatus.dismissed;
}

/// Saves a full backup inside the app before anything destructive (restore, sign-out).
/// Keeps the newest five. Returns the file.
Future<File> writeSafetyCopy(AppDatabase db) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = await Directory('${docs.path}/safety').create(recursive: true);
  final stamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;
  final file = await File('${dir.path}/enough-safety-$stamp.json')
      .writeAsString(encodeBackup(await exportBackup(db)), flush: true);
  final all = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final old in all.skip(5)) {
    old.deleteSync();
  }
  return file;
}

/// Lets the user pick any file and reads it as text; null when cancelled.
Future<String?> pickTextFile() async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty || files.first.path == null) return null;
  return File(files.first.path!).readAsString();
}
