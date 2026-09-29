import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

class AddInsuranceScreen extends StatefulWidget {
  const AddInsuranceScreen({super.key});

  @override
  State<AddInsuranceScreen> createState() =>
      _AddInsuranceScreenState();
}

class _AddInsuranceScreenState extends State<AddInsuranceScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _providerController =
      TextEditingController();

  final TextEditingController _sumAssuredController =
      TextEditingController();

  final TextEditingController _premiumController =
      TextEditingController();

  String? _selectedType;
  DateTime? _selectedDueDate;
  bool _isSaving = false;

  final List<String> _insuranceTypes = [
    'Term',
    'Health',
    'Vehicle',
    'Life',
  ];

  @override
  void dispose() {
    _providerController.dispose();
    _sumAssuredController.dispose();
    _premiumController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 50),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _saveInsurance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select the policy renewal date.',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login before adding insurance.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('insurance')
          .add({
        'provider': _providerController.text.trim(),
        'type': _selectedType,
        'sumAssured': double.parse(
          _sumAssuredController.text.trim(),
        ),
        'premium': double.parse(
          _premiumController.text.trim(),
        ),
        'dueDate': _selectedDueDate!.toIso8601String(),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Insurance policy added successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save insurance policy: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Insurance Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insurance Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Insurance Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.shield_outlined,
                  ),
                ),
                items: _insuranceTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select insurance type';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _providerController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Insurance Provider',
                  hintText: 'e.g. LIC, HDFC Life, Star Health',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.business_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter insurance provider';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _sumAssuredController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Sum Assured',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    value?.trim() ?? '',
                  );

                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid positive sum assured';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _premiumController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Premium',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    value?.trim() ?? '',
                  );

                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid positive premium';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDueDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Policy Renewal Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.calendar_today,
                    ),
                  ),
                  child: Text(
                    _selectedDueDate == null
                        ? 'Select renewal date'
                        : _formatDate(
                            _selectedDueDate!,
                          ),
                    style: TextStyle(
                      color: _selectedDueDate == null
                          ? AppColors.textMuted
                          : AppColors.textDark,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isSaving ? null : _saveInsurance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Insurance Policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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


