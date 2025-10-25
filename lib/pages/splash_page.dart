import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.roofing_outlined, size: 80),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing App...'),
          ],
        ),
      ),
    );
  }
}
