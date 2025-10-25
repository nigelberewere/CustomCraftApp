import 'package:cloud_firestore/cloud_firestore.dart';
import 'quotation_item.dart';
import '../constants/firestore_constants.dart';

class Quotation {
  String id;
  String clientName;
  DateTime creationDate;
  double? floorArea;
  List<QuotationItem> items;
  String? additionalNotes;

  Quotation({
    this.id = '',
    required this.clientName,
    required this.creationDate,
    required this.items,
    this.floorArea,
    this.additionalNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      FirestoreFields.clientName: clientName,
      FirestoreFields.creationDate: Timestamp.fromDate(creationDate),
      FirestoreFields.floorArea: floorArea,
      FirestoreFields.additionalNotes: additionalNotes,
      FirestoreFields.items: items.map((item) => item.toMap()).toList(),
    };
  }

  factory Quotation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    List<QuotationItem> itemList = [];
    if (data[FirestoreFields.items] != null) {
      for (var itemMap in (data[FirestoreFields.items] as List)) {
        itemList.add(QuotationItem.fromMap(itemMap));
      }
    }

    return Quotation(
      id: doc.id,
      clientName: data[FirestoreFields.clientName] ?? '',
      creationDate:
          (data[FirestoreFields.creationDate] as Timestamp?)?.toDate() ??
              DateTime.now(),
      floorArea: (data[FirestoreFields.floorArea] as num?)?.toDouble(),
      additionalNotes: data[FirestoreFields.additionalNotes],
      items: itemList,
    );
  }
}
