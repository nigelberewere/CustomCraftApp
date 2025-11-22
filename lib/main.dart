import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
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
  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(
        '6Ld_YAAsAAAAAAZb1Imug35f-tK5bq6fEWrCgAQP',
      ),
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      // Add providerApple if needed
    );
  }
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
