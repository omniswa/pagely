import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/book_cover.dart';
import '../../../data/models/book.dart';
import '../../../state/library_state.dart';
import '../../../state/reading_state.dart';

class BookCard extends ConsumerWidget {
  const BookCard({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFavorite = ref.watch(
      favoritesProvider.select((ids) => ids.contains(book.id)),
    );
    final isDownloaded = ref.watch(
      downloadsProvider.select((s) => s.completed.contains(book.id)),
    );
    final started = ref.watch(
      progressProvider.select((m) => (m[book.id]?.index ?? 0) > 0),
    );
    final fraction = ref.watch(
      progressProvider.select((m) => m[book.id]?.fraction ?? 0.0),
    );

    return Semantics(
      button: true,
      label: '${book.title} by ${book.author}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'cover-${book.id}',
                child: BookCover(book: book),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 32, 10, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                              Colors.black87,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        if (started)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 3,
                              backgroundColor: Colors.black26,
                            ),
                          ),
                        if (isFavorite || isDownloaded)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Column(
                              children: [
                                if (isFavorite)
                                  const _Badge(
                                    icon: Icons.favorite_rounded,
                                    color: Color(0xFFFF6B7A),
                                  ),
                                if (isFavorite && isDownloaded)
                                  const SizedBox(height: 4),
                                if (isDownloaded)
                                  const _Badge(
                                    icon: Icons.download_done_rounded,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
