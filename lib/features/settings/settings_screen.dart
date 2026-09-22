import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_screen.dart';
import '../budgets/budgets_screen.dart';
import '../exports/exports_screen.dart';
import '../people/people_screen.dart';
import '../recurring/recurring_list_screen.dart';
import '../savings/savings_goals_screen.dart';
import '../security/security_settings_screen.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'payment_methods_screen.dart';

/// Section 30 settings shell. Payment Methods management and a manual
/// Light/Dark toggle remain for a later phase.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(currencyProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader('General'),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(locale.languageCode == 'am' ? 'አማርኛ' : 'English'),
            onTap: () => _pickLanguage(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: Text(l10n.settingsCurrency),
            subtitle: Text(currency),
            onTap: () => _pickCurrency(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.settingsTheme),
            subtitle: Text(_themeLabel(ref.watch(themeModeProvider))),
            onTap: () => _pickTheme(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_month_outlined),
            title: const Text('Ethiopian Calendar'),
            subtitle: const Text('Show dates in the Ethiopian calendar (display only)'),
            value: ref.watch(ethiopianCalendarProvider),
            onChanged: (v) async {
              ref.read(ethiopianCalendarProvider.notifier).state = v;
              final repo = ref.read(settingsRepositoryProvider);
              final settings = await repo.getOrCreate();
              await repo.save(settings.copyWith(useEthiopianCalendar: v));
            },
          ),
          const Divider(),
          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.settingsAccounts),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.settingsCategories),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('People'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PeopleScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.payment_outlined),
            title: Text(l10n.settingsPaymentMethods),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
          ),
          const Divider(),
          _SectionHeader('Automation'),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: const Text('Recurring Transactions'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringListScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Budgets'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(l10n.settingsSavingsGoals),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())),
          ),
          const Divider(),
          _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('PIN & Biometric'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
          ),
          const Divider(),
          _SectionHeader('Backup'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export Reports'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportsScreen())),
          ),
          const Divider(),
          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('My Financial Manager · offline, no account required'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Follows system';
    }
  }

  void _pickTheme(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Follows system'), onTap: () => _setTheme(context, ref, ThemeMode.system, 'system')),
            ListTile(title: const Text('Light'), onTap: () => _setTheme(context, ref, ThemeMode.light, 'light')),
            ListTile(title: const Text('Dark'), onTap: () => _setTheme(context, ref, ThemeMode.dark, 'dark')),
          ],
        ),
      ),
    );
  }

  Future<void> _setTheme(BuildContext context, WidgetRef ref, ThemeMode mode, String dbValue) async {
    ref.read(themeModeProvider.notifier).state = mode;
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getOrCreate();
    await repo.save(settings.copyWith(themeMode: dbValue));
    if (context.mounted) Navigator.pop(context);
  }

  void _pickLanguage(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () async {
                ref.read(localeProvider.notifier).state = const Locale('en');
                await _persistLocale(ref, 'en');
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('አማርኛ'),
              onTap: () async {
                ref.read(localeProvider.notifier).state = const Locale('am');
                await _persistLocale(ref, 'am');
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistLocale(WidgetRef ref, String code) async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getOrCreate();
    await repo.save(settings.copyWith(language: code));
  }

  void _pickCurrency(BuildContext context, WidgetRef ref) {
    const currencies = ['ETB', 'USD', 'EUR', 'GBP'];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies
              .map((c) => ListTile(
                    title: Text(c),
                    onTap: () async {
                      ref.read(currencyProvider.notifier).state = c;
                      final repo = ref.read(settingsRepositoryProvider);
                      final settings = await repo.getOrCreate();
                      await repo.save(settings.copyWith(currency: c));
                      if (context.mounted) Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature ships in a later phase.')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
