class PaymentMethod {
  final int? id;
  final String nameEn;
  final String nameAm;
  final bool active;
  final bool isDefault;

  const PaymentMethod({
    this.id,
    required this.nameEn,
    required this.nameAm,
    this.active = true,
    this.isDefault = false,
  });

  String displayName(String languageCode) {
    return languageCode == 'am' ? nameAm : nameEn;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name_en': nameEn,
      'name_am': nameAm,
      'active': active ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as int?,
      nameEn: map['name_en'] as String,
      nameAm: map['name_am'] as String,
      active: (map['active'] as int) == 1,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
