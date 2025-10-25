import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { ongoing, onHold, finished }

class Project {
  String id;
  String name;
  DateTime? startDate;
  DateTime? endDate;
  String? leaderId;
  List<String> memberIds;
  // NEW: Added the list to store offline member names.
  List<String> offlineMemberNames;
  String? quotationId;
  ProjectStatus status;
  double budget;
  Map<String, double> finalPayouts;
  DateTime creationDate;

  Project({
    this.id = '',
    required this.name,
    required this.creationDate,
    this.startDate,
    this.endDate,
    this.leaderId,
    this.quotationId,
    List<String>? memberIds,
    // NEW: Initialize the list in the constructor.
    List<String>? offlineMemberNames,
    this.status = ProjectStatus.ongoing,
    this.budget = 0.0,
    Map<String, double>? finalPayouts,
  })  : memberIds = memberIds ?? [],
        // NEW: Assign the value from the constructor.
        offlineMemberNames = offlineMemberNames ?? [],
        finalPayouts = finalPayouts ?? {};

  factory Project.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Project(
      id: doc.id,
      name: data['name'] ?? '',
      creationDate: (data['creationDate'] as Timestamp).toDate(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      leaderId: data['leaderId'],
      quotationId: data['quotationId'],
      memberIds: List<String>.from(data['memberIds'] ?? []),
      // NEW: Read the list from Firestore.
      offlineMemberNames: List<String>.from(data['offlineMemberNames'] ?? []),
      status: ProjectStatus.values[data['status'] ?? 0],
      budget: (data['budget'] ?? 0.0).toDouble(),
      finalPayouts: (data['finalPayouts'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'creationDate': Timestamp.fromDate(creationDate),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'leaderId': leaderId,
      'quotationId': quotationId,
      'memberIds': memberIds,
      // NEW: Add the list to the map for saving.
      'offlineMemberNames': offlineMemberNames,
      'status': status.index,
      'budget': budget,
      'finalPayouts': finalPayouts,
    };
  }
}

