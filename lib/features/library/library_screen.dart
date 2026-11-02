import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/svgs.dart';
import '../../core/ui.dart';
import '../../core/widgets/state_message.dart';
import '../../data/models/book.dart';
import '../../state/library_state.dart';
import '../details/book_details_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/book_card.dart';
import 'widgets/book_grid.dart';
import 'widgets/continue_reading_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(catalogProvider.notifier).refresh();
    if (!ok && context.mounted) {
      showAppSnackBar(context, "Couldn't refresh. Showing the saved library.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(visibleBooksProvider);
    final offline = ref.watch(catalogOfflineProvider);
    final query = ref.watch(libraryQueryProvider);
    final showContinue =
        query.text.isEmpty && query.filter == LibraryFilter.all;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const _LibraryAppBar(),
              const SliverToBoxAdapter(child: _LibraryFilters()),
              if (offline) const SliverToBoxAdapter(child: _OfflineBanner()),
              if (showContinue)
                const SliverToBoxAdapter(child: ContinueReadingCard()),
              ...books.when<List<Widget>>(
                loading: () => [const _LibraryLoading()],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateMessage(
                      svg: AppSvgs.offline,
                      title: "Can't load the library",
                      message: e is AppException
                          ? e.message
                          : 'Something went wrong.',
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(catalogProvider),
                    ),
                  ),
                ],
                data: (list) {
                  if (list.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(query: query),
                      ),
                    ];
                  }
                  return [
                    SliverToBoxAdapter(
                      child: _CollectionHeading(count: list.length),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
                      sliver: AdaptiveBookGrid(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final Book book = list[i];
                          return BookCard(
                            book: book,
                            onTap: () => openBookDetails(context, book),
                          );
                        },
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionHeading extends StatelessWidget {
  const _CollectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text(
            'COLLECTION',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '$count ${count == 1 ? 'book' : 'books'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryAppBar extends ConsumerStatefulWidget {
  const _LibraryAppBar();

  @override
  ConsumerState<_LibraryAppBar> createState() => _LibraryAppBarState();
}

class _LibraryAppBarState extends ConsumerState<_LibraryAppBar> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  var _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(libraryQueryProvider).text,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _controller.clear();
    ref.read(libraryQueryProvider.notifier).setText('');
    _focusNode.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(libraryQueryProvider.notifier);

    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      leading: _searching
          ? IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _closeSearch,
            )
          : null,
      leadingWidth: _searching ? 56 : null,
      titleSpacing: _searching ? 0 : 20,
      title: _searching
          ? TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: notifier.setText,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 40,
                ),
                hintText: 'Search title or author',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            notifier.setText('');
                          },
                        ),
                ),
              ),
            )
          : const Text(
              '3NDING',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
      actions: _searching
          ? null
          : [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search_rounded),
                onPressed: _openSearch,
              ),
              const _SortButton(),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
    );
  }
}

class _LibraryFilters extends ConsumerWidget {
  const _LibraryFilters();

  static IconData _iconFor(LibraryFilter f) => switch (f) {
    LibraryFilter.all => Icons.grid_view_rounded,
    LibraryFilter.favorites => Icons.favorite_border_rounded,
    LibraryFilter.downloaded => Icons.download_done_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(libraryQueryProvider.notifier);
    final filter = ref.watch(libraryQueryProvider.select((q) => q.filter));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in LibraryFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: Icon(_iconFor(f), size: 18),
                  label: Text(
                    f.label,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                  selected: filter == f,
                  onSelected: (_) => notifier.setFilter(f),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends ConsumerWidget {
  const _SortButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(libraryQueryProvider.select((q) => q.sort));
    return PopupMenuButton<LibrarySort>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort_rounded),
      initialValue: current,
      onSelected: ref.read(libraryQueryProvider.notifier).setSort,
      itemBuilder: (_) => [
        for (final s in LibrarySort.values)
          CheckedPopupMenuItem<LibrarySort>(
            value: s,
            checked: s == current,
            child: Text(s.label),
          ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Offline — showing the saved library',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.query});
  final LibraryQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.text.trim().isNotEmpty) {
      return const StateMessage(
        svg: AppSvgs.noResults,
        title: 'No matches',
        message: 'Try a different title or author.',
      );
    }
    switch (query.filter) {
      case LibraryFilter.favorites:
        return const StateMessage(
          svg: AppSvgs.emptyLibrary,
          title: 'No favorites yet',
          message: 'Open a book and tap the heart to save it here.',
        );
      case LibraryFilter.downloaded:
        return const StateMessage(
          svg: AppSvgs.emptyLibrary,
          title: 'Nothing downloaded',
          message: 'Download books to read them without a connection.',
        );
      case LibraryFilter.all:
        return StateMessage(
          svg: AppSvgs.emptyLibrary,
          title: 'The library is empty',
          message: 'No books were found. Pull down to refresh.',
          actionLabel: 'Refresh',
          onAction: () => ref.read(catalogProvider.notifier).refresh(),
        );
    }
  }
}

class _LibraryLoading extends StatelessWidget {
  const _LibraryLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your library',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
