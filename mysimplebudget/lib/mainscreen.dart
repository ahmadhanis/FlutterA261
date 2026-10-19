import 'package:flutter/material.dart';

import 'budget_database.dart';
import 'newbudget.dart';

/// Shows saved budget entries and opens the form for a new entry.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Map<String, Object?>> _budgets = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // Load existing entries as soon as the main screen appears.
    _loadBudgets();
  }

  // Read all rows from SQLite and update the list or show an error state.
  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final budgets = await BudgetDatabase.instance.getAllBudgets();
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openNewBudgetPage() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const NewBudgetPage()),
    );
    // The form returns true only after a successful insert.
    if (saved == true) await _loadBudgets();
  }

  Future<void> _confirmDeleteBudget(Map<String, Object?> budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget entry?'),
        content: const Text('This budget entry will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await BudgetDatabase.instance.deleteBudget(
        budget['id'] as int,
      );
      if (!mounted) return;
      await _loadBudgets();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted > 0
                ? 'Budget deleted successfully'
                : 'Budget could not be deleted',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete budget')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Simple Budget')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewBudgetPage,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load budgets.'),
            TextButton(onPressed: _loadBudgets, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_budgets.isEmpty) {
      return const Center(child: Text('No budget entries yet.'));
    }

    return ListView.builder(
      itemCount: _budgets.length,
      itemBuilder: (context, index) {
        final budget = _budgets[index];
        final direction = budget['direction'] as String;
        final value = (budget['value'] as num).toDouble();
        final description = budget['description'] as String;
        final isIncome = direction == 'in';

        return ListTile(
          onLongPress: () => _confirmDeleteBudget(budget),
          leading: CircleAvatar(
            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
          ),
          title: Text(budget['type'] as String),
          subtitle: Text(
            description.isEmpty
                ? (isIncome ? 'Income' : 'Expense')
                : description,
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }
}
