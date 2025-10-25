import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/quotation.dart';
import '../models/quotation_item.dart';
import '../constants/firestore_constants.dart';

class QuotationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String generateShareableText(Quotation quotation) {
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
      if (entry.value.isEmpty) continue;
      buffer.writeln('\n-- ${entry.key.toUpperCase()} --');
      for (var item in entry.value) {
        buffer.writeln(
          '${item.displayName}: ${item.quantity} ${item.unit ?? ''}'.trim(),
        );
      }
    }

    if (quotation.additionalNotes != null &&
        quotation.additionalNotes!.isNotEmpty) {
      buffer.writeln('\n-- Additional Notes --');
      buffer.writeln(quotation.additionalNotes);
    }

    return buffer.toString();
  }

  Future<Quotation> duplicateQuotation(Quotation original) async {
    final newQuotationData = original.toMap();
    newQuotationData[FirestoreFields.clientName] = '${original.clientName} (Copy)';
    newQuotationData[FirestoreFields.creationDate] = Timestamp.now();

    final docRef = await _firestore
        .collection(FirestoreCollections.quotations)
        .add(newQuotationData);

    final newQuotation = Quotation(
      id: docRef.id,
      clientName: newQuotationData[FirestoreFields.clientName],
      creationDate: (newQuotationData[FirestoreFields.creationDate] as Timestamp).toDate(),
      floorArea: newQuotationData[FirestoreFields.floorArea],
      additionalNotes: newQuotationData[FirestoreFields.additionalNotes],
      items: original.items,
    );

    return newQuotation;
  }
}
