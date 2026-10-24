import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/providers.dart';
import '../../core/day.dart';
import '../../data/database.dart';
import '../shared/widgets.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(overviewProvider);
    final f = ref.watch(fmtProvider);
    final store = ref.read(storeProvider);
    final t = Theme.of(context).textTheme;
    if (o == null) {
      return const GlassScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final cycleKey = dayKey(o.cycle.start);
    return GlassScaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
      body: o.s.bills.where((b) => !b.archived).isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Add fixed costs like internet or rent. They stay out of your numbers until you pay them; this is a reminder.',
                  style: t.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 112),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    o.pendingBills.isEmpty
                        ? 'All paid for this cycle'
                        : '${f.money(o.pendingTotal)} still to pay this cycle',
                    style: t.titleMedium,
                  ),
                ),
                for (final b in o.s.bills.where((b) => !b.archived))
                  ListTile(
                    title: Text(b.name),
                    subtitle: Text(f.money(b.amount)),
                    onTap: () => _edit(context, ref, bill: b),
                    trailing: FilterChip(
                      avatar: b.paidForCycle == cycleKey
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      label: Text(
                        b.paidForCycle == cycleKey ? 'Paid' : 'Mark paid',
                      ),
                      selected: b.paidForCycle == cycleKey,
                      onSelected: (v) => store.saveBill(
                        id: b.id,
                        name: b.name,
                        amount: b.amount,
                        paidForCycle: v ? cycleKey : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, {Bill? bill}) {
    final name = TextEditingController(text: bill?.name ?? '');
    final amount = TextEditingController(
      text: bill == null ? '' : '${bill.amount ~/ 100}',
    );
    final store = ref.read(storeProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bill == null ? 'New bill' : 'Edit bill',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name (gym, internet...)',
                ),
              ),
              const SizedBox(height: 12),
              AmountField(controller: amount, label: 'Amount per cycle'),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (bill != null)
                    TextButton(
                      onPressed: () {
                        store.deleteBill(bill.id);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final v = positiveMoney(amount.text);
                      if (name.text.trim().isEmpty || v == null) return;
                      store.saveBill(
                        id: bill?.id ?? '',
                        name: name.text.trim(),
                        amount: v,
                        paidForCycle: bill?.paidForCycle,
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      amount.dispose();
    });
  }
}
