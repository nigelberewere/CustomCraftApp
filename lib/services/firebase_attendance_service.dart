import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class FirebaseAttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static final FirebaseAttendanceService instance = FirebaseAttendanceService._internal();
  
  FirebaseAttendanceService._internal();

  Future<List<Map<String, dynamic>>> getPendingAttendanceRecords() async {
    // Try cache first but fall back to server to ensure we have any recent local writes
    final querySnapshot = await _firestore
        .collection('pending_attendances')
        .get(const GetOptions(source: Source.cache));

    // If cache empty, try server (useful when cache cleared)
    if (querySnapshot.docs.isEmpty) {
      final serverSnapshot = await _firestore
          .collection('pending_attendances')
          .get(const GetOptions(source: Source.server));
      return serverSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    }

    return querySnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<String> addPendingAttendance({
    required String workerId,
    required String workerName,
    required DateTime date,
    required bool present,
    required String projectId,
    required String projectName,
  }) async {
    final docRef = await _firestore.collection('pending_attendances').add({
      FirestoreFields.workerId: workerId,
      FirestoreFields.workerName: workerName,
      FirestoreFields.date: date,
      FirestoreFields.present: present,
      FirestoreFields.projectId: projectId,
      FirestoreFields.projectName: projectName,
      'syncStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Return the generated document ID so callers can reference it if needed
    return docRef.id;
  }

  Future<void> deletePendingAttendance(String id) async {
    await _firestore.collection('pending_attendances').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getAttendanceForToday(String workerId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

  final querySnapshot = await _firestore
    .collection('pending_attendances')
    .where(FirestoreFields.workerId, isEqualTo: workerId)
    .where(FirestoreFields.date, isGreaterThanOrEqualTo: startOfDay)
    .where(FirestoreFields.date, isLessThan: endOfDay)
    .get(const GetOptions(source: Source.cache));

  if (querySnapshot.docs.isEmpty) {
    final serverSnapshot = await _firestore
      .collection('pending_attendances')
      .where(FirestoreFields.workerId, isEqualTo: workerId)
      .where(FirestoreFields.date, isGreaterThanOrEqualTo: startOfDay)
      .where(FirestoreFields.date, isLessThan: endOfDay)
      .get(const GetOptions(source: Source.server));

    return serverSnapshot.docs
      .map((doc) => {...doc.data(), 'id': doc.id})
      .toList();
  }

  return querySnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<void> markAttendanceAsSynced(String id) async {
    await _firestore.collection('pending_attendances').doc(id).update({
      'syncStatus': 'synced',
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingAttendances() {
    return _firestore
        .collection('pending_attendances')
        .where('syncStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}