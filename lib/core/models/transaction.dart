/// Transaction types. `loan_*` types exist so every loan/account movement
/// (Spec Addendum #1) shows up in the ledger without polluting Income or
/// Expense reports, which filter to `income`/`expense` only. `savings_*`
/// types follow the exact same idea for Phase 11 savings goals: a
/// contribution/withdrawal moves real money through an account, so it must
/// be a transaction, but it isn't income or an expense either.
enum TransactionType {
  income,
  expense,
  transfer,
  loanInflow, // money borrowed -> account increases
  loanOutflow, // money lent out -> account decreases
  loanPaymentIn, // repayment received on money you lent -> account increases
  loanPaymentOut, // repayment you made on money you borrowed -> account decreases
  savingsContributionOut, // money moved into a goal -> account decreases
  savingsWithdrawalIn, // money moved back out of a goal -> account increases
}

extension TransactionTypeDb on TransactionType {
  String get dbValue {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
      case TransactionType.loanInflow:
        return 'loan_inflow';
      case TransactionType.loanOutflow:
        return 'loan_outflow';
      case TransactionType.loanPaymentIn:
        return 'loan_payment_in';
      case TransactionType.loanPaymentOut:
        return 'loan_payment_out';
      case TransactionType.savingsContributionOut:
        return 'savings_contribution_out';
      case TransactionType.savingsWithdrawalIn:
        return 'savings_withdrawal_in';
    }
  }

  /// Whether this transaction type increases (+) or decreases (-) the
  /// account balance it's posted against.
  bool get isCredit {
    switch (this) {
      case TransactionType.income:
      case TransactionType.loanInflow:
      case TransactionType.loanPaymentIn:
      case TransactionType.savingsWithdrawalIn:
        return true;
      case TransactionType.expense:
      case TransactionType.loanOutflow:
      case TransactionType.loanPaymentOut:
      case TransactionType.savingsContributionOut:
        return false;
      case TransactionType.transfer:
        return false; // sign handled specially by the transfer pair
    }
  }

  static TransactionType fromDbValue(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      case 'loan_inflow':
        return TransactionType.loanInflow;
      case 'loan_outflow':
        return TransactionType.loanOutflow;
      case 'loan_payment_in':
        return TransactionType.loanPaymentIn;
      case 'loan_payment_out':
        return TransactionType.loanPaymentOut;
      case 'savings_contribution_out':
        return TransactionType.savingsContributionOut;
      case 'savings_withdrawal_in':
        return TransactionType.savingsWithdrawalIn;
      default:
        throw ArgumentError('Unknown transaction type: $value');
    }
  }
}

class Transaction {
  final int? id;
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String? description;
  final int? paymentMethodId;
  final String? reference;
  final int? relatedLoanId;
  final int? relatedGoalId;
  final int? relatedTransferAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    this.description,
    this.paymentMethodId,
    this.reference,
    this.relatedLoanId,
    this.relatedGoalId,
    this.relatedTransferAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'type': type.dbValue,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'payment_method_id': paymentMethodId,
      'reference': reference,
      'related_loan_id': relatedLoanId,
      'related_goal_id': relatedGoalId,
      'related_transfer_account_id': relatedTransferAccountId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int?,
      type: TransactionTypeDb.fromDbValue(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String?,
      paymentMethodId: map['payment_method_id'] as int?,
      reference: map['reference'] as String?,
      relatedLoanId: map['related_loan_id'] as int?,
      relatedGoalId: map['related_goal_id'] as int?,
      relatedTransferAccountId: map['related_transfer_account_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
