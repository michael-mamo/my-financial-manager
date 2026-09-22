import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

/// Section 27. Only lists people with at least one loan on record — this is
/// a financial-relationships view, not a general contacts book.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleWithLoanTotalsProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: peopleAsync.when(
        data: (rows) => rows.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No one here yet — people appear once you add a loan involving them.'),
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final owedByThem = (r['owed_by_them'] as num).toDouble();
                  final owedByYou = (r['owed_by_you'] as num).toDouble();
                  final net = owedByThem - owedByYou;
                  return Card(
                    child: ListTile(
                      title: Text(r['name'] as String),
                      subtitle: Text(
                        [
                          if (owedByThem > 0) 'Owes you ${formatMoney(owedByThem, currency)}',
                          if (owedByYou > 0) 'You owe ${formatMoney(owedByYou, currency)}',
                        ].join(' · '),
                      ),
                      trailing: Text(
                        '${net >= 0 ? '+' : ''}${formatMoney(net, currency)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: net >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load people: $e')),
      ),
    );
  }
}
