import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class Worker {
  String uid;
  String name;
  String username;
  bool isAdmin;
  bool isPlaceholder;
  double dailyRate;

  Worker({
    this.uid = '',
    required this.name,
    required this.username,
    this.isAdmin = false,
    this.isPlaceholder = false,
    this.dailyRate = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      FirestoreFields.name: name,
      FirestoreFields.username: username,
      FirestoreFields.isAdmin: isAdmin,
      FirestoreFields.isPlaceholder: isPlaceholder,
      FirestoreFields.dailyRate: dailyRate,
    };
  }

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Worker(
      uid: doc.id,
      name: data[FirestoreFields.name] ?? '',
      username: data[FirestoreFields.username] ?? '',
      isAdmin: data[FirestoreFields.isAdmin] ?? false,
      isPlaceholder: data[FirestoreFields.isPlaceholder] ?? false,
      dailyRate: (data[FirestoreFields.dailyRate] as num?)?.toDouble() ?? 0.0,
    );
  }
}
