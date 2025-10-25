import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker.dart';
import '../pages/company_settings_page.dart';
import '../pages/help_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/firestore_constants.dart';

class AppDrawer extends StatefulWidget {
  final Worker currentUser;
  final VoidCallback onLogout;
  const AppDrawer({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _settingsRef = FirebaseFirestore.instance
      .collection(FirestoreCollections.settings)
      .doc(FirestoreFields.companyConfig);

  void _sendFeedbackEmail() {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'nigelberewere@gmail.com',
      query: 'subject=Feedback for Custom Craft Carpenters App',
    );
    launchUrl(emailLaunchUri);
  }

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();

    String companyName = 'Custom Craft Carpenters';
    String companyPhone = 'N/A';
    String companyEmail = 'N/A';

    try {
      final doc = await _settingsRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        companyName = data[FirestoreFields.companyName] ?? companyName;
        companyPhone = data[FirestoreFields.companyPhone] ?? companyPhone;
        companyEmail = data[FirestoreFields.companyEmail] ?? companyEmail;
      }
    } catch (_) {
      // Keep default values if Firestore is unavailable
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: companyName,
        applicationVersion: 'Version ${packageInfo.version}',
        applicationIcon: const Icon(Icons.roofing, size: 48),
        applicationLegalese: '© 2025 $companyName',
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'This is a $companyName management app.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Contact Information:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(leading: const Icon(Icons.phone), title: Text(companyPhone)),
          ListTile(leading: const Icon(Icons.email), title: Text(companyEmail)),
          const Divider(),
          const SizedBox(height: 16),
          Text('Developed by:', style: Theme.of(context).textTheme.titleMedium),
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Nigel Berewere'),
            subtitle: Text(
              '+263 78 050 7162 \n+263 71 542 6206 \nnigelberewere@gmail.com',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _settingsRef.snapshots(),
            builder: (context, snapshot) {
              String companyName = 'Custom Craft Carpenters';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                companyName = data?[FirestoreFields.companyName] ?? companyName;
              }
              return DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.roofing,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      companyName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.currentUser.isAdmin)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Company Settings'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => const CompanySettingsPage(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              _showAboutDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => HelpPage(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send Feedback'),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              _sendFeedbackEmail();
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Logout',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }
}
