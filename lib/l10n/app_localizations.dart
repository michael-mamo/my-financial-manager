import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Finance Manager'**
  String get appTitle;

  /// No description provided for @onboardingChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get onboardingChooseLanguage;

  /// No description provided for @onboardingEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get onboardingEnglish;

  /// No description provided for @onboardingAmharic.
  ///
  /// In en, this message translates to:
  /// **'Amharic'**
  String get onboardingAmharic;

  /// No description provided for @onboardingYourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get onboardingYourName;

  /// No description provided for @onboardingYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get onboardingYourNameHint;

  /// No description provided for @onboardingChooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose Currency'**
  String get onboardingChooseCurrency;

  /// No description provided for @onboardingSecuritySetup.
  ///
  /// In en, this message translates to:
  /// **'Protect Your Data'**
  String get onboardingSecuritySetup;

  /// No description provided for @onboardingSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. You can add a PIN or use your fingerprint/face to open the app.'**
  String get onboardingSecuritySubtitle;

  /// No description provided for @onboardingSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get onboardingSetPin;

  /// No description provided for @onboardingUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use Biometric Unlock'**
  String get onboardingUseBiometric;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingFinish;

  /// No description provided for @onboardingPinWarning.
  ///
  /// In en, this message translates to:
  /// **'There is no password recovery. If you forget your PIN, you can only regain access by restoring a backup or erasing all data.'**
  String get onboardingPinWarning;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dashboardBalance;

  /// No description provided for @dashboardThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get dashboardThisMonth;

  /// No description provided for @dashboardIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get dashboardIncome;

  /// No description provided for @dashboardExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get dashboardExpenses;

  /// No description provided for @dashboardNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get dashboardNet;

  /// No description provided for @dashboardYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You Owe'**
  String get dashboardYouOwe;

  /// No description provided for @dashboardOthersOweYou.
  ///
  /// In en, this message translates to:
  /// **'Others Owe You'**
  String get dashboardOthersOweYou;

  /// No description provided for @dashboardRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get dashboardRecentTransactions;

  /// No description provided for @dashboardNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Add your first income or expense.'**
  String get dashboardNoTransactions;

  /// No description provided for @dashboardAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get dashboardAccounts;

  /// No description provided for @dashboardNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet.'**
  String get dashboardNoAccounts;

  /// No description provided for @dashboardHideBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get dashboardHideBalances;

  /// No description provided for @dashboardShowBalances.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get dashboardShowBalances;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get accountTypeMobileMoney;

  /// No description provided for @accountTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get accountTypeOther;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get navLoans;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get actionAddIncome;

  /// No description provided for @actionAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get actionAddExpense;

  /// No description provided for @actionAddLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get actionAddLoan;

  /// No description provided for @actionAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get actionAddPayment;

  /// No description provided for @incomeAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get incomeAddTitle;

  /// No description provided for @expenseAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get expenseAddTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fieldAccount;

  /// No description provided for @fieldPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get fieldPaymentMethod;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fieldDescriptionHint;

  /// No description provided for @fieldMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get fieldMoreOptions;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @validationAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get validationAmountRequired;

  /// No description provided for @validationAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get validationAmountPositive;

  /// No description provided for @validationCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get validationCategoryRequired;

  /// No description provided for @validationAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an account'**
  String get validationAccountRequired;

  /// No description provided for @categorySalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// No description provided for @categoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// No description provided for @categoryFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get categoryFreelance;

  /// No description provided for @categoryInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryInvestment;

  /// No description provided for @categoryRentalIncome.
  ///
  /// In en, this message translates to:
  /// **'Rental Income'**
  String get categoryRentalIncome;

  /// No description provided for @categoryGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get categoryGift;

  /// No description provided for @categoryInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get categoryInterest;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryRent;

  /// No description provided for @categoryUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// No description provided for @categoryPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get categoryPhone;

  /// No description provided for @categoryInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get categoryInternet;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryMedical;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryFamily;

  /// No description provided for @categoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryClothing;

  /// No description provided for @categoryFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryFuel;

  /// No description provided for @categoryHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get categoryHouse;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get paymentMethodBank;

  /// No description provided for @paymentMethodTelebirr.
  ///
  /// In en, this message translates to:
  /// **'Telebirr'**
  String get paymentMethodTelebirr;

  /// No description provided for @paymentMethodCbeBirr.
  ///
  /// In en, this message translates to:
  /// **'CBE Birr'**
  String get paymentMethodCbeBirr;

  /// No description provided for @paymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// No description provided for @loanTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loanTitle;

  /// No description provided for @loanYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You Owe'**
  String get loanYouOwe;

  /// No description provided for @loanOthersOweYou.
  ///
  /// In en, this message translates to:
  /// **'Others Owe You'**
  String get loanOthersOweYou;

  /// No description provided for @loanStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get loanStatusActive;

  /// No description provided for @loanStatusPartiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get loanStatusPartiallyPaid;

  /// No description provided for @loanStatusFullyPaid.
  ///
  /// In en, this message translates to:
  /// **'Fully Paid'**
  String get loanStatusFullyPaid;

  /// No description provided for @loanStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get loanStatusOverdue;

  /// No description provided for @savingsGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoalsTitle;

  /// No description provided for @savingsGoalAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Goal'**
  String get savingsGoalAdd;

  /// No description provided for @savingsGoalName.
  ///
  /// In en, this message translates to:
  /// **'Goal Name'**
  String get savingsGoalName;

  /// No description provided for @savingsGoalTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target Amount'**
  String get savingsGoalTargetAmount;

  /// No description provided for @savingsGoalTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Target Date'**
  String get savingsGoalTargetDate;

  /// No description provided for @savingsGoalTargetDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get savingsGoalTargetDateOptional;

  /// No description provided for @savingsGoalNoGoals.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. Add one to start tracking progress toward something.'**
  String get savingsGoalNoGoals;

  /// No description provided for @savingsGoalSavedOf.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target} saved'**
  String savingsGoalSavedOf(String saved, String target);

  /// No description provided for @savingsGoalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get savingsGoalCompleted;

  /// No description provided for @savingsGoalStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get savingsGoalStatusActive;

  /// No description provided for @savingsGoalStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get savingsGoalStatusCompleted;

  /// No description provided for @savingsGoalContribute.
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get savingsGoalContribute;

  /// No description provided for @savingsGoalWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get savingsGoalWithdraw;

  /// No description provided for @savingsGoalHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get savingsGoalHistory;

  /// No description provided for @savingsGoalNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet.'**
  String get savingsGoalNoHistory;

  /// No description provided for @savingsGoalAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get savingsGoalAmount;

  /// No description provided for @savingsGoalNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get savingsGoalNote;

  /// No description provided for @savingsGoalNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get savingsGoalNoteHint;

  /// No description provided for @savingsGoalFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get savingsGoalFromAccount;

  /// No description provided for @savingsGoalToAccount.
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get savingsGoalToAccount;

  /// No description provided for @savingsGoalWithdrawExceeds.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal exceeds the amount saved toward this goal'**
  String get savingsGoalWithdrawExceeds;

  /// No description provided for @savingsGoalValidationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a goal name'**
  String get savingsGoalValidationNameRequired;

  /// No description provided for @savingsGoalValidationTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a target amount'**
  String get savingsGoalValidationTargetRequired;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// No description provided for @settingsPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get settingsPaymentMethods;

  /// No description provided for @settingsAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get settingsAccounts;

  /// No description provided for @settingsSavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get settingsSavingsGoals;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settingsRestore;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @confirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get confirmYes;

  /// No description provided for @confirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get confirmNo;

  /// No description provided for @emptyStateNoData.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptyStateNoData;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
