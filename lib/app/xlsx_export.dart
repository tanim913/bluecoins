import 'package:excel_plus/excel_plus.dart';

import '../core/day.dart';
import '../core/format.dart';
import 'overview.dart';

CellValue _t(String s) => TextCellValue(s);
CellValue _m(int minor) => DoubleCellValue(minor / 100);
CellValue _d(Day d) => DateCellValue(year: d.year, month: d.month, day: d.day);
String _month(Day d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

final _head = CellStyle(
  bold: true,
  fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
  backgroundColorHex: ExcelColor.fromHexString('#2B385A'),
);
final _incomeRow = CellStyle(
  backgroundColorHex: ExcelColor.fromHexString('#DFF5E8'),
);
final _bold = CellStyle(bold: true);

void _style(Sheet s, int row, int cols, CellStyle style) {
  for (var c = 0; c < cols; c++) {
    s
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .cellStyle =
        style;
  }
}

/// The spec's report: full history from day one, a cycle table with charts, and line charts.
List<int> buildWorkbook(Overview o) {
  final book = Excel.createExcel();
  final ledger = o.ledger;
  final segs = {for (final s in ledger.segments) s.to: s};

  // History: one row per entry, income rows coloured, summary at the bottom.
  final h = book['History'];
  h.appendRow([
    for (final c in [
      '#',
      'Date',
      'Type',
      'Amount',
      'Balance',
      'Spent since last',
      'Cumulative spent',
      'Month',
      'Note',
    ])
      _t(c),
  ]);
  _style(h, 0, 9, _head);
  final rows = <({Day date, int order, List<CellValue?> cells, bool income})>[];
  var cumulative = 0;
  for (final c in ledger.checkins) {
    final seg = segs[c.date];
    cumulative += seg?.spent ?? 0;
    rows.add((
      date: c.date,
      order: 0,
      income: false,
      cells: [
        _d(c.date),
        _t(c.balance == null ? 'Nothing spent' : 'Balance'),
        null,
        c.balance == null ? null : _m(c.balance!),
        seg == null ? null : _m(seg.spent),
        _m(cumulative),
        _t(_month(c.date)),
        _t(c.note),
      ],
    ));
  }
  for (final i in o.s.incomes) {
    rows.add((
      date: i.date,
      order: 1,
      income: true,
      cells: [
        _d(i.date),
        _t('Income (${i.source})'),
        _m(i.amount),
        null,
        null,
        null,
        _t(_month(i.date)),
        _t(i.note),
      ],
    ));
  }
  for (final e in o.s.expenses) {
    final cat =
        o.s.categories.where((c) => c.id == e.categoryId).firstOrNull?.name ??
        'Uncategorised';
    rows.add((
      date: e.date,
      order: 2,
      income: false,
      cells: [
        _d(e.date),
        _t('Expense ($cat)'),
        _m(-e.amount),
        null,
        null,
        null,
        _t(_month(e.date)),
        _t(e.note),
      ],
    ));
  }
  rows.sort(
    (a, b) => a.date != b.date
        ? a.date.compareTo(b.date)
        : a.order.compareTo(b.order),
  );
  for (var i = 0; i < rows.length; i++) {
    h.appendRow([IntCellValue(i + 1), ...rows[i].cells]);
    if (rows[i].income) _style(h, i + 1, 9, _incomeRow);
  }
  var r = rows.length + 2;
  void line(String label, CellValue value) {
    h.appendRow([_t(label), value]);
    _style(h, r, 1, _bold);
    r++;
  }

  h.appendRow([_t('Summary')]);
  _style(h, r++, 1, _bold);
  line('Starting balance', _m(ledger.eod.first));
  line('Total income', _m(o.cycles.fold(0, (s, c) => s + c.income)));
  line(
    'Total spent (net of income)',
    _m(o.cycles.fold(0, (s, c) => s + c.spent)),
  );
  line('Current balance', _m(o.balance));
  line('Net savings since the start', _m(o.balance - ledger.eod.first));
  final perMonth = <String, int>{};
  ledger.dailySpend().forEach(
    (d, v) => perMonth[_month(d)] = (perMonth[_month(d)] ?? 0) + v,
  );
  for (final e
      in (perMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
    line('Spent in ${e.key}', _m(e.value));
  }
  h.setColumnWidth(1, 14);
  h.setColumnWidth(2, 22);
  h.setColumnWidth(8, 30);

  // Cycles: the ratio table and its charts.
  final c = book['Cycles'];
  c.appendRow([
    for (final x in [
      'Cycle',
      'Opening',
      'Income',
      'Spent',
      'Saved',
      'Saved %',
      'Days tracked',
      'Average per day',
    ])
      _t(x),
  ]);
  _style(c, 0, 8, _head);
  for (final x in o.cycles) {
    c.appendRow([
      _t(Fmt.range(x.start, x.end)),
      _m(x.opening),
      _m(x.incomeForRatio),
      _m(x.spent),
      _m(x.saved),
      x.savedPercent == null ? null : DoubleCellValue(x.savedPercent!),
      IntCellValue(x.daysTracked),
      _m(x.avgPerDay),
    ]);
  }
  final n = o.cycles.length + 1;
  c.setColumnWidth(0, 22);
  c.addChart(
    Chart.column(
      anchor: CellIndex.indexByString('K2'),
      title: 'Average spend per day',
      categories: 'A2:A$n',
      series: [ChartSeries(name: 'Per day', values: 'H2:H$n')],
      legend: LegendPosition.bottom,
    ),
  );
  c.addChart(
    Chart.column(
      anchor: CellIndex.indexByString('K20'),
      title: 'Savings percent',
      categories: 'A2:A$n',
      series: [ChartSeries(name: 'Saved %', values: 'F2:F$n')],
      legend: LegendPosition.bottom,
    ),
  );

  // Charts: balance and cumulative spend, spaced so neither covers the other.
  final ch = book['Charts'];
  ch.appendRow([_t('Date'), _t('Balance'), _t('Cumulative spent')]);
  _style(ch, 0, 3, _head);
  var run = 0;
  for (var i = 0; i < ledger.checkins.length; i++) {
    run += segs[ledger.checkins[i].date]?.spent ?? 0;
    ch.appendRow([
      _t(dayKey(ledger.checkins[i].date)),
      _m(ledger.eod[i]),
      _m(run),
    ]);
  }
  final k = ledger.checkins.length + 1;
  ch.setColumnWidth(0, 14);
  ch.addChart(
    Chart.line(
      anchor: CellIndex.indexByString('E2'),
      title: 'Balance',
      categories: 'A2:A$k',
      series: [ChartSeries(name: 'Balance', values: 'B2:B$k')],
      legend: LegendPosition.bottom,
    ),
  );
  ch.addChart(
    Chart.line(
      anchor: CellIndex.indexByString('E22'),
      title: 'Cumulative spend',
      categories: 'A2:A$k',
      series: [ChartSeries(name: 'Spent', values: 'C2:C$k')],
      legend: LegendPosition.bottom,
    ),
  );

  book.delete('Sheet1');
  book.setDefaultSheet('History');
  return book.save()!;
}
