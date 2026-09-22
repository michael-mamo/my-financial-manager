import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_shell.dart';

/// Section 5: language -> name -> currency -> optional PIN, then dashboard.
class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _pageController = PageController();
  int _step = 0;

  String _languageCode = 'en';
  final _nameController = TextEditingController();
  String _currency = 'ETB';
  bool _pinEnabled = false;
  final _pinController = TextEditingController();

  static const _currencies = ['ETB', 'USD', 'EUR', 'GBP'];

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    ref.read(localeProvider.notifier).state = Locale(_languageCode);
    ref.read(currencyProvider.notifier).state = _currency;

    final settingsRepo = ref.read(settingsRepositoryProvider);
    var settings = await settingsRepo.getOrCreate();
    settings = settings.copyWith(
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      language: _languageCode,
      currency: _currency,
      onboardingComplete: true,
    );
    if (_pinEnabled && _pinController.text.length >= 4) {
      settings = settings.copyWith(pinHash: settingsRepo.hashPin(_pinController.text));
    }
    await settingsRepo.save(settings);

    // The user just set this PIN themselves in this session — don't
    // immediately turn around and demand it back on the next screen.
    ref.read(sessionUnlockedProvider.notifier).state = true;
    ref.invalidate(bootstrapProvider);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _LanguageStep(
                    selected: _languageCode,
                    onSelect: (code) {
                      setState(() => _languageCode = code);
                      // Apply immediately, not just at _finish(): otherwise
                      // every later step in this wizard keeps rendering in
                      // whatever locale was active before onboarding
                      // started (always 'en'), regardless of what was just
                      // picked here — the translated Name/Currency/Security
                      // steps would silently never show up in Amharic.
                      ref.read(localeProvider.notifier).state = Locale(code);
                    },
                    onNext: () => _goTo(1),
                  ),
                  _NameStep(
                    controller: _nameController,
                    onBack: () => _goTo(0),
                    onNext: () => _goTo(2),
                  ),
                  _CurrencyStep(
                    currencies: _currencies,
                    selected: _currency,
                    onSelect: (c) => setState(() => _currency = c),
                    onBack: () => _goTo(1),
                    onNext: () => _goTo(3),
                  ),
                  _SecurityStep(
                    pinEnabled: _pinEnabled,
                    pinController: _pinController,
                    onTogglePin: (v) => setState(() => _pinEnabled = v),
                    onBack: () => _goTo(2),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  const _LanguageStep({required this.selected, required this.onSelect, required this.onNext});

  @override
  Widget build(BuildContext context) {
    // Deliberately hardcoded, not run through AppLocalizations: at this
    // point in onboarding the locale hasn't been chosen yet, so it's still
    // sitting at its 'en' default. A language picker needs to show each
    // option in ITS OWN native script regardless of the current locale —
    // otherwise an Amharic-reading user who can't read English has no way
    // to find their own option, since "Amharic" (the English word) would
    // render instead of "አማርኛ". Every multilingual app's language picker
    // follows this same self-referential-script convention.
    return _StepScaffold(
      title: 'Choose Language / ቋንቋ ይምረጡ',
      body: Column(
        children: [
          _ChoiceCard(
            label: '🇬🇧  English',
            selected: selected == 'en',
            onTap: () => onSelect('en'),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            label: '🇪🇹  አማርኛ',
            selected: selected == 'am',
            onTap: () => onSelect('am'),
          ),
        ],
      ),
      onNext: onNext,
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _NameStep({required this.controller, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _StepScaffold(
      title: l10n.onboardingYourName,
      body: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.onboardingYourName, hintText: l10n.onboardingYourNameHint),
      ),
      onBack: onBack,
      onNext: onNext,
    );
  }
}

class _CurrencyStep extends StatelessWidget {
  final List<String> currencies;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _CurrencyStep({
    required this.currencies,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: AppLocalizations.of(context)!.onboardingChooseCurrency,
      body: Column(
        children: currencies.map((c) {
          final label = c == 'ETB' ? 'ETB — Ethiopian Birr (ብር)' : c;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceCard(label: label, selected: selected == c, onTap: () => onSelect(c)),
          );
        }).toList(),
      ),
      onBack: onBack,
      onNext: onNext,
    );
  }
}

class _SecurityStep extends StatelessWidget {
  final bool pinEnabled;
  final TextEditingController pinController;
  final ValueChanged<bool> onTogglePin;
  final VoidCallback onBack;
  final VoidCallback onFinish;
  const _SecurityStep({
    required this.pinEnabled,
    required this.pinController,
    required this.onTogglePin,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _StepScaffold(
      title: l10n.onboardingSecuritySetup,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingSecuritySubtitle),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.onboardingSetPin),
            value: pinEnabled,
            onChanged: onTogglePin,
            contentPadding: EdgeInsets.zero,
          ),
          if (pinEnabled) ...[
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              // No dedicated short arb key for a bare "PIN" field label
              // (only the longer "Set a PIN" switch-title string exists) —
              // left as a literal rather than reusing that longer phrase
              // somewhere it reads oddly (a floating field label showing
              // "Set a PIN" once the user is already typing into it).
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.onboardingPinWarning,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
      onBack: onBack,
      onNext: onFinish,
      nextLabel: l10n.onboardingFinish,
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  // Null means "use the translated default" (onboardingContinue) —
  // resolved in build() since a compile-time constant can't call
  // AppLocalizations, which needs a BuildContext.
  final String? nextLabel;
  const _StepScaffold({
    required this.title,
    required this.body,
    this.onBack,
    required this.onNext,
    this.nextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(child: SingleChildScrollView(child: body)),
          Row(
            children: [
              // No dedicated "Back" arb key exists yet — left as a literal,
              // same reasoning as the bare "PIN" field label above.
              if (onBack != null)
                TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: Text(nextLabel ?? AppLocalizations.of(context)!.onboardingContinue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primaryContainer.withOpacity(0.3) : null,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
