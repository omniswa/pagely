import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/library/library_screen.dart';
import 'state/settings_state.dart';

class EndingApp extends ConsumerWidget {
  const EndingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (themeMode, accentIndex) =
        ref.watch(settingsProvider.select((s) => (s.themeMode, s.accentIndex)));
    final seed = AppTheme.accentAt(accentIndex).color;

    return MaterialApp(
      title: '3NDING',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.build(Brightness.light, seed),
      darkTheme: AppTheme.build(Brightness.dark, seed),
      // Respect accessibility text scaling, but clamp it so layouts never break.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4),
        ),
        child: child!,
      ),
      home: const LibraryScreen(),
    );
  }
}
