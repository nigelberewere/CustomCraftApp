import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class PersonalWorker {
  final String id;
  final String name;

  PersonalWorker({required this.id, required this.name});

  factory PersonalWorker.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PersonalWorker(id: doc.id, name: data[FirestoreFields.name] ?? '');
  }
}
