import 'package:bluecoins/app/overview.dart';
import 'package:bluecoins/app/xlsx_export.dart';
import 'package:bluecoins/core/day.dart';
import 'package:bluecoins/data/database.dart';
import 'package:bluecoins/data/store.dart';
import 'package:bluecoins/domain/ledger/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'workbook has the three sheets, the full history and native charts',
    () async {
      final s = Store(AppDatabase.forTesting(NativeDatabase.memory()));
      addTearDown(s.db.close);
      await s.saveSettings(
        const SettingsCompanion(payday: Value(25), budget: Value(6000000)),
      );
      await s.addCycleStart(day(2026, 4, 25));
      await s.saveCheckin(day(2026, 4, 24), 12500000);
      await s.saveCheckin(day(2026, 5, 6), 14730000);
      await s.saveIncome(Income(day(2026, 5, 6), 5100000, source: 'bonus'));
      await s.saveExpense(Expense(day(2026, 5, 7), 45000, categoryId: 'food'));
      final o = Overview(await s.load(), day(2026, 5, 10));
      final bytes = buildWorkbook(o);
      final book = Excel.decodeBytes(bytes);
      expect(book.tables.keys, containsAll(['History', 'Cycles', 'Charts']));
      expect(book.tables.keys, isNot(contains('Sheet1')));
      final history = book['History'].rows;
      expect(history.first.map((c) => c?.value.toString()).first, '#');
      expect(history.length, greaterThan(5)); // header + 4 entries + summary
      expect(String.fromCharCodes(bytes).contains('xl/charts/chart'), isTrue);
    },
  );
}
