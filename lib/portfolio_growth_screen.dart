import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';


class PortfolioGrowthScreen extends StatelessWidget {
  const PortfolioGrowthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Portfolio Growth'),
        elevation: 0,
      ),
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

          // Each ticker may have multiple buy "lots" (bought on different
          // dates, possibly different quantities). We keep the individual
          // lots so we can work out how many shares were actually held on
          // any given historical date - not just the current total.
          final Map<String, List<_Lot>> lotsByTicker = {};
          String? earliestBuyDate;
          for (final doc in investmentDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final ticker = (data['ticker'] ?? '').toString();
            final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
            // buyDate may be stored as an ISO datetime string; keep just
            // the date portion (yyyy-MM-dd) so it compares against the
            // priceHistory date strings correctly.
            final rawBuyDate = (data['buyDate'] ?? '').toString();
            final buyDate = rawBuyDate.length >= 10 ? rawBuyDate.substring(0, 10) : rawBuyDate;
            if (buyDate.isEmpty) continue;
            lotsByTicker.putIfAbsent(ticker, () => []).add(_Lot(buyDate, qty));
            if (earliestBuyDate == null || buyDate.compareTo(earliestBuyDate) < 0) {
              earliestBuyDate = buyDate;
            }
          }

          if (lotsByTicker.isEmpty || earliestBuyDate == null) {
            return const Center(child: Text('No investments yet.'));
          }

          // Quantity of a ticker actually held on a given date - only
          // counts lots bought on or before that date.
          double heldQuantity(String ticker, String date) {
            final lots = lotsByTicker[ticker];
            if (lots == null) return 0;
            double total = 0;
            for (final lot in lots) {
              if (lot.buyDate.compareTo(date) <= 0) total += lot.quantity;
            }
            return total;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('priceHistory').snapshots(),
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return Center(child: Text('Error: ${historySnapshot.error}'));
              }
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final historyDocs = historySnapshot.data?.docs ?? [];

              // Sum portfolio value per date, across held tickers only,
              // and only counting shares actually owned by that date.
              final Map<String, double> valueByDate = {};
              // Also track per-ticker value by date, so we can draw a
              // separate line for each stock, not just the combined total.
              final Map<String, Map<String, double>> valueByTickerByDate = {};
              for (final doc in historyDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final ticker = (data['ticker'] ?? '').toString();
                if (!lotsByTicker.containsKey(ticker)) continue;
                final date = (data['date'] ?? '').toString();
                // Skip any price data from before the earliest purchase
                // overall - nothing was owned yet, so it isn't relevant.
                if (date.compareTo(earliestBuyDate!) < 0) continue;
                final qty = heldQuantity(ticker, date);
                if (qty <= 0) continue; // not bought yet as of this date
                final price = (data['price'] as num?)?.toDouble() ?? 0;
                final value = price * qty;
                valueByDate[date] = (valueByDate[date] ?? 0) + value;
                valueByTickerByDate.putIfAbsent(ticker, () => {});
                valueByTickerByDate[ticker]![date] =
                    (valueByTickerByDate[ticker]![date] ?? 0) + value;
              }

              final dates = valueByDate.keys.toList()..sort();

              if (dates.length < 2) {
                return _buildEmptyState(dates.length);
              }

              final spots = <FlSpot>[
                for (var i = 0; i < dates.length; i++)
                  FlSpot(i.toDouble(), valueByDate[dates[i]] ?? 0),
              ];

              final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
              final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
              final range = (maxY - minY).abs();
              final yPadding = range == 0 ? maxY * 0.1 + 1 : range * 0.15;

              final firstValue = spots.first.y;
              final lastValue = spots.last.y;
              final change = lastValue - firstValue;
              final changePct = firstValue == 0 ? 0.0 : (change / firstValue) * 100;
              final isUp = change >= 0;
              final lineColor = isUp ? const Color(0xFF1DB954) : const Color(0xFFE53935);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(
                      lastValue: lastValue,
                      change: change,
                      changePct: changePct,
                      isUp: isUp,
                      sinceDate: _formatDate(dates.first),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'Value Over Time',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 260,
                            child: LineChart(
                              LineChartData(
                                minY: minY - yPadding,
                                maxY: maxY + yPadding,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: (range + yPadding * 2) / 4,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.15),
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 52,
                                      interval: (range + yPadding * 2) / 4,
                                      getTitlesWidget: (value, meta) => Text(
                                        _formatCompactRupee(value),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: (dates.length / 5).ceilToDouble().clamp(1, 1000),
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i >= dates.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            _formatDateShort(dates[i]),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (touchedSpot) => Colors.black87,
                                    tooltipRoundedRadius: 8,
                                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                                      final i = s.x.toInt();
                                      final date = (i >= 0 && i < dates.length)
                                          ? _formatDate(dates[i])
                                          : '';
                                      return LineTooltipItem(
                                        '$date\n₹${s.y.toStringAsFixed(2)}',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    curveSmoothness: 0.25,
                                    color: lineColor,
                                    barWidth: 3,
                                    dotData: FlDotData(
                                      show: spots.length <= 14,
                                      getDotPainter: (spot, percent, bar, index) =>
                                          FlDotCirclePainter(
                                        radius: 3,
                                        color: lineColor,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          lineColor.withOpacity(0.25),
                                          lineColor.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatsRow(minY: minY, maxY: maxY, days: dates.length),
                    const SizedBox(height: 20),
                    _buildPerStockChart(dates, valueByTickerByDate),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required double lastValue,
    required double change,
    required double changePct,
    required bool isUp,
    required String sinceDate,
  }) {
    final color = isUp ? const Color(0xFF1DB954) : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2A4A), Color(0xFF2C3E6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PORTFOLIO VALUE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${lastValue.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${change.abs().toStringAsFixed(2)} (${changePct.abs().toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'since $sinceDate',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({required double minY, required double maxY, required int days}) {
    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat('Lowest', '₹${minY.toStringAsFixed(0)}'),
        const SizedBox(width: 10),
        stat('Highest', '₹${maxY.toStringAsFixed(0)}'),
        const SizedBox(width: 10),
        stat('Days Tracked', '$days'),
      ],
    );
  }

  static const List<Color> _tickerColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // green
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
  ];

  Widget _buildPerStockChart(
    List<String> dates,
    Map<String, Map<String, double>> valueByTickerByDate,
  ) {
    final tickers = valueByTickerByDate.keys.toList()..sort();
    if (tickers.isEmpty) return const SizedBox.shrink();

    // Build one line per ticker, using the same date axis as the combined chart.
    // A stock with no data yet on a given date holds its last known value flat.
    final lines = <LineChartBarData>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var t = 0; t < tickers.length; t++) {
      final ticker = tickers[t];
      final series = valueByTickerByDate[ticker]!;
      double lastKnown = 0;
      final spots = <FlSpot>[];
      for (var i = 0; i < dates.length; i++) {
        final v = series[dates[i]];
        if (v != null) lastKnown = v;
        spots.add(FlSpot(i.toDouble(), lastKnown));
        if (lastKnown < minY) minY = lastKnown;
        if (lastKnown > maxY) maxY = lastKnown;
      }
      final color = _tickerColors[t % _tickerColors.length];
      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 1;
    final range = (maxY - minY).abs();
    final padding = range == 0 ? maxY * 0.1 + 1 : range * 0.15;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Growth by Stock',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) => Text(
                        _formatCompactRupee(value),
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (dates.length / 5).ceilToDouble().clamp(1, 1000),
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _formatDateShort(dates[i]),
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black87,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final i = s.x.toInt();
                      final date = (i >= 0 && i < dates.length) ? _formatDateShort(dates[i]) : '';
                      final ticker = (s.barIndex >= 0 && s.barIndex < tickers.length)
                          ? tickers[s.barIndex]
                          : '';
                      return LineTooltipItem(
                        '$ticker · $date\n₹${s.y.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: lines,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (var t = 0; t < tickers.length; t++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _tickerColors[t % _tickerColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(tickers[t], style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int daysRecorded) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Building your growth chart',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prices are now saved daily to track history.\n'
              'This chart appears once at least 2 days are recorded.\n\n'
              'Days recorded so far: $daysRecorded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[int.parse(parts[1]) - 1];
      return '${parts[2]} $month ${parts[0]}';
    } catch (_) {
      return isoDate;
    }
  }

  static String _formatDateShort(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length == 3) return '${parts[1]}/${parts[2]}';
    return isoDate;
  }

  static String _formatCompactRupee(double value) {
    if (value.abs() >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value.abs() >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}k';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}

/// A single purchase of a ticker: bought on [buyDate] (yyyy-MM-dd),
/// for [quantity] shares. Used to work out how many shares of a stock
/// were actually held as of any given historical date.
class _Lot {
  final String buyDate;
  final double quantity;
  const _Lot(this.buyDate, this.quantity);
}