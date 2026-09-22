import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'features/home/home_shell.dart';
import 'features/security/pin_lock_screen.dart';
import 'features/setup/setup_wizard_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: PersonalFinanceApp()));
}

class PersonalFinanceApp extends ConsumerWidget {
  const PersonalFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'My Financial Manager',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      home: const _AppRoot(),
    );
  }
}

/// Decides what the user sees first: a loading splash while settings load
/// and the recurring-transaction catch-up runs (Addendum #7), the setup
/// wizard (Section 5) if onboarding hasn't finished, the PIN lock screen
/// (Addendum #4) if a PIN is set and this session hasn't unlocked yet, or
/// the main app shell.
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);

    return bootstrap.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not start the app: $e'),
        )),
      ),
      data: (settings) {
        if (!settings.onboardingComplete) return const SetupWizardScreen();

        final unlocked = ref.watch(sessionUnlockedProvider);
        if (settings.hasPin && !unlocked) {
          return PinLockScreen(
            settings: settings,
            onUnlocked: () => ref.read(sessionUnlockedProvider.notifier).state = true,
          );
        }
        return const HomeShell();
      },
    );
  }
}

// Brand-neutral palette for the app itself — this is a personal app, not
// bank-branded collateral, so it uses its own theme rather than BoA colors.
ThemeData _buildLightTheme() {
  const seed = Color(0xFF1F7A5C); // calm green, common "money positive" tone
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
    ),
  );
}

ThemeData _buildDarkTheme() {
  const seed = Color(0xFF1F7A5C);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
    ),
  );
}
