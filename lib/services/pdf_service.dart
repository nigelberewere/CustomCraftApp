import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/quotation.dart';
import '../models/quotation_item.dart';
import '../constants/firestore_constants.dart';

class PdfService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> generateAndSharePdf(Quotation quotation) async {
    final pdf = pw.Document();

    String companyName = 'Custom Craft Carpenters';
    String companyContact = 'N/A';

    try {
      final settingsDoc = await _firestore
          .collection(FirestoreCollections.settings)
          .doc(FirestoreFields.companyConfig)
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        companyName = data[FirestoreFields.companyName] ?? companyName;
        companyContact = data[FirestoreFields.companyPhone] ?? companyContact;
      }
    } catch (e) {
      debugPrint('Error fetching company settings for PDF: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
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
                  "Date: ${DateFormat.yMMMd().format(quotation.creationDate)}",
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) {
          final Map<String, List<QuotationItem>> itemsByCategory = {};
          for (var item in quotation.items) {
            itemsByCategory[item.category] ??= [];
            itemsByCategory[item.category]!.add(item);
          }

          List<pw.Widget> content = [];
          content.add(
            pw.Text(
              "Quotation for: ${quotation.clientName}",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          );
          content.add(pw.SizedBox(height: 20));

          for (var entry in itemsByCategory.entries) {
            final category = entry.key;
            final items = entry.value;
            if (items.isEmpty) continue;

            content.add(pw.Header(level: 1, text: category));

            final tableData = items.map((item) {
              String name = item.displayName;
              if (item.name == 'IBR Sheet') {
                name =
                    '${item.thickness}mm x 686mm x ${item.length}m IBR Sheet';
              } else if (item.name == 'Roll top Ridges' ||
                  item.name == 'Valley gutters') {
                name = '${item.name} (${item.thickness}mm x 2.4m)';
              }

              String qty = item.quantity.toString();
              if (item.unit != null) {
                qty += ' ${item.unit}';
              }
              return [name, qty];
            }).toList();

            content.add(
              pw.TableHelper.fromTextArray(
                headers: ['Item Description', 'Quantity'],
                data: tableData,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(1),
                },
              ),
            );
            content.add(pw.SizedBox(height: 20));
          }

          if (quotation.additionalNotes != null &&
              quotation.additionalNotes!.isNotEmpty) {
            content.add(pw.SizedBox(height: 20));
            content.add(pw.Divider());
            content.add(pw.Header(level: 2, text: 'Additional Notes'));
            content.add(pw.Paragraph(text: quotation.additionalNotes!));
          }

          return content;
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
