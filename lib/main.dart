import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/splash_page.dart';
import 'theme_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'auth_wrapper.dart';
import 'services/service_locator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  setupLocator();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const SuperApp(),
    ),
  );
}

// All async initializations now happen here.
Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // App Check initialization remains the same
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(
      '6LdUhNQrAAAAAFSMxln3w5DPx3MlwPgnbAXCW3yM',
    ),
    // Use the new providerAndroid parameter which accepts provider classes
    // (the older `androidProvider` parameter expects the AndroidProvider enum
    // and is deprecated).
    providerAndroid: const AndroidDebugProvider(),
  );
}

class SuperApp extends StatelessWidget {
  const SuperApp({super.key});

  static final Future<void> _initialization = _initializeApp();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        // MaterialApp itself handles theme transitions smoothly when its properties change.
        return MaterialApp(
          title: 'CustomCraft App',
          theme: themeNotifier.lightTheme,
          darkTheme: themeNotifier.darkTheme,
          themeMode: themeNotifier.themeMode,
          debugShowCheckedModeBanner: false,
          home: FutureBuilder(
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashPage();
              }

              if (snapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text('Error initializing app: ${snapshot.error}'),
                  ),
                );
              }

              return AuthWrapper();
            },
          ),
        );
      },
    );
  }
}
