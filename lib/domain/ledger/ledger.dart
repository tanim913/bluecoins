import 'dart:math' as math;

import '../../core/day.dart';
import '../../core/money.dart';
import 'models.dart';

class Segment {
  const Segment(this.from, this.to, this.spent);

  /// Covers the days from+1 .. to.
  final Day from, to;
  final int spent;
  int get days => daysBetween(from, to);
  int get perDay => roundDiv(spent, days);
}

class Point {
  const Point(this.value, this.exact);
  final int value;

  /// False when interpolated between two check-ins or projected past the last one.
  final bool exact;
}

class CycleStats {
  const CycleStats({
    required this.start,
    required this.end,
    required this.opening,
    required this.income,
    required this.incomeForRatio,
    required this.spent,
    required this.closing,
    required this.daysTracked,
    required this.daysLeft,
    required this.logged,
    required this.estimated,
  });

  final Day start, end;
  final int opening, income, spent, closing, logged;
  final int incomeForRatio;
  final int daysTracked, daysLeft;
  final bool estimated;

  int get length => daysBetween(start, end) + 1;
  int get avgPerDay => daysTracked > 0 ? roundDiv(spent, daysTracked) : 0;

  /// Spend the user did not itemise. Negative means they logged more than the balance shows.
  int get notItemised => spent - logged;
  int get saved => incomeForRatio - spent;
  double? get savedPercent =>
      incomeForRatio > 0 ? saved * 100 / incomeForRatio : null;
  int remaining(int budget) => budget - spent;
  int safePerDay(int budget) =>
      daysLeft > 0 ? roundDiv(remaining(budget), daysLeft) : remaining(budget);
  int prorated(int budget, int nominal) =>
      length >= nominal ? budget : roundDiv(budget * length, nominal);
}

class Ledger {
  Ledger(
    Iterable<Checkin> checkins,
    Iterable<Income> incomes,
    Iterable<Expense> expenses,
  ) : checkins = (<Day, Checkin>{
        for (final c in checkins) c.date: c,
      }.values.toList()..sort((a, b) => a.date.compareTo(b.date))),
      incomes = incomes.toList(),
      expenses = expenses.toList() {
    if (this.checkins.isEmpty) return;
    for (var i = 0; i < this.checkins.length; i++) {
      final c = this.checkins[i];
      if (i == 0) {
        eod.add((c.balance ?? 0) + _incomeOn(c.date, afterOnly: true));
        continue;
      }
      final prev = this.checkins[i - 1].date;
      final inc = incomeIn(prev, c.date);
      final b = c.balance;
      eod.add(
        b == null ? eod[i - 1] + inc : b + _incomeOn(c.date, afterOnly: true),
      );
      segments.add(Segment(prev, c.date, eod[i - 1] - eod[i] + inc));
    }
  }

  final List<Checkin> checkins;
  final List<Income> incomes;
  final List<Expense> expenses;
  final List<int> eod = [];
  final List<Segment> segments = [];

  bool get isEmpty => checkins.isEmpty;
  Day get first => checkins.first.date;
  Day get last => checkins.last.date;

  int _incomeOn(Day d, {required bool afterOnly}) => incomes
      .where((i) => i.date == d && (!afterOnly || i.afterCheckin))
      .fold(0, (s, i) => s + i.amount);

  /// Income dated in (a, b].
  int incomeIn(Day a, Day b) => incomes
      .where((i) => i.date.isAfter(a) && !i.date.isAfter(b))
      .fold(0, (s, i) => s + i.amount);

  int expensesIn(Day a, Day b) => expenses
      .where((e) => e.date.isAfter(a) && !e.date.isAfter(b))
      .fold(0, (s, e) => s + e.amount);

  /// Balance at the end of [d]: exact on a check-in, interpolated inside a gap,
  /// projected (income in, expenses out) after the last check-in.
  Point eodAt(Day d) {
    if (!d.isAfter(first)) return Point(eod.first, d == first);
    if (d.isAfter(last)) {
      return Point(
        eod.last + incomeIn(last, d) - expensesIn(last, d),
        d == last,
      );
    }
    for (var i = 1; i < checkins.length; i++) {
      if (d.isAfter(checkins[i].date)) continue;
      if (d == checkins[i].date) return Point(eod[i], true);
      final s = segments[i - 1];
      final share = roundDiv(s.spent * daysBetween(s.from, d), s.days);
      return Point(eod[i - 1] + incomeIn(s.from, d) - share, false);
    }
    return Point(eod.last, true);
  }

  /// Balance right now: last check-in plus income since, minus expenses logged since.
  int balanceNow(Day today) => eodAt(today.isAfter(last) ? today : last).value;

  /// Net spend over (from, to]. [exact] is false when an end was estimated.
  ({int spent, bool exact}) rangeSpent(Day from, Day to) {
    final a = eodAt(from), b = eodAt(to);
    return (
      spent: a.value - b.value + incomeIn(from, to),
      exact: a.exact && b.exact,
    );
  }

  /// [starts] comes from [resolveStarts]; the last entry only closes the final cycle.
  List<CycleStats> cycles(
    List<Day> starts, {
    required Tracking tracking,
    required Day today,
  }) {
    if (isEmpty) return const [];
    final covered =
        tracking == Tracking.expenses && addDays(today, -1).isAfter(last)
        ? addDays(today, -1)
        : last;
    final out = <CycleStats>[];
    for (var i = 0; i < starts.length - 1; i++) {
      final s = starts[i], e = addDays(starts[i + 1], -1);
      final base = addDays(s, -1).isAfter(first) ? addDays(s, -1) : first;
      final open = eodAt(base);
      final close = eodAt(e.isAfter(base) ? e : base);
      final inc = e.isAfter(base) ? incomeIn(base, e) : 0;
      var ratio = inc;
      for (final x in incomes.where((x) => x.countsInPrevious)) {
        if (i > 0 && x.date == s) ratio -= x.amount;
        if (x.date == starts[i + 1]) ratio += x.amount;
      }
      out.add(
        CycleStats(
          start: s,
          end: e,
          opening: open.value,
          income: inc,
          incomeForRatio: ratio,
          spent: open.value + inc - close.value,
          closing: close.value,
          daysTracked: math.max(
            0,
            daysBetween(base, covered.isBefore(e) ? covered : e),
          ),
          daysLeft: math.max(
            0,
            daysBetween(covered.isAfter(base) ? covered : base, e),
          ),
          logged: expenses
              .where((x) => !x.date.isBefore(s) && !x.date.isAfter(e))
              .fold(0, (t, x) => t + x.amount),
          estimated: !(open.exact && close.exact) && !(e.isAfter(last)),
        ),
      );
    }
    return out;
  }

  /// Net spend per day for charts. Each gap is spread evenly (or draw it as one wide bar).
  Map<Day, int> dailySpend() {
    final m = <Day, int>{};
    for (final s in segments) {
      for (var i = 0; i < s.days; i++) {
        m[addDays(s.from, i + 1)] =
            roundDiv(s.spent * (i + 1), s.days) - roundDiv(s.spent * i, s.days);
      }
    }
    for (final e in expenses.where((e) => e.date.isAfter(last))) {
      m[e.date] = (m[e.date] ?? 0) + e.amount;
    }
    return m;
  }

  /// The biggest spend period and its share of everything spent (percent).
  ({Segment segment, double share})? biggest() {
    if (segments.isEmpty) return null;
    final top = segments.reduce((a, b) => a.spent >= b.spent ? a : b);
    final total = segments.fold(0, (s, x) => s + x.spent);
    return total > 0 ? (segment: top, share: top.spent * 100 / total) : null;
  }
}
