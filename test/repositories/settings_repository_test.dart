import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/repositories/settings_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late SettingsRepository repo;
  setUp(() => repo = SettingsRepository());

  group('SettingsRepository', () {
    test('getOrCreate() creates exactly one row and returns the same row on repeat calls', () async {
      final first = await repo.getOrCreate();
      final second = await repo.getOrCreate();
      expect(first.id, second.id);
      expect(first.language, 'en');
      expect(first.currency, 'ETB');
      expect(first.onboardingComplete, isFalse);
    });

    test('setPin() stores a hash, never the plaintext PIN', () async {
      final settings = await repo.getOrCreate();
      final updated = await repo.setPin(settings, '1234');

      expect(updated.hasPin, isTrue);
      expect(updated.pinHash, isNot('1234'));
      expect(updated.pinHash, repo.hashPin('1234'));
    });

    test('verifyPin() returns true only for the correct PIN', () async {
      final settings = await repo.getOrCreate();
      final withPin = await repo.setPin(settings, '4321');

      expect(repo.verifyPin(withPin, '4321'), isTrue);
      expect(repo.verifyPin(withPin, '0000'), isFalse);
    });

    test('verifyPin() is false when no PIN has been set (Addendum #4 has no bypass)', () async {
      final settings = await repo.getOrCreate();
      expect(repo.verifyPin(settings, ''), isFalse);
      expect(repo.verifyPin(settings, '1234'), isFalse);
    });

    test('clearPin() removes the PIN and turns off biometric unlock with it', () async {
      final settings = await repo.getOrCreate();
      final withPin = await repo.setPin(settings, '1234');
      final biometricOn = await repo.save(withPin.copyWith(biometricEnabled: true));

      final cleared = await repo.clearPin(biometricOn);
      expect(cleared.hasPin, isFalse);
      expect(cleared.biometricEnabled, isFalse);
    });

    test('save() persists changes that getOrCreate() reflects afterward', () async {
      final settings = await repo.getOrCreate();
      await repo.save(settings.copyWith(currency: 'USD', name: 'Michael'));

      final reloaded = await repo.getOrCreate();
      expect(reloaded.currency, 'USD');
      expect(reloaded.name, 'Michael');
    });

    test('hideBalances defaults to false and persists once toggled on', () async {
      final settings = await repo.getOrCreate();
      expect(settings.hideBalances, isFalse);

      await repo.save(settings.copyWith(hideBalances: true));
      final reloaded = await repo.getOrCreate();
      expect(reloaded.hideBalances, isTrue);
    });
  });
}
