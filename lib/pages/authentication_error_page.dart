import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class AuthErrorPage extends StatelessWidget {
  final String message;
  const AuthErrorPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 80, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'Account Error',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Return to Login'),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
