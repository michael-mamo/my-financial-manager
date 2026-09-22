import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/repositories/settings_repository.dart';
import 'package:my_financial_manager/features/home/home_shell.dart';
import 'package:my_financial_manager/features/setup/setup_wizard_screen.dart';

import '../test_helpers.dart';
import 'widget_test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  group('SetupWizardScreen', () {
    testWidgets('walks language -> name -> currency -> no PIN, persists settings, opens HomeShell',
        (tester) async {
      await tester.pumpWidget(wrapAsRoot(const SetupWizardScreen()));
      await tester.pump();

      // Step 1: language. English is preselected — just move on.
      expect(find.text('Choose Language / ቋንቋ ይምረጡ'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: name.
      expect(find.text('Your Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Abebe Kebede');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: currency — pick USD instead of the ETB default.
      expect(find.text('Choose Currency'), findsOneWidget);
      await tester.tap(find.text('USD'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: security — leave PIN off and finish.
      expect(find.text('Protect Your Data'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // field only appears once toggled on
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      // Lands on the main shell.
      expect(find.byType(SetupWizardScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);

      // And it actually persisted, not just navigated.
      final settings = await SettingsRepository().getOrCreate();
      expect(settings.name, 'Abebe Kebede');
      expect(settings.currency, 'USD');
      expect(settings.language, 'en');
      expect(settings.onboardingComplete, isTrue);
      expect(settings.hasPin, isFalse);
    });

    testWidgets('setting a PIN hashes it and unlocks the current session', (tester) async {
      await tester.pumpWidget(wrapAsRoot(const SetupWizardScreen()));
      await tester.pump();

      await tester.tap(find.text('Continue')); // language
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue')); // name (left blank)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue')); // currency (ETB default)
      await tester.pumpAndSettle();

      // Security step: turn the PIN switch on, the field should appear.
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.textContaining('no password recovery'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      expect(find.byType(HomeShell), findsOneWidget);

      final repo = SettingsRepository();
      final settings = await repo.getOrCreate();
      expect(settings.hasPin, isTrue);
      expect(repo.verifyPin(settings, '1234'), isTrue);
      expect(repo.verifyPin(settings, '0000'), isFalse);
    });

    testWidgets('an unfinished PIN (under 4 digits) is not saved', (tester) async {
      await tester.pumpWidget(wrapAsRoot(const SetupWizardScreen()));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12'); // too short
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      final settings = await SettingsRepository().getOrCreate();
      expect(settings.onboardingComplete, isTrue);
      expect(settings.hasPin, isFalse);
    });
  });
}
