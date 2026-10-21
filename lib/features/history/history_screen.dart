import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../add/add_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _hidden =
      <String>{}; // dismissed rows, until the database stream catches up

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapshotProvider).value;
    final f = ref.watch(fmtProvider);
    final store = ref.read(storeProvider);
    final t = Theme.of(context).textTheme;
    if (snap == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ledger = snap.ledger;
    final spentAt = {for (final s in ledger.segments) s.to: s};
    final rows = <({Day date, String key, Widget tile})>[];

    void undo(String msg, Future<void> Function() restore) =>
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              action: SnackBarAction(label: 'Undo', onPressed: restore),
            ),
          );

    Widget dismissible(
      String key,
      Widget child,
      Future<void> Function() delete,
      Future<void> Function() restore,
    ) => Dismissible(
      key: ValueKey(key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        setState(() => _hidden.add(key));
        await delete();
        undo('Deleted', () async {
          await restore();
          if (mounted) setState(() => _hidden.remove(key));
        });
      },
      child: child,
    );

    for (final c in snap.checkins) {
      final key = 'c${dayKey(c.date)}';
      final seg = spentAt[c.date];
      final sub = c.balance == null
          ? 'Nothing spent'
          : seg == null
          ? 'Starting balance'
          : seg.spent < 0
          ? 'Up ${f.money(-seg.spent)}'
          : 'Spent ${f.money(seg.spent)}${seg.days > 1 ? ' over ${seg.days} days' : ''}';
      rows.add((
        date: c.date,
        key: key,
        tile: dismissible(
          key,
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(
              c.balance == null
                  ? 'Balance carried forward'
                  : 'Balance ${f.money(c.balance!)}',
            ),
            subtitle: Text(c.note.isEmpty ? sub : '$sub · ${c.note}'),
            onTap: () => showAddSheet(context, editCheckin: c),
          ),
          () => store.deleteCheckin(c.date),
          () => store.saveCheckin(c.date, c.balance, note: c.note),
        ),
      ));
    }
    for (final i in snap.incomes) {
      final key = 'i${i.id}';
      rows.add((
        date: i.date,
        key: key,
        tile: dismissible(
          key,
          ListTile(
            leading: Icon(Icons.south_west, color: context.palette.good),
            title: Text(
              '${f.signed(i.amount)}  ${i.source[0].toUpperCase()}${i.source.substring(1)}',
            ),
            subtitle: Text(
              i.note.isEmpty ? 'Income, not counted as spending' : i.note,
            ),
            onTap: () => showAddSheet(context, editIncome: i),
          ),
          () => store.deleteIncome(i.id),
          () => store.saveIncome(i),
        ),
      ));
    }
    for (final e in snap.expenses) {
      final key = 'e${e.id}';
      final cat =
          snap.categories
              .where((c) => c.id == e.categoryId)
              .firstOrNull
              ?.name ??
          'Uncategorised';
      rows.add((
        date: e.date,
        key: key,
        tile: dismissible(
          key,
          ListTile(
            leading: const Icon(Icons.north_east),
            title: Text('−${f.money(e.amount)}  $cat'),
            subtitle: Text(e.note.isEmpty ? 'Expense' : e.note),
            onTap: () => showAddSheet(context, editExpense: e),
          ),
          () => store.deleteExpense(e.id),
          () => store.saveExpense(e),
        ),
      ));
    }
    final shown = rows.where((r) => !_hidden.contains(r.key)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: shown.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nothing here yet. Tap Add to log your first balance.',
                  style: t.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 112),
              itemCount: shown.length,
              itemBuilder: (_, n) {
                final r = shown[n];
                final header = n == 0 || shown[n - 1].date != r.date;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Semantics(
                          header: true,
                          child: Text(
                            Fmt.dateY(r.date),
                            style: t.titleSmall?.copyWith(
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      ),
                    r.tile,
                  ],
                );
              },
            ),
    );
  }
}
