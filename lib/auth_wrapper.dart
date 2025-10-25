import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/worker.dart';
import 'pages/admin_dashboard.dart';
import 'pages/employee_dashboard.dart';
import 'pages/login_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to authentication state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. While waiting for the initial auth state, show a loading screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If the user is logged in (snapshot has data)
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Now, check if the user is an admin or a regular worker
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('workers')
                .doc(user.uid)
                .get(),
            builder: (context, workerSnapshot) {
              // While fetching worker data, show a loading screen.
              if (workerSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              // If there's an error or no data, log out to be safe.
              if (workerSnapshot.hasError ||
                  !workerSnapshot.hasData ||
                  !workerSnapshot.data!.exists) {
                // You could show an error page, but logging out is a safe default.
                FirebaseAuth.instance.signOut();
                return LoginPage();
              }

              // Successfully fetched worker data.
              final worker = Worker.fromFirestore(workerSnapshot.data!);

              // Decide which dashboard to show based on the 'isAdmin' flag.
              if (worker.isAdmin) {
                return AdminDashboard(worker: worker);
              } else {
                return EmployeeDashboard(worker: worker);
              }
            },
          );
        }

        // 3. If the user is NOT logged in, show the LoginPage.
        return LoginPage();
      },
    );
  }
}
