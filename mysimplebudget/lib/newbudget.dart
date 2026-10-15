import 'package:flutter/material.dart';

class NewBudgetPage extends StatefulWidget {
  const NewBudgetPage({super.key});

  @override
  State<NewBudgetPage> createState() => _NewBudgetPageState();
}

class _NewBudgetPageState extends State<NewBudgetPage> {
  final _formKey = GlobalKey<FormState>();
  String _budgetDirection = 'out';
  String? _budgetType;

  static const List<String> _budgetTypes = [
    'Food',
    'Transport',
    'Housing',
    'Study',
    'Entertainment',
    'Other',
  ];

  Future<void> _confirmBudgetEntry() async {
    if (!_formKey.currentState!.validate()) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm budget entry'),
        content: const Text('This budget entry is ready to be added.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Confirm'),
          ),
        ],
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
                onPressed: _confirmBudgetEntry,
                child: const Text('Add budget'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
