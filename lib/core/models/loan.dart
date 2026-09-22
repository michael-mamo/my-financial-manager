enum LoanType { borrowed, lent }

enum InterestMode { none, fixed, percentage }

enum LoanFrequency { daily, weekly, biweekly, monthly, custom }

enum LoanStatus { active, partiallyPaid, fullyPaid, overdue }

/// See Spec Addendum #2: interest is flat, calculated once at creation.
/// `total_amount = principal + interest_amount`, fixed for the loan's life.
double calculateInterestAmount({
  required double principal,
  required InterestMode mode,
  required double value,
}) {
  switch (mode) {
    case InterestMode.none:
      return 0;
    case InterestMode.fixed:
      return value;
    case InterestMode.percentage:
      return principal * (value / 100);
  }
}

class Loan {
  final int? id;
  final int personId;
  final int accountId;
  final LoanType loanType;
  final double principalAmount;
  final InterestMode interestMode;
  final double interestValue;
  final double interestAmount;
  final double totalAmount;
  final double remainingAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final double? installmentAmount;
  final LoanFrequency? frequency;
  final LoanStatus status;
  final String? description;
  final DateTime createdAt;

  const Loan({
    this.id,
    required this.personId,
    required this.accountId,
    required this.loanType,
    required this.principalAmount,
    required this.interestMode,
    required this.interestValue,
    required this.interestAmount,
    required this.totalAmount,
    required this.remainingAmount,
    required this.startDate,
    this.dueDate,
    this.installmentAmount,
    this.frequency,
    required this.status,
    this.description,
    required this.createdAt,
  });

  /// Builds a new loan with interest/totals derived per Addendum #2.
  factory Loan.create({
    required int personId,
    required int accountId,
    required LoanType loanType,
    required double principalAmount,
    InterestMode interestMode = InterestMode.none,
    double interestValue = 0,
    required DateTime startDate,
    DateTime? dueDate,
    double? installmentAmount,
    LoanFrequency? frequency,
    String? description,
  }) {
    final interestAmount = calculateInterestAmount(
      principal: principalAmount,
      mode: interestMode,
      value: interestValue,
    );
    final total = principalAmount + interestAmount;
    return Loan(
      personId: personId,
      accountId: accountId,
      loanType: loanType,
      principalAmount: principalAmount,
      interestMode: interestMode,
      interestValue: interestValue,
      interestAmount: interestAmount,
      totalAmount: total,
      remainingAmount: total,
      startDate: startDate,
      dueDate: dueDate,
      installmentAmount: installmentAmount,
      frequency: frequency,
      status: LoanStatus.active,
      description: description,
      createdAt: DateTime.now(),
    );
  }

  Loan copyWith({double? remainingAmount, LoanStatus? status}) {
    return Loan(
      id: id,
      personId: personId,
      accountId: accountId,
      loanType: loanType,
      principalAmount: principalAmount,
      interestMode: interestMode,
      interestValue: interestValue,
      interestAmount: interestAmount,
      totalAmount: totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      startDate: startDate,
      dueDate: dueDate,
      installmentAmount: installmentAmount,
      frequency: frequency,
      status: status ?? this.status,
      description: description,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'person_id': personId,
      'account_id': accountId,
      'loan_type': loanType.name,
      'principal_amount': principalAmount,
      'interest_mode': interestMode.name,
      'interest_value': interestValue,
      'interest_amount': interestAmount,
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'installment_amount': installmentAmount,
      'frequency': frequency?.name,
      'status': _statusToDb(status),
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as int?,
      personId: map['person_id'] as int,
      accountId: map['account_id'] as int,
      loanType: LoanType.values.firstWhere((e) => e.name == map['loan_type']),
      principalAmount: (map['principal_amount'] as num).toDouble(),
      interestMode:
          InterestMode.values.firstWhere((e) => e.name == map['interest_mode']),
      interestValue: (map['interest_value'] as num).toDouble(),
      interestAmount: (map['interest_amount'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      installmentAmount: (map['installment_amount'] as num?)?.toDouble(),
      frequency: map['frequency'] != null
          ? LoanFrequency.values.firstWhere((e) => e.name == map['frequency'])
          : null,
      status: _statusFromDb(map['status'] as String),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static String _statusToDb(LoanStatus s) {
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

  static LoanStatus _statusFromDb(String value) {
    switch (value) {
      case 'active':
        return LoanStatus.active;
      case 'partially_paid':
        return LoanStatus.partiallyPaid;
      case 'fully_paid':
        return LoanStatus.fullyPaid;
      case 'overdue':
        return LoanStatus.overdue;
      default:
        throw ArgumentError('Unknown loan status: $value');
    }
  }
}

class LoanPayment {
  final int? id;
  final int loanId;
  final double amount;
  final DateTime paymentDate;
  final int accountId;
  final String? note;
  final DateTime createdAt;

  const LoanPayment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.paymentDate,
    required this.accountId,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'loan_id': loanId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'account_id': accountId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LoanPayment.fromMap(Map<String, dynamic> map) {
    return LoanPayment(
      id: map['id'] as int?,
      loanId: map['loan_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      accountId: map['account_id'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
