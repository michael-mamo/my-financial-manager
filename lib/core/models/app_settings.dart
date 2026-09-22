class AppSettings {
  final int? id;
  final String? name;
  final String language;
  final String currency;
  final String? pinHash;
  final bool biometricEnabled;
  final String? backupReminderFrequency; // 'weekly' | 'monthly' | null (off)
  final bool onboardingComplete;
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool useEthiopianCalendar;
  final bool hideBalances;
  final DateTime createdAt;

  const AppSettings({
    this.id,
    this.name,
    required this.language,
    required this.currency,
    this.pinHash,
    this.biometricEnabled = false,
    this.backupReminderFrequency,
    this.onboardingComplete = false,
    this.themeMode = 'system',
    this.useEthiopianCalendar = false,
    this.hideBalances = false,
    required this.createdAt,
  });

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  AppSettings copyWith({
    String? name,
    String? language,
    String? currency,
    String? pinHash,
    bool? clearPin,
    bool? biometricEnabled,
    String? backupReminderFrequency,
    bool? clearBackupReminder,
    bool? onboardingComplete,
    String? themeMode,
    bool? useEthiopianCalendar,
    bool? hideBalances,
  }) {
    return AppSettings(
      id: id,
      name: name ?? this.name,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      pinHash: clearPin == true ? null : (pinHash ?? this.pinHash),
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      backupReminderFrequency: clearBackupReminder == true
          ? null
          : (backupReminderFrequency ?? this.backupReminderFrequency),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      useEthiopianCalendar: useEthiopianCalendar ?? this.useEthiopianCalendar,
      hideBalances: hideBalances ?? this.hideBalances,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'language': language,
      'currency': currency,
      'pin_hash': pinHash,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'backup_reminder_frequency': backupReminderFrequency,
      'onboarding_complete': onboardingComplete ? 1 : 0,
      'theme_mode': themeMode,
      'use_ethiopian_calendar': useEthiopianCalendar ? 1 : 0,
      'hide_balances': hideBalances ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] as int?,
      name: map['name'] as String?,
      language: map['language'] as String? ?? 'en',
      currency: map['currency'] as String? ?? 'ETB',
      pinHash: map['pin_hash'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int? ?? 0) == 1,
      backupReminderFrequency: map['backup_reminder_frequency'] as String?,
      onboardingComplete: (map['onboarding_complete'] as int? ?? 0) == 1,
      themeMode: map['theme_mode'] as String? ?? 'system',
      useEthiopianCalendar: (map['use_ethiopian_calendar'] as int? ?? 0) == 1,
      hideBalances: (map['hide_balances'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
