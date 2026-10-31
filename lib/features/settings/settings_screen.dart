import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../state/library_state.dart';
import '../../state/settings_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear downloads?'),
        content: const Text('Downloaded books will be removed from this device. Your progress is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(downloadsProvider.notifier).clearAll();
      if (context.mounted) showAppSnackBar(context, 'Downloads cleared');
    } on AppException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final downloadCount = ref.watch(downloadsProvider.select((s) => s.completed.length));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _Section(
                  title: 'Appearance',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                              ],
                              selected: {settings.themeMode},
                              onSelectionChanged: (v) =>
                                  notifier.apply((c) => c.copyWith(themeMode: v.first)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Accent color', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < AppTheme.accents.length; i++)
                                _AccentSwatch(
                                  option: AppTheme.accents[i],
                                  selected: settings.accentIndex == i,
                                  onTap: () => notifier.apply((c) => c.copyWith(accentIndex: i)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _Section(
                  title: 'Storage',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download_done_rounded),
                      title: const Text('Downloaded books'),
                      subtitle: Text('$downloadCount saved for offline reading'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_outline_rounded,
                          color: downloadCount == 0 ? null : scheme.error),
                      title: const Text('Clear downloads'),
                      enabled: downloadCount > 0,
                      onTap: () => _confirmClear(context, ref),
                    ),
                  ],
                ),
                const _Section(
                  title: 'About',
                  children: [
                    ListTile(
                      leading: Icon(Icons.auto_stories_rounded),
                      title: Text('Pagely'),
                      subtitle: Text('Version ${AppConfig.version}'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.public_rounded),
                      title: Text('Library source'),
                      subtitle: Text(AppConfig.baseUrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.option, required this.selected, required this.onTap});

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.name} accent',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: option.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
        ),
      ),
    );
  }
}
