import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/l10n/app_localizations.dart';

// As of Phase 9, screens DO call `AppLocalizations.of(context)!` — every
// English arb value was written to match the string it's replacing
// character-for-character, so with `locale: Locale('en')` set below,
// every existing `find.text('...')` assertion elsewhere in this test
// suite keeps matching the same literal text it always did. Without a
// registered `AppLocalizations.delegate`, `AppLocalizations.of(context)`
// returns null and the `!` on it throws — so this delegate list isn't
// optional scaffolding, it's required for any of these screens to build
// at all now.
const _localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
const _supportedLocales = [Locale('en'), Locale('am')];

/// Wraps [child] as the *root* route of its own [MaterialApp] +
/// [ProviderScope]. Use this for screens the test drives from a cold
/// start (setup wizard, security step) where there's nothing to pop back
/// to and nothing should try to.
Widget wrapAsRoot(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
      locale: const Locale('en'),
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationsDelegates,
    ),
  );
}

/// Wraps [child] behind a placeholder first route with a single "open"
/// button that pushes it. Use this for any screen the real app only ever
/// reaches via `Navigator.push` (add income/expense, add loan, loan
/// detail's payment sheet) — those screens call `Navigator.pop()` on
/// save/cancel, which is a no-op (and a red flag if it silently does
/// nothing) unless there's a route underneath to return to.
///
/// Call [openPushedScreen] after pumping this to actually navigate in.
Widget wrapPushable(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => child),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> openPushedScreen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await pumpUntilSettled(tester);
}

/// Screens under test load their data through `FutureProvider`s and show
/// an indeterminate [CircularProgressIndicator] or [LinearProgressIndicator]
/// while a query is in flight. `tester.pumpAndSettle()` waits for
/// animations to fully stop — which an indeterminate indicator never does
/// on its own — so it can spin until it times out even though the
/// underlying (real, in-memory, sub-millisecond) sqlite call has long
/// since finished.
///
/// This instead advances the clock a fixed number of times. That's enough
/// for every provider in this app to resolve and for page-transition /
/// bottom-sheet animations to finish, without the risk of hanging on a
/// spinner that's simply still on screen for a frame or two.
Future<void> pumpUntilSettled(WidgetTester tester, {int times = 20}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
