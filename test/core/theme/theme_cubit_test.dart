import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/theme/theme_cubit.dart';

Future<ThemeCubit> buildCubit([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return ThemeCubit(await SharedPreferences.getInstance());
}

void main() {
  test('follows the device when nothing has been chosen yet', () async {
    final cubit = await buildCubit();

    expect(cubit.state, ThemeMode.system);
  });

  test('restores a saved choice', () async {
    final cubit = await buildCubit({ThemeCubit.storageKey: 'dark'});

    expect(cubit.state, ThemeMode.dark);
  });

  test('falls back to the device on an unrecognised saved value', () async {
    final cubit = await buildCubit({ThemeCubit.storageKey: 'purple'});

    expect(cubit.state, ThemeMode.system);
  });

  test('setMode emits the new mode and saves it for the next launch', () async {
    final cubit = await buildCubit();

    await cubit.setMode(ThemeMode.light);

    expect(cubit.state, ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeCubit.storageKey), 'light');
    expect(ThemeCubit(prefs).state, ThemeMode.light);
  });
}
