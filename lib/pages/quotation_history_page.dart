import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/quotation.dart';
import '../services/quotation_service.dart';
import 'quotation_page.dart';
import 'quotation_viewer_page.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'ai_quotation_status_page.dart';
import '../constants/firestore_constants.dart';
import '../services/service_locator.dart';

class QuotationHistoryPage extends StatefulWidget {
  const QuotationHistoryPage({super.key});

  @override
  State<QuotationHistoryPage> createState() => _QuotationHistoryPageState();
}

class _QuotationHistoryPageState extends State<QuotationHistoryPage> {
  final QuotationService _quotationService = getIt<QuotationService>();
  String _searchQuery = '';

  void _showDeleteConfirmDialog(BuildContext context, Quotation quotation) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Please Confirm'),
          content: Text(
            'Are you sure you want to permanently delete the quotation for "${quotation.clientName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteQuotation(quotation);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickPlan() async {
    final navigator = Navigator.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      dialogTitle: 'Select a House Plan',
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => AiQuotationStatusPage(file: file)),
      );
    }
  }

  void _deleteQuotation(Quotation quotation) {
    FirebaseFirestore.instance
        .collection(FirestoreCollections.quotations)
        .doc(quotation.id)
        .delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quotation deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation History'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Color.lerp(
                    Theme.of(context).colorScheme.primary, Colors.black, 0.2)!
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Search by Client or Floor Area',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.quotations)
                  .orderBy(FirestoreFields.creationDate, descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No quotations found.'));
                }

                final allQuotations = snapshot.data!.docs
                    .map((doc) => Quotation.fromFirestore(doc))
                    .toList();

                final filteredQuotations = allQuotations.where((q) {
                  final clientMatch = q.clientName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  final areaMatch = q.floorArea != null &&
                      q.floorArea.toString().contains(_searchQuery);
                  return _searchQuery.isEmpty || clientMatch || areaMatch;
                }).toList();

                if (filteredQuotations.isEmpty) {
                  return const Center(
                    child: Text('No quotations match your search.'),
                  );
                }
                return ListView.builder(
                  itemCount: filteredQuotations.length,
                  itemBuilder: (context, index) {
                    final quotation = filteredQuotations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(quotation.clientName),
                        subtitle: Text(
                          'Date: ${DateFormat.yMMMd().format(quotation.creationDate)} - Area: ${quotation.floorArea ?? 'N/A'} m²',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuotationViewerPage(quotation: quotation),
                            ),
                          );
                        },
                        trailing: PopupMenuButton(
                          onSelected: (value) async {
                            final navigator = Navigator.of(context);
                            if (value == 'edit') {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      QuotationPage(quotation: quotation),
                                ),
                              );
                            } else if (value == 'duplicate') {
                              final newQuotation =
                                  await _quotationService.duplicateQuotation(
                                quotation,
                              );
                              if (!mounted) return;
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      QuotationPage(quotation: newQuotation),
                                ),
                              );
                            } else if (value == 'share') {
                              // FIX: Use the updated Share API
                              final textToShare = _quotationService
                                  .generateShareableText(quotation);
                              SharePlus.instance.share(
                                ShareParams(
                                  text: textToShare,
                                  subject: 'Quotation for ${quotation.clientName}',
                                ),
                              );
                            } else if (value == 'delete') {
                              _showDeleteConfirmDialog(context, quotation);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: ListTile(
                                leading: Icon(Icons.copy),
                                title: Text('Duplicate & Edit'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: ListTile(
                                leading: Icon(Icons.share),
                                title: Text('Share'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _pickPlan,
            label: const Text('New AI Quotation'),
            icon: const Icon(Icons.auto_awesome),
            heroTag: 'ai_quotation_fab',
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuotationPage()),
            ),
            label: const Text('New Manual Quotation'),
            icon: const Icon(Icons.add),
            heroTag: 'manual_quotation_fab',
          ),
        ],
      ),
    );
  }
}
