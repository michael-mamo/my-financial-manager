import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_providers.dart';

class ExportsScreen extends ConsumerStatefulWidget {
  const ExportsScreen({super.key});

  @override
  ConsumerState<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends ConsumerState<ExportsScreen> {
  String? _busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExportTile(
            icon: Icons.receipt_long_outlined,
            title: 'All Transactions (CSV)',
            subtitle: 'Every income and expense entry, with category, account, and payment method.',
            busy: _busy == 'transactions',
            onTap: () => _run('transactions', () => ref.read(exportRepositoryProvider).exportTransactionsCsv()),
          ),
          const SizedBox(height: 12),
          _ExportTile(
            icon: Icons.handshake_outlined,
            title: 'All Loans (CSV)',
            subtitle: 'Every loan with principal, interest, remaining balance, and status.',
            busy: _busy == 'loans',
            onTap: () => _run('loans', () => ref.read(exportRepositoryProvider).exportLoansCsv()),
          ),
          const SizedBox(height: 12),
          _ExportTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Monthly Summary (PDF)',
            subtitle: 'This month\'s income, expenses, and category breakdown as a shareable document.',
            busy: _busy == 'summary',
            onTap: () => _run(
              'summary',
              () => ref.read(exportRepositoryProvider).exportMonthlySummaryPdf(
                    currency: ref.read(currencyProvider),
                    languageCode: ref.read(localeProvider).languageCode,
                    useEthiopian: ref.read(ethiopianCalendarProvider),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(String key, Future<dynamic> Function() action) async {
    setState(() => _busy = key);
    try {
      final file = await action();
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: busy
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right),
        onTap: busy ? null : onTap,
      ),
    );
  }
}
