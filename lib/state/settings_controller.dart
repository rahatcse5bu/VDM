import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);
  final SharedPreferences _prefs;

  bool get onboarded => _prefs.getBool('onboarded') ?? false;

  ThemeMode get themeMode {
    final name = _prefs.getString('themeMode');
    return ThemeMode.values.firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);
  }

  /// Base URL of a Cobalt API instance (https://github.com/imputnet/cobalt).
  String get cobaltUrl => _prefs.getString('cobaltUrl') ?? '';
  String get cobaltKey => _prefs.getString('cobaltKey') ?? '';

  /// Use the free TikWM API for TikTok links.
  bool get useTikwm => _prefs.getBool('useTikwm') ?? true;

  bool get saveToGallery => _prefs.getBool('saveToGallery') ?? true;

  Future<void> completeOnboarding() => _set(() => _prefs.setBool('onboarded', true));
  Future<void> setThemeMode(ThemeMode m) => _set(() => _prefs.setString('themeMode', m.name));
  Future<void> setCobaltUrl(String v) => _set(() => _prefs.setString('cobaltUrl', v.trim()));
  Future<void> setCobaltKey(String v) => _set(() => _prefs.setString('cobaltKey', v.trim()));
  Future<void> setUseTikwm(bool v) => _set(() => _prefs.setBool('useTikwm', v));
  Future<void> setSaveToGallery(bool v) => _set(() => _prefs.setBool('saveToGallery', v));

  Future<void> _set(Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }
}

/// Selected tab of the bottom navigation.
class NavController extends ValueNotifier<int> {
  NavController() : super(0);
}
