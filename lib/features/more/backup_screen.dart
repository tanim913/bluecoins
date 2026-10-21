import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/xlsx_export.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../../data/backup.dart';
import '../../data/files.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  void _say(BuildContext context, String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final stamp = dayKey(ref.read(todayProvider));
    final text = encodeBackup(await exportBackup(db));
    final shared = await shareBytes(
      'bluecoins-backup-$stamp.json',
      utf8.encode(text),
      'application/json',
    );
    if (shared) {
      await ref
          .read(prefsProvider)
          .setInt('lastBackup', DateTime.now().millisecondsSinceEpoch);
    }
    ref.invalidate(lastBackupProvider);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final text = await pickTextFile();
    if (text == null || !context.mounted) return;
    final BackupPreview preview;
    try {
      preview = parseBackup(store.db, text);
    } on FormatException catch (e) {
      return _say(context, e.message);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace everything on this phone?'),
        content: Text(
          'This backup has ${preview.checkins} balance entries and ${preview.counts['incomes'] ?? 0} incomes. '
          'Everything on this phone is replaced by it. A safety copy of your current data is saved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await writeSafetyCopy(store.db);
    await restoreBackup(store, preview);
    if (context.mounted) _say(context, 'Backup restored.');
  }

  Future<void> _excel(BuildContext context, WidgetRef ref) async {
    final o = ref.read(overviewProvider);
    if (o == null) return;
    final bytes = buildWorkbook(o);
    await shareBytes(
      'bluecoins-${dayKey(o.today)}.xlsx',
      bytes,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastBackupProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and export')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              last == null
                  ? 'You have not saved a backup file yet.'
                  : 'Last backup file: ${Fmt.dateY(dayOf(DateTime.fromMillisecondsSinceEpoch(last)))}',
              style: t.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Save a backup file'),
            subtitle: const Text(
              'Everything, as one file you can keep anywhere.',
            ),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from a backup file'),
            subtitle: const Text('Replaces what is on this phone.'),
            onTap: () => _restore(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export to Excel'),
            subtitle: const Text('Full history, cycle table and charts.'),
            onTap: () => _excel(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('Import from text'),
            subtitle: const Text('Paste lines like "26 april, 123720".'),
            onTap: () => context.push(Routes.importText),
          ),
        ],
      ),
    );
  }
}
