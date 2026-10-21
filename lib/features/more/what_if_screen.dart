import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/ledger/what_if.dart';
import '../shared/widgets.dart';

class WhatIfScreen extends ConsumerStatefulWidget {
  const WhatIfScreen({super.key});

  @override
  ConsumerState<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends ConsumerState<WhatIfScreen> {
  final _less = TextEditingController();
  final _tomorrow = TextEditingController();
  final _flat = TextEditingController();
  final _total = TextEditingController();

  @override
  void dispose() {
    for (final c in [_less, _tomorrow, _flat, _total]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(overviewProvider);
    final f = ref.watch(fmtProvider);
    final t = Theme.of(context).textTheme;
    if (o == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final w = WhatIf(o.cycle, o.balance);
    Widget out(String label, String value) => StatRow(label, value);
    Widget block(
      String title,
      TextEditingController c,
      String field,
      List<Widget> Function(int v) results,
    ) {
      final v = positiveMoney(c.text);
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 12),
            AmountField(
              controller: c,
              label: field,
              onChanged: (_) => setState(() {}),
            ),
            if (v != null) ...[const SizedBox(height: 8), ...results(v)],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('What if')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(
            'Try a scenario for this cycle. Nothing here is saved.',
            style: t.bodyMedium?.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('At your current pace', style: t.titleMedium),
                out('Average per day', f.money(o.cycle.avgPerDay)),
                out(
                  'Balance on ${o.cycle.end.day}/${o.cycle.end.month}',
                  f.money(w.projectedBalance()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          block('If I had spent less so far', _less, 'How much less', (v) {
            final r = w.spentLess(v * 1);
            return [
              out('Total spent', f.money(r.spent)),
              out('Balance', f.money(r.balance)),
              out('Average per day', f.money(r.avg)),
            ];
          }),
          const SizedBox(height: 16),
          block('If I spend tomorrow', _tomorrow, 'Amount', (v) {
            final r = w.spendTomorrow(v);
            return [
              out('Total spent', f.money(r.spent)),
              out('Balance', f.money(r.balance)),
              out('Average per day', f.money(r.avg)),
            ];
          }),
          const SizedBox(height: 16),
          block(
            'If I spend a flat amount a day',
            _flat,
            'Per day',
            (v) => [
              out('Balance at the end of the cycle', f.money(w.flatPerDay(v))),
            ],
          ),
          const SizedBox(height: 16),
          block(
            'If I want to spend only',
            _total,
            'Total for this cycle',
            (v) => [
              out('Daily average from now', f.money(w.dailyForTotal(v))),
              out(
                'Average over the whole cycle',
                f.money(w.averageForTotal(v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
