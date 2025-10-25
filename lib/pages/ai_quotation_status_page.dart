import 'dart:io';
import 'package:flutter/material.dart';

class AiQuotationStatusPage extends StatefulWidget {
  final File file; // The file the user picked
  const AiQuotationStatusPage({super.key, required this.file});

  @override
  State<AiQuotationStatusPage> createState() => _AiQuotationStatusPageState();
}

class _AiQuotationStatusPageState extends State<AiQuotationStatusPage> {
  // In the future, this state will be updated by the backend process.
  // For now, we'll keep it simple.
  final int _currentStep = 0; // 0 = Uploading, 1 = Analyzing, 2 = Complete

  @override
  void initState() {
    super.initState();
    // Here is where you will eventually start the actual upload process.
    // For now, we'll just simulate it.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating AI Quotation')),
      body: Stepper(
        currentStep: _currentStep,
        controlsBuilder: (context, details) {
          // This removes the default "Continue" and "Cancel" buttons
          return const SizedBox.shrink();
        },
        steps: [
          Step(
            title: const Text('Uploading Plan'),
            content: Text(
              'Uploading your plan: ${widget.file.path.split('/').last}',
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Analyzing Plan'),
            content: const Text(
              'Our AI is reading the dimensions and materials...',
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Quotation Ready'),
            content: const Text('Your new quotation has been generated!'),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
