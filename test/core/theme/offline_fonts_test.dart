import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show FontWeight;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Google Fonts loads bundled variants without runtime fetching',
    () async {
      final previousAllowRuntimeFetching =
          GoogleFonts.config.allowRuntimeFetching;
      final previousDebugPrint = debugPrint;
      final loadErrors = <String>[];

      GoogleFonts.config.allowRuntimeFetching = false;
      debugPrint = (message, {wrapWidth}) {
        if (message?.contains('google_fonts was unable to load font') ??
            false) {
          loadErrors.add(message!);
          return;
        }
        previousDebugPrint(message, wrapWidth: wrapWidth);
      };

      try {
        GoogleFonts.inter(fontWeight: FontWeight.w400);
        GoogleFonts.inter(fontWeight: FontWeight.w500);
        GoogleFonts.inter(fontWeight: FontWeight.w600);
        GoogleFonts.inter(fontWeight: FontWeight.w700);
        GoogleFonts.literata(fontWeight: FontWeight.w400);
        GoogleFonts.literata(fontWeight: FontWeight.w700);
        GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w400);
        GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700);

        await GoogleFonts.pendingFonts();

        expect(loadErrors, isEmpty);
      } finally {
        debugPrint = previousDebugPrint;
        GoogleFonts.config.allowRuntimeFetching = previousAllowRuntimeFetching;
      }
    },
  );
}
