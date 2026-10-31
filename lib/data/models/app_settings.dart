import 'package:flutter/material.dart';

import '../../core/theme/reader_style.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accentIndex = 0,
    this.readerTheme = ReaderTheme.paper,
    this.readerFont = ReaderFont.serif,
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.justify = false,
  });

  final ThemeMode themeMode;
  final int accentIndex;
  final ReaderTheme readerTheme;
  final ReaderFont readerFont;
  final double fontSize;
  final double lineHeight;
  final bool justify;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentIndex,
    ReaderTheme? readerTheme,
    ReaderFont? readerFont,
    double? fontSize,
    double? lineHeight,
    bool? justify,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentIndex: accentIndex ?? this.accentIndex,
      readerTheme: readerTheme ?? this.readerTheme,
      readerFont: readerFont ?? this.readerFont,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      justify: justify ?? this.justify,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'accentIndex': accentIndex,
        'readerTheme': readerTheme.name,
        'readerFont': readerFont.name,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'justify': justify,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? d.themeMode,
      accentIndex: (json['accentIndex'] as num?)?.toInt() ?? d.accentIndex,
      readerTheme: ReaderTheme.values.asNameMap()[json['readerTheme']] ?? d.readerTheme,
      readerFont: ReaderFont.values.asNameMap()[json['readerFont']] ?? d.readerFont,
      fontSize: ((json['fontSize'] as num?)?.toDouble() ?? d.fontSize).clamp(14.0, 32.0),
      lineHeight: ((json['lineHeight'] as num?)?.toDouble() ?? d.lineHeight).clamp(1.2, 2.2),
      justify: json['justify'] as bool? ?? d.justify,
    );
  }
}
