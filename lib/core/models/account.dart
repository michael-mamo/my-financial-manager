enum AccountType { cash, bank, mobileMoney, other }

class Account {
  final int? id;
  final String name;
  final AccountType accountType;
  final String currency;
  final double openingBalance;
  final double currentBalance;
  final bool active;
  final DateTime createdAt;

  const Account({
    this.id,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.openingBalance,
    required this.currentBalance,
    this.active = true,
    required this.createdAt,
  });

  Account copyWith({
    int? id,
    String? name,
    AccountType? accountType,
    String? currency,
    double? openingBalance,
    double? currentBalance,
    bool? active,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'account_type': accountType.name,
      'currency': currency,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      accountType: AccountType.values.firstWhere(
        (e) => e.name == map['account_type'],
        orElse: () => AccountType.other,
      ),
      currency: map['currency'] as String,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      active: (map['active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
