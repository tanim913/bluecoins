import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_gate.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class BluecoinsApp extends ConsumerWidget {
  const BluecoinsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Enough',
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => LockGate(child: child!),
    debugShowCheckedModeBanner: false,
  );
}
