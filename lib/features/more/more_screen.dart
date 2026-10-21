import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(overviewProvider)?.pendingBills.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('What if'),
            subtitle: const Text('Try a scenario. Nothing is saved.'),
            onTap: () => context.push(Routes.whatIf),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('Bills'),
            subtitle: Text(
              pending == 0 ? 'Nothing pending' : '$pending to pay this cycle',
            ),
            onTap: () => context.push(Routes.bills),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Currency, cycle, budget, theme'),
            onTap: () => context.push(Routes.settings),
          ),
        ],
      ),
    );
  }
}
