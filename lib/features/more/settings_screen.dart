import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/providers.dart';
import '../../app/updates.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../shared/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _payday = TextEditingController();
  final _every = TextEditingController();
  final _budget = TextEditingController();
  final _salary = TextEditingController();
  Setting? _s;
  late String _currency;
  late bool _lakh, _monthly, _byExpense;

  String _fill(int minor) => minor == 0
      ? ''
      : (minor % 100 == 0
            ? '${minor ~/ 100}'
            : (minor / 100).toStringAsFixed(2));

  @override
  void dispose() {
    for (final c in [_payday, _every, _budget, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Setting s) {
    _s = s;
    _currency = s.currency;
    _lakh = s.lakh;
    _monthly = s.payday != null;
    _byExpense = s.tracking == 'expenses';
    _payday.text = '${s.payday ?? 1}';
    _every.text = '${s.everyDays ?? 30}';
    _budget.text = _fill(s.budget);
    _salary.text = _fill(s.baseSalary);
  }

  Future<void> _save() async {
    await ref
        .read(storeProvider)
        .saveSettings(
          SettingsCompanion(
            currency: Value(_currency),
            lakh: Value(_lakh),
            payday: Value(
              _monthly ? (int.tryParse(_payday.text) ?? 1).clamp(1, 31) : null,
            ),
            everyDays: Value(
              _monthly ? null : (int.tryParse(_every.text) ?? 30).clamp(1, 366),
            ),
            budget: Value(parseMoney(_budget.text)?.clamp(0, 1 << 50) ?? 0),
            baseSalary: Value(parseMoney(_salary.text)?.clamp(0, 1 << 50) ?? 0),
            tracking: Value(_byExpense ? 'expenses' : 'balance'),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Settings saved. New cycle rules apply from the next cycle.',
          ),
        ),
      );
  }

  Future<void> _newCycle() async {
    final today = ref.read(todayProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new cycle today?'),
        content: Text(
          'A new cycle begins on ${Fmt.date(today)}, opening with your last balance. Past cycles stay in Insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start new cycle'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(storeProvider).addCycleStart(today);
  }

  void _say(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleReminder(bool on, {bool change = false}) async {
    final n = ref.read(reminderProvider.notifier);
    if (!on) {
      await n.set(null);
      return;
    }
    final cur = (ref.read(reminderProvider) ?? '21:00').split(':');
    final t = change || ref.read(reminderProvider) == null
        ? await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: int.parse(cur[0]),
              minute: int.parse(cur[1]),
            ),
          )
        : null;
    if (t == null) return;
    final ok = await n.set(
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
    );
    if (!ok && mounted) {
      _say(
        'Notifications are off for Bluecoins. Turn them on in your phone settings.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(snapshotProvider).value?.settings;
    if (s == null) {
      return const GlassScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_s == null) _load(s);
    final mode = ref.watch(themeModeProvider);
    final reminder = ref.watch(reminderProvider);
    return GlassScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const SectionTitle('Money'),
          DropdownMenu<String>(
            initialSelection: _currency,
            label: const Text('Currency'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final c in currencies.keys)
                DropdownMenuEntry(
                  value: c,
                  label: '$c  ${currencies[c]!.trim()}',
                ),
            ],
            onSelected: (c) => setState(() => _currency = c ?? _currency),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Group digits as 1,00,000'),
            value: _lakh,
            onChanged: (v) => setState(() => _lakh = v),
          ),
          const SectionTitle('Cycle'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Every month')),
              ButtonSegment(value: false, label: Text('Every N days')),
            ],
            selected: {_monthly},
            onSelectionChanged: (v) => setState(() => _monthly = v.first),
          ),
          const SizedBox(height: 12),
          if (_monthly)
            TextField(
              controller: _payday,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Payday (day of the month)',
              ),
            )
          else
            TextField(
              controller: _every,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cycle length in days',
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _newCycle,
            child: const Text('Start a new cycle today'),
          ),
          const SectionTitle('Budget'),
          AmountField(controller: _budget, label: 'Budget per cycle'),
          const SizedBox(height: 12),
          AmountField(
            controller: _salary,
            label: 'Monthly salary (savings rate only)',
          ),
          const SectionTitle('How you track'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Daily balance')),
              ButtonSegment(value: true, label: Text('Every expense')),
            ],
            selected: {_byExpense},
            onSelectionChanged: (v) => setState(() => _byExpense = v.first),
          ),
          const SizedBox(height: 8),
          Text(
            _byExpense
                ? 'Days count as covered up to yesterday; log each expense.'
                : 'Days count as covered up to your latest balance.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SectionTitle('Reminder and privacy'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            subtitle: Text(
              reminder == null
                  ? 'A nudge to log your balance'
                  : 'Every day at $reminder',
            ),
            value: reminder != null,
            onChanged: (on) => _toggleReminder(on),
          ),
          if (reminder != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time'),
              subtitle: Text(reminder),
              trailing: const Icon(Icons.schedule),
              onTap: () => _toggleReminder(true, change: true),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock the app'),
            subtitle: const Text(
              'Ask for your fingerprint or PIN. Also hides the app in recent apps.',
            ),
            value: ref.watch(lockProvider),
            onChanged: (on) async {
              if (!await ref.read(lockProvider.notifier).set(on) && mounted) {
                _say(
                  'Could not confirm your fingerprint or PIN, so the lock stays off.',
                );
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tell me about new versions'),
            subtitle: const Text(
              'Asks GitHub once a day if a newer release exists. Nothing else is sent.',
            ),
            value: ref.watch(updateCheckProvider),
            onChanged: (on) => ref.read(updateCheckProvider.notifier).set(on),
          ),
          const SectionTitle('Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {mode},
            onSelectionChanged: (v) =>
                ref.read(themeModeProvider.notifier).set(v.first),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
        ],
      ),
    );
  }
}
