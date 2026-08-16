import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String _otherOptionValue = '__OTHER__';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _manualTickerController = TextEditingController();
  DateTime _buyDate = DateTime.now();
  bool _isSaving = false;
  String? _selectedTicker;
  bool _isManualEntry = false;

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

  Future<bool> _isKnownTicker(String ticker) async {
    final doc = await FirebaseFirestore.instance.collection('stockPrices').doc(ticker).get();
    return doc.exists;
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    String? tickerToSave;

    if (_isManualEntry) {
      tickerToSave = _manualTickerController.text.trim().toUpperCase();
      if (tickerToSave.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a ticker')),
        );
        return;
      }
    } else {
      tickerToSave = _selectedTicker;
      if (tickerToSave == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a stock')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    // For manual entries, warn if the ticker isn't recognized yet - but still
    // allow saving, since it'll be picked up automatically by tomorrow's
    // price-fetch run (the script unions the watchlist with real investments).
    if (_isManualEntry) {
      final isKnown = await _isKnownTicker(tickerToSave);
      if (!isKnown && mounted) {
        setState(() => _isSaving = false);

        final proceedAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ticker not recognized yet'),
            content: Text(
              '"$tickerToSave" isn\'t in our current price list. If this is a valid '
              'NSE ticker, it\'ll be picked up automatically the next time prices are '
              'refreshed (usually within a day). Double-check the spelling before saving.',
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

        if (proceedAnyway != true) return;
        setState(() => _isSaving = true);
      }
    }

    await FirebaseFirestore.instance.collection('investments').add({
      'ticker': tickerToSave,
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
      _quantityController.clear();
      _buyPriceController.clear();
      _manualTickerController.clear();
      setState(() {
        _buyDate = DateTime.now();
        _selectedTicker = null;
        _isManualEntry = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Investment')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stockPrices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stockDocs = (snapshot.data?.docs ?? []).map((doc) {
            return doc.data() as Map<String, dynamic>;
          }).toList();

          // Sort by daily % change, best performers first (nulls go last)
          stockDocs.sort((a, b) {
            final aChange = a['changePct'];
            final bChange = b['changePct'];
            if (aChange == null && bChange == null) return 0;
            if (aChange == null) return 1;
            if (bChange == null) return -1;
            return (bChange as num).compareTo(aChange as num);
          });

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isManualEntry) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTicker,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Stock',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (!_isManualEntry && value == null) ? 'Select a stock' : null,
                        items: [
                          ...stockDocs.map((stock) {
                            final ticker = stock['ticker'] as String;
                            final price = (stock['price'] as num).toDouble();
                            final changePct = stock['changePct'] as num?;

                            return DropdownMenuItem<String>(
                              value: ticker,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ticker, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 12),
                                  Text('₹${price.toStringAsFixed(2)}'),
                                  const SizedBox(width: 8),
                                  if (changePct != null)
                                    Text(
                                      '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: changePct >= 0 ? Colors.green[700] : Colors.red[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const DropdownMenuItem<String>(
                            value: _otherOptionValue,
                            child: Text(
                              "Other (type ticker manually)",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == _otherOptionValue) {
                            setState(() {
                              _isManualEntry = true;
                              _selectedTicker = null;
                            });
                            return;
                          }
                          setState(() => _selectedTicker = value);
                          final match = stockDocs.firstWhere((s) => s['ticker'] == value);
                          _buyPriceController.text = (match['price'] as num).toStringAsFixed(2);
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _manualTickerController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Stock Ticker (e.g. BAJAJFINSV)',
                          border: OutlineInputBorder(),
                          helperText: 'Not in our curated list - enter the exact NSE ticker',
                        ),
                        validator: (value) => (_isManualEntry && (value == null || value.trim().isEmpty))
                            ? 'Enter a ticker'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isManualEntry = false;
                              _manualTickerController.clear();
                            });
                          },
                          child: const Text('Back to stock list'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
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
        },
      ),
    );
  }
}