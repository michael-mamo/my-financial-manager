import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/database/database_helper.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/app_providers.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  final AppSettings settings;
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.settings, required this.onUnlocked});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _entered = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.settings.biometricEnabled) {
      // Fire-and-forget: if it succeeds, unlock; if not, the user just
      // falls through to PIN entry, which is always available regardless.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) return;
      final ok = await auth.authenticate(
        localizedReason: 'Unlock My Financial Manager',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (ok) widget.onUnlocked();
    } catch (_) {
      // Biometric hardware/config issue — silently fall back to PIN.
    }
  }

  void _onDigit(String d) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length >= 4) _tryVerify();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _tryVerify() {
    final ok = ref.read(settingsRepositoryProvider).verifyPin(widget.settings, _entered);
    if (ok) {
      widget.onUnlocked();
    } else if (_entered.length >= 6) {
      setState(() {
        _error = 'Incorrect PIN';
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              Text('Enter PIN', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.red))
                    : null,
              ),
              const Spacer(),
              _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _openForgotPin(context),
                child: const Text('Forgot PIN?'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForgotPin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'There is no password recovery. Choose one of the options below.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore from a backup file'),
              subtitle: const Text('You\'ll set a new PIN as part of restoring.'),
              onTap: () {
                Navigator.pop(context);
                _restoreFromBackup(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Erase all data', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently deletes everything and starts fresh.'),
              onTap: () {
                Navigator.pop(context);
                _confirmErase(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    if (!mounted) return;
    final encrypted = await ref.read(backupRepositoryProvider).isEncrypted(file);
    String? password;
    if (encrypted) {
      password = await _promptPassword(context);
      if (password == null) return;
    }

    try {
      await ref.read(backupRepositoryProvider).restoreFromFile(file, password: password);
      ref.invalidate(bootstrapProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'This permanently deletes every transaction, loan, and setting on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.eraseAllData();
    ref.invalidate(bootstrapProvider);
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    Widget button(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(child: child ?? Text(label, style: const TextStyle(fontSize: 22))),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [1, 2, 3].map((n) => button('$n', onTap: () => onDigit('$n'))).toList()),
        Row(children: [4, 5, 6].map((n) => button('$n', onTap: () => onDigit('$n'))).toList()),
        Row(children: [7, 8, 9].map((n) => button('$n', onTap: () => onDigit('$n'))).toList()),
        Row(children: [
          const Expanded(child: SizedBox()),
          button('0', onTap: () => onDigit('0')),
          button('', onTap: onBackspace, child: const Icon(Icons.backspace_outlined)),
        ]),
      ],
    );
  }
}
