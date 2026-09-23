import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  DateTime _buyDate = DateTime.now();
  bool _isSaving = false;
  bool _isLoadingStocks = true;
  String? _selectedTicker;
  List<Map<String, dynamic>> _allStocks = [];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    final snap = await FirebaseFirestore.instance.collection('stockPrices').get();
    setState(() {
      _allStocks = snap.docs.map((d) => d.data()).toList();
      _isLoadingStocks = false;
    });
  }

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

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTicker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a stock from the list')),
      );
      return;
    }

    // NEW: get the currently logged-in user. This should never be null here,
    // since this screen is only reachable after login -- but we check anyway
    // rather than assume, so a bug elsewhere fails loudly instead of silently
    // saving data with no owner.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add an investment')),
      );
      return;
    }

    setState(() => _isSaving = true);

    await FirebaseFirestore.instance.collection('investments').add({
      'ticker': _selectedTicker,
      'quantity': int.parse(_quantityController.text.trim()),
      'buyPrice': double.parse(_buyPriceController.text.trim()),
      'buyDate': _buyDate.toIso8601String(),
      'createdAt': DateTime.now(),
      'userId': currentUser.uid, // NEW: ties this record to its owner
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investment added!')),
      );
      _quantityController.clear();
      _buyPriceController.clear();
      setState(() {
        _buyDate = DateTime.now();
        _selectedTicker = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Investment')),
      body: _isLoadingStocks
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['ticker'] as String,
                        optionsBuilder: (TextEditingValue value) {
                          if (value.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          final query = value.text.toUpperCase();
                          return _allStocks
                              .where((s) => (s['ticker'] as String).contains(query))
                              .take(50);
                        },
                        onSelected: (option) {
                          setState(() => _selectedTicker = option['ticker'] as String);
                          _buyPriceController.text = (option['price'] as num).toStringAsFixed(2);
                        },
                        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Search Stock (e.g. RELIANCE, TCS...)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _selectedTicker != null
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                            ),
                            validator: (v) =>
                                _selectedTicker == null ? 'Search and select a stock' : null,
                            onChanged: (v) {
                              if (_selectedTicker != null) {
                                setState(() => _selectedTicker = null);
                              }
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 32,
                                height: 280,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final opt = options.elementAt(index);
                                    final changePct = opt['changePct'] as num?;
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        opt['ticker'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('\u20b9${(opt['price'] as num).toStringAsFixed(2)}'),
                                          if (changePct != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                color: changePct >= 0 ? Colors.green[700] : Colors.red[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_allStocks.length} stocks available to search',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                          labelText: 'Buy Price (per share, \u20b9)',
                          border: OutlineInputBorder(),
                          helperText: 'Pre-filled with today\'s price - edit if you bought earlier',
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
            ),
    );
  }
}