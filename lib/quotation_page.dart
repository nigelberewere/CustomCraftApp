import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

// The QuotationItem class remains the same.
class QuotationItem {
  final String name;
  final int quantity;

  QuotationItem({required this.name, required this.quantity});
}

class QuotationPage extends StatefulWidget {
  const QuotationPage({super.key});

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  // All your state variables and logic (addItem, removeItem, etc.) remain the same.
  String clientName = "";
  final String companyName = "Your Company Name";
  final String companyContact = "Phone: 077-XXX-XXXX";
  final _formKey = GlobalKey<FormState>();

  final Map<String, List<String>> categoryItems = {
    'Timber': [
      '114x38x6 m',
      '152x38x6 m',
      '228x38x6 m',
      '76x38x6 m',
      '38x38x6 m',
    ],
    'Nails': ['3 inch wire nails', 'Sereted clout nails', '4 inch wire nails'],
    'Roofing Sheets': ['IBR Sheets', 'Corrugated Sheets'],
  };

  final Map<String, List<QuotationItem>> itemsByCategory = {
    'Timber': [],
    'Nails': [],
    'Roofing Sheets': [],
  };

  final Map<String, String?> selectedItems = {
    'Timber': null,
    'Nails': null,
    'Roofing Sheets': null,
  };

  final Map<String, TextEditingController> quantityControllers = {
    'Timber': TextEditingController(),
    'Nails': TextEditingController(),
    'Roofing Sheets': TextEditingController(),
  };

  void addItem(String category) {
    // This logic is unchanged
    final selectedItemName = selectedItems[category];
    final quantityText = quantityControllers[category]!.text;
    final quantity = int.tryParse(quantityText);

    if (selectedItemName == null || selectedItemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an item for $category.')),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid quantity for $category.')),
      );
      return;
    }
    final newItem = QuotationItem(name: selectedItemName, quantity: quantity);
    setState(() {
      itemsByCategory[category]!.add(newItem);
      quantityControllers[category]!.clear();
      selectedItems[category] = null;
    });
  }

  void removeItem(String category, QuotationItem itemToRemove) {
    // This logic is unchanged
    setState(() {
      itemsByCategory[category]!.remove(itemToRemove);
    });
  }

  Future<void> generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    final bool hasItems = itemsByCategory.values.any((list) => list.isNotEmpty);
    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item.')),
      );
      return;
    }

    // Capture navigator & messenger before async gaps
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      // PDF generation logic is unchanged
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(companyContact),
                      ],
                    ),
                    pw.Text(
                      "Date: ${DateTime.now().toLocal().toString().split(' ')[0]}",
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  "Quotation for: $clientName",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(height: 30),
                ...itemsByCategory.entries.map((entry) {
                  final category = entry.key;
                  final items = entry.value;
                  if (items.isEmpty) {
                    return pw.Container();
                  }
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        category,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.TableHelper.fromTextArray(
                        headers: ['Item', 'Quantity'],
                        data: items
                            .map((item) {
                              String qty = item.quantity.toString();
                              if (category == 'Nails') qty += ' Kgs';
                              return <dynamic>[item.name, qty];
                            })
                            .toList()
                            .cast<List<dynamic>>(),
                        border: pw.TableBorder.all(),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                        ),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        cellAlignment: pw.Alignment.centerLeft,
                        cellPadding: const pw.EdgeInsets.all(5),
                      ),
                      pw.SizedBox(height: 20),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      // Hide loading dialog
      navigator.pop();
    }
  }

  @override
  void dispose() {
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // REFACTORED BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation Generator')),
      // Use a ListView for better structure and performance
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Client Name Input
            TextFormField(
              onChanged: (value) => clientName = value,
              decoration: const InputDecoration(
                labelText: "Client Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter client name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Build category sections using ExpansionTiles
            ...categoryItems.keys.map(
              (category) => _buildCategorySection(category),
            ),
          ],
        ),
      ),
      // Use a FloatingActionButton for the primary action
      floatingActionButton: FloatingActionButton.extended(
        onPressed: generatePDF,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Generate PDF"),
      ),
    );
  }

  // NEW: Refactored category section using ExpansionTile
  Widget _buildCategorySection(String category) {
    final items = itemsByCategory[category]!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior:
          Clip.antiAlias, // Ensures the ExpansionTile ink splash is clipped
      child: ExpansionTile(
        title: Text(
          category,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${items.length} item(s) added'),
        childrenPadding: const EdgeInsets.all(16.0),
        initiallyExpanded:
            category == 'Timber', // Open the first category by default
        children: [
          // Input fields organized in a Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedItems[category],
                  hint: const Text("Select item"),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: categoryItems[category]!
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedItems[category] = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: quantityControllers[category],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Qty",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => addItem(category),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add Item"),
            ),
          ),
          const Divider(height: 24),

          // Display added items or an "empty state" message
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  "No items added yet.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...items.map((item) {
              String subtitleText =
                  'Quantity: ${item.quantity} ${category == 'Nails' ? 'Kgs' : ''}';
              return ListTile(
                title: Text(item.name),
                subtitle: Text(subtitleText),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => removeItem(category, item),
                ),
              );
            }),
        ],
      ),
    );
  }
}
