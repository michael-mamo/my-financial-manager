import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers/app_providers.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(settingsRepositoryProvider).getOrCreate();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('PIN Lock'),
                  subtitle: Text(settings.hasPin ? 'On' : 'Off'),
                  value: settings.hasPin,
                  onChanged: (enable) => enable ? _setPin(context) : _removePin(context),
                ),
                if (settings.hasPin) ...[
                  ListTile(
                    title: const Text('Change PIN'),
                    leading: const Icon(Icons.password),
                    onTap: () => _setPin(context),
                  ),
                  SwitchListTile(
                    title: const Text('Biometric Unlock'),
                    subtitle: const Text('Use fingerprint or face unlock in addition to your PIN'),
                    value: settings.biometricEnabled,
                    onChanged: (v) => _toggleBiometric(context, v),
                  ),
                ],
                const Divider(),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'There is no password recovery. If you forget your PIN, you can only '
                    'regain access by restoring a backup or erasing all data.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _setPin(BuildContext context) async {
    final pin = await _promptPin(context, title: 'Set a PIN');
    if (pin == null || pin.length < 4) return;
    final repo = ref.read(settingsRepositoryProvider);
    final updated = await repo.setPin(_settings!, pin);
    if (mounted) setState(() => _settings = updated);
    ref.invalidate(bootstrapProvider);
  }

  Future<void> _removePin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('The app will no longer require a PIN to open.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(settingsRepositoryProvider);
    final updated = await repo.clearPin(_settings!);
    if (mounted) setState(() => _settings = updated);
    ref.invalidate(bootstrapProvider);
  }

  Future<void> _toggleBiometric(BuildContext context, bool enable) async {
    if (enable) {
      try {
        final auth = LocalAuthentication();
        final supported = await auth.isDeviceSupported();
        if (!supported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric unlock is not available on this device.')),
            );
          }
          return;
        }
        final ok = await auth.authenticate(localizedReason: 'Confirm to enable biometric unlock');
        if (!ok) return;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not set up biometric unlock on this device.')),
          );
        }
        return;
      }
    }
    final repo = ref.read(settingsRepositoryProvider);
    final updated = await repo.save(_settings!.copyWith(biometricEnabled: enable));
    if (mounted) setState(() => _settings = updated);
  }

  Future<String?> _promptPin(BuildContext context, {required String title}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN (4–6 digits)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
  }
}
