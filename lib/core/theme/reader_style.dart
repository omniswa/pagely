import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReaderTheme {
  paper('Paper', Color(0xFFFBFAF7), Color(0xFF22252A), Color(0xFF7B8088), Brightness.light),
  sepia('Sepia', Color(0xFFF3EAD7), Color(0xFF43372A), Color(0xFF8C7B64), Brightness.light),
  night('Night', Color(0xFF14161A), Color(0xFFC8CCD2), Color(0xFF7E848D), Brightness.dark);

  const ReaderTheme(this.label, this.background, this.foreground, this.muted, this.brightness);

  final String label;
  final Color background;
  final Color foreground;
  final Color muted;
  final Brightness brightness;
}

enum ReaderFont {
  serif('Serif'),
  sans('Sans'),
  mono('Mono');

  const ReaderFont(this.label);
  final String label;

  TextStyle style({
    required double size,
    required double height,
    required Color color,
    FontWeight? weight,
  }) {
    switch (this) {
      case ReaderFont.serif:
        return GoogleFonts.literata(fontSize: size, height: height, color: color, fontWeight: weight);
      case ReaderFont.sans:
        return GoogleFonts.inter(fontSize: size, height: height, color: color, fontWeight: weight);
      case ReaderFont.mono:
        return GoogleFonts.jetBrainsMono(fontSize: size, height: height, color: color, fontWeight: weight);
    }
  }
}
