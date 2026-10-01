import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'recommendation_engine.dart';

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  static const int _sourceCount = 4;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _loaded = {};

  String? _error;

  _Docs _investments = [];
  _Docs _prices = [];
  _Docs _policies = [];
  _Docs _transactions = [];

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final db = FirebaseFirestore.instance;

    _listen(
      'investments',
      db.collection('investments').where('userId', isEqualTo: user.uid),
      (docs) => _investments = docs,
    );

    _listen(
      'stock prices',
      db.collection('stockPrices'),
      (docs) => _prices = docs,
    );

    _listen(
      'insurance',
      db.collection('insurance').where('userId', isEqualTo: user.uid),
      (docs) => _policies = docs,
    );

    _listen(
      'income',
      db.collection('income').where('userId', isEqualTo: user.uid),
      (docs) => _transactions = docs,
    );
  }

  // Live listeners, so recommendations update the moment data changes.
  void _listen(
    String name,
    Query<Map<String, dynamic>> query,
    void Function(_Docs docs) assign,
  ) {
    _subscriptions.add(
      query.snapshots().listen(
        (snapshot) {
          if (!mounted) return;

          setState(() {
            assign(snapshot.docs);
            _loaded.add(name);
          });
        },
        onError: (Object e) {
          if (!mounted) return;

          setState(() {
            _error = 'Could not load $name data.\n\n$e';
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  // ---- Convert Firestore documents into plain engine inputs ----

  List<HoldingInput> _buildHoldings() {
    final prices = <String, double>{};
    final sectors = <String, String>{};

    for (final doc in _prices) {
      final data = doc.data();
      final ticker = data['ticker'] as String?;
      final price = (data['price'] as num?)?.toDouble();

      if (ticker == null || price == null) {
        continue;
      }

      prices[ticker] = price;
      sectors[ticker] = (data['sector'] as String?) ?? 'Other';
    }

    final holdings = <HoldingInput>[];

    for (final doc in _investments) {
      final data = doc.data();
      final ticker = data['ticker'] as String? ?? '';
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final price = prices[ticker];

      if (price == null || quantity <= 0) {
        continue;
      }

      holdings.add(
        HoldingInput(
          ticker: ticker,
          sector: sectors[ticker] ?? 'Other',
          value: quantity * price,
        ),
      );
    }

    return holdings;
  }

  List<PolicyInput> _buildPolicies() {
    return _policies.map((doc) {
      final data = doc.data();

      return PolicyInput(
        type: data['type']?.toString() ?? 'Unknown',
        provider: data['provider']?.toString(),
        sumAssured: (data['sumAssured'] as num?)?.toDouble() ?? 0,
        premium: (data['premium'] as num?)?.toDouble() ?? 0,
        dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? ''),
      );
    }).toList();
  }

  List<TransactionInput> _buildTransactions() {
    final result = <TransactionInput>[];

    for (final doc in _transactions) {
      final data = doc.data();
      final type = data['type'] as String? ?? '';

      if (type != 'Income' && type != 'Expense') {
        continue;
      }

      result.add(
        TransactionInput(
          isIncome: type == 'Income',
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          date: DateTime.tryParse(data['date']?.toString() ?? ''),
        ),
      );
    }

    return result;
  }

  // ---- Look and feel per severity ----

  Color _colorFor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return AppColors.loss;
      case Severity.warning:
        return AppColors.warning;
      case Severity.info:
        return AppColors.accent;
    }
  }

  IconData _iconFor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return Icons.error_outline;
      case Severity.warning:
        return Icons.warning_amber_rounded;
      case Severity.info:
        return Icons.info_outline;
    }
  }

  String _labelFor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return 'Critical';
      case Severity.warning:
        return 'Needs attention';
      case Severity.info:
        return 'For your info';
    }
  }

  Widget _buildCard(Recommendation r) {
    final color = _colorFor(r.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(r.severity), color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  _labelFor(r.severity),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  r.category,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.message,
              style: TextStyle(color: AppColors.textDark),
            ),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 10),
                title: Text(
                  'Why am I seeing this?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      r.why,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
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

  Widget _centerMessage(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(
        child: Text('Please log in to see your recommendations.'),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_loaded.length < _sourceCount) {
      return const Center(child: CircularProgressIndicator());
    }

    final holdings = _buildHoldings();
    final policies = _buildPolicies();
    final transactions = _buildTransactions();

    if (holdings.isEmpty && policies.isEmpty && transactions.isEmpty) {
      return _centerMessage(
        Icons.lightbulb_outline,
        'No recommendations yet',
        'Add investments, insurance policies or income and expenses, '
            'and personalised suggestions will appear here.',
      );
    }

    final recs = RecommendationEngine.generate(
      holdings: holdings,
      policies: policies,
      transactions: transactions,
    );

    final criticalCount =
        recs.where((r) => r.severity == Severity.critical).length;

    final warningCount =
        recs.where((r) => r.severity == Severity.warning).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recs.isEmpty
                      ? 'All clear'
                      : '${recs.length} '
                          '${recs.length == 1 ? 'recommendation' : 'recommendations'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recs.isEmpty
                      ? 'Your portfolio, insurance and spending look healthy '
                          'against all our checks.'
                      : '$criticalCount critical, $warningCount need attention. '
                          'Tap "Why am I seeing this?" on any card to see the '
                          'rule and the numbers behind it.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...recs.map(_buildCard),
        const SizedBox(height: 8),
        Text(
          'These suggestions come from fixed, rule-based checks on the data '
          'you entered. They are for education and are not professional '
          'financial advice.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: _buildBody(),
    );
  }
}