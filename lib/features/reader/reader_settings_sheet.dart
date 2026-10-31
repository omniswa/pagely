import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reader_style.dart';
import '../../state/settings_state.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading settings',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            const _Label('Theme'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final t in ReaderTheme.values)
                  _ThemeSwatch(
                    theme: t,
                    selected: s.readerTheme == t,
                    onTap: () => notifier.apply((c) => c.copyWith(readerTheme: t)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _Label('Font'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ReaderFont>(
                showSelectedIcon: false,
                segments: [
                  for (final f in ReaderFont.values)
                    ButtonSegment<ReaderFont>(value: f, label: Text(f.label)),
                ],
                selected: {s.readerFont},
                onSelectionChanged: (v) => notifier.apply((c) => c.copyWith(readerFont: v.first)),
              ),
            ),
            const SizedBox(height: 24),
            _SliderRow(
              label: 'Text size',
              valueLabel: '${s.fontSize.round()}',
              small: Icons.text_decrease_rounded,
              large: Icons.text_increase_rounded,
              value: s.fontSize,
              min: 14,
              max: 32,
              divisions: 18,
              onChanged: (v) => notifier.apply((c) => c.copyWith(fontSize: v)),
            ),
            const SizedBox(height: 8),
            _SliderRow(
              label: 'Line spacing',
              valueLabel: s.lineHeight.toStringAsFixed(1),
              small: Icons.density_small_rounded,
              large: Icons.density_large_rounded,
              value: s.lineHeight,
              min: 1.2,
              max: 2.2,
              divisions: 10,
              onChanged: (v) => notifier.apply((c) => c.copyWith(lineHeight: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Justify text'),
              value: s.justify,
              onChanged: (v) => notifier.apply((c) => c.copyWith(justify: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      );
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  color: theme.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(theme.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.small,
    required this.large,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final IconData small;
  final IconData large;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Label(label),
            Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Row(
          children: [
            Icon(small, size: 20, color: scheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
            Icon(large, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ],
    );
  }
}
