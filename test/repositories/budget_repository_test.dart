import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/budget.dart';
import 'package:my_financial_manager/core/models/category.dart';
import 'package:my_financial_manager/core/models/transaction.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/budget_repository.dart';
import 'package:my_financial_manager/core/repositories/category_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late BudgetRepository budgetRepo;
  late TransactionRepository txnRepo;
  late int cashAccountId;
  late int foodCategoryId;

  setUp(() async {
    budgetRepo = BudgetRepository();
    txnRepo = TransactionRepository();
    cashAccountId = (await AccountRepository().getAll()).first.id!;
    foodCategoryId = (await CategoryRepository().getByType(CategoryType.expense))
        .firstWhere((c) => c.nameEn == 'Food')
        .id!;
  });

  Future<void> spend(double amount, DateTime date) => txnRepo.recordIncomeOrExpense(Transaction(
        accountId: cashAccountId,
        categoryId: foodCategoryId,
        type: TransactionType.expense,
        amount: amount,
        date: date,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

  group('BudgetRepository — Section 22 progress and warnings', () {
    test('spending under budget shows neither near-limit nor over-budget', () async {
      await budgetRepo.create(Budget(categoryId: foodCategoryId, amount: 5000, month: 6, year: 2026));
      await spend(1000, DateTime(2026, 6, 5));

      final progress = await budgetRepo.progressForMonth(month: 6, year: 2026);
      expect(progress, hasLength(1));
      expect(progress.first.spent, 1000);
      expect(progress.first.isOverBudget, isFalse);
      expect(progress.first.isNearLimit, isFalse);
    });

    test('spending at or above 80% of budget is flagged near-limit', () async {
      await budgetRepo.create(Budget(categoryId: foodCategoryId, amount: 1000, month: 6, year: 2026));
      await spend(850, DateTime(2026, 6, 5));

      final progress = await budgetRepo.progressForMonth(month: 6, year: 2026);
      expect(progress.first.isNearLimit, isTrue);
      expect(progress.first.isOverBudget, isFalse);
    });

    test('spending past the budget amount is flagged over-budget', () async {
      await budgetRepo.create(Budget(categoryId: foodCategoryId, amount: 1000, month: 6, year: 2026));
      await spend(1200, DateTime(2026, 6, 5));

      final progress = await budgetRepo.progressForMonth(month: 6, year: 2026);
      expect(progress.first.isOverBudget, isTrue);
      expect(progress.first.remaining, -200);
    });

    test('spending outside the budget month is not counted', () async {
      await budgetRepo.create(Budget(categoryId: foodCategoryId, amount: 1000, month: 6, year: 2026));
      await spend(500, DateTime(2026, 5, 31)); // just before the month starts
      await spend(500, DateTime(2026, 7, 1)); // just after it ends

      final progress = await budgetRepo.progressForMonth(month: 6, year: 2026);
      expect(progress.first.spent, 0);
    });
  });
}
