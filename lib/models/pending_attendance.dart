class PendingAttendance {
  final String id;
  final String workerId;
  final String workerName;
  final DateTime date;
  final bool present;
  final String projectId;
  final String projectName;
  final String syncStatus;

  PendingAttendance({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.date,
    required this.present,
    required this.projectId,
    required this.projectName,
    this.syncStatus = 'pending',
  });

  factory PendingAttendance.fromFirestore(Map<String, dynamic> data, String id) {
    return PendingAttendance(
      id: id,
      workerId: data['workerId'],
      workerName: data['workerName'],
      date: (data['date'] as DateTime),
      present: data['present'],
      projectId: data['projectId'],
      projectName: data['projectName'],
      syncStatus: data['syncStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'date': date,
      'present': present,
      'projectId': projectId,
      'projectName': projectName,
      'syncStatus': syncStatus,
    };
  }
}