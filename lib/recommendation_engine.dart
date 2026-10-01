/// FinWise rule-based recommendation engine.
///
/// Pure Dart: no Flutter, no Firestore. It takes plain data in and returns a
/// list of [Recommendation]s. Every recommendation carries a `why` text that
/// states the rule and the exact numbers that triggered it, so the advice is
/// transparent and explainable (no black box).
library;

enum Severity { critical, warning, info }

class Recommendation {
  final String id;
  final Severity severity;
  final String category; // Investments / Insurance / Cash flow
  final String title;
  final String message;
  final String why;

  const Recommendation({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.message,
    required this.why,
  });
}

class HoldingInput {
  final String ticker;
  final String sector;
  final double value; // quantity x current price

  const HoldingInput({
    required this.ticker,
    required this.sector,
    required this.value,
  });
}

class PolicyInput {
  final String type; // Term / Health / Vehicle / Life
  final String? provider;
  final double sumAssured;
  final double premium; // annual premium
  final DateTime? dueDate;

  const PolicyInput({
    required this.type,
    required this.provider,
    required this.sumAssured,
    required this.premium,
    required this.dueDate,
  });
}

class TransactionInput {
  final bool isIncome; // false = expense
  final double amount;
  final DateTime? date;

  const TransactionInput({
    required this.isIncome,
    required this.amount,
    required this.date,
  });
}

/// Formats a rupee amount with Indian digit grouping, e.g. ₹12,50,000.
String formatInr(double value) {
  final n = value.round();
  final negative = n < 0;
  var digits = n.abs().toString();

  if (digits.length > 3) {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];

    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }

    if (rest.isNotEmpty) {
      groups.insert(0, rest);
    }

    digits = '${groups.join(',')},$last3';
  }

  return '${negative ? '-' : ''}₹$digits';
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _monthKey(DateTime d) => '${d.year}-${d.month}';

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

class _IncomeEstimate {
  final double annual;
  final double avgMonthly;
  final int months;

  const _IncomeEstimate(this.annual, this.avgMonthly, this.months);
}

class RecommendationEngine {
  // ---- Rule thresholds (shown to the user in each "why" text) ----
  static const double sectorLimitPct = 40;
  static const double sectorCriticalPct = 60;
  static const double stockLimitPct = 25;
  static const double stockCriticalPct = 50;
  static const double coverageMultiple = 10;
  static const double spendingWarnPct = 70;
  static const double spendingCriticalPct = 100;
  static const int renewalWindowDays = 30;
  static const int renewalUrgentDays = 7;

  static List<Recommendation> generate({
    required List<HoldingInput> holdings,
    required List<PolicyInput> policies,
    required List<TransactionInput> transactions,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());

    final recs = <Recommendation>[
      ..._portfolioRules(holdings),
      ..._insuranceRules(policies, transactions, today),
      ..._cashFlowRules(transactions),
    ];

    // Most serious first.
    recs.sort((a, b) => a.severity.index.compareTo(b.severity.index));

    return recs;
  }

  // ------------------------------------------------------------------
  // Rules 1 and 2: portfolio concentration
  // ------------------------------------------------------------------
  static List<Recommendation> _portfolioRules(List<HoldingInput> holdings) {
    final recs = <Recommendation>[];

    final total = holdings.fold<double>(0, (sum, h) => sum + h.value);

    if (total <= 0) {
      return recs;
    }

    final bySector = <String, double>{};
    final byTicker = <String, double>{};

    for (final h in holdings) {
      bySector[h.sector] = (bySector[h.sector] ?? 0) + h.value;
      byTicker[h.ticker] = (byTicker[h.ticker] ?? 0) + h.value;
    }

    // Rule 1: sector concentration. "Other" is a catch-all bucket, not a
    // real sector, so it is never flagged.
    bySector.forEach((sector, value) {
      if (sector == 'Other') {
        return;
      }

      final pct = value / total * 100;

      if (pct <= sectorLimitPct) {
        return;
      }

      recs.add(
        Recommendation(
          id: 'sector_$sector',
          severity:
              pct > sectorCriticalPct ? Severity.critical : Severity.warning,
          category: 'Investments',
          title: '$sector is ${pct.toStringAsFixed(0)}% of your portfolio',
          message:
              'A large share in one sector raises your risk if that sector '
              'falls. Consider spreading new investments across other sectors.',
          why:
              'Rule: a sector above ${sectorLimitPct.toStringAsFixed(0)}% of '
              'portfolio value is flagged (above '
              '${sectorCriticalPct.toStringAsFixed(0)}% is critical). '
              'Your $sector holdings are worth ${formatInr(value)} out of '
              '${formatInr(total)} (${pct.toStringAsFixed(1)}%).',
        ),
      );
    });

    // Rule 2: single-stock concentration.
    byTicker.forEach((ticker, value) {
      final pct = value / total * 100;

      if (pct <= stockLimitPct) {
        return;
      }

      recs.add(
        Recommendation(
          id: 'stock_$ticker',
          severity:
              pct > stockCriticalPct ? Severity.critical : Severity.warning,
          category: 'Investments',
          title: '$ticker is ${pct.toStringAsFixed(0)}% of your portfolio',
          message:
              'Depending heavily on one stock means a single bad result can '
              'hurt your whole portfolio. Consider holding more stocks.',
          why:
              'Rule: a single stock above '
              '${stockLimitPct.toStringAsFixed(0)}% of portfolio value is '
              'flagged (above ${stockCriticalPct.toStringAsFixed(0)}% is '
              'critical). Your $ticker holding is worth ${formatInr(value)} '
              'out of ${formatInr(total)} (${pct.toStringAsFixed(1)}%).',
        ),
      );
    });

    return recs;
  }

  // ------------------------------------------------------------------
  // Rules 3, 4 and 5: insurance
  // ------------------------------------------------------------------
  static List<Recommendation> _insuranceRules(
    List<PolicyInput> policies,
    List<TransactionInput> transactions,
    DateTime today,
  ) {
    final recs = <Recommendation>[];

    // ---- Rule 3: Term/Life cover vs income ----
    final lifePolicies =
        policies.where((p) => p.type == 'Term' || p.type == 'Life').toList();

    final lifeCover =
        lifePolicies.fold<double>(0, (sum, p) => sum + p.sumAssured);

    final estimate = _estimateIncome(transactions);

    if (lifePolicies.isEmpty) {
      recs.add(
        Recommendation(
          id: 'no_life_cover',
          severity: estimate != null ? Severity.warning : Severity.info,
          category: 'Insurance',
          title: 'No term or life cover recorded',
          message:
              'If anyone depends on your income, a Term or Life policy '
              'protects them. Add your policy if you already have one.',
          why:
              'Rule: Term/Life cover is expected when you earn an income. '
              'None of your ${_plural(policies.length, 'recorded policy')} '
              'is a Term or Life policy.',
        ),
      );
    } else if (estimate == null) {
      recs.add(
        Recommendation(
          id: 'add_income_for_cover',
          severity: Severity.info,
          category: 'Insurance',
          title: 'Add your income to check your cover',
          message:
              'We can tell you whether your life cover is enough once you '
              'record your income in the Income tab.',
          why:
              'Rule: Term/Life cover is compared with '
              '${coverageMultiple.toStringAsFixed(0)}x your annual income. '
              'No income entries were found, so the check was skipped.',
        ),
      );
    } else {
      final target = estimate.annual * coverageMultiple;

      if (lifeCover < target) {
        final ratio = target > 0 ? lifeCover / target : 1.0;

        recs.add(
          Recommendation(
            id: 'low_life_cover',
            severity: ratio < 0.5 ? Severity.critical : Severity.warning,
            category: 'Insurance',
            title: 'Your life cover may be low',
            message:
                'Your Term/Life cover is ${formatInr(lifeCover)}. A common '
                'guideline is about ${formatInr(target)}.',
            why:
                'Rule: Term/Life sum assured should be at least '
                '${coverageMultiple.toStringAsFixed(0)}x annual income '
                '(below half of that is critical). Estimated annual income '
                'is ${formatInr(estimate.annual)} (average '
                '${formatInr(estimate.avgMonthly)}/month over '
                '${_plural(estimate.months, 'month')} with income entries, '
                'times 12). Target: ${formatInr(target)}. Your cover: '
                '${formatInr(lifeCover)} '
                '(${(ratio * 100).toStringAsFixed(0)}% of target).',
          ),
        );
      }
    }

    // ---- Rule 4: no health insurance ----
    final hasHealth = policies.any((p) => p.type == 'Health');

    if (!hasHealth) {
      final detail = policies.isEmpty
          ? 'You have no policies recorded.'
          : 'None of your ${_plural(policies.length, 'recorded policy')} '
              'is a Health policy.';

      recs.add(
        Recommendation(
          id: 'no_health',
          severity: Severity.warning,
          category: 'Insurance',
          title: 'No health insurance recorded',
          message:
              'Medical costs can wipe out savings. A Health policy is one of '
              'the most useful covers to have.',
          why: 'Rule: at least one Health policy should be recorded. $detail',
        ),
      );
    }

    // ---- Rule 5: renewals due soon or overdue ----
    for (var i = 0; i < policies.length; i++) {
      final p = policies[i];

      if (p.dueDate == null) {
        continue;
      }

      final due = _dateOnly(p.dueDate!);
      final days = due.difference(today).inDays;

      if (days > renewalWindowDays) {
        continue;
      }

      final label = (p.provider != null && p.provider!.isNotEmpty)
          ? '${p.type} policy (${p.provider})'
          : '${p.type} policy';

      final String title;
      final String message;
      final Severity severity;

      if (days < 0) {
        severity = Severity.critical;
        title = '$label renewal date has passed';
        message =
            'The renewal date was ${_plural(-days, 'day')} ago. Check that '
            'the policy has not lapsed, and update the date once renewed.';
      } else if (days == 0) {
        severity = Severity.warning;
        title = '$label renews today';
        message = 'Pay the premium today to keep your cover active.';
      } else {
        severity =
            days <= renewalUrgentDays ? Severity.warning : Severity.info;
        title = '$label renews in ${_plural(days, 'day')}';
        message = 'Keep ${formatInr(p.premium)} ready for the premium.';
      }

      recs.add(
        Recommendation(
          id: 'renewal_$i',
          severity: severity,
          category: 'Insurance',
          title: title,
          message: message,
          why:
              'Rule: renewals due within $renewalWindowDays days are shown '
              '(within $renewalUrgentDays days as a warning, past due as '
              'critical). Renewal date: ${_fmtDate(due)}. Recorded premium: '
              '${formatInr(p.premium)}.',
        ),
      );
    }

    return recs;
  }

  // ------------------------------------------------------------------
  // Rule 6: spending vs income
  // ------------------------------------------------------------------
  static List<Recommendation> _cashFlowRules(
    List<TransactionInput> transactions,
  ) {
    final months = <String>{};
    var totalIncome = 0.0;
    var totalExpense = 0.0;

    for (final t in transactions) {
      if (t.date == null) {
        continue;
      }

      months.add(_monthKey(t.date!));

      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    if (months.isEmpty || totalIncome <= 0) {
      return const [];
    }

    final avgIncome = totalIncome / months.length;
    final avgExpense = totalExpense / months.length;
    final pct = avgExpense / avgIncome * 100;

    if (pct <= spendingWarnPct) {
      return const [];
    }

    final critical = pct > spendingCriticalPct;

    return [
      Recommendation(
        id: 'spending_high',
        severity: critical ? Severity.critical : Severity.warning,
        category: 'Cash flow',
        title: critical
            ? 'You are spending more than you earn'
            : 'Spending is ${pct.toStringAsFixed(0)}% of your income',
        message: critical
            ? 'Your average monthly expenses are higher than your average '
                'monthly income. Look for expenses you can reduce.'
            : 'Little is left to save or invest each month. Review your '
                'biggest expense categories.',
        why:
            'Rule: average monthly expenses above '
            '${spendingWarnPct.toStringAsFixed(0)}% of average monthly '
            'income are flagged (above '
            '${spendingCriticalPct.toStringAsFixed(0)}% is critical). Over '
            '${_plural(months.length, 'month')} with entries: income '
            '${formatInr(avgIncome)}/month, expenses '
            '${formatInr(avgExpense)}/month (${pct.toStringAsFixed(1)}%). '
            'Insurance premiums are not counted as expenses.',
      ),
    ];
  }

  // ------------------------------------------------------------------
  // Helper: estimate annual income from recorded income entries.
  // Average monthly income (over months that have income entries) x 12.
  // ------------------------------------------------------------------
  static _IncomeEstimate? _estimateIncome(List<TransactionInput> transactions) {
    final byMonth = <String, double>{};

    for (final t in transactions) {
      if (!t.isIncome || t.date == null) {
        continue;
      }

      final key = _monthKey(t.date!);
      byMonth[key] = (byMonth[key] ?? 0) + t.amount;
    }

    if (byMonth.isEmpty) {
      return null;
    }

    final total = byMonth.values.fold<double>(0, (sum, v) => sum + v);
    final avgMonthly = total / byMonth.length;

    if (avgMonthly <= 0) {
      return null;
    }

    return _IncomeEstimate(avgMonthly * 12, avgMonthly, byMonth.length);
  }
}