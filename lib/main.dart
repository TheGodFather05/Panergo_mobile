import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/network/api_client.dart';
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

  // A build with no backend address cannot do anything at all. Say so on the
  // first screen rather than letting every request fail behind a spinner, which
  // is indistinguishable from a server being down.
  if (!ApiConfig.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  runApp(const ProviderScope(child: PanergoApp()));
}

/// Shown when the binary was built without PANERGO_API_BASE_URL.
///
/// Deliberately plain and in English: this is a build mistake, seen by whoever
/// made it, never by someone in Douala.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: PanergoColors.page,
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('No backend configured',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
              SizedBox(height: 10),
              Text(
                'This build carries no PANERGO_API_BASE_URL, so every request '
                'would fail.\n\nBuild with scripts/dev_run.sh, which resolves '
                'this Mac\u2019s address and passes it in.',
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: PanergoColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      // Tapping away from a field puts the keyboard away, everywhere.
      //
      // In `builder` rather than on each screen: it wraps pushed routes and
      // sheets too, and a rule applied per screen is one that gets forgotten
      // on the next screen somebody adds a field to.
      builder: (context, child) => Listener(
        // Listener, not GestureDetector: a tap on a button is claimed by that
        // button, and a gesture detector above it never fires. Listener sees
        // the pointer either way, so the keyboard goes whether the tap landed
        // on blank page or on a control — and the control still gets it.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          final focus = FocusManager.instance.primaryFocus;
          // Only when something is actually focused, so an ordinary tap on a
          // screen with no field does no work at all.
          if (focus != null && focus.hasPrimaryFocus) focus.unfocus();
        },
        child: child,
      ),
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
