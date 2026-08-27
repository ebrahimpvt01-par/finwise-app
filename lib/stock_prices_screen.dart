import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_investment_screen.dart';
import 'my_investments_screen.dart';
import 'portfolio_charts_screen.dart';
import 'portfolio_growth_screen.dart';
class StockPricesScreen extends StatelessWidget {
  const StockPricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Prices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: 'My Investments',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyInvestmentsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Investment',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Portfolio Charts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PortfolioChartsScreen()),
              );
            },
          ),
         IconButton(
  icon: const Icon(Icons.trending_up),
  tooltip: 'Portfolio Growth',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PortfolioGrowthScreen()),
    );
  },
), 
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stockPrices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No stock prices found yet.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final ticker = data['ticker'] ?? 'Unknown';
              final price = data['price'] ?? 0;
              final dataDate = data['dataDate'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text(ticker.toString().substring(0, 1))),
                  title: Text(
                    ticker,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('As of $dataDate'),
                  trailing: Text(
                    '₹$price',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
