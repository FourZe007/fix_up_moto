import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's light/dark choice — [ThemeMode.system] until the member picks one.
///
/// App-scoped like [SelectedWorkshopCubit]: register as a lazy singleton and
/// provide with `BlocProvider.value` at the app root, since `MaterialApp`
/// itself reads it. The choice is saved so it survives a restart.
class ThemeCubit extends Cubit<ThemeMode> {
  static const String storageKey = 'theme_mode';

  final SharedPreferences _prefs;

  ThemeCubit(this._prefs) : super(_read(_prefs));

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    await _prefs.setString(storageKey, mode.name);
  }

  // Anything missing or unrecognised means "never chosen" → follow the device,
  // which is also what the app did before this setting existed.
  static ThemeMode _read(SharedPreferences prefs) {
    final saved = prefs.getString(storageKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }
}
