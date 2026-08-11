import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyInvestmentsScreen extends StatelessWidget {
  const MyInvestmentsScreen({super.key});

  Future<void> _deleteInvestment(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('investments').doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investment deleted')),
      );
    }
  }

  Future<void> _editInvestment(
    BuildContext context,
    String docId,
    int currentQuantity,
    double currentBuyPrice,
  ) async {
    final quantityController = TextEditingController(text: currentQuantity.toString());
    final buyPriceController = TextEditingController(text: currentBuyPrice.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Investment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buyPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Buy Price (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newQuantity = int.tryParse(quantityController.text.trim());
      final newBuyPrice = double.tryParse(buyPriceController.text.trim());

      if (newQuantity == null || newBuyPrice == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid input, nothing was changed')),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('investments').doc(docId).update({
        'quantity': newQuantity,
        'buyPrice': newBuyPrice,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Investment updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Investments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('investments').snapshots(),
        builder: (context, investmentSnapshot) {
          if (investmentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!investmentSnapshot.hasData || investmentSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No investments added yet.'));
          }

          final investments = investmentSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('stockPrices').snapshots(),
            builder: (context, priceSnapshot) {
              if (priceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Build quick lookups: ticker -> current price, ticker -> sector
              final Map<String, double> currentPrices = {};
              final Map<String, String> tickerSectors = {};
              if (priceSnapshot.hasData) {
                for (var doc in priceSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  currentPrices[data['ticker']] = (data['price'] as num).toDouble();
                  tickerSectors[data['ticker']] = data['sector'] ?? 'Other';
                }
              }

              // ---- Portfolio-wide totals ----
              double totalInvested = 0;
              double totalCurrentValue = 0;
              bool anyPriceMissing = false;

              // ---- Sector-wise breakdown (by current value) ----
              // This is the calculation the Logic & Analytics Lead can plug
              // straight into a pie chart later - the numbers are ready,
              // just needs a chart widget wrapped around this map.
              final Map<String, double> sectorValues = {};

              for (var doc in investments) {
                final inv = doc.data() as Map<String, dynamic>;
                final ticker = inv['ticker'] ?? '';
                final quantity = (inv['quantity'] as num).toInt();
                final buyPrice = (inv['buyPrice'] as num).toDouble();
                final currentPrice = currentPrices[ticker];

                totalInvested += quantity * buyPrice;

                if (currentPrice != null) {
                  final value = quantity * currentPrice;
                  totalCurrentValue += value;

                  final sector = tickerSectors[ticker] ?? 'Other';
                  sectorValues[sector] = (sectorValues[sector] ?? 0) + value;
                } else {
                  anyPriceMissing = true;
                }
              }

              final totalGainLoss = totalCurrentValue - totalInvested;
              final totalGainLossPct =
                  totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;
              final isOverallProfit = totalGainLoss >= 0;

              // Sort sectors by value, largest first - makes the breakdown
              // read naturally and makes concentration risk obvious at a glance
              final sortedSectors = sectorValues.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: [
                  // ---- Summary card ----
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isOverallProfit ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOverallProfit ? Colors.green[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Portfolio Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryColumn('Invested', '₹${totalInvested.toStringAsFixed(2)}'),
                            _summaryColumn('Current Value', '₹${totalCurrentValue.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              isOverallProfit ? Icons.trending_up : Icons.trending_down,
                              color: isOverallProfit ? Colors.green[700] : Colors.red[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${isOverallProfit ? '+' : ''}₹${totalGainLoss.toStringAsFixed(2)} '
                              '(${isOverallProfit ? '+' : ''}${totalGainLossPct.toStringAsFixed(2)}%)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isOverallProfit ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        if (anyPriceMissing)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Note: some holdings are missing live prices, totals may be incomplete.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ---- Sector allocation card ----
                  if (sortedSectors.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sector Allocation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          ...sortedSectors.map((entry) {
                            final sector = entry.key;
                            final value = entry.value;
                            final pct = totalCurrentValue > 0
                                ? (value / totalCurrentValue) * 100
                                : 0;
                            final isConcentrated = pct > 40;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(sector, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (isConcentrated) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.warning_amber_rounded,
                                                size: 16, color: Colors.orange[700]),
                                          ],
                                        ],
                                      ),
                                      Text('${pct.toStringAsFixed(1)}%'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct / 100,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      color: isConcentrated ? Colors.orange[700] : Colors.blue[400],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (sortedSectors.any((e) =>
                              totalCurrentValue > 0 && (e.value / totalCurrentValue) * 100 > 40))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'One or more sectors exceed 40% of your portfolio - consider diversifying.',
                                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ---- Investment list ----
                  Expanded(
                    child: ListView.builder(
                      itemCount: investments.length,
                      itemBuilder: (context, index) {
                        final docId = investments[index].id;
                        final inv = investments[index].data() as Map<String, dynamic>;
                        final ticker = inv['ticker'] ?? '';
                        final quantity = (inv['quantity'] as num).toInt();
                        final buyPrice = (inv['buyPrice'] as num).toDouble();
                        final currentPrice = currentPrices[ticker];

                        final invested = quantity * buyPrice;
                        final currentValue = currentPrice != null ? quantity * currentPrice : null;
                        final gainLoss = currentValue != null ? currentValue - invested : null;
                        final gainLossPct =
                            currentValue != null ? (gainLoss! / invested) * 100 : null;

                        final isProfit = (gainLoss ?? 0) >= 0;

                        return Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Investment?'),
                                content: Text('Remove $ticker from your investments?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) => _deleteInvestment(context, docId),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ticker,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('$quantity shares'),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text('Invested: ₹${invested.toStringAsFixed(2)}'),
                                  if (currentValue != null) ...[
                                    Text('Current: ₹${currentValue.toStringAsFixed(2)}'),
                                    Text(
                                      '${isProfit ? '+' : ''}₹${gainLoss!.toStringAsFixed(2)} '
                                      '(${isProfit ? '+' : ''}${gainLossPct!.toStringAsFixed(2)}%)',
                                      style: TextStyle(
                                        color: isProfit ? Colors.green[700] : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ] else
                                    const Text('Price not available yet',
                                        style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editInvestment(context, docId, quantity, buyPrice),
                              ),
                            ),
                          ),
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

  Widget _summaryColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}