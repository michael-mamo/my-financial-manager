import '../database/database_helper.dart';
import '../models/transaction.dart';

/// Handles the ledger. Every write that touches an account balance runs
/// inside a single `db.transaction()` so the transaction row and the
/// account balance never drift apart (Section 34: "Use database
/// transactions when updating multiple related records").
class TransactionRepository {
  final DatabaseHelper _dbHelper;
  TransactionRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Records a plain income or expense and atomically updates the account
  /// balance. [type] must be [TransactionType.income] or [TransactionType.expense].
  Future<int> recordIncomeOrExpense(Transaction txn) async {
    assert(txn.type == TransactionType.income || txn.type == TransactionType.expense);
    final db = await _dbHelper.database;

    return db.transaction<int>((tx) async {
      final id = await tx.insert('transactions', txn.toMap());
      final delta = txn.type.isCredit ? txn.amount : -txn.amount;
      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [delta, txn.accountId],
      );
      return id;
    });
  }

  /// Transfer between two of the user's own accounts (Section 29).
  /// Never counted as income or expense.
  Future<void> recordTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((tx) async {
      final outId = await tx.insert('transactions', Transaction(
        accountId: fromAccountId,
        type: TransactionType.transfer,
        amount: amount,
        date: date,
        description: description,
        relatedTransferAccountId: toAccountId,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.insert('transactions', Transaction(
        accountId: toAccountId,
        type: TransactionType.transfer,
        amount: amount,
        date: date,
        description: description,
        relatedTransferAccountId: fromAccountId,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?',
        [amount, fromAccountId],
      );
      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [amount, toAccountId],
      );

      // outId is unused beyond insertion; kept for potential future linkage
      // (e.g. displaying paired transfer rows as one entry).
      return outId;
    });
  }

  Future<List<Transaction>> recent({int limit = 10}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC', limit: limit);
    return rows.map(Transaction.fromMap).toList();
  }

  /// Paginated history (Section 35: never load everything into memory).
  Future<List<Transaction>> page({int limit = 50, int offset = 0}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> search(String query) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'description LIKE ? OR reference LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// All transactions within [start, end) — powers the Reports screen's
  /// day/week/month/year drill-down list (Section 20).
  Future<List<Transaction>> forPeriod({required DateTime start, required DateTime end}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Sum of income/expense in [start, end) — powers dashboard "This Month"
  /// (Section 6) and monthly summaries (Section 19).
  Future<Map<String, double>> incomeExpenseTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE type IN ('income', 'expense') AND date >= ? AND date < ?
      GROUP BY type
    ''', [start.toIso8601String(), end.toIso8601String()]);

    var income = 0.0;
    var expense = 0.0;
    for (final row in rows) {
      final total = (row['total'] as num).toDouble();
      if (row['type'] == 'income') income = total;
      if (row['type'] == 'expense') expense = total;
    }
    return {'income': income, 'expense': expense};
  }

  /// Income/expense totals for the last [months] calendar months (oldest
  /// first) — powers the Section 21 monthly cash-flow chart.
  Future<List<Map<String, Object?>>> monthlySeries({int months = 6}) async {
    final now = DateTime.now();
    final results = <Map<String, Object?>>[];
    for (var i = months - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 1);
      final totals = await incomeExpenseTotals(start: start, end: end);
      results.add({'month': monthDate, 'income': totals['income'], 'expense': totals['expense']});
    }
    return results;
  }

  /// Generalized version of [monthlySeries] for the Section 20 report range
  /// picker: 'daily' -> last N days, 'weekly' -> last N weeks, 'monthly' ->
  /// last N months, 'yearly' -> last N years. Each bucket's label is its
  /// own start date; the caller formats it.
  Future<List<Map<String, Object?>>> periodSeries({required String granularity, int buckets = 6}) async {
    final now = DateTime.now();
    final results = <Map<String, Object?>>[];
    for (var i = buckets - 1; i >= 0; i--) {
      late DateTime start;
      late DateTime end;
      switch (granularity) {
        case 'daily':
          start = DateTime(now.year, now.month, now.day - i);
          end = start.add(const Duration(days: 1));
          break;
        case 'weekly':
          final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
          start = DateTime(weekStart.year, weekStart.month, weekStart.day - (7 * i));
          end = start.add(const Duration(days: 7));
          break;
        case 'yearly':
          start = DateTime(now.year - i, 1, 1);
          end = DateTime(now.year - i + 1, 1, 1);
          break;
        case 'monthly':
        default:
          start = DateTime(now.year, now.month - i, 1);
          end = DateTime(now.year, now.month - i + 1, 1);
      }
      final totals = await incomeExpenseTotals(start: start, end: end);
      results.add({'periodStart': start, 'income': totals['income'], 'expense': totals['expense']});
    }
    return results;
  }

  /// Expense (or income) total per category in [start, end) — powers the
  /// Section 19 monthly category breakdown.
  Future<List<Map<String, Object?>>> categoryBreakdown({
    required DateTime start,
    required DateTime end,
    required String type, // 'income' or 'expense'
  }) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT c.name_en AS category, COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = ? AND t.date >= ? AND t.date < ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', [type, start.toIso8601String(), end.toIso8601String()]);
  }

  Future<void> delete(int id) async {
    // Fetch first so the balance reversal knows the amount/direction/account.
    final db = await _dbHelper.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final txn = Transaction.fromMap(rows.first);

    await db.transaction((tx) async {
      await tx.delete('transactions', where: 'id = ?', whereArgs: [id]);
      if (txn.type == TransactionType.income || txn.type == TransactionType.expense) {
        final reversal = txn.type.isCredit ? -txn.amount : txn.amount;
        await tx.rawUpdate(
          'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
          [reversal, txn.accountId],
        );
      }
      // Transfer/loan deletion reversal intentionally deferred to the
      // Loans phase, where it's handled alongside loan status recalculation.
    });
  }
}
