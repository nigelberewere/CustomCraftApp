import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../widgets/financial_summary_card.dart';

class FinancialsPage extends StatelessWidget {
  const FinancialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        title: Text(
          'Financial Insights',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .orderBy('creationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error loading financial data.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No projects found.'));
          }

          final projects = snapshot.data!.docs
              .map((doc) => Project.fromFirestore(doc))
              .toList();

          // Calculate overall totals for the summary header
          double totalBudget = 0;
          double totalPayouts = 0;
          for (final project in projects) {
            totalBudget += project.budget;
            totalPayouts += project.finalPayouts.values
                .fold(0.0, (acc, amount) => acc + amount);
          }
          final double totalProfit = totalBudget - totalPayouts;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Overall Summary Card
              _OverallSummary(
                totalBudget: totalBudget,
                totalPayouts: totalPayouts,
                totalProfit: totalProfit,
              ),
              const SizedBox(height: 24),
              Text(
                'Projects Breakdown',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 16),
              // List of individual project financial cards
              ...projects.map((project) {
                return FinancialSummaryCard(project: project);
              }),
            ],
          );
        },
      ),
    );
  }
}

// A helper widget for the summary card at the top of the page.
class _OverallSummary extends StatelessWidget {
  final double totalBudget;
  final double totalPayouts;
  final double totalProfit;

  const _OverallSummary({
    required this.totalBudget,
    required this.totalPayouts,
    required this.totalProfit,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);
    final profitColor = totalProfit >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryFigure(
                  label: 'Total Budget',
                  value: currencyFormat.format(totalBudget),
                ),
                _SummaryFigure(
                  label: 'Total Payouts',
                  value: currencyFormat.format(totalPayouts),
                ),
                _SummaryFigure(
                  label: 'Total Profit',
                  value: currencyFormat.format(totalProfit),
                  valueColor: profitColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// A helper widget for displaying a single figure in the summary card.
class _SummaryFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryFigure({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: valueColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

