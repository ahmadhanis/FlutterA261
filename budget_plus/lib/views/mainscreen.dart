import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../controllers/database_controller.dart';
import '../models/budget_entry_model.dart';
import 'addbudgetscreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.userId});

  final int userId;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _databaseController = DatabaseController();
  List<BudgetEntryModel> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _databaseController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      final entries = await _databaseController.getBudgetEntries(widget.userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _errorMessage = null;
        _isLoading = false;
      });
    } on DatabaseControllerException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openNewEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddBudgetScreen(userId: widget.userId),
      ),
    );

    if (saved == true && mounted) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully.')),
        );
      }
    }
  }

  Future<void> _editEntry(BudgetEntryModel entry) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddBudgetScreen(userId: widget.userId, entry: entry),
      ),
    );

    if (updated == true && mounted) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget Plus')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewEntry,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New budget'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF147D64)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Color(0xFF87928D),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF65736E)),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _loadEntries,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 52,
                color: Color(0xFFB7C7C0),
              ),
              SizedBox(height: 14),
              Text(
                'No budget entries yet',
                style: TextStyle(
                  color: Color(0xFF263831),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Add your first entry with the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF65736E), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF147D64),
      onRefresh: () => _loadEntries(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _BudgetEntryTile(entry: _entries[index], onEdit: _editEntry),
      ),
    );
  }
}

class _BudgetEntryTile extends StatelessWidget {
  const _BudgetEntryTile({required this.entry, required this.onEdit});

  final BudgetEntryModel entry;
  final ValueChanged<BudgetEntryModel> onEdit;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(entry.transactionDate);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(entry.transactionDate));
    final amountColor = switch (entry.type) {
      'Income' => const Color(0xFF147D64),
      'Expense' => const Color(0xFF263831),
      _ => const Color(0xFF65736E),
    };
    final amountSign = switch (entry.type) {
      'Income' => '+',
      'Expense' => '−',
      _ => '',
    };

    return ListTile(
      onTap: () => _showDetails(context),
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EAE6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      minVerticalPadding: 4,
      minLeadingWidth: 108,
      horizontalTitleGap: 12,
      leading: SizedBox.square(
        dimension: 108,
        child: _EntryImage(entry: entry),
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF172A25),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.category} · ${entry.type}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF65736E), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            '$date · $time',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF87928D), fontSize: 11),
          ),
          if (entry.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              entry.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF52615B), fontSize: 12),
            ),
          ],
        ],
      ),
      trailing: Text(
        '${amountSign}MYR ${entry.amount.toStringAsFixed(2)}',
        textAlign: TextAlign.end,
        style: TextStyle(
          color: amountColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(entry.transactionDate);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(entry.transactionDate));
    final imageName = entry.imageName;
    final contentWidth = (MediaQuery.sizeOf(context).width - 80)
        .clamp(200.0, 420.0)
        .toDouble();

    final editEntry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(entry.title),
        content: SizedBox(
          width: contentWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageName != null && imageName.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      '${ApiConfig.serverIpAddress}/budgetplus/uploads/${Uri.encodeComponent(imageName)}',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: Color(0xFF87928D),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _DetailRow(label: 'Type', value: entry.type),
                _DetailRow(label: 'Category', value: entry.category),
                _DetailRow(
                  label: 'Amount',
                  value: 'MYR ${entry.amount.toStringAsFixed(2)}',
                ),
                _DetailRow(label: 'Date and time', value: '$date · $time'),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Color(0xFF65736E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.description),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );

    if (editEntry == true && context.mounted) onEdit(entry);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF65736E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF263831), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryImage extends StatelessWidget {
  const _EntryImage({required this.entry});

  final BudgetEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final imageName = entry.imageName;
    if (imageName == null || imageName.isEmpty) {
      return CircleAvatar(
        radius: 54,
        backgroundColor: const Color(0xFFE2F1EB),
        child: Icon(
          _categoryIcon(entry.category),
          color: const Color(0xFF147D64),
        ),
      );
    }

    final imageUrl =
        '${ApiConfig.serverIpAddress}/budgetplus/uploads/${Uri.encodeComponent(imageName)}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 108,
        height: 108,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(
          width: 108,
          height: 108,
          child: ColoredBox(
            color: Color(0xFFE2F1EB),
            child: Icon(Icons.receipt_long_outlined, color: Color(0xFF147D64)),
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Food' => Icons.restaurant_outlined,
    'Transport' => Icons.directions_car_outlined,
    'Shopping' => Icons.shopping_bag_outlined,
    'Bills' => Icons.receipt_outlined,
    'Health' => Icons.favorite_border_rounded,
    _ => Icons.category_outlined,
  };
}
