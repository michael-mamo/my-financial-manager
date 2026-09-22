import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/savings_goal.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/savings_goal_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late SavingsGoalRepository goalRepo;
  late AccountRepository accountRepo;
  late int cashAccountId;

  setUp(() async {
    goalRepo = SavingsGoalRepository();
    accountRepo = AccountRepository();
    cashAccountId = (await accountRepo.getAll()).first.id!;
    // Give the seeded Cash account a starting balance so decreasing it on
    // a contribution has somewhere to come from.
    await accountRepo.update((await accountRepo.getById(cashAccountId))!.copyWith(currentBalance: 50000));
  });

  group('SavingsGoalRepository — creation', () {
    test('a new goal starts at zero saved, active, without moving any money', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'New Laptop',
        targetAmount: 30000,
        accountId: cashAccountId,
        createdAt: DateTime.now(),
      ));

      final saved = await goalRepo.getById(id);
      expect(saved!.currentAmount, 0);
      expect(saved.status, SavingsGoalStatus.active);
      expect(await accountRepo.totalBalance(), 50000); // unchanged
    });
  });

  group('SavingsGoalRepository — Addendum #1 pattern applied to goals', () {
    test('a contribution decreases the account and increases current_amount', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Emergency Fund', targetAmount: 20000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      final goal = (await goalRepo.getById(id))!;

      await goalRepo.contribute(
        goal: goal, amount: 5000, date: DateTime(2026, 1, 1), accountId: cashAccountId,
      );

      final updated = (await goalRepo.getById(id))!;
      expect(updated.currentAmount, 5000);
      expect(updated.status, SavingsGoalStatus.active);
      expect(await accountRepo.totalBalance(), 45000);

      final txns = await TransactionRepository().recent();
      expect(txns, hasLength(1));
      expect(txns.first.relatedGoalId, id);
    });

    test('a contribution that reaches the target flips the goal to completed', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Vacation', targetAmount: 10000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      final goal = (await goalRepo.getById(id))!;

      await goalRepo.contribute(goal: goal, amount: 10000, date: DateTime(2026, 1, 1), accountId: cashAccountId);

      final updated = (await goalRepo.getById(id))!;
      expect(updated.currentAmount, 10000);
      expect(updated.status, SavingsGoalStatus.completed);
      expect(updated.progress, 1.0);
    });

    test('multiple contributions accumulate toward the target', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Phone', targetAmount: 9000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));

      for (final amount in [3000.0, 3000.0, 3000.0]) {
        final current = (await goalRepo.getById(id))!;
        await goalRepo.contribute(goal: current, amount: amount, date: DateTime(2026, 1, 1), accountId: cashAccountId);
      }

      final finalGoal = (await goalRepo.getById(id))!;
      expect(finalGoal.currentAmount, 9000);
      expect(finalGoal.status, SavingsGoalStatus.completed);

      final history = await goalRepo.contributionsForGoal(id);
      expect(history, hasLength(3));
    });

    test('a withdrawal increases the account and decreases current_amount', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Rainy Day', targetAmount: 8000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      var goal = (await goalRepo.getById(id))!;
      await goalRepo.contribute(goal: goal, amount: 5000, date: DateTime(2026, 1, 1), accountId: cashAccountId);
      goal = (await goalRepo.getById(id))!;

      await goalRepo.withdraw(goal: goal, amount: 2000, date: DateTime(2026, 1, 15), accountId: cashAccountId);

      final updated = (await goalRepo.getById(id))!;
      expect(updated.currentAmount, 3000);
      // 50000 - 5000 (contribution) + 2000 (withdrawal) = 47000
      expect(await accountRepo.totalBalance(), 47000);
    });

    test('withdrawing everything reopens a completed goal as active if under-target', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Gadget', targetAmount: 5000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      var goal = (await goalRepo.getById(id))!;
      await goalRepo.contribute(goal: goal, amount: 5000, date: DateTime(2026, 1, 1), accountId: cashAccountId);
      goal = (await goalRepo.getById(id))!;
      expect(goal.status, SavingsGoalStatus.completed);

      await goalRepo.withdraw(goal: goal, amount: 1000, date: DateTime(2026, 2, 1), accountId: cashAccountId);

      final updated = (await goalRepo.getById(id))!;
      expect(updated.currentAmount, 4000);
      expect(updated.status, SavingsGoalStatus.active);
    });

    test('a withdrawal larger than what is saved is rejected (Section 34)', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Books', targetAmount: 2000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      var goal = (await goalRepo.getById(id))!;
      await goalRepo.contribute(goal: goal, amount: 500, date: DateTime(2026, 1, 1), accountId: cashAccountId);
      goal = (await goalRepo.getById(id))!;

      expect(
        goalRepo.withdraw(goal: goal, amount: 1000, date: DateTime(2026, 1, 2), accountId: cashAccountId),
        throwsArgumentError,
      );
    });

    test('a zero or negative contribution is rejected', () async {
      final id = await goalRepo.create(SavingsGoal(
        name: 'Misc', targetAmount: 1000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      final goal = (await goalRepo.getById(id))!;

      expect(
        goalRepo.contribute(goal: goal, amount: 0, date: DateTime(2026, 1, 1), accountId: cashAccountId),
        throwsArgumentError,
      );
    });
  });

  group('SavingsGoalRepository — listing', () {
    test('getAll(status: active) excludes completed goals', () async {
      final activeId = await goalRepo.create(SavingsGoal(
        name: 'Still Saving', targetAmount: 10000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      final completedId = await goalRepo.create(SavingsGoal(
        name: 'Done', targetAmount: 1000, accountId: cashAccountId, createdAt: DateTime.now(),
      ));
      final completedGoal = (await goalRepo.getById(completedId))!;
      await goalRepo.contribute(goal: completedGoal, amount: 1000, date: DateTime(2026, 1, 1), accountId: cashAccountId);

      final active = await goalRepo.getAll(status: SavingsGoalStatus.active);
      expect(active.map((g) => g.id), contains(activeId));
      expect(active.map((g) => g.id), isNot(contains(completedId)));
    });
  });
}
