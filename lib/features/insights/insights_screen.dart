import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/overview.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../../domain/ledger/ledger.dart';
import '../shared/widgets.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int? _picked;
  Day? _from, _to;

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(overviewProvider);
    final f = ref.watch(fmtProvider);
    if (o == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final i = (_picked ?? o.index).clamp(0, o.cycles.length - 1);
    final c = o.cycles[i];
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous cycle',
                onPressed: i > 0 ? () => setState(() => _picked = i - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(Fmt.range(c.start, c.end), style: t.titleMedium),
                    Text(
                      'Cycle ${i + 1} of ${o.cycles.length}${c.estimated ? ' · partly estimated' : ''}',
                      style: t.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next cycle',
                onPressed: i < o.cycles.length - 1
                    ? () => setState(() => _picked = i + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          _Summary(c, f),
          const SectionTitle('Spend per day'),
          _DayBars(o, c, f),
          const SectionTitle('Cumulative spend'),
          _Cumulative(o, c, f, i == 0 ? o.budget : o.settings.budget),
          const SectionTitle('Balance over time'),
          _BalanceLine(o, f),
          const SectionTitle('Where it went'),
          _Categories(o, c, f),
          const SectionTitle('Every cycle'),
          _CycleTable(o, f),
          if (o.cycles.length > 1) ...[
            const SectionTitle('Savings and average by cycle'),
            _CycleBars(o, f),
          ],
          const SectionTitle('Between two dates'),
          _Range(
            o,
            f,
            _from ?? c.start,
            _to ?? o.today,
            (a, b) => setState(() {
              _from = a;
              _to = b;
            }),
          ),
          _Biggest(o, f),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.c, this.f);
  final CycleStats c;
  final Fmt f;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      StatRow('Spent', f.money(c.spent), note: 'Net of income'),
      const Divider(),
      StatRow('Income', f.money(c.income)),
      const Divider(),
      StatRow(
        'Average per day',
        f.money(c.avgPerDay),
        note: c.daysTracked > 0 ? 'over ${c.daysTracked} days' : null,
      ),
      const Divider(),
      StatRow(
        'Saved',
        f.signed(c.saved),
        note: c.savedPercent == null
            ? null
            : '${c.savedPercent!.toStringAsFixed(0)}% of income',
      ),
    ],
  );
}

Widget _chart(
  BuildContext context,
  String label,
  Widget chart, {
  double height = 190,
}) => Semantics(
  label: label,
  child: Panel(
    padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
    child: SizedBox(
      height: height,
      child: ExcludeSemantics(child: chart),
    ),
  ),
);

FlTitlesData _titles(
  BuildContext context,
  Fmt f,
  Day start,
  int n, {
  bool left = true,
}) {
  final style = Theme.of(context).textTheme.labelSmall
      ?.copyWith(color: context.palette.muted);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: left,
        reservedSize: 44,
        getTitlesWidget: (v, m) => v == m.max || v == m.min
            ? const SizedBox.shrink()
            : Text(Fmt.compact((v * 100).round()), style: style),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: (n / 4).ceilToDouble().clamp(1, 1000),
        getTitlesWidget: (v, m) => v == m.max && n > 4
            ? const SizedBox.shrink()
            : Text(Fmt.date(addDays(start, v.toInt())), style: style),
      ),
    ),
  );
}

class _DayBars extends StatelessWidget {
  const _DayBars(this.o, this.c, this.f);
  final Overview o;
  final CycleStats c;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final daily = o.ledger.dailySpend();
    final end = c.end.isBefore(o.today) ? c.end : o.today;
    final n = (daysBetween(c.start, end) + 1).clamp(1, 400);
    final vals = [
      for (var i = 0; i < n; i++)
        (daily[addDays(c.start, i)] ?? 0).clamp(0, 1 << 40),
    ];
    final max = vals.fold(0, (m, v) => v > m ? v : m);
    final cs = Theme.of(context).colorScheme;
    return _chart(
      context,
      'Spending for each day of the cycle. Highest day ${f.money(max)}. Days with a gap between balances show the average of that gap.',
      BarChart(
        BarChartData(
          maxY: max == 0 ? 1 : max / 100 * 1.15,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, f, c.start, n),
          barGroups: [
            for (var i = 0; i < n; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: vals[i] / 100,
                    width: n > 31 ? 3 : 7,
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Cumulative extends StatelessWidget {
  const _Cumulative(this.o, this.c, this.f, this.budget);
  final Overview o;
  final CycleStats c;
  final Fmt f;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final daily = o.ledger.dailySpend();
    final end = c.end.isBefore(o.today) ? c.end : o.today;
    final n = (daysBetween(c.start, end) + 1).clamp(1, 400);
    var run = 0;
    final spots = [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), (run += daily[addDays(c.start, i)] ?? 0) / 100),
    ];
    final cs = Theme.of(context).colorScheme;
    final p = context.palette;
    final top = [
      if (spots.isNotEmpty) spots.last.y,
      if (budget > 0) budget / 100,
    ].fold(1.0, (m, v) => v > m ? v : m);
    return _chart(
      context,
      'Total spent so far ${f.money(run)}${budget > 0 ? ' against a budget of ${f.money(budget)}' : ''}',
      LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble().clamp(1, 1000),
          minY: 0,
          maxY: top * 1.1,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, f, c.start, n),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: cs.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.15),
              ),
            ),
            if (budget > 0)
              LineChartBarData(
                spots: [
                  FlSpot(0, budget / 100),
                  FlSpot((n - 1).toDouble().clamp(1, 1000), budget / 100),
                ],
                color: p.warn,
                barWidth: 2,
                dashArray: [6, 5],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final l = o.ledger;
    final first = l.first;
    final n = (daysBetween(first, l.last) + 1).clamp(2, 4000);
    final spots = [
      for (var i = 0; i < l.checkins.length; i++)
        FlSpot(
          daysBetween(first, l.checkins[i].date).toDouble(),
          l.eod[i] / 100,
        ),
    ];
    final cs = Theme.of(context).colorScheme;
    final ys = spots.map((s) => s.y);
    final lo = ys.reduce((a, b) => a < b ? a : b),
        hi = ys.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo).abs() * 0.1 + 1;
    return _chart(
      context,
      'Balance over time, from ${f.money(l.eod.first)} to ${f.money(l.eod.last)}',
      LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          minY: lo - pad,
          maxY: hi + pad,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, f, first, n),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: cs.primary,
              barWidth: 3,
              isCurved: false,
              dotData: FlDotData(show: spots.length < 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories(this.o, this.c, this.f);
  final Overview o;
  final CycleStats c;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final by = <String, int>{};
    for (final e in o.s.expenses.where(
      (e) => !e.date.isBefore(c.start) && !e.date.isAfter(c.end),
    )) {
      by[e.categoryId ?? 'none'] = (by[e.categoryId ?? 'none'] ?? 0) + e.amount;
    }
    final rows = [
      for (final e in by.entries)
        (
          name:
              o.s.categories.where((x) => x.id == e.key).firstOrNull?.name ??
              'Uncategorised',
          value: e.value,
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final rest = c.notItemised;
    if (rows.isEmpty) {
      return Panel(
        child: Text(
          'Log expenses with a category to see where your money goes. Everything else stays in your balance numbers.',
          style: t.bodyMedium?.copyWith(color: context.palette.muted),
        ),
      );
    }
    final total = (c.spent > 0 ? c.spent : 1);
    return Panel(
      child: Column(
        children: [
          for (final r in rows) _CatRow(r.name, r.value, r.value / total, f),
          if (rest > 0) _CatRow('Not itemised', rest, rest / total, f),
          if (rest < 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You logged ${f.money(-rest)} more than your balance shows. Check your expenses and balances.',
                style: t.bodySmall?.copyWith(color: context.palette.warn),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  const _CatRow(this.name, this.value, this.share, this.f);
  final String name;
  final int value;
  final double share;
  final Fmt f;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(f.money(value), style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 8,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: context.palette.track,
          ),
        ),
      ],
    ),
  );
}

class _CycleTable extends StatelessWidget {
  const _CycleTable(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final salary = o.settings.baseSalary;
    return Semantics(
      label: 'Table of every cycle with income, spent, saved, savings rate and daily average',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingTextStyle: Theme.of(context).textTheme.labelMedium,
          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
          columns: [
            const DataColumn(label: Text('Cycle')),
            const DataColumn(label: Text('Income'), numeric: true),
            const DataColumn(label: Text('Spent'), numeric: true),
            const DataColumn(label: Text('Saved'), numeric: true),
            const DataColumn(label: Text('Saved %'), numeric: true),
            if (salary > 0)
              const DataColumn(label: Text('vs salary'), numeric: true),
            const DataColumn(label: Text('Per day'), numeric: true),
          ],
          rows: [
            for (final c in o.cycles)
              DataRow(
                cells: [
                  DataCell(Text(Fmt.range(c.start, c.end))),
                  DataCell(Text(f.plain(c.incomeForRatio))),
                  DataCell(Text(f.plain(c.spent))),
                  DataCell(Text(f.plain(c.saved))),
                  DataCell(
                    Text(
                      c.savedPercent == null
                          ? '–'
                          : '${c.savedPercent!.toStringAsFixed(0)}%',
                    ),
                  ),
                  if (salary > 0)
                    DataCell(
                      Text(
                        '${((salary - c.spent) * 100 / salary).toStringAsFixed(0)}%',
                      ),
                    ),
                  DataCell(Text(f.plain(c.avgPerDay))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CycleBars extends StatelessWidget {
  const _CycleBars(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: context.palette.muted);
    Widget bars(String label, List<double> v, Color color) => _chart(
      context,
      label,
      BarChart(
        BarChartData(
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (x, m) => Text(
                  x == m.max || x == m.min ? '' : x.toStringAsFixed(0),
                  style: style,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (x, _) =>
                    Text(Fmt.date(o.cycles[x.toInt()].start), style: style),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < v.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: v[i],
                    width: 14,
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
      height: 150,
    );
    return Column(
      children: [
        bars('Savings percent for each cycle', [
          for (final c in o.cycles) c.savedPercent ?? 0,
        ], cs.primary),
        const SizedBox(height: 12),
        bars('Average spend per day for each cycle', [
          for (final c in o.cycles) c.avgPerDay / 100,
        ], cs.secondary),
      ],
    );
  }
}

class _Range extends StatelessWidget {
  const _Range(this.o, this.f, this.from, this.to, this.onChange);
  final Overview o;
  final Fmt f;
  final Day from, to;
  final void Function(Day, Day) onChange;

  @override
  Widget build(BuildContext context) {
    final ok = to.isAfter(from);
    final r = ok ? o.ledger.rangeSpent(from, to) : null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async =>
                      onChange(await pickDay(context, from) ?? from, to),
                  child: Text(Fmt.dateY(from)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('to'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async =>
                      onChange(from, await pickDay(context, to) ?? to),
                  child: Text(Fmt.dateY(to)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (r == null)
            Text(
              'Pick an end date after the start date.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            Text(
              'You spent ${f.money(r.spent)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              r.exact
                  ? 'From your balances on those two days, with income in between left out.'
                  : 'Estimated: one of those days has no balance, so it is worked out from the nearest entries.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Biggest extends StatelessWidget {
  const _Biggest(this.o, this.f);
  final Overview o;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final b = o.ledger.biggest();
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        child: Text(
          'Your biggest spend was ${f.money(b.segment.spent)} between ${Fmt.date(addDays(b.segment.from, 1))} and ${Fmt.date(b.segment.to)}, ${b.share.toStringAsFixed(0)}% of everything you have spent.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
