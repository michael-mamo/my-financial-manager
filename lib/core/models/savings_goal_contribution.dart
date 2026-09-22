enum SavingsGoalContributionType { contribution, withdrawal }

extension SavingsGoalContributionTypeDb on SavingsGoalContributionType {
  String get dbValue {
    switch (this) {
      case SavingsGoalContributionType.contribution:
        return 'contribution';
      case SavingsGoalContributionType.withdrawal:
        return 'withdrawal';
    }
  }

  static SavingsGoalContributionType fromDbValue(String value) {
    switch (value) {
      case 'withdrawal':
        return SavingsGoalContributionType.withdrawal;
      default:
        return SavingsGoalContributionType.contribution;
    }
  }
}

/// One entry in a goal's history — money moved in from, or back out to, an
/// account. Mirrors `LoanPayment`'s role for loans.
class SavingsGoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final SavingsGoalContributionType type;
  final DateTime date;
  final int accountId;
  final String? note;
  final DateTime createdAt;

  const SavingsGoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    required this.date,
    required this.accountId,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'goal_id': goalId,
      'amount': amount,
      'type': type.dbValue,
      'contribution_date': date.toIso8601String(),
      'account_id': accountId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoalContribution.fromMap(Map<String, dynamic> map) {
    return SavingsGoalContribution(
      id: map['id'] as int?,
      goalId: map['goal_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: SavingsGoalContributionTypeDb.fromDbValue(map['type'] as String),
      date: DateTime.parse(map['contribution_date'] as String),
      accountId: map['account_id'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
