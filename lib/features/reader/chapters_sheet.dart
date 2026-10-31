import 'package:flutter/material.dart';

import '../../data/models/parsed_book.dart';

/// Pops with the paragraph index of the chosen chapter.
class ChaptersSheet extends StatelessWidget {
  const ChaptersSheet({super.key, required this.parsed, required this.currentIndex});

  final ParsedBook parsed;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = parsed.chapterAt(currentIndex);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Chapters',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (parsed.chapters.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  'No chapters were detected in this book.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: parsed.chapters.length,
                  itemBuilder: (context, i) {
                    final chapter = parsed.chapters[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(chapter.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      selected: identical(chapter, current),
                      onTap: () => Navigator.of(context).pop(chapter.index),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
