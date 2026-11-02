import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes a column count and a fixed row height matching the cover aspect ratio.
class BookGridSpec {
  const BookGridSpec({required this.columns, required this.mainAxisExtent});

  static const double spacing = 16;

  final int columns;
  final double mainAxisExtent;

  factory BookGridSpec.compute({
    required double width,
  }) {
    final columns = math.max(2, (width / 168).floor());
    final itemWidth = (width - spacing * (columns - 1)) / columns;
    final extent = itemWidth * 1.5;
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
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final spec = BookGridSpec.compute(
          width: constraints.crossAxisExtent,
        );
        return SliverGrid.builder(
          gridDelegate: spec.delegate,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
