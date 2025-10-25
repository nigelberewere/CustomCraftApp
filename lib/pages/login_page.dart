import 'package:flutter/foundation.dart' show kIsWeb; // ADDED for platform check
import 'package:flutter/material.dart';
import '../models/worker.dart';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';
import 'signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isPasswordObscured = true;

  // ADDED: Use the GoogleSignIn.instance singleton
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ADDED: State to track if Google Sign-In is ready on web
  bool _isGoogleInitialized = false;

  @override
  void initState() {
    super.initState();

    // UPDATED: Initialize Google Sign-In and track its completion
    _googleSignIn.initialize(
      clientId: '1072334388749-6pi1f3issjagadgc1gl2pap3l3re7t64.apps.googleusercontent.com',
    ).then((_) {
      if (mounted) {
        setState(() {
          _isGoogleInitialized = true;
        });
      }
    }).catchError((error) {
      debugPrint("Google Sign-In initialization error: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Google Sign-In: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('workers')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists && mounted) {
          final worker = Worker.fromFirestore(docSnapshot);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => worker.isAdmin
                  ? AdminDashboard(worker: worker)
                  : EmployeeDashboard(worker: worker),
            ),
          );
        }
      }
    });
  }

  void login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: username, password: password);

      if (userCredential.user != null) {
        final String uid = userCredential.user!.uid;
        final docSnapshot = await FirebaseFirestore.instance
            .collection('workers')
            .doc(uid)
            .get();

        if (docSnapshot.exists) {
          final worker = Worker.fromFirestore(docSnapshot);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => worker.isAdmin
                    ? AdminDashboard(worker: worker)
                    : EmployeeDashboard(worker: worker),
              ),
            );
          }
        } else {
          throw Exception('User profile not found in the database.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please check your credentials.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to handle the entire Google Sign-In flow
  Future<void> _signInWithGoogle() async {
    // Check if Google Sign-In is initialized on web
    if (kIsWeb && !_isGoogleInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In is initializing. Please wait a moment.'),
        ),
      );
      return;
    }

    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Use a web-specific flow for web builds to avoid calling
      // `authenticate()` (which throws on web). On web, use FirebaseAuth
      // `signInWithPopup` with a `GoogleAuthProvider`. On mobile, continue
      // using the google_sign_in package flow (authenticate()).
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        // Web: use FirebaseAuth signInWithPopup to show the Google popup.
        final provider = GoogleAuthProvider();
        final UserCredential webUserCredential =
            await FirebaseAuth.instance.signInWithPopup(provider);
        final User? webUser = webUserCredential.user;

        if (webUser == null) {
          if (mounted) setState(() => _isGoogleLoading = false);
          return;
        }

        // For the rest of the flow we have a Firebase `User` already,
        // so we can skip the google_sign_in account handling below and
        // fall through to the worker/document checks using `webUser`.
        final workerRef =
            FirebaseFirestore.instance.collection('workers').doc(webUser.uid);
        final docSnapshot = await workerRef.get();
        late final Worker worker;

        if (!docSnapshot.exists) {
          worker = Worker(
            uid: webUser.uid,
            name: webUser.displayName ?? 'New User',
            username: webUser.email ?? '${webUser.uid}@unknown',
            isAdmin: false,
            dailyRate: 0.0,
          );
          await workerRef.set(worker.toMap());
        } else {
          worker = Worker.fromFirestore(docSnapshot);
        }

        if (mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => worker.isAdmin
                  ? AdminDashboard(worker: worker)
                  : EmployeeDashboard(worker: worker),
            ),
          );
        }

        // Done for web.
        return;
      } else {
        // Mobile (Android/iOS): use the google_sign_in plugin flow.
        googleUser = await _googleSignIn.authenticate();
      }

      // Obtain auth details
  final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create credential - idToken is the primary thing Firebase needs.
      final credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential (mobile flow)
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final workerRef =
            FirebaseFirestore.instance.collection('workers').doc(user.uid);
        final docSnapshot = await workerRef.get();
        late final Worker worker;

        // 5. Check if user is new. If so, create a document for them.
        if (!docSnapshot.exists) {
          worker = Worker(
            uid: user.uid,
            name: user.displayName ?? 'New User',
            username: user.email!, // Google guarantees an email.
            isAdmin: false, // New users are never admins by default.
            dailyRate: 0.0, // Default daily rate.
          );
          await workerRef.set(worker.toMap());
        } else {
          worker = Worker.fromFirestore(docSnapshot);
        }

        // 6. Navigate to the correct dashboard.
        if (mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => worker.isAdmin
                  ? AdminDashboard(worker: worker)
                  : EmployeeDashboard(worker: worker),
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _resetPassword() async {
    final email = usernameController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email to reset password.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password reset link sent! Please check your email inbox (and spam folder).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'user-not-found') {
        // Obscure the message for security - don't confirm if a user exists
        message =
            'Password reset link sent! Please check your email inbox (and spam folder).';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                e.code == 'user-not-found' ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the Google button should be enabled
    final bool isGoogleButtonDisabled =
        _isGoogleLoading || (kIsWeb && !_isGoogleInitialized);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.roofing,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'CustomCraft App',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter your email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: _isPasswordObscured,
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter a password' : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordObscured = !_isPasswordObscured,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text("Forgot Password?"),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 8),
                // NEW: Google Sign-In Button
                _isGoogleLoading
                    ? const Center(child: CircularProgressIndicator())
                    : OutlinedButton.icon(
                        icon: SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              // Load the Google logo from local assets
                              Image.asset('assets/images/google_logo.png'),
                        ),
                        label: const Text('Sign in with Google'),
                        // UPDATED: Disable button on web until init is complete
                        onPressed: isGoogleButtonDisabled ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          // Optionally show a disabled state
                          disabledForegroundColor: Colors.grey.shade600,
                        ),
                      ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  ),
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

