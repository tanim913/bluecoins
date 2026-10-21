import '../../core/day.dart';

/// End-of-day balance the user typed. Null = "nothing spent today": carry the balance forward.
class Checkin {
  const Checkin(this.date, this.balance, {this.note = ''});
  final Day date;
  final int? balance;
  final String note;
}

/// [afterCheckin]: it arrived after the balance was typed (balance excludes it).
/// [countsInPrevious]: a salary on a cycle's first day that the user wants shown in the
/// previous cycle's savings ratio. It never changes spending or balances.
class Income {
  const Income(
    this.date,
    this.amount, {
    this.afterCheckin = false,
    this.countsInPrevious = false,
    this.source = 'salary',
    this.note = '',
    this.id = '',
  });
  final Day date;
  final int amount;
  final bool afterCheckin;
  final bool countsInPrevious;
  final String source, note, id;
}

class Expense {
  const Expense(
    this.date,
    this.amount, {
    this.categoryId,
    this.note = '',
    this.id = '',
  });
  final Day date;
  final int amount;
  final String? categoryId;
  final String note, id;
}

/// Where cycles start: a payday of the month, or every N days. Exactly one is set.
class CycleRule {
  const CycleRule.monthly(int this.payday) : everyDays = null;
  const CycleRule.every(int this.everyDays) : payday = null;
  final int? payday;
  final int? everyDays;

  /// Nominal length, used to prorate a short first cycle.
  int get nominalDays => everyDays ?? 30;

  Day next(Day from) {
    if (everyDays != null) return addDays(from, everyDays!.clamp(1, 366));
    int clamp(int y, int m) =>
        payday! > daysInMonth(y, m) ? daysInMonth(y, m) : payday!;
    final same = DateTime.utc(
      from.year,
      from.month,
      clamp(from.year, from.month),
    );
    if (same.isAfter(from)) return same;
    final y = from.month == 12 ? from.year + 1 : from.year;
    final m = from.month == 12 ? 1 : from.month + 1;
    return DateTime.utc(y, m, clamp(y, m));
  }
}

enum Tracking { balance, expenses }

/// Stored starts plus rule-generated ones, ending with the first start after [ref]
/// (so the last cycle containing [ref] has an end). Past starts never move.
List<Day> resolveStarts(List<Day> stored, CycleRule rule, Day ref) {
  assert(stored.isNotEmpty);
  final s = [...stored]..sort();
  while (!s.last.isAfter(ref)) {
    s.add(rule.next(s.last));
  }
  return s;
}
