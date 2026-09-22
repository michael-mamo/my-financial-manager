enum RecurringFrequency { daily, weekly, monthly, yearly }

class RecurringTransaction {
  final int? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final int? categoryId;
  final int accountId;
  final String? description;
  final RecurringFrequency frequency;
  final DateTime nextDate;
  final bool active;

  const RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.accountId,
    this.description,
    required this.frequency,
    required this.nextDate,
    this.active = true,
  });

  RecurringTransaction copyWith({DateTime? nextDate, bool? active}) {
    return RecurringTransaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      description: description,
      frequency: frequency,
      nextDate: nextDate ?? this.nextDate,
      active: active ?? this.active,
    );
  }

  /// Advances [nextDate] by one frequency interval (Addendum #7).
  DateTime advancedDate() {
    switch (frequency) {
      case RecurringFrequency.daily:
        return nextDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return nextDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
      case RecurringFrequency.yearly:
        return DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'description': description,
      'frequency': frequency.name,
      'next_date': nextDate.toIso8601String(),
      'active': active ? 1 : 0,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int?,
      accountId: map['account_id'] as int,
      description: map['description'] as String?,
      frequency: RecurringFrequency.values.firstWhere((f) => f.name == map['frequency']),
      nextDate: DateTime.parse(map['next_date'] as String),
      active: (map['active'] as int) == 1,
    );
  }
}
