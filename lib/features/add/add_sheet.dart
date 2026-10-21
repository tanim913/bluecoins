import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../../domain/ledger/models.dart';
import '../../domain/parse/entry_parser.dart';
import '../shared/widgets.dart';
import 'actions.dart';

enum EntryKind { balance, expense, income }

/// Opens the add sheet. Pass one of the edit* arguments to edit an existing entry.
Future<void> showAddSheet(
  BuildContext context, {
  EntryKind kind = EntryKind.balance,
  Checkin? editCheckin,
  Income? editIncome,
  Expense? editExpense,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true, // cover the nav bar and scrim the whole screen
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AddSheet(
    kind: kind,
    editCheckin: editCheckin,
    editIncome: editIncome,
    editExpense: editExpense,
  ),
);

class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({
    super.key,
    this.kind = EntryKind.balance,
    this.editCheckin,
    this.editIncome,
    this.editExpense,
  });
  final EntryKind kind;
  final Checkin? editCheckin;
  final Income? editIncome;
  final Expense? editExpense;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late EntryKind _kind = widget.editIncome != null
      ? EntryKind.income
      : widget.editExpense != null
      ? EntryKind.expense
      : widget.editCheckin != null
      ? EntryKind.balance
      : widget.kind;
  late Day _day =
      widget.editCheckin?.date ??
      widget.editIncome?.date ??
      widget.editExpense?.date ??
      ref.read(todayProvider);
  String? _category;
  String _source = 'salary';
  bool _includesIncome = true;
  bool _afterCheckin = false;
  bool _countsInPrevious = false;
  String? _error;

  bool get _editing =>
      widget.editCheckin != null ||
      widget.editIncome != null ||
      widget.editExpense != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editCheckin, i = widget.editIncome, e = widget.editExpense;
    String fill(int minor) =>
        minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);
    if (c != null) {
      _amount.text = c.balance == null ? '' : fill(c.balance!);
      _note.text = c.note;
    } else if (i != null) {
      _amount.text = fill(i.amount);
      _note.text = i.note;
      _source = i.source;
      _afterCheckin = i.afterCheckin;
      _countsInPrevious = i.countsInPrevious;
    } else if (e != null) {
      _amount.text = fill(e.amount);
      _note.text = e.note;
      _category = e.categoryId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  ParsedEntry? get _parsed => _amount.text.trim().isEmpty
      ? null
      : parseEntry(_amount.text, ref.read(todayProvider));
  Day get _effectiveDay => _parsed?.day ?? _day;
  int? get _value => _parsed?.amount;

  Future<void> _save() async {
    final store = ref.read(storeProvider);
    final snap = ref.read(snapshotProvider).value!;
    final f = ref.read(fmtProvider);
    final o = ref.read(overviewProvider);
    final day = _effectiveDay;
    final v = _value;
    String msg;
    switch (_kind) {
      case EntryKind.balance:
        if (_parsed == null && _amount.text.trim().isNotEmpty ||
            v == null && _amount.text.trim().isNotEmpty) {
          return setState(() => _error = "That doesn't look like an amount");
        }
        if (_amount.text.trim().isEmpty && !_editing) {
          return setState(
            () => _error = 'Enter your balance, or use Nothing spent',
          );
        }
        msg = await saveBalance(
          store,
          snap,
          f,
          day,
          v,
          note: _note.text.trim(),
          includesIncome: _includesIncome,
          budgetPerDay: o != null && o.hasBudget
              ? o.budget ~/ o.cycle.length
              : 0,
        );
      case EntryKind.expense:
        if (v == null || v <= 0) {
          return setState(() => _error = 'Enter an amount above zero');
        }
        await store.saveExpense(
          Expense(
            day,
            v,
            categoryId: _category,
            note: _note.text.trim(),
            id: widget.editExpense?.id ?? '',
          ),
        );
        msg = 'Expense saved.';
      case EntryKind.income:
        if (v == null || v <= 0) {
          return setState(() => _error = 'Enter an amount above zero');
        }
        await store.saveIncome(
          Income(
            day,
            v,
            afterCheckin: _afterCheckin,
            countsInPrevious: _countsInPrevious,
            source: _source,
            note: _note.text.trim(),
            id: widget.editIncome?.id ?? '',
          ),
        );
        msg = 'Income saved. It is not counted as spending.';
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    final store = ref.read(storeProvider);
    if (widget.editCheckin != null) {
      await store.deleteCheckin(widget.editCheckin!.date);
    }
    if (widget.editIncome != null) {
      await store.deleteIncome(widget.editIncome!.id);
    }
    if (widget.editExpense != null) {
      await store.deleteExpense(widget.editExpense!.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapshotProvider).value;
    final o = ref.watch(overviewProvider);
    final f = ref.watch(fmtProvider);
    final t = Theme.of(context).textTheme;
    if (snap == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final day = _effectiveDay;
    final dayIncomes = snap.incomes.where((i) => i.date == day).toList();
    final hasCheckin = snap.checkins.any(
      (c) => c.date == day && c.balance != null,
    );
    final isStart = o != null && o.starts.skip(1).contains(day);
    final preview = _kind == EntryKind.balance
        ? previewSpend(snap, f, day, _value)
        : null;
    final typed = _amount.text.trim().isNotEmpty;
    final bad = typed && _parsed == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editing)
              Row(
                children: [
                  Expanded(child: Text('Edit entry', style: t.titleLarge)),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            else
              SegmentedButton<EntryKind>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EntryKind.balance,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Balance', maxLines: 1),
                    ),
                  ),
                  ButtonSegment(
                    value: EntryKind.expense,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Expense', maxLines: 1),
                    ),
                  ),
                  ButtonSegment(
                    value: EntryKind.income,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Income', maxLines: 1),
                    ),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _error = null;
                }),
              ),
            const SizedBox(height: 16),
            AmountField(
              controller: _amount,
              label: switch (_kind) {
                EntryKind.balance => 'Balance at the end of the day',
                EntryKind.expense => 'Amount spent',
                EntryKind.income => 'Amount received',
              },
              autofocus: true,
              errorText:
                  _error ?? (bad ? "That doesn't look like an amount" : null),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (typed && !bad && _value != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  '= ${f.money(_value!)}${_parsed?.day != null ? ' on ${Fmt.date(day)}' : ''}',
                  style: t.bodySmall?.copyWith(color: context.palette.muted),
                ),
              ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  preview,
                  style: t.bodySmall?.copyWith(color: context.palette.muted),
                ),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Date'),
              subtitle: Text(Fmt.dateY(day)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await pickDay(context, day);
                if (d != null) setState(() => _day = d);
              },
            ),
            if (_kind == EntryKind.balance &&
                dayIncomes.isNotEmpty &&
                !_editing)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  'This balance already includes the ${f.money(dayIncomes.fold(0, (s, i) => s + i.amount))} you received',
                ),
                subtitle: const Text(
                  'Turn off if you typed it before the money arrived.',
                ),
                value: _includesIncome,
                onChanged: (v) => setState(() => _includesIncome = v),
              ),
            if (_kind == EntryKind.expense) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in snap.categories.where((c) => !c.archived))
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _category == c.id,
                      onSelected: (s) =>
                          setState(() => _category = s ? c.id : null),
                    ),
                ],
              ),
            ],
            if (_kind == EntryKind.income) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const ['salary', 'bonus', 'other'])
                    ChoiceChip(
                      label: Text('${s[0].toUpperCase()}${s.substring(1)}'),
                      selected: _source == s,
                      onSelected: (_) => setState(() => _source = s),
                    ),
                ],
              ),
              if (hasCheckin)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    'It arrived after I logged that day\'s balance',
                  ),
                  value: _afterCheckin,
                  onChanged: (v) => setState(() => _afterCheckin = v),
                ),
              if (isStart)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    'Count it in the previous cycle\'s savings',
                  ),
                  subtitle: const Text(
                    'Only changes the savings ratio, never your spending.',
                  ),
                  value: _countsInPrevious,
                  onChanged: (v) => setState(() => _countsInPrevious = v),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_editing ? 'Save changes' : 'Save'),
              ),
            ),
            if (_kind == EntryKind.balance && !_editing)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    _amount.clear();
                    await _save();
                  },
                  child: const Text('Nothing spent on this day'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
