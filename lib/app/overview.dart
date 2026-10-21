import '../core/day.dart';
import '../data/database.dart';
import '../data/store.dart';
import '../domain/ledger/ledger.dart';
import '../domain/ledger/models.dart';

/// What the screens show, derived from one snapshot. Pure: all rules live in the ledger.
class Overview {
  Overview(this.s, this.today) {
    ledger = s.ledger;
    starts = resolveStarts(
      s.cycleStarts,
      s.rule,
      today.isAfter(ledger.isEmpty ? today : ledger.last) ? today : ledger.last,
    );
    cycles = ledger.cycles(starts, tracking: s.tracking, today: today);
    cycle = cycles.lastWhere(
      (c) => !c.start.isAfter(today),
      orElse: () => cycles.first,
    );
    index = cycles.indexOf(cycle);
  }

  final Snapshot s;
  final Day today;
  late final Ledger ledger;
  late final List<Day> starts;
  late final List<CycleStats> cycles;
  late final CycleStats cycle;
  late final int index;

  Setting get settings => s.settings!;

  /// Budget for this cycle; a short first cycle is prorated.
  int get budget => index == 0
      ? cycle.prorated(settings.budget, s.rule.nominalDays)
      : settings.budget;
  bool get hasBudget => settings.budget > 0;
  bool get prorated => index == 0 && budget != settings.budget;

  int get balance => ledger.balanceNow(today);
  int get remaining => cycle.remaining(budget);
  int get safePerDay => cycle.safePerDay(budget);

  /// Days spent so far in this cycle, for the pace marker (0..1).
  double get timeFraction =>
      ((daysBetween(cycle.start, today) + 1) / cycle.length).clamp(0.0, 1.0);
  double get moneyFraction =>
      hasBudget && budget > 0 ? (cycle.spent / budget).clamp(0.0, 1.0) : 0;

  /// Projected balance at the end of the cycle if spending continues at today's average.
  int get projectedEnd => balance - cycle.avgPerDay * cycle.daysLeft;

  List<Bill> get pendingBills => s.bills
      .where((b) => !b.archived && b.paidForCycle != dayKey(cycle.start))
      .toList();
  int get pendingTotal => pendingBills.fold(0, (t, b) => t + b.amount);

  bool get loggedToday => ledger.checkins.any((c) => c.date == today);

  /// Generated cycle starts that have begun but are not stored yet; the app persists them so
  /// past cycles never move when the rule changes.
  List<Day> get missingStarts => starts
      .where((d) => !d.isAfter(today) && !s.cycleStarts.contains(d))
      .toList();

  /// Spend per day for the last [n] days up to today, negatives shown as 0.
  List<({Day day, int spent})> lastDays(int n) {
    final daily = ledger.dailySpend();
    return [
      for (var i = n - 1; i >= 0; i--)
        (
          day: addDays(today, -i),
          spent: (daily[addDays(today, -i)] ?? 0).clamp(0, 1 << 40),
        ),
    ];
  }
}
