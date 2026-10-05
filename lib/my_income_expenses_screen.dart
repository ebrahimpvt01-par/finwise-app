import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_income_expense_screen.dart';
import 'app_theme.dart';
import 'edit_transaction_dialog.dart';

class MyIncomeExpensesScreen extends StatefulWidget {
  const MyIncomeExpensesScreen({super.key});

  @override
  State<MyIncomeExpensesScreen> createState() =>
      _MyIncomeExpensesScreenState();
}

class _MyIncomeExpensesScreenState
    extends State<MyIncomeExpensesScreen> {
  final _goalAmountController = TextEditingController();

  DateTime? _targetDate;

  @override
  void dispose() {
    _goalAmountController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString);

    if (date == null) {
      return dateString;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectTargetDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );

    if (pickedDate != null) {
      setState(() {
        _targetDate = pickedDate;
      });
    }
  }

  int _monthsRemaining() {
    if (_targetDate == null) {
      return 0;
    }

    final now = DateTime.now();

    int months =
        (_targetDate!.year - now.year) * 12 +
        (_targetDate!.month - now.month);

    if (_targetDate!.day > now.day) {
      months++;
    }

    return months < 1 ? 1 : months;
  }

  double _requiredMonthlySavings() {
    final goal = double.tryParse(
      _goalAmountController.text.trim(),
    );

    if (goal == null || goal <= 0) {
      return 0;
    }

    final months = _monthsRemaining();

    if (months <= 0) {
      return 0;
    }

    return goal / months;
  }

  Future<void> _showEditDialog(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    if (data == null) {
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return EditTransactionDialog(
          initialType: data['type'] as String? ?? 'Income',
          initialCategory: data['category'] as String? ?? 'Other',
          initialAmount: (data['amount'] ?? '').toString(),
          initialDate:
              DateTime.tryParse(data['date'] as String? ?? '') ??
                  DateTime.now(),
        );
      },
    );

    // Dialog is fully closed here. Cancelled -> result is null.
    if (result == null || !mounted) {
      return;
    }

    try {
      await document.reference.update(result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update transaction: $e'),
        ),
      );
    }
  }

  Widget _buildSummaryCard(
    double totalIncome,
    double totalExpenses,
    double netSavings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    'Total Income',
                    totalIncome,
                    AppColors.profit,
                  ),
                ),
                Expanded(
                  child: _summaryItem(
                    'Total Expenses',
                    totalExpenses,
                    AppColors.loss,
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            _summaryItem(
              'Net Savings',
              netSavings,
              netSavings >= 0
                  ? AppColors.profit
                  : AppColors.loss,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    String title,
    double amount,
    Color color,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInsuranceCard(
    double annualPremium,
    int policyCount,
  ) {
    final monthlyPremium = annualPremium / 12;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Insurance Financial Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _insuranceItem(
                    'Policies',
                    '$policyCount',
                  ),
                ),
                Expanded(
                  child: _insuranceItem(
                    'Annual Premium',
                    _formatCurrency(annualPremium),
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            _insuranceItem(
              'Monthly Premium Equivalent',
              _formatCurrency(monthlyPremium),
            ),

            const SizedBox(height: 10),

            const Text(
              'Insurance premiums are shown separately '
              'and are not included in your expense total.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insuranceItem(
    String title,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsCalculator(
    double netSavings,
  ) {
    final monthlyRequired =
        _requiredMonthlySavings();

    final goalEntered =
        double.tryParse(
              _goalAmountController.text.trim(),
            ) !=
            null;

    String comparisonText = '';

    if (goalEntered && _targetDate != null) {
      if (netSavings >= monthlyRequired) {
        comparisonText =
            'You are currently on track for this goal.';
      } else {
        comparisonText =
            'Your current Net Savings is below '
            'the required monthly amount.';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Savings Goal Calculator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Set a goal and target date to estimate '
              'how much you need to save each month.',
              style: TextStyle(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _goalAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Goal Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: _selectTargetDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Target Date',
                  border: OutlineInputBorder(),
                  suffixIcon:
                      Icon(Icons.calendar_today),
                ),
                child: Text(
                  _targetDate == null
                      ? 'Select target date'
                      : '${_targetDate!.day.toString().padLeft(2, '0')}/'
                          '${_targetDate!.month.toString().padLeft(2, '0')}/'
                          '${_targetDate!.year}',
                ),
              ),
            ),

            if (goalEntered &&
                _targetDate != null) ...[
              const SizedBox(height: 16),

              Text(
                'Required Monthly Savings: '
                '${_formatCurrency(monthlyRequired)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Current Net Savings: '
                '${_formatCurrency(netSavings)}',
              ),

              const SizedBox(height: 6),

              Text(
                comparisonText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      netSavings >= monthlyRequired
                          ? AppColors.profit
                          : AppColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyFundCard(
    double averageMonthlyExpenses,
  ) {
    final recommendedFund =
        averageMonthlyExpenses * 6;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.emergency_outlined,
              color: AppColors.warning,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency Fund Tip',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Recommended emergency fund: '
                    '${_formatCurrency(recommendedFund)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Based on 6 × your average monthly expenses.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      return const SizedBox.shrink();
    }

    final type =
        data['type'] as String? ?? 'Expense';

    final category =
        data['category'] as String? ?? 'Other';

    final amount =
        (data['amount'] as num?)?.toDouble() ?? 0;

    final date =
        data['date'] as String? ?? '';

    final isIncome = type == 'Income';

    final amountColor =
        isIncome
            ? AppColors.profit
            : AppColors.loss;

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,

      confirmDismiss: (_) async {
        final confirmed =
            await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title:
                  const Text('Delete Transaction'),
              content: const Text(
                'Are you sure you want to delete '
                'this transaction?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    dialogContext,
                    false,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(
                    dialogContext,
                    true,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );

        return confirmed ?? false;
      },

      onDismissed: (_) async {
        try {
          await document.reference.delete();
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                'Unable to delete transaction: $e',
              ),
            ),
          );
        }
      },

      background: Container(
        alignment: Alignment.centerRight,
        padding:
            const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.loss,
        ),
      ),

      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(
              isIncome
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: amountColor,
            ),
          ),

          title: Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          subtitle: Text(
            '$type • ${_formatDate(date)}',
          ),

          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isIncome ? '+' : '-'}'
                '${_formatCurrency(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                onPressed: () =>
                    _showEditDialog(document),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to view your transactions.',
          ),
        ),
      );
    }

    final incomeQuery =
        FirebaseFirestore.instance
            .collection('income')
            .where(
              'userId',
              isEqualTo: user.uid,
            );

    // Insurance query
    final insuranceQuery =
        FirebaseFirestore.instance
            .collection('insurance')
            .where(
              'userId',
              isEqualTo: user.uid,
            );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Income & Expenses'),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: incomeQuery.snapshots(),

        builder: (context, incomeSnapshot) {
          if (incomeSnapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Unable to load income and expenses.\n\n'
                  '${incomeSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (incomeSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final documents =
              incomeSnapshot.data?.docs ?? [];

          documents.sort((a, b) {
            final dateA =
                DateTime.tryParse(
                      a.data()['date']
                              as String? ??
                          '',
                    ) ??
                    DateTime(2000);

            final dateB =
                DateTime.tryParse(
                      b.data()['date']
                              as String? ??
                          '',
                    ) ??
                    DateTime(2000);

            return dateB.compareTo(dateA);
          });

          double totalIncome = 0;
          double totalExpenses = 0;

          final monthlyExpenses =
              <String, double>{};

          for (final document in documents) {
            final data = document.data();

            final type =
                data['type'] as String? ?? '';

            final amount =
                (data['amount'] as num?)
                        ?.toDouble() ??
                    0;

            if (type == 'Income') {
              totalIncome += amount;
            } else if (type == 'Expense') {
              totalExpenses += amount;

              final dateString =
                  data['date'] as String? ?? '';

              final date =
                  DateTime.tryParse(
                dateString,
              );

              if (date != null) {
                final monthKey =
                    '${date.year}-${date.month}';

                monthlyExpenses[monthKey] =
                    (monthlyExpenses[monthKey] ??
                            0) +
                        amount;
              }
            }
          }

          final netSavings =
              totalIncome - totalExpenses;

          final averageMonthlyExpenses =
              monthlyExpenses.isEmpty
                  ? 0.0
                  : monthlyExpenses.values
                          .reduce(
                            (a, b) => a + b,
                          ) /
                      monthlyExpenses.length;

          return StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: insuranceQuery.snapshots(),

            builder:
                (context, insuranceSnapshot) {
              if (insuranceSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load insurance data.\n\n'
                      '${insuranceSnapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              if (insuranceSnapshot
                      .connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final insuranceDocuments =
                  insuranceSnapshot.data?.docs ??
                      [];

              double totalAnnualPremium = 0;

              for (final document
                  in insuranceDocuments) {
                final data =
                    document.data();

                final premium =
                    (data['premium'] as num?)
                            ?.toDouble() ??
                        0;

                totalAnnualPremium +=
                    premium;
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(
                    const Duration(
                      milliseconds: 300,
                    ),
                  );
                },

                child: ListView(
                  padding:
                      const EdgeInsets.all(16),

                  children: [
                    _buildSummaryCard(
                      totalIncome,
                      totalExpenses,
                      netSavings,
                    ),

                    const SizedBox(height: 16),

                    // Insurance connected here
                    _buildInsuranceCard(
                      totalAnnualPremium,
                      insuranceDocuments.length,
                    ),

                    const SizedBox(height: 16),

                    _buildSavingsCalculator(
                      netSavings,
                    ),

                    const SizedBox(height: 16),

                    _buildEmergencyFundCard(
                      averageMonthlyExpenses,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        const Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                AppColors.textDark,
                          ),
                        ),

                        Text(
                          '${documents.length} entries',
                          style:
                              const TextStyle(
                            color:
                                AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (documents.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No income or expenses added yet.',
                              textAlign:
                                  TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      ...documents.map(
                        _buildTransactionCard,
                      ),

                    const SizedBox(
                      height: 90,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddIncomeExpenseScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label:
            const Text('Add Transaction'),
      ),
    );
  }
}