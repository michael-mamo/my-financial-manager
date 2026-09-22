enum SavingsGoalStatus { active, completed }

extension SavingsGoalStatusDb on SavingsGoalStatus {
  String get dbValue {
    switch (this) {
      case SavingsGoalStatus.active:
        return 'active';
      case SavingsGoalStatus.completed:
        return 'completed';
    }
  }

  static SavingsGoalStatus fromDbValue(String value) {
    switch (value) {
      case 'completed':
        return SavingsGoalStatus.completed;
      default:
        return SavingsGoalStatus.active;
    }
  }
}

/// A savings goal with a target amount tied to an account (Phase 10's
/// suggested-next-phase #1). Contributions and withdrawals move real money
/// through [accountId], exactly like loans do (Spec Addendum #1) — this
/// model only tracks the goal itself; [SavingsGoalContribution] rows and
/// the linked `transactions` rows carry the actual money movements.
class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final int accountId;
  final DateTime? targetDate;
  final SavingsGoalStatus status;
  final DateTime createdAt;

  const SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.accountId,
    this.targetDate,
    this.status = SavingsGoalStatus.active,
    required this.createdAt,
  });

  /// 0.0–1.0, never past 100% even if a rounding edge pushes currentAmount
  /// a hair over targetAmount.
  double get progress {
    if (targetAmount <= 0) return 0;
    final fraction = currentAmount / targetAmount;
    return fraction > 1 ? 1 : (fraction < 0 ? 0 : fraction);
  }

  double get remaining {
    final r = targetAmount - currentAmount;
    return r < 0 ? 0 : r;
  }

  SavingsGoal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    int? accountId,
    DateTime? targetDate,
    bool? clearTargetDate,
    SavingsGoalStatus? status,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      accountId: accountId ?? this.accountId,
      targetDate: clearTargetDate == true ? null : (targetDate ?? this.targetDate),
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'account_id': accountId,
      'target_date': targetDate?.toIso8601String(),
      'status': status.dbValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      accountId: map['account_id'] as int,
      targetDate: map['target_date'] != null ? DateTime.parse(map['target_date'] as String) : null,
      status: SavingsGoalStatusDb.fromDbValue(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
