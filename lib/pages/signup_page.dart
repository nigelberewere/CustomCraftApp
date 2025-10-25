import 'package:flutter/material.dart';
import '../models/worker.dart';
import 'employee_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  void signUp() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      if (userCredential.user != null) {
        final newWorker = Worker(
          uid: userCredential.user!.uid,
          name: nameController.text.trim(),
          username: email,
        );

        await FirebaseFirestore.instance
            .collection(FirestoreCollections.workers)
            .doc(userCredential.user!.uid)
            .set(newWorker.toMap());

        if (mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmployeeDashboard(worker: newWorker),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType:
                      TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!val.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (val) =>
                      val!.length < 6 ? 'Password must be 6+ chars long' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : signUp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text("Create Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
