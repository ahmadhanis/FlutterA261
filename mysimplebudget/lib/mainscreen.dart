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
  static const int _pageSize = 10;

  List<Map<String, Object?>> _budgets = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    // Load existing entries as soon as the main screen appears.
    _loadBudgets();
  }

  // Read one page from SQLite and update the list or show an error state.
  Future<void> _loadBudgets({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _currentPage = page;
    });

    try {
      final budgetCount = await BudgetDatabase.instance.getBudgetCount();
      final totalPages = (budgetCount / _pageSize).ceil().clamp(1, 1 << 31);
      final targetPage = page.clamp(1, totalPages);
      final budgets = await BudgetDatabase.instance.getBudgets(
        limit: _pageSize,
        offset: (targetPage - 1) * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _isLoading = false;
        _currentPage = targetPage;
        _totalPages = totalPages;
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
    if (saved == true) await _loadBudgets(page: 1);
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
      await _loadBudgets(page: _currentPage);
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

  Future<void> _showBudgetDetails(Map<String, Object?> budget) async {
    final isIncome = budget['direction'] == 'in';
    final createdAt = DateTime.tryParse(budget['created_at'] as String);
    final formattedDate = createdAt == null
        ? budget['created_at'] as String
        : createdAt.toLocal().toString().split('.').first;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(budget['type'] as String),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Direction', isIncome ? 'Income' : 'Expense'),
              _detailRow(
                'Value',
                (budget['value'] as num).toDouble().toStringAsFixed(2),
              ),
              _detailRow(
                'Description',
                (budget['description'] as String).isEmpty
                    ? 'No description'
                    : budget['description'] as String,
              ),
              _detailRow('Created', formattedDate),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Simple Budget'),
        actions: [
          IconButton(
            tooltip: 'Refresh budgets',
            onPressed: _isLoading
                ? null
                : () => _loadBudgets(page: _currentPage),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (!_isLoading && !_loadFailed && _budgets.isNotEmpty)
            _buildPaginationControls(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewBudgetPage,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: _currentPage > 1 && !_isLoading
                  ? () => _loadBudgets(page: _currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Page $_currentPage of $_totalPages'),
            IconButton(
              tooltip: 'Next page',
              onPressed: _currentPage < _totalPages && !_isLoading
                  ? () => _loadBudgets(page: _currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
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
            TextButton(
              onPressed: () => _loadBudgets(page: _currentPage),
              child: const Text('Retry'),
            ),
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
          onTap: () => _showBudgetDetails(budget),
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
