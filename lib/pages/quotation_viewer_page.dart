import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/quotation.dart';
import '../services/pdf_service.dart';
import 'quotation_page.dart';
import '../services/quotation_service.dart';
import '../services/service_locator.dart';

class QuotationViewerPage extends StatefulWidget {
  final Quotation quotation;
  const QuotationViewerPage({super.key, required this.quotation});

  @override
  State<QuotationViewerPage> createState() => _QuotationViewerPageState();
}

class _QuotationViewerPageState extends State<QuotationViewerPage> {
  final QuotationService _quotationService = getIt<QuotationService>();
  final PdfService _pdfService = getIt<PdfService>();

  void _showShareOptions(BuildContext context, Quotation quotation) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Share as Text'),
            onTap: () {
              Navigator.of(ctx).pop();
              final textToShare = _quotationService.generateShareableText(
                quotation,
              );
              // FIX: Use the updated Share API
              SharePlus.instance.share(
                ShareParams(
                  text: textToShare,
                  subject: 'Quotation for ${quotation.clientName}',
                ),
              );
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
        ],
      ),
    );
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
          'View Quotation',
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
          PopupMenuButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onSelected: (value) async {
              final navigator = Navigator.of(context);
              if (value == 'edit') {
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => QuotationPage(quotation: widget.quotation),
                  ),
                );
              } else if (value == 'duplicate') {
                final newQuotation =
                    await _quotationService.duplicateQuotation(
                  widget.quotation,
                );
                if (!mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => QuotationPage(quotation: newQuotation),
                  ),
                );
              } else if (value == 'share') {
                _showShareOptions(context, widget.quotation);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_copy_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Duplicate & Edit',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(
                      Icons.share_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Share',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client: ${widget.quotation.clientName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${DateFormat.yMMMd().format(widget.quotation.creationDate)}',
                  ),
                  if (widget.quotation.floorArea != null) ...[
                    const SizedBox(height: 4),
                    Text('Floor Area: ${widget.quotation.floorArea} m²'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Qty'), numeric: true),
            ],
            rows: widget.quotation.items.map((item) {
              final titleText = item.displayName;
              final qtyText = ' ${item.quantity} ${item.unit ?? ''}'.trim();
              return DataRow(
                cells: [DataCell(Text(titleText)), DataCell(Text(qtyText))],
              );
            }).toList(),
          ),
          if (widget.quotation.additionalNotes != null &&
              widget.quotation.additionalNotes!.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(height: 16),
                    Text(widget.quotation.additionalNotes!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

