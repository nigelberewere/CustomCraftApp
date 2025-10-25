import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProjectListShimmer extends StatelessWidget {
  const ProjectListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use surfaceContainerHighest (replacement for deprecated surfaceVariant)
    // and withAlpha instead of withOpacity to avoid deprecation warnings.
    final highlightColor = colorScheme.surfaceContainerHighest;
    final baseColor = colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).round());

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 160),
        itemCount: 5, // Display 5 placeholder items
        itemBuilder: (_, __) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20.0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8.0),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: 14.0,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
