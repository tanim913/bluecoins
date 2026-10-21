import 'dart:math';

import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/domain/ledger/ledger.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:bluecoins/domain/ledger/what_if.dart';
import 'package:flutter_test/flutter_test.dart';

Day d(int m, int dd) => day(2026, m, dd);
const rule = CycleRule.monthly(25);

void main() {
  group('spec sample (adjacent pairs)', () {
    // Start 25 Apr; onboarding stores the balance at the start of 25 Apr as a check-in on 24 Apr.
    final l = Ledger(
      [
        Checkin(d(4, 24), 12500000),
        Checkin(d(4, 26), 12033000),
        Checkin(d(4, 27), 11700000),
      ],
      [],
      [],
    );
    test('total 8000, 3 days, average 2667, cycle is 30 days', () {
      final c = l
          .cycles(
            resolveStarts([d(4, 25)], rule, d(4, 27)),
            tracking: Tracking.balance,
            today: d(4, 27),
          )
          .single;
      expect(l.segments.map((s) => s.spent), [467000, 333000]); // 4670 and 3330
      expect(
        (c.spent, c.daysTracked, c.avgPerDay, c.length, c.daysLeft),
        (800000, 3, 266667, 30, 27),
      );
      expect(c.opening + c.income - c.spent, c.closing);
      expect(l.balanceNow(d(4, 27)), 11700000);
    });

    test('bonus: 100300 -> 147300 with a 51000 bonus spent 4000', () {
      final b = Ledger(
        [Checkin(d(5, 5), 10030000), Checkin(d(5, 6), 14730000)],
        [Income(d(5, 6), 5100000)],
        [],
      );
      expect(b.segments.single.spent, 400000);
    });

    test('bulk entry: 19300 over 6 days', () {
      final b = Ledger(
        [Checkin(d(5, 6), 14730000), Checkin(d(5, 12), 12800000)],
        [],
        [],
      );
      expect(
        (
          b.segments.single.spent,
          b.segments.single.days,
          b.segments.single.perDay,
        ),
        (1930000, 6, 321667),
      );
      expect(
        b.dailySpend().values.fold(0, (a, x) => a + x),
        1930000,
      ); // charts add up exactly
    });
  });

  group('income and corrections', () {
    test('typed balance after or before the salary agree', () {
      final after = Ledger(
        [Checkin(d(8, 24), 14952032), Checkin(d(8, 25), 23452032)],
        [Income(d(8, 25), 8500000)],
        [],
      );
      final before = Ledger(
        [Checkin(d(8, 24), 14952032), Checkin(d(8, 25), 14952032)],
        [Income(d(8, 25), 8500000, afterCheckin: true)],
        [],
      );
      expect(after.segments.single.spent, 0);
      expect(before.segments.single.spent, 0);
      expect(before.eod.last, 23452032);
    });

    test('"nothing spent" carries forward; correcting the day before creates no fake spend', () {
      final l = Ledger(
        [
          Checkin(d(5, 1), 100000),
          Checkin(d(5, 2), 90000),
          Checkin(d(5, 3), null),
        ],
        [],
        [],
      );
      expect(l.segments.map((s) => s.spent), [10000, 0]);
      final fixed = Ledger(
        [
          Checkin(d(5, 1), 100000),
          Checkin(d(5, 2), 95000),
          Checkin(d(5, 3), null),
        ],
        [],
        [],
      );
      expect(fixed.segments.map((s) => s.spent), [5000, 0]);
    });

    test('balance rising with no income is negative spend', () {
      final l = Ledger(
        [Checkin(d(5, 1), 100000), Checkin(d(5, 2), 120000)],
        [],
        [],
      );
      expect(l.segments.single.spent, -20000);
    });

    test(
      'expenses since the last check-in lower the balance and count as spend',
      () {
        final l = Ledger([Checkin(d(5, 1), 100000)], [Income(d(5, 2), 50000)], [
          Expense(d(5, 2), 7000),
          Expense(d(5, 3), 3000),
        ]);
        expect(l.balanceNow(d(5, 3)), 140000);
        final c = l
            .cycles(
              resolveStarts([d(5, 2)], const CycleRule.every(30), d(5, 3)),
              tracking: Tracking.expenses,
              today: d(5, 4),
            )
            .single;
        expect(
          (c.spent, c.logged, c.notItemised, c.daysTracked),
          (10000, 10000, 0, 2),
        ); // expense mode counts through yesterday
      },
    );
  });

  group('cycles', () {
    test('a gap crossing a boundary is split by days and marked estimated', () {
      final l = Ledger(
        [Checkin(d(1, 9), 1000), Checkin(d(1, 24), 400)],
        [],
        [],
      );
      final cs = l.cycles(
        resolveStarts([d(1, 10)], const CycleRule.every(10), d(1, 24)),
        tracking: Tracking.balance,
        today: d(1, 24),
      );
      expect(cs.map((c) => c.spent), [
        400,
        200,
      ]); // 10 days then 5 days of a 600 spend over 15 days
      expect(cs.first.estimated, isTrue);
      expect(cs.first.closing, 600);
    });

    test(
      'payday on day 31 clamps in short months and starts are monotonic',
      () {
        final s = resolveStarts(
          [d(1, 31)],
          const CycleRule.monthly(31),
          d(4, 1),
        );
        expect(s.map((x) => x.day), [31, 28, 31, 30]);
        expect(
          resolveStarts([d(12, 25)], rule, d(12, 26)).last,
          day(2027, 1, 25),
        );
      },
    );

    test('boundary salary counts in the previous cycle ratio only', () {
      final l = Ledger(
        [
          Checkin(d(1, 9), 1000),
          Checkin(d(1, 19), 900),
          Checkin(d(1, 20), 1900),
        ],
        [Income(d(1, 20), 1000, countsInPrevious: true)],
        [],
      );
      final cs = l.cycles(
        resolveStarts([d(1, 10)], const CycleRule.every(10), d(1, 20)),
        tracking: Tracking.balance,
        today: d(1, 20),
      );
      expect((cs[0].income, cs[0].incomeForRatio), (0, 1000));
      expect((cs[1].income, cs[1].incomeForRatio), (1000, 0));
      expect(cs[0].spent + cs[1].spent, 100);
    });

    test('invariants hold on random data under any time zone', () {
      final r = Random(7);
      for (var run = 0; run < 200; run++) {
        var bal = 100000;
        final cks = <Checkin>[Checkin(d(3, 1), bal)];
        final inc = <Income>[];
        var cur = d(3, 1);
        for (var i = 0; i < 25; i++) {
          cur = addDays(cur, 1 + r.nextInt(5));
          if (r.nextInt(6) == 0) inc.add(Income(cur, r.nextInt(50000)));
          bal += r.nextInt(30000) - 25000;
          cks.add(Checkin(cur, r.nextInt(8) == 0 ? null : bal));
        }
        final l = Ledger(cks, inc, []);
        final cs = l.cycles(
          resolveStarts([d(3, 1)], CycleRule.every(1 + r.nextInt(20)), cur),
          tracking: Tracking.balance,
          today: cur,
        );
        for (var i = 0; i < cs.length; i++) {
          expect(cs[i].opening + cs[i].income - cs[i].spent, cs[i].closing);
          if (i > 0) expect(cs[i].opening, cs[i - 1].closing);
        }
        expect(
          cs.fold(0, (s, c) => s + c.spent),
          l.segments.fold(0, (s, x) => s + x.spent),
        );
      }
    });

    test('day maths is exact across the 8 Mar DST change', () {
      expect(daysBetween(day(2026, 3, 7), day(2026, 3, 9)), 2);
      final l = Ledger(
        [Checkin(day(2026, 3, 7), 1000), Checkin(day(2026, 3, 9), 800)],
        [],
        [],
      );
      expect(l.segments.single.days, 2);
    });
  });

  group('queries', () {
    final l = Ledger(
      [
        Checkin(d(5, 1), 10000),
        Checkin(d(5, 11), 8000),
        Checkin(d(5, 21), 7000),
      ],
      [],
      [],
    );
    test('range query exact and estimated', () {
      expect(l.rangeSpent(d(5, 1), d(5, 21)), (spent: 3000, exact: true));
      expect(l.rangeSpent(d(5, 1), d(5, 6)), (spent: 1000, exact: false));
    });
    test('biggest period and its share', () {
      final b = l.biggest()!;
      expect(b.segment.spent, 2000);
      expect(b.share, closeTo(66.67, 0.01));
    });
  });

  group('what if (never saved)', () {
    final l = Ledger(
      [Checkin(d(4, 24), 12500000), Checkin(d(4, 27), 11700000)],
      [],
      [],
    );
    final c = l
        .cycles(
          resolveStarts([d(4, 25)], rule, d(4, 27)),
          tracking: Tracking.balance,
          today: d(4, 27),
        )
        .single;
    final w = WhatIf(c, 11700000);
    test('spend less / spend tomorrow / projections', () {
      expect(w.spentLess(100000).balance, 11800000);
      expect(w.spentLess(100000).spent, 700000);
      expect(w.spendTomorrow(300000).avg, 275000); // (8000+3000) / 4 days
      expect(w.projectedBalance(), 11700000 - 266667 * 27);
      expect(w.dailyForTotal(6000000), 192593); // (60000-8000)/27 days
      expect(w.averageForTotal(6000000), 200000);
    });
    test('nudges', () {
      expect(nudge(500, 100), Nudge.heavy);
      expect(nudge(20, 100), Nudge.light);
      expect(nudge(100, 100), Nudge.normal);
    });
  });
}
