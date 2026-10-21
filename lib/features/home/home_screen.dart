import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/overview.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../add/actions.dart';
import '../shared/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(overviewProvider);
    final f = ref.watch(fmtProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bluecoins')),
      body: o == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
              children: [
                _Allowance(o, f),
                if (o.hasBudget) ...[
                  const SizedBox(height: 20),
                  _PaceBar(o, f),
                ],
                const SizedBox(height: 24),
                _TodayCard(o, f),
                const SizedBox(height: 16),
                _Rows(o, f),
                const SectionTitle('Last 14 days'),
                _Last14(o, f),
              ],
            ),
    );
  }
}

class _Allowance extends StatelessWidget {
  const _Allowance(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = o.cycle;
    final (lead, amount, tail, color) = !o.hasBudget
        ? ('You spend about', f.whole(c.avgPerDay), 'a day', null)
        : o.remaining < 0
        ? (
            'You are over budget by',
            f.whole(-o.remaining),
            'this cycle',
            Theme.of(context).colorScheme.error,
          )
        : c.daysLeft > 0
        ? (
            'You can spend',
            f.whole(o.safePerDay),
            'a day for the next ${c.daysLeft} days',
            null,
          )
        : ('You have', f.whole(o.remaining), 'left in this cycle', null);
    return Semantics(
      container: true,
      label: '$lead $amount $tail',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead,
              style: t.titleMedium?.copyWith(color: context.palette.muted),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: t.displayLarge?.copyWith(color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tail,
              style: t.titleMedium?.copyWith(color: context.palette.muted),
            ),
            const SizedBox(height: 10),
            Text(
              'Day ${(daysBetween(c.start, o.today) + 1).clamp(1, c.length)} of ${c.length}  ·  ${Fmt.range(c.start, c.end)}',
              style: t.bodySmall?.copyWith(color: context.palette.muted),
            ),
            if (!o.hasBudget)
              Text(
                'Ends with about ${f.whole(o.projectedEnd)} at this pace',
                style: t.bodySmall?.copyWith(color: context.palette.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Money spent (fill) against days passed (marker). Fill ahead of the marker means spending
/// runs ahead of the calendar.
class _PaceBar extends StatelessWidget {
  const _PaceBar(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = context.palette;
    final expected = (o.budget * o.timeFraction).round();
    final diff = o.cycle.spent - expected;
    final ahead = diff > 0;
    final status = o.cycle.daysTracked == 0
        ? 'Log a balance to see your pace'
        : ahead
        ? '${f.whole(diff)} ahead of pace'
        : '${f.whole(-diff)} under pace';
    return Semantics(
      label:
          'Spent ${(o.moneyFraction * 100).round()}% of the budget, ${(o.timeFraction * 100).round()}% of the cycle has passed. $status',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.track,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 8,
                        height: 12,
                        width: (w * o.moneyFraction).clamp(12.0, w),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ahead ? p.warn : cs.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (w * o.timeFraction - 1.5).clamp(0.0, w - 3),
                        top: 0,
                        height: 28,
                        width: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.onSurface,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  ahead ? Icons.trending_up : Icons.trending_down,
                  size: 18,
                  color: ahead ? p.warn : p.good,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${f.money(o.cycle.spent)} of ${f.money(o.budget)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: p.muted),
                ),
              ],
            ),
            if (o.prorated)
              Text(
                'Budget prorated for your first, shorter cycle',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: p.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  final _c = TextEditingController();
  String? _error;
  bool _editing = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save(int? balance) async {
    final o = widget.o;
    final msg = await saveBalance(
      ref.read(storeProvider),
      o.s,
      widget.f,
      o.today,
      balance,
      budgetPerDay: o.hasBudget ? o.budget ~/ o.cycle.length : 0,
    );
    if (!mounted) return;
    _c.clear();
    setState(() {
      _editing = false;
      _error = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final t = Theme.of(context).textTheme;
    if (o.loggedToday && !_editing) {
      return Panel(
        child: Row(
          children: [
            Icon(Icons.check_circle, color: context.palette.good),
            const SizedBox(width: 12),
            Expanded(
              child: Text("Today's balance is logged", style: t.titleSmall),
            ),
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Change'),
            ),
          ],
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.loggedToday
                ? "Change today's balance"
                : 'What is your balance today?',
            style: t.titleMedium,
          ),
          const SizedBox(height: 12),
          AmountField(controller: _c, label: 'Balance', errorText: _error),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final v = parseMoney(_c.text);
                if (v == null) {
                  return setState(() => _error = 'Enter a number, e.g. 123000');
                }
                _save(v);
              },
              child: const Text('Save balance'),
            ),
          ),
          if (!o.loggedToday)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _save(null),
                child: const Text('Nothing spent today'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final c = o.cycle;
    return Column(
      children: [
        StatRow('Balance now', f.money(o.balance)),
        const Divider(),
        StatRow(
          'Spent this cycle',
          f.money(c.spent),
          note: 'Net of income${c.estimated ? ', partly estimated' : ''}',
        ),
        const Divider(),
        StatRow(
          'Average per day',
          f.money(c.avgPerDay),
          note: c.daysTracked > 0 ? 'over ${c.daysTracked} days' : null,
        ),
        if (o.pendingBills.isNotEmpty) ...[
          const Divider(),
          StatRow(
            'Bills still to pay',
            f.money(o.pendingTotal),
            note: '${o.pendingBills.length} pending',
            color: context.palette.warn,
          ),
        ],
      ],
    );
  }
}

class _Last14 extends StatelessWidget {
  const _Last14(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final days = o.lastDays(14);
    final max = days.fold(0, (m, d) => d.spent > m ? d.spent : m);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Spending in the last 14 days, highest ${f.money(max)} in a day',
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        child: SizedBox(
          height: 160,
          child: ExcludeSemantics(
            child: BarChart(
              BarChartData(
                maxY: max == 0 ? 1 : max * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) =>
                          v.toInt() % 3 == 0 || v.toInt() == 13
                          ? Text(
                              '${days[v.toInt()].day.day}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: context.palette.muted),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (g, _, r, _) => BarTooltipItem(
                      '${Fmt.date(days[g.x].day)}\n${f.money(r.toY.round())}',
                      Theme.of(context).textTheme.labelMedium!
                          .copyWith(color: cs.onSurface),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].spent.toDouble(),
                          width: 12,
                          color: i == days.length - 1
                              ? cs.primary
                              : cs.primary.withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
