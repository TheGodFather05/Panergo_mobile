import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/complete_profile_screen.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Panergo is a French product: dates and month names are formatted fr-FR
  // everywhere, which needs the locale data loaded before first paint.
  await initializeDateFormatting('fr_FR');

  runApp(const ProviderScope(child: PanergoApp()));
}

class PanergoApp extends ConsumerWidget {
  const PanergoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(brandDirectionProvider);

    return MaterialApp(
      title: 'Panergo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(direction),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

/// Sends the user to the app or to sign-in, depending on the session.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return switch (auth) {
      AuthLoading() => const _Splash(),
      SignedOut() => const LoginScreen(),
      // Before the shell, and before the bare SignedIn arm — Dart takes the
      // first match, and an account that has not introduced itself has nothing
      // useful to show behind this.
      SignedIn(:final user) when user.needsProfileCompletion =>
        const CompleteProfileScreen(),
      SignedIn() => const AppShell(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: PanergoColors.page,
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
