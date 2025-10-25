import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/quotation.dart';
import '../models/quotation_item.dart';
import '../services/pdf_service.dart';
import 'truss_calculator_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuotationPage extends StatefulWidget {
  final Quotation? quotation;
  const QuotationPage({super.key, this.quotation});

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  // --- Controllers for main form ---
  late final TextEditingController _clientNameController;
  late final TextEditingController _floorAreaController;
  late final TextEditingController _additionalNotesController;
  final _formKey = GlobalKey<FormState>();
  final PdfService _pdfService = PdfService();


  final Map<String, List<QuotationItem>> _itemsByCategory = {
    'Timber': [],
    'Nails & Fasteners': [],
    'Roofing Materials': [],
    'Hardware & Accessories': [],
    'Custom Items': [],
  };

  // --- State for the temporary item forms ---
  String? _selectedCategory;
  String? _selectedItem;
  final _quantityController = TextEditingController();
  final _customItemController = TextEditingController();
  final _customUnitController = TextEditingController();

  // NEW: To track the most recently modified category
  String? _lastModifiedCategory;

  // State for the IBR Sheet form
  String? _selectedIbrThickness;
  final List<Map<String, TextEditingController>> _ibrLengthQuantityControllers =
      [];
  final _ridgeQtyController = TextEditingController();
  final _gutterQtyController = TextEditingController();
  final _safetopNailQtyController = TextEditingController();

  final Map<String, List<String>> categoryOptions = {
    'Timber': ['38x38x6m', '76x38x6m', '114x38x6m', '152x38x6m', '228x38x6m'],
    'Nails & Fasteners': [
      '3 inch wire nails',
      '4 inch wire nails',
      '5 inch wire nails',
      '6 inch wire nails',
      'Sereted clout nails',
      'Clout nails (4mm)',
      'Roofing bolts m10 x 120mm',
      'Roofing bolts m10 x 160mm',
    ],
    'Roofing Materials': [
      'Concrete tiles',
      'IBR sheets',
      'Harvey tiles',
      'Q tiles',
    ],
    'Hardware & Accessories': [
      'Single truss hangers',
      'Double truss hangers',
      'Tying wire',
      'Asbestors fascia 225x3.6m',
      'Steel cutting disc',
      'Diamond cutting disc',
      'Steel bit 10mm',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.quotation != null) {
      _clientNameController = TextEditingController(
        text: widget.quotation!.clientName,
      );
      _floorAreaController = TextEditingController(
        text: widget.quotation!.floorArea?.toString() ?? '',
      );
      _additionalNotesController = TextEditingController(
        text: widget.quotation!.additionalNotes ?? '',
      );
      for (var item in widget.quotation!.items) {
        _itemsByCategory[item.category]?.add(item);
      }
    } else {
      _clientNameController = TextEditingController();
      _floorAreaController = TextEditingController();
      _additionalNotesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _floorAreaController.dispose();
    _additionalNotesController.dispose();
    _quantityController.dispose();
    _customItemController.dispose();
    _customUnitController.dispose();
    for (final map in _ibrLengthQuantityControllers) {
      map['length']!.dispose();
      map['quantity']!.dispose();
    }
    _ridgeQtyController.dispose();
    _gutterQtyController.dispose();
    _safetopNailQtyController.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---

  void _showEditQuantityDialog(QuotationItem item) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Quantity for ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity > 0) {
                setState(() {
                  item.quantity = newQuantity;
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _generateAndShareText(Quotation quotation) {
    final buffer = StringBuffer();
    buffer.writeln('--- QUOTATION ---');
    buffer.writeln('Client: ${quotation.clientName}');
    buffer.writeln(
      'Date: ${DateFormat.yMMMd().format(quotation.creationDate)}',
    );
    if (quotation.floorArea != null) {
      buffer.writeln('Floor Area: ${quotation.floorArea} m²');
    }
    buffer.writeln('--------------------');

    final Map<String, List<QuotationItem>> itemsByCategory = {};
    for (var item in quotation.items) {
      itemsByCategory[item.category] ??= [];
      itemsByCategory[item.category]!.add(item);
    }

    for (var entry in itemsByCategory.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      buffer.writeln('\n-- ${entry.key.toUpperCase()} --');
      for (var item in entry.value) {
        String name = item.name;
        if (item.name == 'IBR Sheet') {
          name = '${item.thickness}mm x 686mm x ${item.length}m IBR Sheet';
        } else if (item.name == 'Roll top Ridges' ||
            item.name == 'Valley gutters') {
          name = '${item.name} (${item.thickness}mm x 2.4m)';
        }
        buffer.writeln('$name: ${item.quantity} ${item.unit ?? ''}'.trim());
      }
    }

    if (quotation.additionalNotes != null &&
        quotation.additionalNotes!.isNotEmpty) {
      buffer.writeln('\n-- Additional Notes --');
      buffer.writeln(quotation.additionalNotes);
    }

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Quotation for ${quotation.clientName}',
      ),
    );
  }

  void _addItem() {
    if (_selectedCategory == null || _selectedItem == null) return;

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
      );
      return;
    }

    String? unit;
    String itemName = _selectedItem!;
    // This is the logic that assigns the correct unit
    if (itemName.contains('(bundles)')) {
      unit = 'bundles';
    } else if (itemName.contains('nails') || itemName.contains('Tying wire')) {
      unit = 'kgs';
    }

    final newItem = QuotationItem(
      category: _selectedCategory!,
      name: itemName,
      quantity: quantity,
      unit: unit,
    );

    setState(() {
      // Insert at start so the most recently added item appears first
      _itemsByCategory[_selectedCategory!]!.insert(0, newItem);
      _lastModifiedCategory = _selectedCategory; // track last modified
      _quantityController.clear();
      _selectedItem = null;
    });
  }

  void _addIbrItems() {
    final List<QuotationItem> newItems = [];
    final double? thickness = double.tryParse(_selectedIbrThickness ?? '0');

    for (var controllerMap in _ibrLengthQuantityControllers) {
      final length = double.tryParse(controllerMap['length']!.text);
      final quantity = int.tryParse(controllerMap['quantity']!.text);
      if (length != null && length > 0 && quantity != null && quantity > 0) {
        newItems.add(
          QuotationItem(
            category: 'Roofing Materials',
            name: 'IBR Sheet',
            quantity: quantity,
            thickness: thickness,
            length: length,
          ),
        );
      }
    }

    final ridgeQty = int.tryParse(_ridgeQtyController.text);
    if (ridgeQty != null && ridgeQty > 0) {
      newItems.add(
        QuotationItem(
          category: 'Roofing Materials',
          name: 'Roll top Ridges',
          quantity: ridgeQty,
          thickness: thickness,
        ),
      );
    }

    final gutterQty = int.tryParse(_gutterQtyController.text);
    if (gutterQty != null && gutterQty > 0) {
      newItems.add(
        QuotationItem(
          category: 'Roofing Materials',
          name: 'Valley gutters',
          quantity: gutterQty,
          thickness: thickness,
        ),
      );
    }

    final nailQty = int.tryParse(_safetopNailQtyController.text);
    if (nailQty != null && nailQty > 0) {
      newItems.add(
        QuotationItem(
          category: 'Nails & Fasteners',
          name: 'Safetop roofing nails 75mm',
          quantity: nailQty,
          unit: 'kgs',
        ),
      );
    }

    setState(() {
      // Insert newItems so that the last item added becomes the first in the list
      if (newItems.isNotEmpty) {
        _itemsByCategory['Roofing Materials']!.insertAll(0, newItems.reversed);
      }
      _lastModifiedCategory = 'Roofing Materials'; // track last modified
      _selectedIbrThickness = null;
      for (final map in _ibrLengthQuantityControllers) {
        map['length']!.dispose();
        map['quantity']!.dispose();
      }
      _ibrLengthQuantityControllers.clear();
      _ridgeQtyController.clear();
      _gutterQtyController.clear();
      _safetopNailQtyController.clear();
      _selectedItem = null;
    });
  }

  void _addCustomItem() {
    final name = _customItemController.text.trim();
    final quantity = int.tryParse(_quantityController.text);
    final unit = _customUnitController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for the custom item.'),
        ),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
      );
      return;
    }

    final newItem = QuotationItem(
      category: 'Custom Items',
      name: name,
      quantity: quantity,
      unit: unit.isNotEmpty ? unit : null,
    );

    setState(() {
      // Put the custom item at the front so it appears first
      _itemsByCategory['Custom Items']!.insert(0, newItem);
      _lastModifiedCategory = 'Custom Items'; // track last modified
      _customItemController.clear();
      _quantityController.clear();
      _customUnitController.clear();
    });

    Navigator.of(context).pop();
  }

  void removeItem(String category, QuotationItem itemToRemove) {
    setState(() {
      _itemsByCategory[category]!.remove(itemToRemove);
    });
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final allItems = _itemsByCategory.values.expand((list) => list).toList();

    Quotation finalQuotation;
    if (widget.quotation != null) {
      // We are editing an existing quotation
      final q = widget.quotation!;
      q.clientName = _clientNameController.text.trim();
      q.floorArea = double.tryParse(_floorAreaController.text.trim());
      q.additionalNotes = _additionalNotesController.text.trim();
      q.items = allItems; // Assign the updated list
      finalQuotation = q;

      // Update the document in Firestore
      await FirebaseFirestore.instance
          .collection('quotations')
          .doc(finalQuotation.id)
          .update(finalQuotation.toMap());
    } else {
      // We are creating a new quotation
      finalQuotation = Quotation(
        clientName: _clientNameController.text.trim(),
        creationDate: DateTime.now(),
        floorArea: double.tryParse(_floorAreaController.text.trim()),
        additionalNotes: _additionalNotesController.text.trim(),
        items: allItems, // <-- CORRECT: Use the simple List
      );

      // Add a new document to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('quotations')
          .add(finalQuotation.toMap());

      finalQuotation.id = docRef.id; // Store the new ID
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quotation saved successfully!'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _showShareOptions(finalQuotation),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _showShareOptions(Quotation quotation) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Share as Text'),
            onTap: () {
              Navigator.of(ctx).pop();
              _generateAndShareText(quotation);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Share as PDF'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pdfService.generateAndSharePdf(quotation);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Share as Picture (Coming Soon)'),
            onTap: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This feature is not yet available.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- UI BUILDING METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quotation == null ? 'New Quotation' : 'Edit Quotation',
        ),
        // ENHANCEMENT: Add a subtle gradient to the AppBar.
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Color.lerp(Theme.of(context).colorScheme.primary, Colors.black, 0.2)!
              ],
            ),
          ),
        ),
        actions: [
          // NEW: Calculator button
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Truss Calculator',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrussCalculatorPage(isAdmin: false),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Save Quotation',
            onPressed: () {
              _saveQuotation();
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'Client Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val!.trim().isEmpty ? 'Please enter a client name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _floorAreaController,
              decoration: const InputDecoration(
                labelText: 'Floor Area (m²)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const Divider(height: 32),
            _buildItemAdder(),
            const Divider(height: 32),
            _buildAddedItemsList(),
            const SizedBox(height: 24),
            TextFormField(
              controller: _additionalNotesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (e.g., Generator Hire)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemAdder() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              hint: const Text("Select Category"),
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: categoryOptions.keys
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedCategory = value;
                _selectedItem = null;
              }),
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final addedItemNames = _itemsByCategory[_selectedCategory!]!
                      .map((item) => item.name)
                      .toSet();
                  final availableOptions = categoryOptions[_selectedCategory]!
                      .where((option) => !addedItemNames.contains(option))
                      .toList();

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedItem,
                    hint: const Text("Select Item"),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: availableOptions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedItem = value),
                  );
                },
              ),
            ],
            if (_selectedItem != null) ...[
              const SizedBox(height: 16),
              if (_selectedItem == 'IBR sheets')
                _buildIbrSheetForm()
              else
                _buildSimpleQuantityForm(),
            ],
            const Divider(height: 24, thickness: 1),
            Center(
              child: TextButton(
                onPressed: _showCustomItemDialog,
                child: const Text('Add a Custom Item?'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleQuantityForm() {
    return Column(
      children: [
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Quantity",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text("Add Item"),
          ),
        ),
      ],
    );
  }

  Widget _buildIbrSheetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedIbrThickness,
          hint: const Text("Select Sheet Thickness"),
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ['0.1', '0.2', '0.3', '0.4', '0.5']
              .map((t) => DropdownMenuItem(value: t, child: Text('$t mm')))
              .toList(),
          onChanged: (value) => setState(() => _selectedIbrThickness = value),
        ),
        if (_selectedIbrThickness != null) ...[
          const Divider(height: 24),
          Text(
            'IBR Sheet Lengths',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ibrLengthQuantityControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            _ibrLengthQuantityControllers[index]['length'],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Length (m)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller:
                            _ibrLengthQuantityControllers[index]['quantity'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(
                        () => _ibrLengthQuantityControllers.removeAt(index),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Length'),
            onPressed: () => setState(() {
              _ibrLengthQuantityControllers.add({
                'length': TextEditingController(),
                'quantity': TextEditingController(),
              });
            }),
          ),
          const Divider(height: 24),
          Text(
            'Associated Items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            title: Text('Roll top Ridges (${_selectedIbrThickness}mm x 2.4m)'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: _ridgeQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
          ),
          ListTile(
            title: Text('Valley gutters (${_selectedIbrThickness}mm x 2.4m)'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: _gutterQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
          ),
          ListTile(
            title: const Text('Safetop roofing nails 75mm'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: _safetopNailQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty (kgs)'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addIbrItems,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add All Roofing Items"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddedItemsList() {
    final bool hasItems = _itemsByCategory.values.any(
      (list) => list.isNotEmpty,
    );
    if (!hasItems) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            "No items added to this quotation yet.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // --- NEW SORTING LOGIC ---
    // Get the original order of keys
    final sortedCategoryKeys = _itemsByCategory.keys.toList();

    // If a category was recently modified, move it to the front of the list
    if (_lastModifiedCategory != null) {
      sortedCategoryKeys.remove(_lastModifiedCategory);
      sortedCategoryKeys.insert(0, _lastModifiedCategory!);
    }
    // --- END OF SORTING LOGIC ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Iterate over the NEW sorted list of keys
      children: sortedCategoryKeys.map((categoryKey) {
        final itemsForCategory = _itemsByCategory[categoryKey]!;
        if (itemsForCategory.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                categoryKey,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...itemsForCategory.map((item) {
              String titleText =
                  item.displayName; // Using the getter from the model

              // The subtitle now correctly displays the unit from the item object
              return ListTile(
                title: Text(titleText),
                subtitle: Text(
                  'Quantity: ${item.quantity} ${item.unit ?? ''}'.trim(),
                ),
                onTap: () => _showEditQuantityDialog(item),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    // When removing an item, also update the state
                    setState(() {
                      _itemsByCategory[categoryKey]!.remove(item);
                    });
                  },
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  void _showCustomItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customItemController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _customUnitController,
              decoration: const InputDecoration(
                labelText: 'Unit (e.g., "boxes", "litres")',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _addCustomItem, child: const Text('Add')),
        ],
      ),
    );
  }
}
