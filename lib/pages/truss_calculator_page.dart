import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class TrussCalculatorPage extends StatefulWidget {
  final bool isAdmin;
  const TrussCalculatorPage({super.key, required this.isAdmin});

  @override
  State<TrussCalculatorPage> createState() => _TrussCalculatorPageState();
}

class _TrussCalculatorPageState extends State<TrussCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _spanController = TextEditingController();
  final _pitchController = TextEditingController();

  Map<String, double>? _results;

  // NEW: A reference to the single document where settings are stored
  final _settingsRef =
      FirebaseFirestore.instance.collection('settings').doc('company_config');

  Future<void> _saveSetting(String key, dynamic value) async {
    // Use .set with merge:true to create or update the field
    await _settingsRef.set({key: value}, SetOptions(merge: true));
  }

  // UPDATED: This function now receives the settings from the StreamBuilder
  void _calculateTruss({
    required bool showTieBeam,
    required bool showRafter,
    required bool showHalfSpan,
    required bool showRoofingSheet,
    required double roofingOverlap,
    required double rafterEve,
  }) {
    if (_formKey.currentState!.validate()) {
      final double span = double.parse(_spanController.text);
      final double pitch = double.parse(_pitchController.text);

      final double halfSpan = span / 2;
      final double pitchRadians = pitch * (pi / 180);

      final double rafterLength = (halfSpan / cos(pitchRadians)) + rafterEve;
      final double kingPostLength = halfSpan * tan(pitchRadians);
      final double roofingSheetLength = (halfSpan / cos(pitchRadians)) + roofingOverlap;

      setState(() {
        _results = {};
        _results!['King Post'] = kingPostLength;
        if (showHalfSpan) {
          _results!['Half Span'] = halfSpan;
        }
        if (showTieBeam) {
          _results!['Tie Beam'] = span;
        }
        if (showRafter) {
          _results!['Rafter (x2)'] = rafterLength;
        }
        if (showRoofingSheet) {
          _results!['Roofing Sheet Length'] = roofingSheetLength;
        }
      });
    }
  }

  // UPDATED: This dialog now receives the current overlap value and saves to Firestore
  void _showOverlapDialog(double currentOverlap) {
    final controller = TextEditingController(text: currentOverlap.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Roofing Overlap'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Overlap (meters)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                // Call the new save function
                _saveSetting('calc_roofingOverlap', value);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRafterEveDialog(double currentEve) {
    final controller = TextEditingController(text: currentEve.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Rafter Eve'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Eve (meters)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                // Call the new save function
                _saveSetting('calc_rafterEve', value);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _spanController.dispose();
    _pitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Wrap the entire page in a StreamBuilder to get live settings
    return StreamBuilder<DocumentSnapshot>(
      stream: _settingsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Error loading settings.')),
          );
        }

        // Extract settings from the snapshot, with default values
        final settings = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isCalculatorVisible =
            settings['isCalculatorVisible'] as bool? ?? true; // Main visibility
        final showTieBeam = settings['calc_showTieBeam'] as bool? ?? true;
        final showRafter = settings['calc_showRafter'] as bool? ?? true;
        final showHalfSpan = settings['calc_showHalfSpan'] as bool? ?? true;
        final showRoofingSheet =
            settings['calc_showRoofingSheet'] as bool? ?? true;
        final roofingOverlap =
            (settings['calc_roofingOverlap'] as num?)?.toDouble() ?? 0.5;
        final rafterEve =
            (settings['calc_rafterEve'] as num?)?.toDouble() ?? 0.0;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: IconThemeData(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            title: Text(
              'King Post Truss Calculator',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            centerTitle: true,
            elevation: 2,
            actions: [
              if (widget.isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // UPDATED: Use the new single save function
                    if (value == 'toggle_visibility') {
                      _saveSetting('isCalculatorVisible', !isCalculatorVisible);
                    }
                    if (value == 'toggle_tiebeam') {
                      _saveSetting('calc_showTieBeam', !showTieBeam);
                    }
                    if (value == 'toggle_rafter') {
                      _saveSetting('calc_showRafter', !showRafter);
                    }
                    if (value == 'toggle_halfspan') {
                      _saveSetting('calc_showHalfSpan', !showHalfSpan);
                    }
                    if (value == 'toggle_roofing') {
                      _saveSetting('calc_showRoofingSheet', !showRoofingSheet);
                    }
                    if (value == 'set_overlap') {
                      _showOverlapDialog(roofingOverlap);
                    }
                    if (value == 'set_rafter_eve') {
                      _showRafterEveDialog(rafterEve);
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    CheckedPopupMenuItem<String>(
                      checked: isCalculatorVisible,
                      value: 'toggle_visibility',
                      child: const Text('Show for Everyone'),
                    ),
                    const PopupMenuDivider(),
                    CheckedPopupMenuItem<String>(
                      checked: showHalfSpan,
                      value: 'toggle_halfspan',
                      child: const Text('Include Half Span'),
                    ),
                    CheckedPopupMenuItem<String>(
                      checked: showTieBeam,
                      value: 'toggle_tiebeam',
                      child: const Text('Include Tie Beam'),
                    ),
                    CheckedPopupMenuItem<String>(
                      checked: showRafter,
                      value: 'toggle_rafter',
                      child: const Text('Include Rafter'),
                    ),
                    CheckedPopupMenuItem<String>(
                      checked: showRoofingSheet,
                      value: 'toggle_roofing',
                      child: const Text('Include Roofing Sheet'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'set_overlap',
                      child: Text(
                          'Set Overlap (${roofingOverlap.toStringAsFixed(2)}m)'),
                    ),
                    PopupMenuItem<String>(
                      value: 'set_rafter_eve',
                      child: Text(
                          'Set Rafter Eve (${rafterEve.toStringAsFixed(2)}m)'),
                    ),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _spanController,
                    decoration: const InputDecoration(
                      labelText: 'Roof Span / Width (meters)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (val) =>
                        val!.isEmpty ? 'Please enter a span' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pitchController,
                    decoration: const InputDecoration(
                      labelText: 'Roof Pitch (degrees)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (val) =>
                        val!.isEmpty ? 'Please enter a pitch' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    // UPDATED: Pass the live settings to the calculate function
                    onPressed: () => _calculateTruss(
                      showTieBeam: showTieBeam,
                      showRafter: showRafter,
                      showHalfSpan: showHalfSpan,
                      showRoofingSheet: showRoofingSheet,
                      roofingOverlap: roofingOverlap,
                      rafterEve: rafterEve,
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calculate'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_results != null) ...[
                    const Divider(height: 48),
                    Text(
                      'Calculated Timber Lengths:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: _results!.entries.map((entry) {
                          return ListTile(
                            title: Text(entry.key),
                            trailing: Text(
                              '${entry.value.toStringAsFixed(3)} m',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
