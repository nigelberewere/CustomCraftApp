import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'quotation_page.dart';

// Your main dashboard page, now using a GridView and the new DashboardCard.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Super App Dashboard'),
        // A little elevation makes the AppBar pop.
        elevation: 4,
        shadowColor: Colors.black.withAlpha((0.2 * 255).round()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Using the app's theme for the title for consistency.
            Text(
              'Select a module:',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Expanded makes the GridView fill the remaining available space.
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // Creates a 2-column grid.
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  DashboardCard(
                    title: 'Quotations',
                    icon: Icons.request_quote_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuotationPage(),
                        ),
                      );
                    },
                  ),
                  DashboardCard(
                    title: 'Worker Register',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                  ),
                  const DashboardCard(
                    title: 'ML Blueprint (Soon)',
                    icon: Icons.auto_awesome_outlined,
                    // No onTap makes it appear disabled automatically.
                  ),
                  const DashboardCard(
                    title: 'Magic Loops (Soon)',
                    icon: Icons.all_inclusive_outlined,
                    // No onTap makes it appear disabled automatically.
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable card widget for your dashboard items.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Check if the card should be enabled or disabled.
    final bool isEnabled = onTap != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isEnabled ? 4.0 : 0.0,
      shadowColor: colorScheme.primary.withAlpha((0.2 * 255).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Opacity(
          // Lower opacity for disabled cards.
          opacity: isEnabled ? 1.0 : 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
