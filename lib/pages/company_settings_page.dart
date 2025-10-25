// CHANGED: Import for cloud_firestore, remove shared_preferences
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // NEW: A reference to the single document where settings are stored.
  final _settingsRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('company_config');

  // NEW: State for loading indicator on save button
  bool _isLoading = false;

  // REMOVED: The old `_loadSettings` function is no longer needed because
  // the StreamBuilder will handle loading the data.

  // CHANGED: The `_saveSettings` function now writes to Firestore.
  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Use .set with merge:true to create or update the document
        await _settingsRef.set({
          'companyName': _nameController.text.trim(),
          'companyPhone': _phoneController.text.trim(),
          'companyEmail': _emailController.text.trim(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company details saved!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save settings: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Settings')),
      // NEW: Use a StreamBuilder to listen for real-time changes to the settings
      body: StreamBuilder<DocumentSnapshot>(
        stream: _settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading company details.'));
          }

          // Get data from snapshot, or use default values if document doesn't exist yet
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            _nameController.text =
                data['companyName'] ?? 'Custom Craft Carpenters';
            _phoneController.text = data['companyPhone'] ?? '';
            _emailController.text = data['companyEmail'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                    ),
                    validator: (val) =>
                        val!.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Company Phone',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val!.isEmpty ? 'Please enter a phone number' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Company Email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) =>
                        val!.isEmpty ? 'Please enter an email' : null,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Settings'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
