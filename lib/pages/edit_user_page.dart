import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker.dart';

class EditUserPage extends StatefulWidget {
  final Worker worker;

  const EditUserPage({super.key, required this.worker});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _dailyRateController; // NEW: Controller for the daily rate
  late bool _isAdmin;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.worker.name);
    _usernameController = TextEditingController(text: widget.worker.username);
    // NEW: Initialize the daily rate controller
    _dailyRateController =
        TextEditingController(text: widget.worker.dailyRate.toString());
    _isAdmin = widget.worker.isAdmin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _dailyRateController.dispose(); // NEW: Dispose the controller
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final newUsername = _usernameController.text.trim();

    try {
      if (newUsername != widget.worker.username) {
        final existingUser = await FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: newUsername)
            .limit(1)
            .get();

        if (existingUser.docs.isNotEmpty) {
          messenger.showSnackBar(
            const SnackBar(
                content: Text(
                    'This username (email) is already in use by another account.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final workerRef = FirebaseFirestore.instance
          .collection('workers')
          .doc(widget.worker.uid);

      // UPDATED: Include the dailyRate in the data being saved.
      await workerRef.update({
        'name': _nameController.text.trim(),
        'username': newUsername,
        'isAdmin': _isAdmin,
        'dailyRate': double.tryParse(_dailyRateController.text) ?? 0.0,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('User details updated successfully!')),
      );

      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update user: ${e.toString()}')),
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        title: Text(
          'Edit ${widget.worker.name}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (val) =>
                val!.isEmpty ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration:
                const InputDecoration(labelText: 'Username (Email)'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) =>
                val!.isEmpty ? 'Username cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              // NEW: TextFormField for the daily rate.
              TextFormField(
                controller: _dailyRateController,
                decoration: const InputDecoration(
                    labelText: 'Daily Rate', prefixText: '\$ '),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a rate.';
                  }
                  if (double.tryParse(val) == null ||
                      double.parse(val) < 0) {
                    return 'Please enter a valid positive number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Administrator Privileges'),
                subtitle: const Text('Admins can manage users and projects.'),
                value: _isAdmin,
                onChanged: (newValue) {
                  setState(() {
                    _isAdmin = newValue;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveChanges,
                icon: _isLoading
                    ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Icon(Icons.save_alt_outlined),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
