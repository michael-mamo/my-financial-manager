// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Personal Finance Manager';

  @override
  String get onboardingChooseLanguage => 'Choose Language';

  @override
  String get onboardingEnglish => 'English';

  @override
  String get onboardingAmharic => 'Amharic';

  @override
  String get onboardingYourName => 'Your Name';

  @override
  String get onboardingYourNameHint => 'Optional';

  @override
  String get onboardingChooseCurrency => 'Choose Currency';

  @override
  String get onboardingSecuritySetup => 'Protect Your Data';

  @override
  String get onboardingSecuritySubtitle =>
      'Optional. You can add a PIN or use your fingerprint/face to open the app.';

  @override
  String get onboardingSetPin => 'Set a PIN';

  @override
  String get onboardingUseBiometric => 'Use Biometric Unlock';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingFinish => 'Get Started';

  @override
  String get onboardingPinWarning =>
      'There is no password recovery. If you forget your PIN, you can only regain access by restoring a backup or erasing all data.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardBalance => 'Balance';

  @override
  String get dashboardThisMonth => 'This Month';

  @override
  String get dashboardIncome => 'Income';

  @override
  String get dashboardExpenses => 'Expenses';

  @override
  String get dashboardNet => 'Net';

  @override
  String get dashboardYouOwe => 'You Owe';

  @override
  String get dashboardOthersOweYou => 'Others Owe You';

  @override
  String get dashboardRecentTransactions => 'Recent Transactions';

  @override
  String get dashboardNoTransactions =>
      'No transactions yet. Add your first income or expense.';

  @override
  String get dashboardAccounts => 'Accounts';

  @override
  String get dashboardNoAccounts => 'No accounts yet.';

  @override
  String get dashboardHideBalances => 'Hide balances';

  @override
  String get dashboardShowBalances => 'Show balances';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeMobileMoney => 'Mobile Money';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navLoans => 'Loans';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionAddIncome => 'Income';

  @override
  String get actionAddExpense => 'Expense';

  @override
  String get actionAddLoan => 'Loan';

  @override
  String get actionAddPayment => 'Payment';

  @override
  String get incomeAddTitle => 'Add Income';

  @override
  String get expenseAddTitle => 'Add Expense';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldPaymentMethod => 'Payment Method';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldDescriptionHint => 'Optional';

  @override
  String get fieldMoreOptions => 'More Options';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get validationAmountRequired => 'Enter an amount';

  @override
  String get validationAmountPositive => 'Amount must be greater than zero';

  @override
  String get validationCategoryRequired => 'Select a category';

  @override
  String get validationAccountRequired => 'Select an account';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryBusiness => 'Business';

  @override
  String get categoryFreelance => 'Freelance';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryRentalIncome => 'Rental Income';

  @override
  String get categoryGift => 'Gift';

  @override
  String get categoryInterest => 'Interest';

  @override
  String get categoryOther => 'Other';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryRent => 'Rent';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get categoryPhone => 'Phone';

  @override
  String get categoryInternet => 'Internet';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryFamily => 'Family';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryFuel => 'Fuel';

  @override
  String get categoryHouse => 'House';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodBank => 'Bank';

  @override
  String get paymentMethodTelebirr => 'Telebirr';

  @override
  String get paymentMethodCbeBirr => 'CBE Birr';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get loanTitle => 'Loan';

  @override
  String get loanYouOwe => 'You Owe';

  @override
  String get loanOthersOweYou => 'Others Owe You';

  @override
  String get loanStatusActive => 'Active';

  @override
  String get loanStatusPartiallyPaid => 'Partially Paid';

  @override
  String get loanStatusFullyPaid => 'Fully Paid';

  @override
  String get loanStatusOverdue => 'Overdue';

  @override
  String get savingsGoalsTitle => 'Savings Goals';

  @override
  String get savingsGoalAdd => 'Add Goal';

  @override
  String get savingsGoalName => 'Goal Name';

  @override
  String get savingsGoalTargetAmount => 'Target Amount';

  @override
  String get savingsGoalTargetDate => 'Target Date';

  @override
  String get savingsGoalTargetDateOptional => 'Optional';

  @override
  String get savingsGoalNoGoals =>
      'No savings goals yet. Add one to start tracking progress toward something.';

  @override
  String savingsGoalSavedOf(String saved, String target) {
    return '$saved of $target saved';
  }

  @override
  String get savingsGoalCompleted => 'Goal reached!';

  @override
  String get savingsGoalStatusActive => 'Active';

  @override
  String get savingsGoalStatusCompleted => 'Completed';

  @override
  String get savingsGoalContribute => 'Add Money';

  @override
  String get savingsGoalWithdraw => 'Withdraw';

  @override
  String get savingsGoalHistory => 'History';

  @override
  String get savingsGoalNoHistory => 'No contributions yet.';

  @override
  String get savingsGoalAmount => 'Amount';

  @override
  String get savingsGoalNote => 'Note';

  @override
  String get savingsGoalNoteHint => 'Optional';

  @override
  String get savingsGoalFromAccount => 'From Account';

  @override
  String get savingsGoalToAccount => 'To Account';

  @override
  String get savingsGoalWithdrawExceeds =>
      'Withdrawal exceeds the amount saved toward this goal';

  @override
  String get savingsGoalValidationNameRequired => 'Enter a goal name';

  @override
  String get savingsGoalValidationTargetRequired => 'Enter a target amount';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsCategories => 'Categories';

  @override
  String get settingsPaymentMethods => 'Payment Methods';

  @override
  String get settingsAccounts => 'Accounts';

  @override
  String get settingsSavingsGoals => 'Savings Goals';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsRestore => 'Restore';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsImport => 'Import';

  @override
  String get settingsAbout => 'About';

  @override
  String get confirmDeleteTitle => 'Delete this?';

  @override
  String get confirmDeleteBody => 'This cannot be undone.';

  @override
  String get confirmYes => 'Yes';

  @override
  String get confirmNo => 'No';

  @override
  String get emptyStateNoData => 'Nothing here yet.';
}
