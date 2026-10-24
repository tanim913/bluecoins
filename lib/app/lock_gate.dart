import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glass.dart';
import 'providers.dart';

/// Covers the app with a lock screen at launch and after 20 s in the background, when the
/// app lock is on. The system prompt (fingerprint, face or device PIN) does the checking.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  late bool _locked = ref.read(lockProvider);
  DateTime? _away;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(secureWindowProvider)(ref.read(lockProvider));
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _away = DateTime.now();
    if (s == AppLifecycleState.resumed && ref.read(lockProvider) && !_asking) {
      final gone = _away == null
          ? Duration.zero
          : DateTime.now().difference(_away!);
      if (gone > const Duration(seconds: 20)) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final ok = await ref.read(authProvider)('Unlock Bluecoins');
    _asking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lockProvider, (_, on) {
      if (!on) setState(() => _locked = false);
    });
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: GlassScaffold(
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Bluecoins is locked',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _unlock,
                        child: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
