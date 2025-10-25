import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';

class FinancialSummaryCard extends StatelessWidget {
  final Project project;
  const FinancialSummaryCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Calculate total payouts for this specific project
    final double totalPayouts = project.finalPayouts.values
        .fold(0.0, (sum, amount) => sum + amount);
        
    final double profit = project.budget - totalPayouts;
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    // Determine the color for the profit text
    final Color profitColor;
  if (project.budget == 0) {
    // Avoid deprecated withOpacity by using withAlpha for consistent precision
    profitColor = Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round());
    } else if (profit >= 0) {
        profitColor = Colors.green.shade700;
    } else {
        profitColor = Theme.of(context).colorScheme.error;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${project.status.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _buildFinancialsRow(
              'Budget:',
              currencyFormat.format(project.budget),
              context
            ),
            const SizedBox(height: 8),
            _buildFinancialsRow(
              'Total Payouts:',
              currencyFormat.format(totalPayouts),
              context
            ),
            const SizedBox(height: 8),
            _buildFinancialsRow(
              'Profit / Loss:',
              currencyFormat.format(profit),
              context,
              valueColor: profitColor
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create a consistent row for financial details
  Widget _buildFinancialsRow(String label, String value, BuildContext context, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
