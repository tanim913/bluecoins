import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/cloud.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/auth.dart';
import '../../data/database.dart';
import '../shared/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _balance = TextEditingController();
  final _payday = TextEditingController(text: '1');
  final _every = TextEditingController(text: '30');
  final _budget = TextEditingController();
  final _salary = TextEditingController();
  String _currency = 'BDT';
  bool _lakh = true;
  bool _monthly = true;
  late Day _since = ref.read(todayProvider);
  String? _balanceError;
  bool _saving = false;
  bool _signingIn = false;
  String? _accountNote;

  @override
  void dispose() {
    for (final c in [_page, _balance, _payday, _every, _budget, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int p) => _page.animateToPage(
    p,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
  );

  void _next() {
    final v = parseMoney(_balance.text);
    if (v == null) {
      setState(
        () => _balanceError = 'Enter what you have right now, e.g. 125000',
      );
      return;
    }
    setState(() => _balanceError = null);
    _go(2);
  }

  /// Signs in with Google and, in the same step, pulls the account's data. A returning user
  /// lands on Home (the router redirects once the data is here); a new one carries on setting up.
  Future<void> _googleStart() async {
    setState(() => _signingIn = true);
    try {
      await ref.read(syncProvider.notifier).signIn();
      final snap = await ref.read(storeProvider).load();
      if (!mounted || snap.onboarded) return;
      setState(
        () => _accountNote = 'Signed in. This account has no data yet, so let us set up your money.',
      );
      _go(1);
    } on AuthFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _finish() async {
    final balance = parseMoney(_balance.text);
    if (balance == null) return _go(1);
    setState(() => _saving = true);
    final store = ref.read(storeProvider);
    final payday = (int.tryParse(_payday.text) ?? 1).clamp(1, 31);
    final every = (int.tryParse(_every.text) ?? 30).clamp(1, 366);
    await store.saveSettings(
      SettingsCompanion(
        currency: Value(_currency),
        lakh: Value(_lakh),
        payday: Value(_monthly ? payday : null),
        everyDays: Value(_monthly ? null : every),
        budget: Value(parseMoney(_budget.text)?.clamp(0, 1 << 50) ?? 0),
        baseSalary: Value(parseMoney(_salary.text)?.clamp(0, 1 << 50) ?? 0),
      ),
    );
    await store.addCycleStart(_since);
    // The balance you have now is the balance at the end of the day before the first cycle day.
    await store.saveCheckin(
      addDays(_since, -1),
      balance,
      note: 'Starting balance',
    );
    // The router redirects to Home once the snapshot says we are onboarded.
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassScaffold(
      body: SafeArea(
        child: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Step(
              title: 'Do you have enough for today?',
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ref.watch(authServiceProvider) != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _signingIn ? null : _googleStart,
                        icon: _signingIn
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _signingIn
                              ? 'Signing in and fetching your data...'
                              : 'Continue with Google',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _signingIn ? null : () => _go(1),
                        child: const Text('Use without an account'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _go(1),
                        child: const Text('Get started'),
                      ),
                    ),
                ],
              ),
              children: [
                Text(
                  'One balance a day is all you type. Enough works out the rest.',
                  style: t.bodyLarge,
                ),
                const SizedBox(height: 24),
                const _Point(
                  Icons.edit_note,
                  'Type what you have left at the end of the day.',
                ),
                const _Point(
                  Icons.event_repeat,
                  'Months start on your payday, not on the 1st.',
                ),
                const _Point(
                  Icons.lock_outline,
                  'Private: works offline, no bank login, no ads.',
                ),
              ],
            ),
            _Step(
              title: 'Your money',
              back: () => _go(0),
              action: FilledButton(
                onPressed: _next,
                child: const Text('Continue'),
              ),
              children: [
                if (_accountNote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _accountNote!,
                      style: t.bodyMedium?.copyWith(
                        color: context.palette.good,
                      ),
                    ),
                  ),
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
                  onSelected: (c) => setState(() {
                    _currency = c ?? 'BDT';
                    _lakh = const {
                      'BDT',
                      'INR',
                      'PKR',
                      'NPR',
                      'LKR',
                    }.contains(_currency);
                  }),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Group digits as 1,00,000'),
                  value: _lakh,
                  onChanged: (v) => setState(() => _lakh = v),
                ),
                const SizedBox(height: 8),
                AmountField(
                  controller: _balance,
                  label: 'How much do you have right now?',
                  errorText: _balanceError,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cash, bank and mobile money together, as one number.',
                  style: t.bodySmall?.copyWith(color: context.palette.muted),
                ),
              ],
            ),
            _Step(
              title: 'Your cycle',
              back: () => _go(1),
              action: FilledButton(
                onPressed: _saving ? null : _finish,
                child: const Text('Start tracking'),
              ),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Every month')),
                    ButtonSegment(value: false, label: Text('Every N days')),
                  ],
                  selected: {_monthly},
                  onSelectionChanged: (s) => setState(() => _monthly = s.first),
                ),
                const SizedBox(height: 16),
                if (_monthly)
                  TextField(
                    controller: _payday,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payday (day of the month)',
                      helperText: 'A new cycle starts on this day.',
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
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tracking since'),
                  subtitle: Text(Fmt.dateY(_since)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final d = await pickDay(context, _since);
                    if (d != null) setState(() => _since = d);
                  },
                ),
                const SizedBox(height: 8),
                AmountField(
                  controller: _budget,
                  label: 'Budget per cycle (optional)',
                ),
                const SizedBox(height: 16),
                AmountField(
                  controller: _salary,
                  label: 'Monthly salary (optional)',
                ),
                const SizedBox(height: 8),
                Text(
                  'The salary is only used to show your savings rate.',
                  style: t.bodySmall?.copyWith(color: context.palette.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.children,
    required this.action,
    this.back,
  });
  final String title;
  final List<Widget> children;
  final Widget action;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          children: [
            if (back != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SizedBox(width: double.infinity, child: action),
      ),
    ],
  );
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
