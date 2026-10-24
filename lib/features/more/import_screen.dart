import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/parse/entry_parser.dart';

/// Bring in balances typed as text, one per line: "26 april, 123720", "May 3 106500".
/// Lines with only a date mean "nothing spent". A day you already logged is replaced.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({List<ParsedEntry> ok, List<String> bad}) _parse() {
    final today = ref.read(todayProvider);
    final ok = <ParsedEntry>[], bad = <String>[];
    for (final line
        in _c.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)) {
      final e = parseEntry(line, today);
      if (e == null || e.day == null) {
        bad.add(line);
      } else {
        ok.add(e);
      }
    }
    return (ok: ok, bad: bad);
  }

  Future<void> _import(List<ParsedEntry> entries) async {
    setState(() => _busy = true);
    final store = ref.read(storeProvider);
    for (final e in entries) {
      await store.saveCheckin(e.day!, e.amount, note: 'Imported');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${entries.length} entries.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = _parse();
    final t = Theme.of(context).textTheme;
    final f = ref.watch(fmtProvider);
    return GlassScaffold(
      appBar: AppBar(title: const Text('Import from text')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text(
            'One balance per line, with its date. The year is the current or most recent one.',
            style: t.bodyMedium?.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            minLines: 8,
            maxLines: 14,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '26 april, 123720\nMay 3 106500\n199500 jul 30',
            ),
          ),
          const SizedBox(height: 12),
          if (_c.text.trim().isNotEmpty) ...[
            Text('${r.ok.length} ready to import', style: t.titleSmall),
            for (final e in r.ok.take(3))
              Text(
                '${Fmt.dateY(e.day!)}: ${e.amount == null ? 'nothing spent' : f.money(e.amount!)}',
                style: t.bodySmall?.copyWith(color: context.palette.muted),
              ),
            if (r.ok.length > 3)
              Text(
                'and ${r.ok.length - 3} more',
                style: t.bodySmall?.copyWith(color: context.palette.muted),
              ),
            if (r.bad.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${r.bad.length} lines skipped (no date or amount I can read):',
                style: t.titleSmall?.copyWith(color: context.palette.warn),
              ),
              for (final b in r.bad.take(4)) Text(b, style: t.bodySmall),
            ],
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: r.ok.isEmpty || _busy ? null : () => _import(r.ok),
            child: Text('Import ${r.ok.length} entries'),
          ),
        ],
      ),
    );
  }
}
