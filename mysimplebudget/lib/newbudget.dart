import 'package:flutter/material.dart';

import 'budget_database.dart';

class NewBudgetPage extends StatefulWidget {
  const NewBudgetPage({super.key});

  @override
  State<NewBudgetPage> createState() => _NewBudgetPageState();
}

class _NewBudgetPageState extends State<NewBudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _budgetDirection = 'out';
  String? _budgetType;
  bool _isSaving = false;

  static const List<String> _budgetTypes = [
    'Food',
    'Transport',
    'Housing',
    'Study',
    'Entertainment',
    'Other',
  ];

  @override
  void dispose() {
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _confirmBudgetEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm budget entry'),
        content: const Text('Save this budget entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    var saved = false;
    try {
      await BudgetDatabase.instance.insertBudget(
        direction: _budgetDirection,
        type: _budgetType!,
        value: double.parse(_valueController.text.trim()),
        description: _descriptionController.text.trim(),
      );
      saved = true;
    } catch (_) {
      saved = false;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Budget saved successfully' : 'Failed to save budget',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Budget')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget in or out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Out'),
                      value: 'out',
                      groupValue: _budgetDirection,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _budgetDirection = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('In'),
                      value: 'in',
                      groupValue: _budgetDirection,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _budgetDirection = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Budget type',
                  border: OutlineInputBorder(),
                ),
                value: _budgetType,
                validator: (value) =>
                    value == null ? 'Select a budget type' : null,
                items: _budgetTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _budgetType = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null) return 'Enter a valid value';
                  if (amount <= 0) return 'Value must be greater than zero';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _confirmBudgetEntry,
                  child: Text(_isSaving ? 'Saving...' : 'Add budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
