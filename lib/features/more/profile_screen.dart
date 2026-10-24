import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/glass.dart';
import '../../app/profile.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../shared/widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  String? _gender;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _say(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final name = _name.text.trim();
    await ref
        .read(storeProvider)
        .saveSettings(
          SettingsCompanion(
            displayName: Value(name.isEmpty ? null : name),
            gender: Value(_gender),
          ),
        );
    if (mounted) _say('Profile saved.');
  }

  Future<void> _photoMenu(Profile p) async {
    final notifier = ref.read(profilePhotoProvider.notifier);
    final hasPhone = ref.read(profilePhotoProvider) != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (hasPhone)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(
                    p.googleUrl == null
                        ? 'Remove photo'
                        : 'Use my Google photo instead',
                  ),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') return notifier.remove();
    try {
      await notifier.pick(camera: choice == 'camera');
    } on Object {
      if (mounted) _say('Could not open the camera or gallery.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    final s = ref.watch(snapshotProvider).value?.settings;
    if (!_loaded && s != null) {
      _loaded = true;
      _name.text = p.name ?? '';
      _gender = s.gender;
    }
    final t = Theme.of(context).textTheme;
    return GlassScaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Change profile photo',
              child: InkResponse(
                onTap: () => _photoMenu(p),
                radius: 64,
                child: Stack(
                  children: [
                    Avatar(p, size: 112),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.photo_camera,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'The photo stays on this phone. It is never uploaded.',
              style: t.bodySmall?.copyWith(color: context.palette.muted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SectionTitle('Gender'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in genderLabels.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _gender == e.key,
                  showCheckmark: false,
                  onSelected: (on) =>
                      setState(() => _gender = on ? e.key : null),
                ),
            ],
          ),
          const SectionTitle('Email'),
          Text(
            p.email ?? 'Not signed in',
            style: t.titleMedium?.copyWith(
              color: p.email == null ? context.palette.muted : null,
            ),
          ),
          if (p.email == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sign in with Google under Account and sync to show your email and keep your name and gender safe in the cloud.',
                style: t.bodySmall?.copyWith(color: context.palette.muted),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save profile')),
        ],
      ),
    );
  }
}
