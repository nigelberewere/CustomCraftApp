import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class PersonalProject {
  final String id;
  final String name;
  final String ownerUid;

  PersonalProject({
    required this.id,
    required this.name,
    required this.ownerUid,
  });

  factory PersonalProject.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PersonalProject(
      id: doc.id,
      name: data[FirestoreFields.name] ?? '',
      ownerUid: data[FirestoreFields.ownerUid] ?? '',
    );
  }
}
