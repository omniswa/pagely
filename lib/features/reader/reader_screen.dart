import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/theme/reader_style.dart';
import '../../data/models/book.dart';
import '../../data/models/parsed_book.dart';
import '../../data/models/reading_progress.dart';
import '../../state/library_state.dart';
import '../../state/reading_state.dart';
import '../../state/settings_state.dart';
import 'chapters_sheet.dart';
import 'reader_settings_sheet.dart';

void openReader(BuildContext context, Book book) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(book: book)));
}

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(settingsProvider.select((s) => s.readerTheme));
    final parsed = ref.watch(parsedBookProvider(book));
    final overlay =
        (palette.brightness == Brightness.dark
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
              ? _ReaderMessage(
                  palette: palette,
                  message: 'This book appears to be empty.',
                )
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
    final active = ref.watch(
      downloadsProvider.select((s) => s.active.containsKey(book.id)),
    );
    final progress = ref.watch(
      downloadsProvider.select((s) => s.active[book.id]),
    );
    final text = active
        ? (progress == null
              ? 'Downloading…'
              : 'Downloading ${(progress * 100).round()}%')
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
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      text,
                      style: Theme.of(context).textTheme.labelLarge
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
  const _ReaderMessage({
    required this.palette,
    required this.message,
    this.onRetry,
  });

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
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: palette.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: palette.foreground),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
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

class _ReaderViewState extends ConsumerState<_ReaderView>
    with WidgetsBindingObserver {
  final _itemScroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  late final ValueNotifier<int> _index;
  late final ValueNotifier<int> _characterOffset;
  late final ValueNotifier<bool> _chromeVisible;
  late final ProgressNotifier _progress;
  late final int _initialIndex;
  EdgeInsets? _initialInsets;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _hasUserScrolled = false;

  ParsedBook get _parsed => widget.parsed;
  int get _count => _parsed.paragraphs.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialInsets ??= MediaQuery.paddingOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress = ref.read(progressProvider.notifier);
    final saved = ref.read(progressProvider)[widget.book.id];
    final savedOffset = saved?.characterOffset;
    final canResumeByOffset =
        saved != null &&
        saved.contentHash == _parsed.contentHash &&
        savedOffset != null;
    final int offset;
    if (canResumeByOffset) {
      offset = savedOffset.clamp(0, _parsed.characterCount);
    } else if (saved != null && saved.contentHash == null) {
      offset = (saved.fraction * _parsed.characterCount).round();
    } else {
      offset = 0;
    }
    _initialIndex = _parsed.paragraphIndexAtOffset(offset);
    _index = ValueNotifier(_initialIndex);
    _characterOffset = ValueNotifier(
      canResumeByOffset || (saved != null && saved.contentHash == null)
          ? offset
          : _parsed.paragraphOffsets[_initialIndex],
    );
    _chromeVisible = ValueNotifier(true);
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
      final characterOffset = _characterOffset.value;
      final characterCount = _parsed.characterCount;
      final contentHash = _parsed.contentHash;
      final progress = _progress;
      unawaited(
        Future<void>(
          () => progress.save(
            id,
            index,
            total,
            characterOffset: characterOffset,
            characterCount: characterCount,
            contentHash: contentHash,
          ),
        ),
      );
    }
    _index.dispose();
    _characterOffset.dispose();
    _chromeVisible.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveTimer?.cancel();
      _persist();
    }
  }

  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible.value
          ? SystemUiMode.edgeToEdge
          : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleChrome() {
    _chromeVisible.value = !_chromeVisible.value;
    _applySystemUi();
  }

  void _onPositionsChanged() {
    if (!_hasUserScrolled) return;

    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;

    int? top;
    var lastFullyVisible = false;
    for (final p in positions) {
      if (p.itemTrailingEdge > 0.04 && (top == null || p.index < top)) {
        top = p.index;
      }
      if (p.index == _count - 1 && p.itemTrailingEdge <= 1.0) {
        lastFullyVisible = true;
      }
    }
    top ??= positions.first.index;
    if (lastFullyVisible) top = _count - 1;
    final position = positions.firstWhere((p) => p.index == top);
    final paragraph = _parsed.paragraphs[top];
    final paragraphExtent =
        position.itemTrailingEdge - position.itemLeadingEdge;
    final paragraphFraction = paragraphExtent <= 0
        ? 0.0
        : (-position.itemLeadingEdge / paragraphExtent)
              .clamp(0.0, 1.0)
              .toDouble();
    final characterOffset = lastFullyVisible
        ? _parsed.characterCount
        : _parsed.paragraphOffsets[top] +
              (paragraph.text.length * paragraphFraction).round();
    if (top == _index.value && characterOffset == _characterOffset.value) {
      return;
    }

    _index.value = top;
    _characterOffset.value = characterOffset;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _persist);
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) {
      _hasUserScrolled = true;
    }
    return false;
  }

  void _persist() {
    if (!_dirty) return;
    _dirty = false;
    _progress.save(
      widget.book.id,
      _index.value,
      _count,
      characterOffset: _characterOffset.value,
      characterCount: _parsed.characterCount,
      contentHash: _parsed.contentHash,
    );
  }

  void _seek(int index) {
    final target = math.max(0, math.min(index, _count - 1));
    _index.value = target;
    _characterOffset.value = _parsed.paragraphOffsets[target];
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
      builder: (_) =>
          ChaptersSheet(parsed: _parsed, currentIndex: _index.value),
    );
    if (target != null && mounted) {
      _seek(target);
      _chromeVisible.value = false;
      _applySystemUi();
    }
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
    final insets = _initialInsets!;
    final body = s.readerFont.style(
      size: s.fontSize,
      height: s.lineHeight,
      color: palette.foreground,
    );
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
              child: NotificationListener<UserScrollNotification>(
                onNotification: _onUserScroll,
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
              characterOffset: _characterOffset,
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
            child: Text(
              paragraph.text,
              style: headingStyle,
              textAlign: TextAlign.center,
            ),
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

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.index,
    required this.characterOffset,
    required this.parsed,
    required this.palette,
    required this.onSeek,
  });

  final ValueNotifier<int> index;
  final ValueNotifier<int> characterOffset;
  final ParsedBook parsed;
  final ReaderTheme palette;
  final ValueChanged<int> onSeek;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: ValueListenableBuilder<int>(
          valueListenable: widget.characterOffset,
          builder: (context, i, _) {
            final fraction = widget.parsed.characterCount <= 0
                ? 0.0
                : (i / widget.parsed.characterCount).clamp(0.0, 1.0).toDouble();
            final displayedFraction = _dragFraction ?? fraction;
            final paragraphIndex = widget.index.value;
            final chapter =
                widget.parsed.chapterAt(paragraphIndex)?.title ?? '';
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: widget.palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${ReadingProgress.percentageForFraction(displayedFraction)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: widget.palette.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: theme.colorScheme.primary,
                    thumbColor: theme.colorScheme.primary,
                    inactiveTrackColor: widget.palette.foreground.withValues(
                      alpha: 0.15,
                    ),
                  ),
                  child: Slider(
                    value: displayedFraction,
                    min: 0,
                    max: 1,
                    onChanged: (value) => setState(() => _dragFraction = value),
                    onChangeEnd: (value) {
                      widget.onSeek(
                        widget.parsed.paragraphIndexAtOffset(
                          (value * widget.parsed.characterCount).round(),
                        ),
                      );
                      setState(() => _dragFraction = null);
                    },
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
