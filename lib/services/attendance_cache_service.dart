import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

/// Simple in-memory cache for project attendance queries.
/// Keyed by projectId + start-of-day ISO string + sorted memberIds (if provided).
class AttendanceCacheService {
  AttendanceCacheService._internal();
  static final AttendanceCacheService instance =
      AttendanceCacheService._internal();

  final Map<String, Future<List<DocumentSnapshot>>> _cache = {};

  String _key(String projectId, DateTime start, List<String>? memberIds) {
    final dateKey = DateTime(
      start.year,
      start.month,
      start.day,
    ).toIso8601String();
    if (memberIds == null || memberIds.isEmpty) return '$projectId|$dateKey|';
    final sorted = memberIds.toList()..sort();
    return '$projectId|$dateKey|${sorted.join(',')}';
  }

  /// Get attendance documents for a project for the given day (start..end).
  /// If [memberIds] is provided and non-empty, we only return attendance for those workers.
  /// This method caches the Future so repeated calls return the same in-flight or cached result.
  Future<List<DocumentSnapshot>> getAttendanceForProject(
    String projectId,
    DateTime start,
    DateTime end, {
    List<String>? memberIds,
  }) {
    final cacheKey = _key(projectId, start, memberIds);
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final future = _fetchAttendance(
      projectId,
      start,
      end,
      memberIds: memberIds,
    );
    // store the future in cache
    _cache[cacheKey] = future;
    // When future completes, we keep it cached until invalidate is called (simple policy)
    return future;
  }

  Future<List<DocumentSnapshot>> _fetchAttendance(
    String projectId,
    DateTime start,
    DateTime end, {
    List<String>? memberIds,
  }) async {
    final attendanceCol = FirebaseFirestore.instance
        .collection(FirestoreCollections.projects)
        .doc(projectId)
        .collection(FirestoreCollections.attendance);

    // If memberIds is null or <= 10 we can query directly
    if (memberIds == null || memberIds.isEmpty) {
      final snap = await attendanceCol
          .where(FirestoreFields.date, isGreaterThanOrEqualTo: start)
          .where(FirestoreFields.date, isLessThan: end)
          .get();
      return snap.docs;
    }

    // Firestore whereIn supports up to 10 items. If more, chunk the queries.
    const int chunkSize = 10;
    if (memberIds.length <= chunkSize) {
      final snap = await attendanceCol
          .where(FirestoreFields.date, isGreaterThanOrEqualTo: start)
          .where(FirestoreFields.date, isLessThan: end)
          .where(FirestoreFields.workerId, whereIn: memberIds)
          .get();
      return snap.docs;
    }

    final List<DocumentSnapshot> results = [];
    for (var i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(
        i,
        i + chunkSize > memberIds.length ? memberIds.length : i + chunkSize,
      );
      final snap = await attendanceCol
          .where(FirestoreFields.date, isGreaterThanOrEqualTo: start)
          .where(FirestoreFields.date, isLessThan: end)
          .where(FirestoreFields.workerId, whereIn: chunk)
          .get();
      results.addAll(snap.docs);
    }

    return results;
  }

  /// Invalidate cached entry for a given project/day/memberIds combo.
  void invalidate(String projectId, DateTime start, {List<String>? memberIds}) {
    final k = _key(projectId, start, memberIds);
    _cache.remove(k);
  }

  /// Clear entire cache.
  void clear() => _cache.clear();

  /// Clear cached attendance entries for [projectId] for today.
  ///
  /// This removes any cache keys that begin with the projectId and today's
  /// start-of-day ISO date string. It keeps the existing cache map type and
  /// behavior.
  void clearCacheForProject(String projectId) {
    final today = DateTime.now();
    final dateKey = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final prefix = '$projectId|$dateKey|';
    final keysToRemove = _cache.keys
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keysToRemove) {
      _cache.remove(k);
    }
  }
}
