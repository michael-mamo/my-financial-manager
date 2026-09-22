import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../dashboard/dashboard_screen.dart';
import '../loans/loan_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_list_screen.dart';

/// Section 31 primary navigation: Dashboard | Transactions | Loans | Reports
/// | Settings. IndexedStack keeps each tab's scroll position/state alive
/// when switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    TransactionListScreen(),
    LoanListScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: l10n.navDashboard),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: l10n.navTransactions),
          NavigationDestination(icon: const Icon(Icons.handshake_outlined), selectedIcon: const Icon(Icons.handshake), label: l10n.navLoans),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: l10n.navReports),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l10n.navSettings),
        ],
      ),
    );
  }
}
