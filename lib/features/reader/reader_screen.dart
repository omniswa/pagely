import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/theme/reader_style.dart';
import '../../data/models/book.dart';
import '../../data/models/parsed_book.dart';
import '../../state/library_state.dart';
import '../../state/reading_state.dart';
import '../../state/settings_state.dart';
import 'chapters_sheet.dart';
import 'reader_settings_sheet.dart';

void openReader(BuildContext context, Book book) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ReaderScreen(book: book)),
  );
}

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(settingsProvider.select((s) => s.readerTheme));
    final parsed = ref.watch(parsedBookProvider(book));
    final overlay = (palette.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: palette.background,
        body: parsed.when(
          loading: () => _ReaderLoading(book: book, palette: palette),
          error: (e, _) => _ReaderMessage(
            palette: palette,
            message: e.toString(),
            onRetry: () => ref.invalidate(parsedBookProvider(book)),
          ),
          data: (data) => data.paragraphs.isEmpty
              ? _ReaderMessage(palette: palette, message: 'This book appears to be empty.')
              : _ReaderView(book: book, parsed: data),
        ),
      ),
    );
  }
}

// ---- Loading / error -------------------------------------------------------------------

class _ReaderLoading extends ConsumerWidget {
  const _ReaderLoading({required this.book, required this.palette});

  final Book book;
  final ReaderTheme palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(downloadsProvider.select((s) => s.active.containsKey(book.id)));
    final progress = ref.watch(downloadsProvider.select((s) => s.active[book.id]));
    final text = active
        ? (progress == null ? 'Downloading…' : 'Downloading ${(progress * 100).round()}%')
        : 'Opening book…';

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_rounded, color: palette.foreground),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: ReaderFont.serif.style(
                        size: 18,
                        height: 1.3,
                        color: palette.foreground,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, minHeight: 4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      text,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({required this.palette, required this.message, this.onRetry});

  final ReaderTheme palette;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_rounded, color: palette.foreground),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 40, color: palette.muted),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: palette.foreground),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Reader ------------------------------------------------------------------------------

class _ReaderView extends ConsumerStatefulWidget {
  const _ReaderView({required this.book, required this.parsed});

  final Book book;
  final ParsedBook parsed;

  @override
  ConsumerState<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends ConsumerState<_ReaderView> with WidgetsBindingObserver {
  final _itemScroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  late final ValueNotifier<int> _index;
  late final ValueNotifier<bool> _chromeVisible;
  late final ProgressNotifier _progress;
  late final int _initialIndex;
  Timer? _saveTimer;
  bool _dirty = false;

  ParsedBook get _parsed => widget.parsed;
  int get _count => _parsed.paragraphs.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress = ref.read(progressProvider.notifier);
    final saved = ref.read(progressProvider)[widget.book.id];
    _initialIndex = math.max(0, math.min(saved?.index ?? 0, _count - 1));
    _index = ValueNotifier(_initialIndex);
    // When resuming mid-book, start immersive so no text is hidden under the bars.
    _chromeVisible = ValueNotifier(_initialIndex == 0);
    if (!_chromeVisible.value) _applySystemUi();
    _positions.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positions.itemPositions.removeListener(_onPositionsChanged);
    _saveTimer?.cancel();
    if (_dirty) {
      // Deferred: providers must not be modified while the tree is unmounting.
      final id = widget.book.id;
      final index = _index.value;
      final total = _count;
      final progress = _progress;
      unawaited(Future<void>(() => progress.save(id, index, total)));
    }
    _index.dispose();
    _chromeVisible.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveTimer?.cancel();
      _persist();
    }
  }

  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible.value ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleChrome() {
    _chromeVisible.value = !_chromeVisible.value;
    _applySystemUi();
  }

  void _onPositionsChanged() {
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;

    int? top;
    var lastFullyVisible = false;
    for (final p in positions) {
      if (p.itemTrailingEdge > 0.04 && (top == null || p.index < top)) top = p.index;
      if (p.index == _count - 1 && p.itemTrailingEdge <= 1.0) lastFullyVisible = true;
    }
    top ??= positions.first.index;
    if (lastFullyVisible) top = _count - 1;
    if (top == _index.value) return;

    _index.value = top;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _persist);
  }

  void _persist() {
    if (!_dirty) return;
    _dirty = false;
    _progress.save(widget.book.id, _index.value, _count);
  }

  void _seek(int index) {
    final target = math.max(0, math.min(index, _count - 1));
    _index.value = target;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _persist);
    if (_itemScroll.isAttached) _itemScroll.jumpTo(index: target);
  }

  Future<void> _openChapters() async {
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChaptersSheet(parsed: _parsed, currentIndex: _index.value),
    );
    if (target != null && mounted) _seek(target);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final palette = s.readerTheme;
    final insets = MediaQuery.paddingOf(context);
    final body = s.readerFont.style(size: s.fontSize, height: s.lineHeight, color: palette.foreground);
    final heading = s.readerFont.style(
      size: s.fontSize * 1.35,
      height: 1.3,
      color: palette.foreground,
      weight: FontWeight.w700,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              child: ScrollablePositionedList.builder(
                itemCount: _count,
                itemScrollController: _itemScroll,
                itemPositionsListener: _positions,
                initialScrollIndex: _initialIndex,
                itemBuilder: (context, i) => _ParagraphView(
                  paragraph: _parsed.paragraphs[i],
                  bodyStyle: body,
                  headingStyle: heading,
                  justify: s.justify,
                  extraTop: i == 0 ? 72 : 0,
                  extraBottom: i == _count - 1 ? 140 : 0,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _chromeVisible,
            builder: (_, visible, child) => _ChromeBar(
              visible: visible,
              fromTop: true,
              palette: palette,
              child: child!,
            ),
            child: _TopBar(
              title: widget.book.title,
              palette: palette,
              onChapters: _openChapters,
              onSettings: _openSettings,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _chromeVisible,
            builder: (_, visible, child) => _ChromeBar(
              visible: visible,
              fromTop: false,
              palette: palette,
              child: child!,
            ),
            child: _BottomBar(
              index: _index,
              parsed: _parsed,
              palette: palette,
              onSeek: _seek,
            ),
          ),
        ),
      ],
    );
  }
}

class _ParagraphView extends StatelessWidget {
  const _ParagraphView({
    required this.paragraph,
    required this.bodyStyle,
    required this.headingStyle,
    required this.justify,
    required this.extraTop,
    required this.extraBottom,
  });

  final Paragraph paragraph;
  final TextStyle bodyStyle;
  final TextStyle headingStyle;
  final bool justify;
  final double extraTop;
  final double extraBottom;

  @override
  Widget build(BuildContext context) {
    final Widget text = paragraph.isHeading
        ? Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 16),
            child: Text(paragraph.text, style: headingStyle, textAlign: TextAlign.center),
          )
        : Padding(
            padding: EdgeInsets.only(bottom: (bodyStyle.fontSize ?? 18) * 0.9),
            child: Text(
              paragraph.text,
              style: bodyStyle,
              textAlign: justify ? TextAlign.justify : TextAlign.start,
            ),
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, extraTop, 24, extraBottom),
          child: text,
        ),
      ),
    );
  }
}

// ---- Chrome ---------------------------------------------------------------------------------

class _ChromeBar extends StatelessWidget {
  const _ChromeBar({
    required this.visible,
    required this.fromTop,
    required this.palette,
    required this.child,
  });

  final bool visible;
  final bool fromTop;
  final ReaderTheme palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: palette.foreground.withValues(alpha: 0.1));
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, fromTop ? -1 : 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.97),
              border: fromTop ? Border(bottom: line) : Border(top: line),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.palette,
    required this.onChapters,
    required this.onSettings,
  });

  final String title;
  final ReaderTheme palette;
  final VoidCallback onChapters;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              color: palette.foreground,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Chapters',
              color: palette.foreground,
              icon: const Icon(Icons.format_list_bulleted_rounded),
              onPressed: onChapters,
            ),
            IconButton(
              tooltip: 'Reading settings',
              color: palette.foreground,
              icon: const Icon(Icons.text_fields_rounded),
              onPressed: onSettings,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.parsed,
    required this.palette,
    required this.onSeek,
  });

  final ValueNotifier<int> index;
  final ParsedBook parsed;
  final ReaderTheme palette;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = parsed.paragraphs.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, i, _) {
            final fraction = total <= 1 ? 0.0 : i / (total - 1);
            final chapter = parsed.chapterAt(i)?.title ?? '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: theme.colorScheme.primary,
                    thumbColor: theme.colorScheme.primary,
                    inactiveTrackColor: palette.foreground.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: i.toDouble().clamp(0.0, math.max(1, total - 1).toDouble()).toDouble(),
                    min: 0,
                    max: math.max(1, total - 1).toDouble(),
                    onChanged: (v) => onSeek(v.round()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
