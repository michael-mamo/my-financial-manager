import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/loan.dart';
import '../models/payment_method.dart';
import '../models/person.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/savings_goal_contribution.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/backup_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/export_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/person_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import '../repositories/savings_goal_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/transaction_repository.dart';

final accountRepositoryProvider = Provider((ref) => AccountRepository());
final categoryRepositoryProvider = Provider((ref) => CategoryRepository());
final paymentMethodRepositoryProvider = Provider((ref) => PaymentMethodRepository());
final transactionRepositoryProvider = Provider((ref) => TransactionRepository());
final loanRepositoryProvider = Provider((ref) => LoanRepository());
final personRepositoryProvider = Provider((ref) => PersonRepository());
final recurringTransactionRepositoryProvider = Provider((ref) => RecurringTransactionRepository());
final budgetRepositoryProvider = Provider((ref) => BudgetRepository());
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());
final backupRepositoryProvider = Provider((ref) => BackupRepository());
final exportRepositoryProvider = Provider((ref) => ExportRepository());
final savingsGoalRepositoryProvider = Provider((ref) => SavingsGoalRepository());

/// App locale — hydrated from persisted settings by [bootstrapProvider],
/// changeable live from Settings.
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

/// Selected currency code — one per install for Phase 1/2 (Addendum #6).
final currencyProvider = StateProvider<String>((ref) => 'ETB');

/// Whether the app has been unlocked for this session (PIN entered).
/// Irrelevant when the persisted settings have no PIN set.
final sessionUnlockedProvider = StateProvider<bool>((ref) => false);

/// Manual theme override — hydrated from persisted settings; 'system'
/// follows the OS, otherwise 'light'/'dark' pins it (Section 30).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Addendum #10: display-only Ethiopian calendar toggle. Storage and date
/// pickers stay Gregorian; this only changes how dates are shown.
final ethiopianCalendarProvider = StateProvider<bool>((ref) => false);

/// Dashboard privacy toggle: masks the total and every account balance
/// when true, for glancing at the app in public. Persisted like the
/// Ethiopian-calendar toggle, hydrated by [bootstrapProvider].
final hideBalancesProvider = StateProvider<bool>((ref) => false);

/// Runs once per app launch: loads persisted settings (Section 5/30),
/// hydrates locale/currency/theme, and runs the recurring-transaction
/// catch-up (Section 23, Addendum #7) before the UI decides what to show.
final bootstrapProvider = FutureProvider<AppSettings>((ref) async {
  final settings = await ref.read(settingsRepositoryProvider).getOrCreate();
  ref.read(localeProvider.notifier).state = Locale(settings.language);
  ref.read(currencyProvider.notifier).state = settings.currency;
  ref.read(themeModeProvider.notifier).state = _themeModeFromString(settings.themeMode);
  ref.read(ethiopianCalendarProvider.notifier).state = settings.useEthiopianCalendar;
  ref.read(hideBalancesProvider.notifier).state = settings.hideBalances;
  if (settings.onboardingComplete) {
    await ref.read(recurringTransactionRepositoryProvider).runCatchUp();
  }
  return settings;
});

ThemeMode _themeModeFromString(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  return ref.watch(accountRepositoryProvider).getAll();
});

final totalBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  return ref.watch(accountRepositoryProvider).totalBalance();
});

final incomeCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getByType(CategoryType.income);
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getByType(CategoryType.expense);
});

final recentTransactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  return ref.watch(transactionRepositoryProvider).recent(limit: 10);
});

/// This-month income/expense totals, for the dashboard summary (Section 6).
final monthTotalsProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return ref.watch(transactionRepositoryProvider).incomeExpenseTotals(start: start, end: end);
});

final peopleProvider = FutureProvider.autoDispose<List<Person>>((ref) async {
  return ref.watch(personRepositoryProvider).getAll();
});

/// Section 27: people with at least one loan, and their net position.
final peopleWithLoanTotalsProvider = FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
  return ref.watch(personRepositoryProvider).peopleWithLoanTotals();
});

final loansProvider = FutureProvider.autoDispose.family<List<Loan>, LoanType?>((ref, type) async {
  return ref.watch(loanRepositoryProvider).getAll(type: type);
});

/// Section 16 loan dashboard: youOwe, othersOweYou, overdueCount, paymentsThisMonth.
final loanDashboardTotalsProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  return ref.watch(loanRepositoryProvider).dashboardTotals();
});

/// Section 20 Loan Report: status counts + lifetime borrowed/lent/payments totals.
final loanReportSummaryProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  return ref.watch(loanRepositoryProvider).reportSummary();
});

final loansByStatusProvider = FutureProvider.autoDispose.family<List<Loan>, LoanStatus>((ref, status) async {
  return ref.watch(loanRepositoryProvider).getByStatus(status);
});

/// Looks up a person's display name by id for loan list/detail rendering.
final personNameProvider = FutureProvider.autoDispose.family<String, int>((ref, personId) async {
  final person = await ref.watch(personRepositoryProvider).getById(personId);
  return person?.name ?? '—';
});

/// Looks up an account's display name by id.
final accountNameProvider = FutureProvider.autoDispose.family<String, int>((ref, accountId) async {
  final account = await ref.watch(accountRepositoryProvider).getById(accountId);
  return account?.name ?? '—';
});

final recurringTransactionsProvider = FutureProvider.autoDispose<List<RecurringTransaction>>((ref) async {
  return ref.watch(recurringTransactionRepositoryProvider).getAll();
});

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((ref) async {
  return ref.watch(paymentMethodRepositoryProvider).getAll();
});/// (month, year) budget progress for Section 22.
final budgetProgressProvider = FutureProvider.autoDispose.family<List<BudgetProgress>, ({int month, int year})>(
  (ref, period) async {
    return ref.watch(budgetRepositoryProvider).progressForMonth(month: period.month, year: period.year);
  },
);

/// Phase 11 savings goals list, optionally filtered by status (null = all).
final savingsGoalsProvider = FutureProvider.autoDispose.family<List<SavingsGoal>, SavingsGoalStatus?>(
  (ref, status) async {
    return ref.watch(savingsGoalRepositoryProvider).getAll(status: status);
  },
);

/// A single goal by id, split out (same reasoning as `_loanDetailProvider`
/// in loan_detail_screen.dart) so that recording a contribution/withdrawal
/// can invalidate *this* alongside the contributions list — otherwise the
/// detail screen's own `currentAmount`/`status` would keep showing the
/// pre-contribution snapshot even after the history list refreshed.
final savingsGoalByIdProvider = FutureProvider.autoDispose.family<SavingsGoal?, int>((ref, goalId) async {
  return ref.watch(savingsGoalRepositoryProvider).getById(goalId);
});

final savingsGoalContributionsProvider = FutureProvider.autoDispose.family<List<SavingsGoalContribution>, int>(
  (ref, goalId) async {
    return ref.watch(savingsGoalRepositoryProvider).contributionsForGoal(goalId);
  },
);
