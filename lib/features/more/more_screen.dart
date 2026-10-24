import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/glass.dart';
import '../../app/cloud.dart';
import '../../app/profile.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../shared/widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final user = ref.watch(userProvider).value;
    final pending = ref.watch(overviewProvider)?.pendingBills.length ?? 0;
    return GlassScaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: Avatar(profile, size: 32),
                  title: Text(profile.name ?? 'Profile'),
                  subtitle: const Text('Name, photo, gender'),
                  onTap: () => context.push(Routes.profile),
                ),
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
                    pending == 0
                        ? 'Nothing pending'
                        : '$pending to pay this cycle',
                  ),
                  onTap: () => context.push(Routes.bills),
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Account and sync'),
                  subtitle: Text(
                    user == null
                        ? 'Back up and sync with Google'
                        : (user.email ?? 'Signed in'),
                  ),
                  onTap: () => context.push(Routes.account),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Backup and export'),
                  subtitle: const Text('Backup file, Excel, import from text'),
                  onTap: () => context.push(Routes.backup),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text('Currency, cycle, budget, theme'),
                  onTap: () => context.push(Routes.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
