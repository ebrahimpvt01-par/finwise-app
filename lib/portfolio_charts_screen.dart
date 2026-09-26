import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';


class PortfolioChartsScreen extends StatelessWidget {
  const PortfolioChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Overview')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('investments').where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
        builder: (context, investmentSnapshot) {
          if (investmentSnapshot.hasError) {
            return Center(child: Text('Error: ${investmentSnapshot.error}'));
          }
          if (investmentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final investmentDocs = investmentSnapshot.data?.docs ?? [];
          if (investmentDocs.isEmpty) {
            return const Center(child: Text('No investments yet.'));
          }

          // Also listen to live stock prices so the chart stays current
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('stockPrices').snapshots(),
            builder: (context, priceSnapshot) {
              if (priceSnapshot.hasError) {
                return Center(child: Text('Error: ${priceSnapshot.error}'));
              }
              if (priceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final priceDocs = priceSnapshot.data?.docs ?? [];

              // Build a ticker -> current price lookup
              final Map<String, double> currentPrices = {};
              for (final doc in priceDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final ticker = (data['ticker'] ?? '').toString();
                final price = (data['price'] as num?)?.toDouble() ?? 0;
                currentPrices[ticker] = price;
              }

              // Aggregate investments by ticker
              final Map<String, double> investedByTicker = {};
              final Map<String, double> currentValueByTicker = {};
              double totalInvested = 0;
              double totalCurrent = 0;

              for (final doc in investmentDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final ticker = (data['ticker'] ?? 'Unknown').toString();
                final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
                final buyPrice = (data['buyPrice'] as num?)?.toDouble() ?? 0;

                final invested = quantity * buyPrice;
                final currentPrice = currentPrices[ticker] ?? buyPrice;
                final currentValue = quantity * currentPrice;

                investedByTicker[ticker] = (investedByTicker[ticker] ?? 0) + invested;
                currentValueByTicker[ticker] = (currentValueByTicker[ticker] ?? 0) + currentValue;

                totalInvested += invested;
                totalCurrent += currentValue;
              }

              final double totalGainLoss = totalCurrent - totalInvested;
              final double totalGainLossPct =
                  totalInvested == 0 ? 0 : (totalGainLoss / totalInvested) * 100;

              final colors = [
                Colors.blue,
                Colors.orange,
                Colors.green,
                Colors.purple,
                Colors.red,
                Colors.teal,
                Colors.pink,
                Colors.brown,
              ];

              final tickers = currentValueByTicker.keys.toList();
              final sections = <PieChartSectionData>[];
              for (var i = 0; i < tickers.length; i++) {
                final ticker = tickers[i];
                final value = currentValueByTicker[ticker] ?? 0;
                sections.add(
                  PieChartSectionData(
                    value: value,
                    title: ticker,
                    color: colors[i % colors.length],
                    radius: 90,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Portfolio',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${totalCurrent.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalGainLoss >= 0 ? '+' : ''}₹${totalGainLoss.toStringAsFixed(2)} '
                              '(${totalGainLoss >= 0 ? '+' : ''}${totalGainLossPct.toStringAsFixed(2)}%)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: totalGainLoss >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Allocation by Stock',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 260,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Per-Stock Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Per-stock gain/loss list, same style as the summary card
                    ...tickers.map((ticker) {
                      final invested = investedByTicker[ticker] ?? 0;
                      final current = currentValueByTicker[ticker] ?? 0;
                      final gainLoss = current - invested;
                      final gainLossPct = invested == 0 ? 0 : (gainLoss / invested) * 100;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticker,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Invested: ₹${invested.toStringAsFixed(2)}'),
                              Text('Current: ₹${current.toStringAsFixed(2)}'),
                              Text(
                                '${gainLoss >= 0 ? '+' : ''}₹${gainLoss.toStringAsFixed(2)} '
                                '(${gainLoss >= 0 ? '+' : ''}${gainLossPct.toStringAsFixed(2)}%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: gainLoss >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}