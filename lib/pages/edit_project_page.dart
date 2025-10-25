import 'package:flutter/material.dart';
import '../models/project.dart';
//import '../models/quotation.dart'; // Import Quotation model
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProjectPage extends StatefulWidget {
  final Project project;

  const EditProjectPage({super.key, required this.project});

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

// lib/pages/edit_project_page.dart

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  // Renamed for consistency with the Project model
  String? _selectedQuotationId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);

    // --- THIS IS THE FIX ---
    // Use the correct field name 'quotationId'
    _selectedQuotationId = widget.project.quotationId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id);

      projectRef.update({
        'name': _nameController.text.trim(),
        'quotationId': _selectedQuotationId, // Use the renamed variable
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project updated successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.project.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Project Name'),
                validator: (val) =>
                    val!.trim().isEmpty ? 'Project name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('quotations')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final items = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['clientName']),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    initialValue:
                        _selectedQuotationId, // Use the renamed variable
                    decoration: const InputDecoration(
                      labelText: 'Link to Quotation (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...items,
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedQuotationId =
                            value; // Use the renamed variable
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
