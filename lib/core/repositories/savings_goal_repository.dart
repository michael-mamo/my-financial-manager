import '../database/database_helper.dart';
import '../models/savings_goal.dart';
import '../models/savings_goal_contribution.dart';
import '../models/transaction.dart' as txn_model;

/// Savings goals (Phase 11) plus the same account-linkage rule loans follow
/// (Spec Addendum #1): every contribution and withdrawal moves real money
/// through an account and is atomic with the goal's own running total.
class SavingsGoalRepository {
  final DatabaseHelper _dbHelper;
  SavingsGoalRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// A new goal starts at 0 saved — creating it doesn't move any money;
  /// the first contribution does that.
  Future<int> create(SavingsGoal goal) async {
    final db = await _dbHelper.database;
    return db.insert('savings_goals', goal.toMap());
  }

  Future<void> update(SavingsGoal goal) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must be saved before it can be updated.');
    }
    final db = await _dbHelper.database;
    await db.update('savings_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<List<SavingsGoal>> getAll({SavingsGoalStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'savings_goals',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.dbValue] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<SavingsGoal?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
  }

  Future<List<SavingsGoalContribution>> contributionsForGoal(int goalId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'savings_goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'contribution_date DESC',
    );
    return rows.map(SavingsGoalContribution.fromMap).toList();
  }

  /// Moves [amount] from [accountId] into the goal: the account balance
  /// decreases, the goal's `current_amount` increases, and the goal flips
  /// to completed once it reaches (or, on an overshoot, passes) its target
  /// — all in one DB transaction (Section 34 integrity), the same pattern
  /// `LoanRepository.addPayment` uses.
  Future<void> contribute({
    required SavingsGoal goal,
    required double amount,
    required DateTime date,
    required int accountId,
    String? note,
  }) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must be saved before recording a contribution.');
    }
    if (amount <= 0) {
      throw ArgumentError('Contribution amount must be greater than zero.');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final newCurrent = goal.currentAmount + amount;
    final newStatus =
        newCurrent >= goal.targetAmount ? SavingsGoalStatus.completed : SavingsGoalStatus.active;

    await db.transaction((tx) async {
      await tx.insert('savings_goal_contributions', SavingsGoalContribution(
        goalId: goal.id!,
        amount: amount,
        type: SavingsGoalContributionType.contribution,
        date: date,
        accountId: accountId,
        note: note,
        createdAt: now,
      ).toMap());

      await tx.update(
        'savings_goals',
        {'current_amount': newCurrent, 'status': newStatus.dbValue},
        where: 'id = ?',
        whereArgs: [goal.id],
      );

      await tx.insert('transactions', txn_model.Transaction(
        accountId: accountId,
        type: txn_model.TransactionType.savingsContributionOut,
        amount: amount,
        date: date,
        description: note,
        relatedGoalId: goal.id,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?',
        [amount, accountId],
      );
    });
  }

  /// Moves [amount] back out of the goal into [accountId]: the account
  /// balance increases, the goal's `current_amount` decreases, and a goal
  /// that was completed reopens as active if the withdrawal drops it back
  /// below its target. Mirrors [contribute], and — like
  /// `LoanRepository.addPayment`'s overpayment guard — refuses to withdraw
  /// more than the goal actually holds.
  Future<void> withdraw({
    required SavingsGoal goal,
    required double amount,
    required DateTime date,
    required int accountId,
    String? note,
  }) async {
    if (goal.id == null) {
      throw ArgumentError('Goal must be saved before recording a withdrawal.');
    }
    if (amount <= 0) {
      throw ArgumentError('Withdrawal amount must be greater than zero.');
    }
    if (amount > goal.currentAmount) {
      throw ArgumentError('Withdrawal exceeds the amount saved toward this goal.');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final newCurrent = goal.currentAmount - amount;
    final newStatus =
        newCurrent >= goal.targetAmount ? SavingsGoalStatus.completed : SavingsGoalStatus.active;

    await db.transaction((tx) async {
      await tx.insert('savings_goal_contributions', SavingsGoalContribution(
        goalId: goal.id!,
        amount: amount,
        type: SavingsGoalContributionType.withdrawal,
        date: date,
        accountId: accountId,
        note: note,
        createdAt: now,
      ).toMap());

      await tx.update(
        'savings_goals',
        {'current_amount': newCurrent < 0 ? 0 : newCurrent, 'status': newStatus.dbValue},
        where: 'id = ?',
        whereArgs: [goal.id],
      );

      await tx.insert('transactions', txn_model.Transaction(
        accountId: accountId,
        type: txn_model.TransactionType.savingsWithdrawalIn,
        amount: amount,
        date: date,
        description: note,
        relatedGoalId: goal.id,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [amount, accountId],
      );
    });
  }
}
