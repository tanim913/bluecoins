import '../../core/money.dart';
import 'ledger.dart';

/// Pure "what if" maths on a cycle. Nothing here is ever saved.
class WhatIf {
  const WhatIf(this.cycle, this.balance);
  final CycleStats cycle;
  final int balance;

  int _avg(int spent, int days) => days > 0 ? roundDiv(spent, days) : 0;

  /// Spend [x] less so far: balance up, total down, same days.
  ({int spent, int balance, int avg}) spentLess(int x) => (
    spent: cycle.spent - x,
    balance: balance + x,
    avg: _avg(cycle.spent - x, cycle.daysTracked),
  );

  /// Spend [x] tomorrow: one more day, total up.
  ({int spent, int balance, int avg}) spendTomorrow(int x) => (
    spent: cycle.spent + x,
    balance: balance - x,
    avg: _avg(cycle.spent + x, cycle.daysTracked + 1),
  );

  /// Keep spending at today's average: balance at the end of the cycle.
  int projectedBalance() => balance - cycle.avgPerDay * cycle.daysLeft;

  /// Spend [perDay] every remaining day: balance at the end of the cycle.
  int flatPerDay(int perDay) => balance - perDay * cycle.daysLeft;

  /// To end the cycle at [total] spent, what must the daily average be from now on.
  int dailyForTotal(int total) => cycle.daysLeft > 0
      ? roundDiv(total - cycle.spent, cycle.daysLeft)
      : total - cycle.spent;

  /// If the total ends at [total], the average over the whole cycle.
  int averageForTotal(int total) => roundDiv(total, cycle.length);
}

enum Nudge { heavy, light, normal }

/// A day far above the target gets a gentle warning; a low one gets praise.
Nudge nudge(int spentPerDay, int targetPerDay) {
  if (targetPerDay <= 0) return Nudge.normal;
  if (spentPerDay > targetPerDay * 3 ~/ 2) return Nudge.heavy;
  if (spentPerDay < targetPerDay ~/ 2) return Nudge.light;
  return Nudge.normal;
}
