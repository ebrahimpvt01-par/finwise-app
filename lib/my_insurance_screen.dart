import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_insurance_screen.dart';
import 'app_theme.dart';

String _formatDateValue(dynamic value) {
  if (value == null) {
    return 'Not available';
  }

  try {
    final date = DateTime.parse(value.toString());

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  } catch (_) {
    return value.toString();
  }
}

/// Edit dialog as its own widget so it owns (and safely disposes) its
/// controllers. It does NOT touch Firestore: it returns the new values to
/// the caller, which saves them after the dialog has fully closed.
class _EditPolicyDialog extends StatefulWidget {
  final String initialProvider;
  final String? initialType;
  final num initialSumAssured;
  final num initialPremium;
  final DateTime? initialDate;

  const _EditPolicyDialog({
    required this.initialProvider,
    required this.initialType,
    required this.initialSumAssured,
    required this.initialPremium,
    required this.initialDate,
  });

  @override
  State<_EditPolicyDialog> createState() => _EditPolicyDialogState();
}

class _EditPolicyDialogState extends State<_EditPolicyDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _providerController;
  late final TextEditingController _sumAssuredController;
  late final TextEditingController _premiumController;

  static const List<String> _insuranceTypes = [
    'Term',
    'Health',
    'Vehicle',
    'Life',
  ];

  String? _selectedType;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

    _providerController = TextEditingController(
      text: widget.initialProvider,
    );
    _sumAssuredController = TextEditingController(
      text: widget.initialSumAssured.toString(),
    );
    _premiumController = TextEditingController(
      text: widget.initialPremium.toString(),
    );
    _selectedType = widget.initialType;
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _providerController.dispose();
    _sumAssuredController.dispose();
    _premiumController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final initial = _selectedDate ?? today;

    // If the saved renewal date is already in the past, firstDate must not
    // be later than initialDate or showDatePicker asserts.
    final firstDate = initial.isBefore(today) ? initial : today;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 50),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the renewal date'),
        ),
      );
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'provider': _providerController.text.trim(),
      'type': _selectedType,
      'sumAssured': double.parse(_sumAssuredController.text.trim()),
      'premium': double.parse(_premiumController.text.trim()),
      'dueDate': _selectedDate!.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Insurance Policy'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(
                  labelText: 'Insurance Provider',
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

              DropdownButtonFormField<String>(
                initialValue: _insuranceTypes.contains(_selectedType)
                    ? _selectedType
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Insurance Type',
                  border: OutlineInputBorder(),
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
                    return 'Select type';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _sumAssuredController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Sum Assured',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _premiumController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Premium',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Policy Renewal Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Select renewal date'
                        : _formatDateValue(
                            _selectedDate!.toIso8601String(),
                          ),
                  ),
                ),
              ),
            ],
          ),
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

class MyInsuranceScreen extends StatefulWidget {
  const MyInsuranceScreen({super.key});

  @override
  State<MyInsuranceScreen> createState() =>
      _MyInsuranceScreenState();
}

class _MyInsuranceScreenState extends State<MyInsuranceScreen> {
  String _formatCurrency(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic value) => _formatDateValue(value);

  bool _isCoverageLow(
    dynamic sumAssured,
    String type,
    double annualIncome,
  ) {
    // Coverage check is only for Term and Life insurance.
    if (type != 'Term' && type != 'Life') {
      return false;
    }

    if (annualIncome <= 0) {
      return false;
    }

    final amount = (sumAssured as num?)?.toDouble() ?? 0;

    return amount < (annualIncome * 10);
  }

  Future<void> _deletePolicy(
    BuildContext context,
    DocumentSnapshot document,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Policy?'),
          content: const Text(
            'Are you sure you want to delete this insurance policy?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.loss,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await document.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Insurance policy deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete policy: $e'),
        ),
      );
    }
  }

  Future<void> _showEditDialog(DocumentSnapshot document) async {
    final data = document.data() as Map<String, dynamic>;

    DateTime? initialDate;

    try {
      if (data['dueDate'] != null) {
        initialDate = DateTime.parse(data['dueDate'].toString());
      }
    } catch (_) {
      initialDate = null;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return _EditPolicyDialog(
          initialProvider: data['provider']?.toString() ?? '',
          initialType: data['type']?.toString(),
          initialSumAssured: (data['sumAssured'] as num?) ?? 0,
          initialPremium: (data['premium'] as num?) ?? 0,
          initialDate: initialDate,
        );
      },
    );

    // Dialog is fully closed here. Cancelled -> result is null.
    if (result == null || !mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await document.reference.update(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insurance policy updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update policy: $e'),
        ),
      );
    }
  }

  Widget _buildPolicyCard(
    BuildContext context,
    DocumentSnapshot document,
    double annualIncome,
  ) {
    final data = document.data() as Map<String, dynamic>;

    final type = data['type']?.toString() ?? 'Unknown';

    final provider = data['provider']?.toString().trim().isNotEmpty == true
        ? data['provider'].toString()
        : 'Provider not specified';

    final sumAssured = data['sumAssured'];
    final premium = data['premium'];
    final dueDate = data['dueDate'];

    final coverageLow = _isCoverageLow(
      sumAssured,
      type,
      annualIncome,
    );

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.loss,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        await _deletePolicy(context, document);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showEditDialog(document);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () {
                        _showEditDialog(document);
                      },
                      icon: Icon(
                        Icons.edit,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                Text(
                  provider,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        'Sum Assured',
                        _formatCurrency(sumAssured),
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        'Premium',
                        _formatCurrency(premium),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Renewal: ${_formatDate(dueDate)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                if (coverageLow) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Coverage may be low',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoItem(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to view your insurance policies.',
          ),
        ),
      );
    }

    final insuranceQuery = FirebaseFirestore.instance
        .collection('insurance')
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .orderBy(
          'createdAt',
          descending: true,
        );

    final incomeQuery = FirebaseFirestore.instance
        .collection('income')
        .where(
          'userId',
          isEqualTo: user.uid,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Insurance Policies'),
      ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'insurance_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddInsuranceScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: incomeQuery.snapshots(),
        builder: (context, incomeSnapshot) {
          if (incomeSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load income data.\n\n'
                  '${incomeSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (incomeSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Calculate income for the current calendar year.
          final currentYear = DateTime.now().year;

          double annualIncome = 0;

          final incomeDocuments =
              incomeSnapshot.data?.docs ?? [];

          for (final document in incomeDocuments) {
            final data = document.data();

            final type =
                data['type']?.toString() ?? '';

            final amount =
                (data['amount'] as num?)?.toDouble() ?? 0;

            final dateString =
                data['date']?.toString() ?? '';

            final date = DateTime.tryParse(dateString);

            if (type == 'Income' &&
                date != null &&
                date.year == currentYear) {
              annualIncome += amount;
            }
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: insuranceQuery.snapshots(),
            builder: (context, insuranceSnapshot) {
              if (insuranceSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load insurance policies.\n\n'
                      '${insuranceSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (insuranceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final policies =
                  insuranceSnapshot.data?.docs ?? [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      8,
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coverage Check',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Based on your recorded income for $currentYear.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: _infoItem(
                                    'Annual Income',
                                    _formatCurrency(
                                      annualIncome,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _infoItem(
                                    'Reference Coverage',
                                    _formatCurrency(
                                      annualIncome * 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Coverage check applies only to Term and Life insurance.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),

                            if (annualIncome <= 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Add an income transaction for $currentYear to enable the coverage check.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: policies.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 64,
                                    color:
                                        AppColors.textMuted,
                                  ),

                                  const SizedBox(height: 16),

                                  Text(
                                    'No insurance policies added yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          AppColors.textDark,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    'Tap + to add your first insurance policy.',
                                    textAlign:
                                        TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              90,
                            ),
                            itemCount: policies.length,
                            itemBuilder:
                                (context, index) {
                              return _buildPolicyCard(
                                context,
                                policies[index],
                                annualIncome,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}