import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../controllers/database_controller.dart';
import '../models/budget_entry_model.dart';

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key, required this.userId, this.entry});

  final int userId;
  final BudgetEntryModel? entry;

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _databaseController = DatabaseController();

  final List<String> _categories = const [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Other',
  ];

  String? _selectedCategory;
  String _selectedType = 'Expense';
  DateTime _selectedDateTime = DateTime.now();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _removeExistingImage = false;
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;

    _titleController.text = entry.title;
    _amountController.text = entry.amount.toStringAsFixed(2);
    _descriptionController.text = entry.description;
    _selectedCategory = entry.category;
    _selectedType = entry.type;
    _selectedDateTime = entry.transactionDate;
    _imageName = entry.imageName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  bool get _supportsCamera =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  String? get _existingImageUrl {
    final imageName = widget.entry?.imageName;
    if (_removeExistingImage || _imageBytes != null || imageName == null) {
      return null;
    }
    return '${ApiConfig.serverIpAddress}/budgetplus/uploads/${Uri.encodeComponent(imageName)}';
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = image.name;
        _removeExistingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the image picker.')),
      );
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveEntry() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isEditing ? 'Update budget entry?' : 'Add budget entry?'),
        content: Text(
          _isEditing
              ? 'Save your changes to "${_titleController.text.trim()}"?'
              : 'Add "${_titleController.text.trim()}" to your budget entries?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await _databaseController.updateBudgetEntry(
          entryId: widget.entry!.id,
          userId: widget.userId,
          title: _titleController.text,
          type: _selectedType,
          category: _selectedCategory!,
          amount: double.parse(_amountController.text),
          transactionDate: _selectedDateTime,
          description: _descriptionController.text,
          imageBytes: _imageBytes,
          imageName: _imageName,
          removeImage: _removeExistingImage,
        );
      } else {
        await _databaseController.addBudgetEntry(
          userId: widget.userId,
          title: _titleController.text,
          type: _selectedType,
          category: _selectedCategory!,
          amount: double.parse(_amountController.text),
          transactionDate: _selectedDateTime,
          description: _descriptionController.text,
          imageBytes: _imageBytes,
          imageName: _imageName,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on DatabaseControllerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = size.width < 360 ? 20.0 : 28.0;
    final compact = size.height < 760;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit budget entry' : 'Add budget entry'),
        backgroundColor: const Color(0xFFF7F8F5),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 12 : 20,
                  padding,
                  compact ? 24 : 36,
                ),
                children: [
                  Text(
                    _isEditing ? 'Edit transaction' : 'Add a transaction',
                    style: TextStyle(
                      color: Color(0xFF172A25),
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing
                        ? 'Update the details or replace the attached photo.'
                        : 'Add the details and attach a receipt or item photo.',
                    style: TextStyle(
                      color: Color(0xFF65736E),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('Receipt or item photo'),
                  const SizedBox(height: 9),
                  _ImageAttachment(
                    bytes: _imageBytes,
                    imageUrl: _existingImageUrl,
                    imageName: _imageName,
                    onAdd: _chooseImage,
                    onRemove: () => setState(() {
                      _imageBytes = null;
                      _imageName = null;
                      _removeExistingImage = widget.entry?.imageName != null;
                    }),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: _inputDecoration(hint: 'e.g. Grocery shopping'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter a title',
                  ),
                  const SizedBox(height: 8),
                  const _SectionLabel('Type'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 0,
                    children: ['Expense', 'Income', 'Transfer'].map((type) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedType = type),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: type,
                              groupValue: _selectedType,
                              activeColor: const Color(0xFF147D64),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedType = value);
                                }
                              },
                            ),
                            Text(type),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel('Category'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select a category'),
                    decoration: _inputDecoration(),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                    validator: (value) =>
                        value == null ? 'Choose a category' : null,
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Amount (MYR)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: _inputDecoration(hint: '0.00', prefix: 'MYR '),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter an amount greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Date and time'),
                  const SizedBox(height: 8),
                  _DateTimeField(
                    value: _formatDateTime(context, _selectedDateTime),
                    onTap: _selectDateTime,
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 4,
                    maxLength: 240,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      hint: 'Add a note about this transaction',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveEntry,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isSaving
                            ? 'Saving…'
                            : _isEditing
                            ? 'Save changes'
                            : 'Save entry',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF147D64),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(dateTime);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
  return '$date · $time';
}

InputDecoration _inputDecoration({String? hint, String? prefix}) {
  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    hintStyle: const TextStyle(color: Color(0xFFA0AAA5), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFE5EAE6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFE5EAE6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFF147D64), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFBA4A45)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFBA4A45), width: 1.5),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF263831),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE5EAE6)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: Color(0xFF78857F),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF263831),
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                size: 19,
                color: Color(0xFF147D64),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.bytes,
    required this.imageUrl,
    required this.imageName,
    required this.onAdd,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? imageUrl;
  final String? imageName;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || imageUrl != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: hasImage ? null : onAdd,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: hasImage ? 210 : 142,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EAE6)),
          ),
          child: !hasImage
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 30,
                      color: Color(0xFF147D64),
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Add a photo',
                      style: TextStyle(
                        color: Color(0xFF263831),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Take a picture or choose from your device',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF87928D), fontSize: 12),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: bytes != null
                          ? Image.memory(bytes!, fit: BoxFit.cover)
                          : Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFE2F1EB),
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF147D64),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        onPressed: onRemove,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          imageName ?? 'Attached photo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
