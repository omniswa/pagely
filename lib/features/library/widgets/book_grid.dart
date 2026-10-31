import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes a column count and a fixed row height so cards never overflow,
/// regardless of screen width or text scale.
class BookGridSpec {
  const BookGridSpec({required this.columns, required this.mainAxisExtent});

  static const double spacing = 16;

  final int columns;
  final double mainAxisExtent;

  factory BookGridSpec.compute({required double width, required double textScale}) {
    final columns = math.max(2, (width / 168).floor());
    final itemWidth = (width - spacing * (columns - 1)) / columns;
    // cover (2:3) + gap + two-line title + one-line author
    final extent = itemWidth * 1.5 + 12 + 60 * textScale;
    return BookGridSpec(columns: columns, mainAxisExtent: extent);
  }

  SliverGridDelegate get delegate => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 20,
        crossAxisSpacing: spacing,
        mainAxisExtent: mainAxisExtent,
      );
}

/// Sliver grid that adapts to the available width.
class AdaptiveBookGrid extends StatelessWidget {
  const AdaptiveBookGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final spec = BookGridSpec.compute(width: constraints.crossAxisExtent, textScale: scale);
        return SliverGrid.builder(
          gridDelegate: spec.delegate,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
