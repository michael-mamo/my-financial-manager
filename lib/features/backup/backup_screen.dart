import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exporting = false;
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Backup',
            description:
                'Save a copy of everything — transactions, loans, accounts, categories — '
                'as a file you can keep, upload to Drive, or send yourself.',
            child: FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup_outlined),
              label: const Text('Create Backup'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Restore',
            description:
                'Restoring replaces everything currently on this device with the contents '
                'of the backup file. This cannot be undone.',
            child: OutlinedButton.icon(
              onPressed: _restoring ? null : _restore,
              icon: _restoring
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restore_outlined),
              label: const Text('Choose Backup File'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final password = await _promptOptionalPassword(context);
    if (password == false) return; // user cancelled the dialog entirely
    final pw = password == true ? await _promptPasswordValue(context) : null;

    setState(() => _exporting = true);
    try {
      final file = await ref.read(backupRepositoryProvider).exportBackup(password: pw);
      await Share.shareXFiles([XFile(file.path)], text: 'My Financial Manager backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Returns true (password wanted), false (skip password), or null if the
  /// user dismissed the dialog without choosing (treated as cancel).
  Future<bool?> _promptOptionalPassword(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Protect this backup?'),
        content: const Text(
          'Without a password, the backup file is plain, human-readable text containing '
          'your financial data. Anyone who opens it can read it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No Password')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set Password')),
        ],
      ),
    );
  }

  Future<String?> _promptPasswordValue(BuildContext context) async {
    final controller = TextEditingController();
    if (!mounted) return null;
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
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces everything currently on this device with the contents of this '
          'backup file. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final encrypted = await ref.read(backupRepositoryProvider).isEncrypted(file);
    String? password;
    if (encrypted) {
      if (!mounted) return;
      password = await _promptPasswordValue(context);
      if (password == null || password.isEmpty) return;
    }

    setState(() => _restoring = true);
    try {
      await ref.read(backupRepositoryProvider).restoreFromFile(file, password: password);
      ref.invalidate(bootstrapProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(monthTotalsProvider);
      ref.invalidate(loanDashboardTotalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;
  const _SectionCard({required this.title, required this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
