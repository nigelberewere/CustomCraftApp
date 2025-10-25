import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class Attendance {
  final String id;
  final String workerId;
  final String workerName;
  final DateTime date;
  final bool present;
  final String projectId;
  final String projectName;

  Attendance({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.date,
    this.present = true,
    required this.projectId,
    required this.projectName,
  });

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      workerId: data[FirestoreFields.workerId] ?? '',
      workerName: data[FirestoreFields.workerName] ?? '',
      date: (data[FirestoreFields.date] as Timestamp).toDate(),
      present: data[FirestoreFields.present] ?? false,
      projectId: data[FirestoreFields.projectId] ?? '',
      projectName: data[FirestoreFields.projectName] ?? '',
    );
  }
}
