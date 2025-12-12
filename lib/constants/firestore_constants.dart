// lib/constants/firestore_constants.dart

/// A centralized place for all Firestore collection names.
class FirestoreCollections {
  static const String workers = 'workers';
  static const String projects = 'projects';
  static const String settings = 'settings';
  static const String quotations = 'quotations';
  static const String attendance = 'attendance';
  static const String personalProjects = 'personal_projects';
  static const String members = 'members';
  static const String errorLogs = 'errorLogs';
}

/// A centralized place for Firestore document field names.
class FirestoreFields {
  // Common
  static const String name = 'name';
  static const String creationDate = 'creationDate';

  // Worker
  static const String isAdmin = 'isAdmin';
  static const String dailyRate = 'dailyRate';
  static const String username = 'username';
  static const String assignedProjectIds = 'assignedProjectIds';
  static const String isPlaceholder = 'isPlaceholder';
  static const String uid = 'uid';

  // Project
  static const String startDate = 'startDate';
  static const String endDate = 'endDate';
  static const String leaderId = 'leaderId';
  static const String quotationId = 'quotationId';
  static const String memberIds = 'memberIds';
  static const String offlineMemberNames = 'offlineMemberNames';
  static const String status = 'status';
  static const String budget = 'budget';
  static const String finalPayouts = 'finalPayouts';

  // Attendance
  static const String workerId = 'workerId';
  static const String workerName = 'workerName';
  static const String date = 'date';
  static const String present = 'present';
  static const String projectId = 'projectId';
  static const String projectName = 'projectName';

  // Quotation
  static const String clientName = 'clientName';
  static const String floorArea = 'floorArea';
  static const String items = 'items';
  static const String additionalNotes = 'additionalNotes';

  // Settings
  static const String companyConfig = 'company_config';
  static const String companyName = 'companyName';
  static const String companyPhone = 'companyPhone';
  static const String companyEmail = 'companyEmail';
  static const String isCalculatorVisible = 'isCalculatorVisible';
  static const String calcShowTieBeam = 'calc_showTieBeam';
  static const String calcShowRafter = 'calc_showRafter';
  static const String calcShowHalfSpan = 'calc_showHalfSpan';
  static const String calcShowRoofingSheet = 'calc_showRoofingSheet';
  static const String calcRoofingOverlap = 'calc_roofingOverlap';
  static const String calcRafterEve = 'calc_rafterEve';

  // Personal Project
  static const String ownerUid = 'ownerUid';
  static const String dateAdded = 'dateAdded';
  static const String memberId = 'memberId';
  static const String memberName = 'memberName';
  static const String isPresent = 'isPresent';
}
