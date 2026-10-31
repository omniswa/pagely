import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/providers.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(localStoreProvider).settings;

  void apply(AppSettings Function(AppSettings current) change) {
    state = change(state);
    unawaited(ref.read(localStoreProvider).saveSettings(state));
  }
}
