import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/book_cover.dart';
import '../../../data/models/reading_progress.dart';
import '../../../state/reading_state.dart';
import '../../reader/reader_screen.dart';

class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(lastReadBookProvider);
    if (book == null) return const SizedBox.shrink();
    final fraction = ref.watch(
      progressProvider.select((m) => m[book.id]?.fraction ?? 0.0),
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: InkWell(
          onTap: () => openReader(context, book),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: BookCover(book: book, radius: 4, cacheWidth: 200),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CONTINUE READING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ReadingProgress.percentageForFraction(fraction)}% read',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
