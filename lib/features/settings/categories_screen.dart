import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/providers/app_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Expense'), Tab(text: 'Income')]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddCategory(context),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryList(type: CategoryType.expense),
          _CategoryList(type: CategoryType.income),
        ],
      ),
    );
  }

  void _openAddCategory(BuildContext context) {
    final type = _tabController.index == 0 ? CategoryType.expense : CategoryType.income;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCategorySheet(type: type),
    ).then((_) {
      ref.invalidate(expenseCategoriesProvider);
      ref.invalidate(incomeCategoriesProvider);
    });
  }
}

class _CategoryList extends ConsumerWidget {
  final CategoryType type;
  const _CategoryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync =
        type == CategoryType.expense ? ref.watch(expenseCategoriesProvider) : ref.watch(incomeCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final c = categories[i];
          return ListTile(
            title: Text(c.nameEn),
            subtitle: Text(c.nameAm),
            trailing: c.isDefault
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(categoryRepositoryProvider).deactivate(c.id!);
                      ref.invalidate(expenseCategoriesProvider);
                      ref.invalidate(incomeCategoriesProvider);
                    },
                  ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load categories: $e')),
    );
  }
}

class _AddCategorySheet extends ConsumerStatefulWidget {
  final CategoryType type;
  const _AddCategorySheet({required this.type});

  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _nameEnController = TextEditingController();
  final _nameAmController = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Category', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameEnController,
            decoration: const InputDecoration(labelText: 'Name (English)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameAmController,
            decoration: const InputDecoration(labelText: 'Name (Amharic) — optional'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final nameEn = _nameEnController.text.trim();
    if (nameEn.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(categoryRepositoryProvider).create(Category(
            nameEn: nameEn,
            nameAm: _nameAmController.text.trim().isEmpty ? nameEn : _nameAmController.text.trim(),
            type: widget.type,
          ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}
