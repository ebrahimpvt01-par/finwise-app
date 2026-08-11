import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  DateTime _buyDate = DateTime.now();
  bool _isSaving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _buyDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _buyDate = picked);
    }
  }

  /// Checks if a ticker exists in our known stockPrices collection.
  /// Returns true if recognized, false if not found.
  Future<bool> _isKnownTicker(String ticker) async {
    final doc = await FirebaseFirestore.instance.collection('stockPrices').doc(ticker).get();
    return doc.exists;
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    final ticker = _tickerController.text.trim().toUpperCase();

    setState(() => _isSaving = true);

    final isKnown = await _isKnownTicker(ticker);

    if (!isKnown && mounted) {
      setState(() => _isSaving = false);

      final proceedAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ticker not recognized'),
          content: Text(
            '"$ticker" was not found in our known stock list. This could be a typo, '
            'or it might just be a stock we haven\'t fetched a price for yet.\n\n'
            'If you save it anyway, it won\'t show live prices or gain/loss until '
            'a price is added for it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Let me fix it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );

      if (proceedAnyway != true) {
        return; // user chose to go back and fix the ticker
      }
      setState(() => _isSaving = true);
    }

    await FirebaseFirestore.instance.collection('investments').add({
      'ticker': ticker,
      'quantity': int.parse(_quantityController.text.trim()),
      'buyPrice': double.parse(_buyPriceController.text.trim()),
      'buyDate': _buyDate.toIso8601String(),
      'createdAt': DateTime.now(),
      // 'userId': will be added once login is wired in
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investment added!')),
      );
      _tickerController.clear();
      _quantityController.clear();
      _buyPriceController.clear();
      setState(() => _buyDate = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Investment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tickerController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Stock Ticker (e.g. RELIANCE)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Enter a ticker' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter quantity';
                  if (int.tryParse(value.trim()) == null) return 'Enter a whole number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Buy Price (per share, ₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter buy price';
                  if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Buy Date'),
                subtitle: Text('${_buyDate.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveInvestment,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Investment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}