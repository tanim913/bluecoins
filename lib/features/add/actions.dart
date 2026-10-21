import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/store.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/models.dart';
import '../../domain/ledger/what_if.dart';

/// Saves a balance check-in and returns the friendly one-line summary the user sees.
/// [includesIncome]: when the day already has income, whether the typed balance already
/// contains it (default) or was typed before it arrived.
Future<String> saveBalance(
  Store store,
  Snapshot snap,
  Fmt f,
  Day day,
  int? balance, {
  String note = '',
  bool includesIncome = true,
  int budgetPerDay = 0,
}) async {
  final incomes = [
    for (final i in snap.incomes)
      i.date == day ? i.withAfter(!includesIncome) : i,
  ];
  for (final i in incomes.where((i) => i.date == day)) {
    await store.saveIncome(i);
  }
  await store.saveCheckin(day, balance, note: note);
  final l = Ledger(
    [...snap.checkins.where((c) => c.date != day), Checkin(day, balance)],
    incomes,
    snap.expenses,
  );
  final seg = l.segments.where((s) => s.to == day).firstOrNull;
  if (seg == null) return 'Saved.';
  if (seg.spent == 0) {
    return balance == null
        ? 'Nothing spent. Saved.'
        : 'No spending since ${Fmt.date(seg.from)}.';
  }
  if (seg.spent < 0) {
    return 'Your balance went up by ${f.money(-seg.spent)}. If it was income, add it so spending stays right.';
  }
  final over = seg.days > 1
      ? ' over ${seg.days} days (${f.money(seg.perDay)} a day)'
      : '';
  final tail = switch (nudge(seg.perDay, budgetPerDay)) {
    Nudge.heavy => ' A heavy day. Easy does it.',
    Nudge.light => ' A light day, nice.',
    Nudge.normal => '',
  };
  return 'Spent ${f.money(seg.spent)}$over.$tail';
}

/// What the balance form previews before saving.
String? previewSpend(Snapshot snap, Fmt f, Day day, int? balance) {
  if (balance == null) return null;
  final l = Ledger(
    [...snap.checkins.where((c) => c.date != day), Checkin(day, balance)],
    snap.incomes,
    snap.expenses,
  );
  final seg = l.segments.where((s) => s.to == day).firstOrNull;
  if (seg == null) return null;
  final days = seg.days > 1 ? ' over ${seg.days} days' : '';
  return seg.spent < 0
      ? 'Up ${f.money(-seg.spent)} since ${Fmt.date(seg.from)}'
      : 'Spent ${f.money(seg.spent)}$days since ${Fmt.date(seg.from)}';
}

/// Validates the money field for an expense or income.
int? amountOf(String text) => parseMoney(text)?.abs();
