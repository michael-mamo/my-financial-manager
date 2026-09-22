import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transaction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/utils/formatters.dart';

/// Section 18 (transaction history + filters) and Section 26 (global-ish
/// search, scoped to transactions here — People/Loans search join in a
/// later pass once those modules exist as their own searchable stores).
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TransactionType? _typeFilter;

  static const _pageSize = 50;
  final List<Transaction> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _query.isNotEmpty) return;
    setState(() => _loading = true);
    final repo = ref.read(transactionRepositoryProvider);
    final page = await repo.page(limit: _pageSize, offset: _offset);
    setState(() {
      _items.addAll(page);
      _offset += page.length;
      _hasMore = page.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final repo = ref.watch(transactionRepositoryProvider);
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search description or reference',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: _typeFilter == null, onTap: () => setState(() => _typeFilter = null)),
                  _FilterChip(label: 'Income', selected: _typeFilter == TransactionType.income, onTap: () => setState(() => _typeFilter = TransactionType.income)),
                  _FilterChip(label: 'Expense', selected: _typeFilter == TransactionType.expense, onTap: () => setState(() => _typeFilter = TransactionType.expense)),
                  _FilterChip(label: 'Loans', selected: _typeFilter == TransactionType.loanInflow, onTap: () => setState(() => _typeFilter = TransactionType.loanInflow)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _SearchResults(
                    query: _query, typeFilter: _typeFilter, currency: currency, repo: repo,
                    useEthiopian: useEthiopian, locale: locale,
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildList(currency, useEthiopian, locale),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String currency, bool useEthiopian, String locale) {
    final filtered = _typeFilter == null
        ? _items
        : _items.where((t) => _matchesFilter(t.type, _typeFilter!)).toList();

    if (filtered.isEmpty && !_loading) {
      return const Center(child: Text('No transactions yet.'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _loadMore();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtered.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _TransactionRow(txn: filtered[index], currency: currency, useEthiopian: useEthiopian, locale: locale);
        },
      ),
    );
  }

  bool _matchesFilter(TransactionType type, TransactionType filter) {
    if (filter == TransactionType.loanInflow) {
      return type == TransactionType.loanInflow ||
          type == TransactionType.loanOutflow ||
          type == TransactionType.loanPaymentIn ||
          type == TransactionType.loanPaymentOut;
    }
    return type == filter;
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final TransactionType? typeFilter;
  final String currency;
  final TransactionRepository repo;
  final bool useEthiopian;
  final String locale;
  const _SearchResults({
    required this.query, required this.typeFilter, required this.currency, required this.repo,
    required this.useEthiopian, required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Transaction>>(
      future: repo.search(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var results = snapshot.data!;
        if (typeFilter != null) {
          results = results.where((t) => t.type == typeFilter).toList();
        }
        if (results.isEmpty) return const Center(child: Text('No matching transactions.'));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: results.length,
          itemBuilder: (context, i) => _TransactionRow(
            txn: results[i], currency: currency, useEthiopian: useEthiopian, locale: locale,
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction txn;
  final String currency;
  final bool useEthiopian;
  final String locale;
  const _TransactionRow({required this.txn, required this.currency, required this.useEthiopian, required this.locale});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.type.isCredit;
    final color = isCredit ? Colors.green : Colors.red;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(txn.description?.isNotEmpty == true ? txn.description! : _typeLabel(txn.type)),
      subtitle: Text(formatDateDisplay(txn.date, useEthiopian: useEthiopian, locale: locale)),
      trailing: Text(
        '${isCredit ? "+" : "-"}${formatMoney(txn.amount, currency)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.loanInflow:
        return 'Loan Received';
      case TransactionType.loanOutflow:
        return 'Loan Given';
      case TransactionType.loanPaymentIn:
        return 'Loan Payment Received';
      case TransactionType.loanPaymentOut:
        return 'Loan Payment Made';
      case TransactionType.savingsContributionOut:
        return 'Savings Contribution';
      case TransactionType.savingsWithdrawalIn:
        return 'Savings Withdrawal';
    }
  }
}
