import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:my_financial_manager/core/models/account.dart';
import 'package:my_financial_manager/core/models/category.dart';
import 'package:my_financial_manager/core/models/transaction.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/backup_repository.dart';
import 'package:my_financial_manager/core/repositories/category_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';

import '../test_helpers.dart';

/// Fakes the documents-directory lookup that BackupRepository uses to write
/// its export file, so the test can run on a plain machine with no device —
/// this only fakes *where* files go, real file I/O still happens for real
/// in a temp folder that's cleaned up afterward.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String path;
  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  setUpDatabaseForTesting();

  late Directory tempDir;
  late BackupRepository backupRepo;
  late TransactionRepository txnRepo;
  late AccountRepository accountRepo;
  late int cashAccountId;
  late int foodCategoryId;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pfm_backup_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  setUp(() async {
    backupRepo = BackupRepository();
    txnRepo = TransactionRepository();
    accountRepo = AccountRepository();
    cashAccountId = (await accountRepo.getAll()).first.id!;
    foodCategoryId = (await CategoryRepository().getByType(CategoryType.expense))
        .firstWhere((c) => c.nameEn == 'Food')
        .id!;
  });

  group('BackupRepository — Section 24, Addendum #5/#8', () {
    test('exporting then restoring an unencrypted backup reproduces the same data', () async {
      await txnRepo.recordIncomeOrExpense(Transaction(
        accountId: cashAccountId,
        categoryId: foodCategoryId,
        type: TransactionType.expense,
        amount: 250,
        date: DateTime(2026, 6, 1),
        description: 'Lunch',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(await accountRepo.totalBalance(), -250);

      final file = await backupRepo.exportBackup();
      expect(await file.exists(), isTrue);
      expect(await backupRepo.isEncrypted(file), isFalse);

      // Mutate current data so restore has something to actually undo.
      await txnRepo.recordIncomeOrExpense(Transaction(
        accountId: cashAccountId,
        categoryId: foodCategoryId,
        type: TransactionType.expense,
        amount: 9999,
        date: DateTime(2026, 6, 2),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(await accountRepo.totalBalance(), -10249);

      await backupRepo.restoreFromFile(file);

      // Balance and transaction set are back to exactly what was backed up.
      expect(await accountRepo.totalBalance(), -250);
      final transactions = await txnRepo.page(limit: 50);
      expect(transactions, hasLength(1));
      expect(transactions.first.description, 'Lunch');
    });

    test('a password-protected backup is flagged encrypted and round-trips correctly', () async {
      await accountRepo.create(Account(
        name: 'CBE',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 3000,
        currentBalance: 3000,
        createdAt: DateTime(2026, 1, 1),
      ));
      expect(await accountRepo.totalBalance(), 3000);

      final file = await backupRepo.exportBackup(password: 'correct-horse');
      expect(await backupRepo.isEncrypted(file), isTrue);

      await backupRepo.restoreFromFile(file, password: 'correct-horse');
      expect(await accountRepo.totalBalance(), 3000);
      final accounts = await accountRepo.getAll();
      expect(accounts.map((a) => a.name), contains('CBE'));
    });

    test('restoring an encrypted backup with the wrong password throws instead of corrupting data', () async {
      final file = await backupRepo.exportBackup(password: 'right-password');

      expect(
        backupRepo.restoreFromFile(file, password: 'wrong-password'),
        throwsFormatException,
      );
    });

    test('restore is a full overwrite: data not in the backup disappears (Addendum #8)', () async {
      final file = await backupRepo.exportBackup(); // backs up just the default Cash account

      await accountRepo.create(Account(
        name: 'Telebirr',
        accountType: AccountType.mobileMoney,
        currency: 'ETB',
        openingBalance: 500,
        currentBalance: 500,
        createdAt: DateTime(2026, 1, 1),
      ));
      expect(await accountRepo.getAll(), hasLength(2));

      await backupRepo.restoreFromFile(file);

      // Telebirr didn't exist at backup time, so a full-overwrite restore
      // removes it — this is the documented behavior, not a bug.
      final accounts = await accountRepo.getAll();
      expect(accounts, hasLength(1));
      expect(accounts.first.name, 'Cash');
    });
  });
}
