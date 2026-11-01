import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/errors.dart';
import '../../core/ui.dart';
import '../../core/widgets/book_cover.dart';
import '../../data/models/book.dart';
import '../../data/models/reading_progress.dart';
import '../../state/library_state.dart';
import '../../state/reading_state.dart';
import '../reader/reader_screen.dart';

void openBookDetails(BuildContext context, Book book) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => BookDetailsScreen(book: book)),
  );
}

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.book});

  final Book book;

  Future<void> _toggleDownload(
    BuildContext context,
    WidgetRef ref,
    bool downloaded,
  ) async {
    final notifier = ref.read(downloadsProvider.notifier);
    try {
      if (downloaded) {
        await notifier.remove(book);
      } else {
        await notifier.download(book);
      }
    } on AppException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFavorite = ref.watch(
      favoritesProvider.select((s) => s.contains(book.id)),
    );
    final downloads = ref.watch(downloadsProvider);
    final downloaded = downloads.completed.contains(book.id);
    final downloading = downloads.active.containsKey(book.id);
    final downloadProgress = downloads.active[book.id];
    final progress = ref.watch(progressProvider.select((m) => m[book.id]));
    final started = progress?.isStarted ?? false;
    final percent = ReadingProgress.percentageForFraction(
      progress?.fraction ?? 0,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? scheme.primary : null,
            ),
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(book.id),
          ),
          if (started)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (_) =>
                  ref.read(progressProvider.notifier).clear(book.id),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reset', child: Text('Mark as unread')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  SizedBox(
                    width: 190,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Hero(
                        tag: 'cover-${book.id}',
                        child: BookCover(
                          book: book,
                          radius: 4,
                          cacheWidth: 600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    book.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.literata(
                      textStyle: theme.textTheme.headlineSmall,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.author,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (book.addedLabel.isNotEmpty)
                        _InfoChip(
                          icon: Icons.calendar_today_rounded,
                          label: 'Added ${book.addedLabel}',
                        ),
                      _InfoChip(
                        icon: downloaded
                            ? Icons.download_done_rounded
                            : Icons.cloud_outlined,
                        label: downloaded ? 'Available offline' : 'Online',
                      ),
                      if (started)
                        _InfoChip(
                          icon: Icons.auto_stories_rounded,
                          label: '$percent% read',
                        ),
                    ],
                  ),
                  if (started) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress!.fraction,
                        minHeight: 4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(
                        started ? 'Continue reading' : 'Start reading',
                      ),
                      onPressed: () => openReader(context, book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: downloading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: downloadProgress,
                              ),
                            )
                          : Icon(
                              downloaded
                                  ? Icons.delete_outline_rounded
                                  : Icons.download_rounded,
                            ),
                      label: Text(
                        downloading
                            ? (downloadProgress == null
                                  ? 'Downloading…'
                                  : 'Downloading ${(downloadProgress * 100).round()}%')
                            : downloaded
                            ? 'Remove download'
                            : 'Download for offline',
                      ),
                      onPressed: downloading
                          ? null
                          : () => _toggleDownload(context, ref, downloaded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
