class Budget {
  final int? id;
  final int categoryId;
  final double amount;
  final int month; // 1-12
  final int year;

  const Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }
}

class BudgetProgress {
  final Budget budget;
  final String categoryName;
  final double spent;

  const BudgetProgress({required this.budget, required this.categoryName, required this.spent});

  double get remaining => budget.amount - spent;
  double get fraction => budget.amount <= 0 ? 0 : (spent / budget.amount).clamp(0, 999);
  bool get isOverBudget => spent > budget.amount;
  bool get isNearLimit => !isOverBudget && fraction >= 0.8;
}
