import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/worker.dart';

class ProjectService {
  static final _firestore = FirebaseFirestore.instance;

  // REWRITTEN: The core logic now uses a proportional distribution model.
  static Future<Map<String, double>> calculateAndSavePayouts(
    Project project, double totalPayoutPool) async {
    try {
      final attendanceCollection = _firestore
          .collection('projects')
          .doc(project.id)
          .collection('attendance');
      final workersCollection = _firestore.collection('workers');

      // 1. Get all "present" attendance records for this project.
      final presentRecordsQuery =
          await attendanceCollection.where('present', isEqualTo: true).get();

      // presentRecordsQuery fetched

      if (presentRecordsQuery.docs.isEmpty) {
        // If no one worked, there's no payout. Set budget and finalPayouts to empty.
        await _firestore
            .collection('projects')
            .doc(project.id)
            .update({'budget': 0.0, 'finalPayouts': {}});
        return {
          'totalPayout': 0.0,
          'workersPaid': 0.0,
        };
      }

      // 2. Count the number of days each worker was present.
      final Map<String, int> memberPresentDays = {};
      for (var doc in presentRecordsQuery.docs) {
        final String workerId = doc['workerId'];
        memberPresentDays[workerId] = (memberPresentDays[workerId] ?? 0) + 1;
      }

      // memberPresentDays computed

      // 3. Fetch the profiles for all workers who were present to get their daily rates.
      final workerIds = memberPresentDays.keys.toList();

      // Firestore limits 'whereIn' to 10 elements. Fetch in batches when necessary.
      final Map<String, Map<String, dynamic>> fetchedWorkerData = {};
      if (workerIds.isNotEmpty) {
        const int batchSize = 10;
        for (var i = 0; i < workerIds.length; i += batchSize) {
          final end = (i + batchSize) > workerIds.length ? workerIds.length : i + batchSize;
          final chunk = workerIds.sublist(i, end);
          final workersQuery =
              await workersCollection.where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in workersQuery.docs) {
            fetchedWorkerData[doc.id] = doc.data();
          }
        }
      }

      final Map<String, double> workerDailyRates = {
        for (var id in workerIds)
          id: (fetchedWorkerData[id]?['dailyRate'] as num?)?.toDouble() ?? 0.0
      };

      // workerDailyRates computed

      // 4. Compute weight for each worker (presentDays * dailyRate) and sum weights.
      final Map<String, double> weights = {};
      double totalWeight = 0.0;
      for (var entry in memberPresentDays.entries) {
        final String workerId = entry.key;
        final int presentDays = entry.value;
        final double dailyRate = workerDailyRates[workerId] ?? 0.0;
        final double weight = presentDays * dailyRate;
        weights[workerId] = weight;
        totalWeight += weight;
      }

      // weights computed

      // 5. Allocate the provided payout pool according to weights.
      final Map<String, double> finalPayouts = {};
      double totalDistributed = 0.0;
      final int workersCount = memberPresentDays.length;

      if (totalWeight > 0) {
        // Distribute proportionally to weight
        for (var entry in weights.entries) {
          final double share = (entry.value / totalWeight) * totalPayoutPool;
          finalPayouts[entry.key] = double.parse(share.toStringAsFixed(2));
          totalDistributed += finalPayouts[entry.key]!;
        }
      } else {
        // If totalWeight is zero (e.g., all dailyRates missing or zero), split equally among present workers.
        final double equalShare = totalPayoutPool / workersCount;
        for (var workerId in memberPresentDays.keys) {
          finalPayouts[workerId] = double.parse(equalShare.toStringAsFixed(2));
          totalDistributed += finalPayouts[workerId]!;
        }
      }

      // Due to rounding we might have a tiny difference; adjust the first worker's payout to match the pool exactly.
      final double roundingDiff = double.parse(totalPayoutPool.toStringAsFixed(2)) - double.parse(totalDistributed.toStringAsFixed(2));
      if (roundingDiff.abs() >= 0.01 && finalPayouts.isNotEmpty) {
        final firstKey = finalPayouts.keys.first;
        finalPayouts[firstKey] = (finalPayouts[firstKey] ?? 0.0) + roundingDiff;
        totalDistributed += roundingDiff;
      }

      // 6. Save the results to Firestore. The project's 'budget' is now the distributed payout pool amount.
      await _firestore.collection('projects').doc(project.id).update({
        'budget': totalDistributed,
        'finalPayouts': finalPayouts,
      });

      // totalDistributed and finalPayouts saved

      // 7. Return the summary for the results dialog.
      return {
        'totalPayout': totalDistributed,
        'workersPaid': workersCount.toDouble(),
      };
    } catch (e, st) {
      // Print to console so errors are visible in flutter run logs as well as being logged to Firestore.
      // Log to console is intentionally omitted for privacy; we still record to Firestore below.
      // Log runtime exceptions to Firestore so we can inspect errors even if I can't stream your terminal.
      try {
        await _firestore.collection('errorLogs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'source': 'ProjectService.calculateAndSavePayouts',
          'projectId': project.id,
          'error': e.toString(),
          'stack': st.toString(),
        });
      } catch (_) {
        // Swallow any logging errors to avoid masking the original exception.
      }
      rethrow;
    }
  }

  static Future<Map<String, DateTime?>> getProjectDateRange(
      Project project) async {
    final attendanceRef =
        _firestore.collection('projects').doc(project.id).collection('attendance');
    final startDateQuery =
        await attendanceRef.orderBy('date', descending: false).limit(1).get();
    final endDateQuery =
        await attendanceRef.orderBy('date', descending: true).limit(1).get();

    DateTime? startDate;
    DateTime? endDate;
    if (startDateQuery.docs.isNotEmpty) {
      startDate = (startDateQuery.docs.first['date'] as Timestamp).toDate();
    }
    if (endDateQuery.docs.isNotEmpty) {
      endDate = (endDateQuery.docs.first['date'] as Timestamp).toDate();
    }
    return {'start': startDate, 'end': endDate};
  }

  static Future<void> updateProjectStatus(
      Project project, ProjectStatus status) async {
    final projectRef = _firestore.collection('projects').doc(project.id);

    if (status == ProjectStatus.finished) {
      final attendanceRef = projectRef.collection('attendance');
      final startDateQuery =
      await attendanceRef.orderBy('date', descending: false).limit(1).get();
      final endDateQuery =
      await attendanceRef.orderBy('date', descending: true).limit(1).get();

      DateTime? startDate;
      DateTime? endDate;
      if (startDateQuery.docs.isNotEmpty) {
        startDate = (startDateQuery.docs.first['date'] as Timestamp).toDate();
      }
      if (endDateQuery.docs.isNotEmpty) {
        endDate = (endDateQuery.docs.first['date'] as Timestamp).toDate();
      }

      await projectRef.update({
        'status': status.index,
        'startDate': startDate,
        'endDate': endDate,
      });
    } else {
      await projectRef.update({'status': status.index});
    }
  }

  static Future<void> deleteProject(
      BuildContext context, Project project) async {
    // LINT FIX: use_build_context_synchronously
    // Store the ScaffoldMessenger before any async calls so we don't use the
    // BuildContext after awaiting asynchronous work.
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    try {
      // Attempt to delete common subcollections first. The client SDK cannot
      // list subcollections dynamically in all platforms, so delete the known
      // ones used by the app. If you use additional subcollections, add them
      // here or prefer a server-side Cloud Function that cleans up recursively.
      final projectRef = _firestore.collection('projects').doc(project.id);
      final subcollectionsToDelete = ['attendance', 'members', 'quotations'];

      for (final sub in subcollectionsToDelete) {
        // Delete in pages to avoid exceeding batch limits. Firestore allows up
        // to 500 writes per batch.
        while (true) {
          final snapshot = await projectRef.collection(sub).limit(500).get();
          if (snapshot.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // Now delete the project document itself.
      await projectRef.delete();

      // Update workers to remove assignment to this project.
      final batch = _firestore.batch();
      for (var workerId in project.memberIds) {
        final workerRef = _firestore.collection('workers').doc(workerId);
        batch.update(
            workerRef, {'assignedProjectIds': FieldValue.arrayRemove([project.id])});
      }
      await batch.commit();

      // Only show the snackbar if a ScaffoldMessenger was available before
      // performing the async work.
      scaffoldMessenger?.showSnackBar(
        SnackBar(content: Text('Project "${project.name}" deleted.')),
      );
    } catch (e) {
      // Use the previously-captured ScaffoldMessenger (if any) to show an
      // error message without accessing the BuildContext after awaits.
      scaffoldMessenger?.showSnackBar(
        SnackBar(content: Text('Error deleting project: $e')),
      );
    }
  }

  static Future<void> assignWorker(Project project, Worker worker,
      {bool leader = false}) async {
    final projectRef = _firestore.collection('projects').doc(project.id);
    final workerRef = _firestore.collection('workers').doc(worker.uid);
    final batch = _firestore.batch();

    batch.update(
        projectRef, {'memberIds': FieldValue.arrayUnion([worker.uid])});
    batch.update(
        workerRef, {'assignedProjectIds': FieldValue.arrayUnion([project.id])});

    if (leader) {
      batch.update(projectRef, {'leaderId': worker.uid});
    }
    await batch.commit();
  }

  static Future<void> unassignWorker(Project project, Worker worker) async {
    final projectRef = _firestore.collection('projects').doc(project.id);
    final workerRef = _firestore.collection('workers').doc(worker.uid);
    final batch = _firestore.batch();

    batch.update(
        projectRef, {'memberIds': FieldValue.arrayRemove([worker.uid])});
    batch.update(
        workerRef, {'assignedProjectIds': FieldValue.arrayRemove([project.id])});

    if (project.leaderId == worker.uid) {
      batch.update(projectRef, {'leaderId': FieldValue.delete()});
    }
    await batch.commit();
  }

  static Future<void> addOfflineWorker(Project project, String workerName) async {
    final projectRef = _firestore.collection('projects').doc(project.id);
    await projectRef.update({
      'offlineMemberNames': FieldValue.arrayUnion([workerName])
    });
  }
}
