import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/theme/theme_cubit.dart';
import 'package:go_router/go_router.dart';

/// App settings, reached from the Profile tab. Currently just appearance.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Both colours come from the active Theme rather than AppColors constants,
    // so this bar follows light/dark automatically when ThemeCubit changes
    // MaterialApp's themeMode — no cubit read needed here. The title and arrow
    // are coloured explicitly because the app's AppBarTheme hard-codes a white
    // title style.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TextStyle(color: onSurface, fontSize: 20),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        // Same colour as the page behind it, so the bar blends into the body.
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(foregroundColor: onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          final followingDevice = mode == ThemeMode.system;

          // Read from the theme actually on screen, so the dark switch shows
          // the truth even while the device (not the member) is deciding.
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cubit = context.read<ThemeCubit>();

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Appearance'),
              ),
              // SwitchListTile(
              //   title: const Text('Follow device setting'),
              //   subtitle: const Text('Match your phone\'s light or dark mode'),
              //   value: followingDevice,
              //   // Turning this off pins the mode that is showing right now, so
              //   // the screen doesn't change until the member flips Dark mode.
              //   onChanged: (follow) => cubit.setMode(
              //     follow
              //         ? ThemeMode.system
              //         : (isDark ? ThemeMode.dark : ThemeMode.light),
              //   ),
              // ),
              SwitchListTile(
                title: const Text('Dark mode'),
                value: isDark,
                // Null disables the switch: the device decides while following it.
                onChanged: followingDevice
                    ? null
                    : (dark) => cubit.setMode(
                        dark ? ThemeMode.dark : ThemeMode.light,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
