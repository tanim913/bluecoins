import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/cloud.dart';
import '../../app/theme.dart';
import '../../data/auth.dart';
import '../shared/widgets.dart';

String ago(DateTime t, DateTime now) {
  final m = now.difference(t).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  if (m < 60 * 24) return '${m ~/ 60} h ago';
  return '${m ~/ (60 * 24)} days ago';
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  void _say(BuildContext context, String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final c = ref.read(syncProvider.notifier);
    try {
      if (await c.signIn() == SignInOutcome.conflict && context.mounted) {
        final use = await _confirm(
          context,
          'This account already has data',
          "Your phone and this account both hold entries. Use the account's data? Your phone's data is saved to a safety file first.",
          "Use the account's data",
        );
        use ? await c.useCloud() : await c.cancelSignIn();
      }
    } on AuthFailure catch (e) {
      if (context.mounted) _say(context, e.message);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final c = ref.read(syncProvider.notifier);
    if (!await _confirm(
      context,
      'Sign out?',
      'Your data stays in your account. It is removed from this phone, after a safety copy is saved here.',
      'Sign out',
    )) {
      return;
    }
    if (!await c.signOut() && context.mounted) {
      final force = await _confirm(
        context,
        'Some changes are not uploaded',
        'They could not be sent to your account. If you sign out now they are only in the safety copy on this phone.',
        'Sign out anyway',
      );
      if (force) await c.signOut(force: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await _confirm(
      context,
      'Delete your account?',
      'This permanently deletes your account and everything stored in the cloud, and empties this phone. A safety copy is saved first. This cannot be undone.',
      'Delete everything',
    )) {
      return;
    }
    try {
      await ref.read(syncProvider.notifier).deleteAccount();
    } on Object {
      if (context.mounted) {
        _say(
          context,
          'Could not delete the account. Check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final user = ref.watch(userProvider).value;
    final sync = ref.watch(syncProvider);
    final pending = ref.watch(pendingProvider).value ?? 0;
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: context.palette.muted);
    return GlassScaffold(
      appBar: AppBar(title: const Text('Account and sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          if (auth == null)
            Panel(
              child: Text(
                'Cloud sync is not set up in this build. Everything works on your phone. Use Backup and export to keep a file copy.',
                style: t.bodyLarge,
              ),
            )
          else if (user == null) ...[
            Text(
              'Back up your data and use Enough on more than one phone. Signing in is optional.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 12),
            const _Point(
              'Your entries are copied to your own private account.',
            ),
            const _Point(
              'Only you can read them. There is no bank access and no ads.',
            ),
            const _Point(
              'You can delete the account and all its data here at any time.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: sync.busy ? null : () => _signIn(context, ref),
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
          ] else ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email ?? 'Signed in', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        sync.error != null
                            ? Icons.error_outline
                            : pending > 0
                            ? Icons.sync
                            : Icons.check_circle,
                        size: 20,
                        color: sync.error != null
                            ? Theme.of(context).colorScheme.error
                            : pending > 0
                            ? context.palette.warn
                            : context.palette.good,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sync.busy
                              ? 'Syncing...'
                              : sync.error ??
                                    (pending > 0
                                        ? '$pending changes waiting to upload'
                                        : sync.lastSync == null
                                        ? 'Not synced yet'
                                        : 'Synced ${ago(sync.lastSync!, DateTime.now())}'),
                          style: t.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (sync.failed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${sync.failed.length} entries were refused by the server and stay on this phone.',
                        style: muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: sync.busy
                  ? null
                  : () => ref.read(syncProvider.notifier).sync(),
              child: const Text('Sync now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: sync.busy
                  ? null
                  : () => ref.read(syncProvider.notifier).reuploadAll(),
              child: const Text('Upload everything again'),
            ),
            const SizedBox(height: 4),
            Text(
              'Use this if your account was restored from an old backup.',
              style: muted,
            ),
            const SectionTitle('Leave'),
            OutlinedButton(
              onPressed: sync.busy ? null : () => _signOut(context, ref),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: sync.busy ? null : () => _delete(context, ref),
              child: Text(
                'Delete my account and cloud data',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
