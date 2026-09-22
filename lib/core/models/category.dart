enum CategoryType { income, expense }

class Category {
  final int? id;
  final String nameEn;
  final String nameAm;
  final CategoryType type;
  final String? icon;
  final bool active;
  final bool isDefault;

  const Category({
    this.id,
    required this.nameEn,
    required this.nameAm,
    required this.type,
    this.icon,
    this.active = true,
    this.isDefault = false,
  });

  /// Localized display name. Pass the current locale's language code.
  String displayName(String languageCode) {
    return languageCode == 'am' ? nameAm : nameEn;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name_en': nameEn,
      'name_am': nameAm,
      'type': type.name,
      'icon': icon,
      'active': active ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      nameEn: map['name_en'] as String,
      nameAm: map['name_am'] as String,
      type: CategoryType.values.firstWhere((e) => e.name == map['type']),
      icon: map['icon'] as String?,
      active: (map['active'] as int) == 1,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
