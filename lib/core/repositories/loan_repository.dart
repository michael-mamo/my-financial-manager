import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/transaction.dart' as txn_model;

/// Loans (Sections 10-17) plus the addendum rules that tie them to accounts:
/// - Addendum #1: every loan action moves money through an account.
/// - Addendum #2: interest is flat, fixed at creation (see Loan.create).
/// - Addendum #3: payments reduce interest-then-principal via a single
///   `remaining_amount`, not a separate amortization schedule.
/// - Addendum #9: "Overdue" is a date-based flag, refreshed lazily on read
///   rather than a background job.
class LoanRepository {
  final DatabaseHelper _dbHelper;
  LoanRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Persists a new loan and moves the principal through the selected
  /// account in the same DB transaction (Section 34 integrity).
  Future<int> createLoan(Loan loan) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    return db.transaction<int>((tx) async {
      final loanId = await tx.insert('loans', loan.toMap());

      final isBorrowed = loan.loanType == LoanType.borrowed;
      final txnType =
          isBorrowed ? txn_model.TransactionType.loanInflow : txn_model.TransactionType.loanOutflow;
      final delta = isBorrowed ? loan.principalAmount : -loan.principalAmount;

      await tx.insert('transactions', txn_model.Transaction(
        accountId: loan.accountId,
        type: txnType,
        amount: loan.principalAmount,
        date: loan.startDate,
        description: loan.description,
        relatedLoanId: loanId,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [delta, loan.accountId],
      );

      return loanId;
    });
  }

  /// Records a payment against a loan, updates its remaining balance and
  /// status, and moves money through the selected account — all atomically.
  Future<void> addPayment({
    required Loan loan,
    required double amount,
    required DateTime paymentDate,
    required int accountId,
    String? note,
  }) async {
    if (loan.id == null) {
      throw ArgumentError('Loan must be saved before recording a payment.');
    }
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    // Section 34: don't silently allow overpayment past the outstanding balance.
    if (amount > loan.remainingAmount) {
      throw ArgumentError('Payment exceeds the outstanding balance.');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final newRemaining = loan.remainingAmount - amount;
    final newStatus = newRemaining <= 0.005 ? LoanStatus.fullyPaid : LoanStatus.partiallyPaid;

    final isBorrowed = loan.loanType == LoanType.borrowed;
    // Borrowed loan repayment: money leaves your account (loan_payment_out).
    // Lent-money repayment received: money enters your account (loan_payment_in).
    final txnType = isBorrowed
        ? txn_model.TransactionType.loanPaymentOut
        : txn_model.TransactionType.loanPaymentIn;
    final delta = isBorrowed ? -amount : amount;

    await db.transaction((tx) async {
      await tx.insert('loan_payments', {
        'loan_id': loan.id,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'account_id': accountId,
        'note': note,
        'created_at': now.toIso8601String(),
      });

      await tx.update(
        'loans',
        {
          'remaining_amount': newRemaining < 0 ? 0 : newRemaining,
          'status': _statusDb(newStatus),
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      await tx.insert('transactions', txn_model.Transaction(
        accountId: accountId,
        type: txnType,
        amount: amount,
        date: paymentDate,
        description: note,
        relatedLoanId: loan.id,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await tx.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [delta, accountId],
      );
    });
  }

  /// Section 20's "Loan Report": counts by status plus lifetime totals for
  /// money borrowed, money lent, and all loan payments made/received.
  /// Distinct from [dashboardTotals], which is scoped to *outstanding*
  /// balances for the Section 16 loan dashboard.
  Future<Map<String, double>> reportSummary() async {
    await _refreshOverdueStatuses();
    final db = await _dbHelper.database;

    final statusCounts = await db.rawQuery('''
      SELECT status, COUNT(*) AS c FROM loans GROUP BY status
    ''');
    var active = 0.0, partiallyPaid = 0.0, fullyPaid = 0.0, overdue = 0.0;
    for (final row in statusCounts) {
      final c = (row['c'] as num).toDouble();
      switch (row['status']) {
        case 'active':
          active = c;
          break;
        case 'partially_paid':
          partiallyPaid = c;
          break;
        case 'fully_paid':
          fullyPaid = c;
          break;
        case 'overdue':
          overdue = c;
          break;
      }
    }

    final borrowedTotal = await db.rawQuery('''
      SELECT COALESCE(SUM(principal_amount), 0) AS total FROM loans WHERE loan_type = 'borrowed'
    ''');
    final lentTotal = await db.rawQuery('''
      SELECT COALESCE(SUM(principal_amount), 0) AS total FROM loans WHERE loan_type = 'lent'
    ''');
    final paymentsTotal = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM loan_payments
    ''');

    return {
      'activeCount': active,
      'partiallyPaidCount': partiallyPaid,
      'fullyPaidCount': fullyPaid,
      'overdueCount': overdue,
      'totalBorrowed': (borrowedTotal.first['total'] as num).toDouble(),
      'totalLent': (lentTotal.first['total'] as num).toDouble(),
      'totalPaymentsAllTime': (paymentsTotal.first['total'] as num).toDouble(),
    };
  }

  Future<List<Loan>> getByStatus(LoanStatus status) async {
    await _refreshOverdueStatuses();
    final db = await _dbHelper.database;
    final rows = await db.query(
      'loans',
      where: 'status = ?',
      whereArgs: [_statusDb(status)],
      orderBy: 'due_date ASC, start_date DESC',
    );
    return rows.map(Loan.fromMap).toList();
  }

  Future<List<Loan>> getAll({LoanType? type}) async {
    await _refreshOverdueStatuses();
    final db = await _dbHelper.database;
    final rows = await db.query(
      'loans',
      where: type != null ? 'loan_type = ?' : null,
      whereArgs: type != null ? [type.name] : null,
      orderBy: 'due_date ASC, start_date DESC',
    );
    return rows.map(Loan.fromMap).toList();
  }

  Future<Loan?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('loans', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Loan.fromMap(rows.first);
  }

  Future<List<LoanPayment>> paymentsForLoan(int loanId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'payment_date ASC',
    );
    return rows.map(LoanPayment.fromMap).toList();
  }

  /// Section 16 loan dashboard aggregates.
  Future<Map<String, double>> dashboardTotals() async {
    await _refreshOverdueStatuses();
    final db = await _dbHelper.database;

    final owe = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_amount), 0) AS total FROM loans
      WHERE loan_type = 'borrowed' AND status != 'fully_paid'
    ''');
    final owed = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_amount), 0) AS total FROM loans
      WHERE loan_type = 'lent' AND status != 'fully_paid'
    ''');
    final overdueCount = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM loans WHERE status = 'overdue'
    ''');
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final monthEnd = DateTime(now.year, now.month + 1, 1).toIso8601String();
    final paymentsThisMonth = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM loan_payments
      WHERE payment_date >= ? AND payment_date < ?
    ''', [monthStart, monthEnd]);

    return {
      'youOwe': (owe.first['total'] as num).toDouble(),
      'othersOweYou': (owed.first['total'] as num).toDouble(),
      'overdueCount': (overdueCount.first['c'] as num).toDouble(),
      'paymentsThisMonth': (paymentsThisMonth.first['total'] as num).toDouble(),
    };
  }

  /// Addendum #9: overdue is a pure date flag, refreshed lazily rather than
  /// via a background job. Never touches total_amount/interest.
  Future<void> _refreshOverdueStatuses() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String();
    await db.rawUpdate('''
      UPDATE loans SET status = 'overdue'
      WHERE due_date IS NOT NULL AND due_date < ?
        AND remaining_amount > 0
        AND status IN ('active', 'partially_paid')
    ''', [today]);
  }

  String _statusDb(LoanStatus s) {
    switch (s) {
      case LoanStatus.active:
        return 'active';
      case LoanStatus.partiallyPaid:
        return 'partially_paid';
      case LoanStatus.fullyPaid:
        return 'fully_paid';
      case LoanStatus.overdue:
        return 'overdue';
    }
  }
}
