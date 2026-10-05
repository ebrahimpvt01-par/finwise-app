import 'package:flutter/material.dart';

/// Edit dialog for an income/expense transaction.
///
/// It owns (and safely disposes) its own controller and does NOT touch
/// Firestore. It returns the new values via Navigator.pop, and the screen
/// saves them after the dialog has fully closed.
class EditTransactionDialog extends StatefulWidget {
  final String initialType; // 'Income' or 'Expense'
  final String initialCategory;
  final String initialAmount;
  final DateTime initialDate;

  const EditTransactionDialog({
    super.key,
    required this.initialType,
    required this.initialCategory,
    required this.initialAmount,
    required this.initialDate,
  });

  @override
  State<EditTransactionDialog> createState() =>
      _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<EditTransactionDialog> {
  static const List<String> _incomeCategories = [
    'Salary',
    'Business',
    'Other',
  ];

  static const List<String> _expenseCategories = [
    'Rent',
    'Groceries',
    'Bills',
    'EMI',
    'Other',
  ];

  late final TextEditingController _amountController;

  late String _type;
  late String _category;
  late DateTime _date;

  String? _amountError;

  List<String> _categoriesFor(String type) {
    return type == 'Income' ? _incomeCategories : _expenseCategories;
  }

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(text: widget.initialAmount);

    _type = widget.initialType;
    _category = widget.initialCategory;
    _date = widget.initialDate;

    if (!_categoriesFor(_type).contains(_category)) {
      _category = _categoriesFor(_type).last;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _date = pickedDate;
      });
    }
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Enter a valid amount.';
      });
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'type': _type,
      'category': _category,
      'amount': amount,
      'date': _date.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Income', child: Text('Income')),
                DropdownMenuItem(value: 'Expense', child: Text('Expense')),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _type = value;
                  _category = value == 'Income' ? 'Salary' : 'Rent';
                });
              },
            ),

            const SizedBox(height: 12),

            // The key makes this dropdown rebuild when the type changes,
            // so its value always matches its list of items.
            DropdownButtonFormField<String>(
              key: ValueKey(_type),
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categoriesFor(_type)
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _category = value;
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                errorText: _amountError,
              ),
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() {
                    _amountError = null;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_date.day.toString().padLeft(2, '0')}/'
                  '${_date.month.toString().padLeft(2, '0')}/'
                  '${_date.year}',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}