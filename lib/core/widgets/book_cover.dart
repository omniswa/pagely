import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/book.dart';

/// Network cover with a generated fallback. Fills its (tight) parent box.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.radius = 12, this.cacheWidth = 420});

  final Book book;
  final double radius;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uri = book.coverUri;
    final borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox.expand(
          child: uri == null
              ? _GeneratedCover(book: book)
              : CachedNetworkImage(
                  imageUrl: uri.toString(),
                  fit: BoxFit.cover,
                  memCacheWidth: cacheWidth,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_, __) => ColoredBox(color: scheme.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => _GeneratedCover(book: book),
                ),
        ),
      ),
    );
  }
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final hue = ((book.id * 47) % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.45, 0.42).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.5, 0.28).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 22),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                book.title,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.literata(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
