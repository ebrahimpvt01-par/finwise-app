import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_insurance_screen.dart';
import 'app_theme.dart';

class MyInsuranceScreen extends StatefulWidget {
  const MyInsuranceScreen({super.key});

  @override
  State<MyInsuranceScreen> createState() => _MyInsuranceScreenState();
}

class _MyInsuranceScreenState extends State<MyInsuranceScreen> {
  final TextEditingController _incomeController =
      TextEditingController();

  double? _annualIncome;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  String _formatCurrency(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic value) {
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

  void _updateIncome() {
    final income = double.tryParse(
      _incomeController.text.trim(),
    );

    if (income == null || income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid annual income'),
        ),
      );
      return;
    }

    setState(() {
      _annualIncome = income;
    });

    FocusScope.of(context).unfocus();
  }

  bool _isCoverageLow(dynamic sumAssured) {
    if (_annualIncome == null) {
      return false;
    }

    final amount = (sumAssured as num?)?.toDouble() ?? 0;

    return amount < (_annualIncome! * 10);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insurance policy deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete policy: $e'),
        ),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot document,
  ) async {
    final data = document.data() as Map<String, dynamic>;

    final sumAssuredController = TextEditingController(
      text: ((data['sumAssured'] as num?) ?? 0).toString(),
    );

    final premiumController = TextEditingController(
      text: ((data['premium'] as num?) ?? 0).toString(),
    );

    String? selectedType = data['type']?.toString();

    DateTime? selectedDate;

    try {
      if (data['dueDate'] != null) {
        selectedDate = DateTime.parse(
          data['dueDate'].toString(),
        );
      }
    } catch (_) {
      selectedDate = null;
    }

    final insuranceTypes = [
      'Term',
      'Health',
      'Vehicle',
      'Life',
    ];

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectDate() async {
              final now = DateTime.now();

              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: now,
                lastDate: DateTime(now.year + 50),
              );

              if (pickedDate != null) {
                setDialogState(() {
                  selectedDate = pickedDate;
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit Insurance Policy'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            insuranceTypes.contains(selectedType)
                                ? selectedType
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Insurance Type',
                          border: OutlineInputBorder(),
                        ),
                        items: insuranceTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedType = value;
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
                        controller: sumAssuredController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Sum Assured',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');

                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: premiumController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Premium',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');

                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      InkWell(
                        onTap: selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Policy Renewal Date',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            selectedDate == null
                                ? 'Select renewal date'
                                : _formatDate(
                                    selectedDate!
                                        .toIso8601String(),
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select the renewal date',
                          ),
                        ),
                      );
                      return;
                    }

                    final user =
                        FirebaseAuth.instance.currentUser;

                    if (user == null) {
                      return;
                    }

                    try {
                      await document.reference.update({
                        'type': selectedType,
                        'sumAssured': double.parse(
                          sumAssuredController.text.trim(),
                        ),
                        'premium': double.parse(
                          premiumController.text.trim(),
                        ),
                        'dueDate':
                            selectedDate!.toIso8601String(),
                      });

                      if (!context.mounted) return;

                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Insurance policy updated',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to update policy: $e',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    sumAssuredController.dispose();
    premiumController.dispose();
  }

  Widget _buildPolicyCard(
    BuildContext context,
    DocumentSnapshot document,
  ) {
    final data = document.data() as Map<String, dynamic>;

    final type = data['type']?.toString() ?? 'Unknown';
    final sumAssured = data['sumAssured'];
    final premium = data['premium'];
    final dueDate = data['dueDate'];

    final coverageLow = _isCoverageLow(sumAssured);

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
            _showEditDialog(context, document);
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
                        _showEditDialog(
                          context,
                          document,
                        );
                      },
                      icon: Icon(
                        Icons.edit,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Insurance Policies'),
      ),

      // FIXED: The + button now opens Add Insurance.
      floatingActionButton: FloatingActionButton(
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

      body: Column(
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
                      'Enter your annual income to check if your insurance coverage may be low.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _incomeController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                const InputDecoration(
                              labelText: 'Annual Income',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              _updateIncome();
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _updateIncome,
                            child: const Text('Check'),
                          ),
                        ),
                      ],
                    ),

                    if (_annualIncome != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reference coverage: ${_formatCurrency(_annualIncome! * 10)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: insuranceQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load insurance policies.\n\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final policies = snapshot.data?.docs ?? [];

                if (policies.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'No insurance policies yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Tap + to add your first insurance policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    90,
                  ),
                  itemCount: policies.length,
                  itemBuilder: (context, index) {
                    return _buildPolicyCard(
                      context,
                      policies[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}