import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:customcraft_app/widgets/animated_list_item.dart';
import '../services/firebase_attendance_service.dart';
import '../theme_notifier.dart';
import '../models/project.dart';
import '../models/quotation.dart';
import '../models/worker.dart';
import '../widgets/app_drawer.dart';
import '../widgets/project_list_shimmer.dart';
import 'attendance_history_page.dart';
import 'login_page.dart';
import 'personal_projects_list_page.dart';
import 'quotation_viewer_page.dart';
import 'truss_calculator_page.dart';

class EmployeeDashboard extends StatefulWidget {
  final Worker worker;
  const EmployeeDashboard({super.key, required this.worker});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync any pending records when the dashboard loads.
    _syncPendingAttendance();
  }

  /// Checks for any attendance records stored locally and syncs them to Firestore.
  Future<void> _syncPendingAttendance({bool showSnackbar = false}) async {
    final firebaseDb = FirebaseAttendanceService.instance;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final pendingRecords = await firebaseDb.getPendingAttendanceRecords();
    if (pendingRecords.isEmpty) {
      if (showSnackbar) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No offline records to sync.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    if (showSnackbar) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Syncing ${pendingRecords.length} offline record(s)...'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    int successCount = 0;
    for (final record in pendingRecords) {
      try {
        final attendanceCollection = FirebaseFirestore.instance
            .collection('projects')
            .doc(record['projectId'] as String)
            .collection('attendance');

        // record['date'] might be a Timestamp or DateTime depending on how it was stored.
        final dateValue = record['date'];
        Timestamp dateTimestamp;
        if (dateValue is Timestamp) {
          dateTimestamp = dateValue;
        } else if (dateValue is DateTime) {
          dateTimestamp = Timestamp.fromDate(dateValue);
        } else {
          dateTimestamp = Timestamp.fromDate(DateTime.now());
        }

        await attendanceCollection.add({
          'workerId': record['workerId'],
          'workerName': record['workerName'],
          'date': dateTimestamp,
          'present': record['present'],
          'projectId': record['projectId'],
          'projectName': record['projectName'],
        });

        await firebaseDb.deletePendingAttendance(record['id'] as String);
        successCount++;
      } catch (e) {
        debugPrint('Failed to sync record ${record['id']}: $e');
      }
    }

    if (mounted && showSnackbar && successCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$successCount record(s) synced successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Logs the user out and navigates to the login page.
  Future<void> _logout() async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseAuth.instance.signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  /// Manually triggers the offline sync process.
  Future<void> _handleRefresh() async {
    await _syncPendingAttendance(showSnackbar: true);
  }

  // --- FIX: Re-added missing helper methods ---

  /// Updates the project status in Firestore.
  void _updateProjectStatus(Project project, ProjectStatus status) {
    FirebaseFirestore.instance
        .collection('projects')
        .doc(project.id)
        .update({'status': status.index});
  }

  /// Shows a confirmation dialog before marking a project as completed.
  void _showMarkCompletedDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Project as Finished'),
        content: Text(
          'Are you sure you want to mark "${project.name}" as finished?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateProjectStatus(project, ProjectStatus.finished);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// Adds a temporary, offline worker's name to the project document.
  Future<void> _addOfflineWorker(Project project, String name) async {
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(project.id);

    await projectRef.update({
      'offlineMemberNames': FieldValue.arrayUnion([name])
    });
  }
  // --- END FIX ---


  /// Saves all pending attendance changes for a specific project to the local DB.
  /// This is now called as a callback from the `_EmployeeProjectTile`.
  Future<void> _saveTodaysAttendance(
      Project project, Map<String, bool> changes) async {
    if (changes.isEmpty) return;

        final today = DateTime.now();
    final firebaseDb = FirebaseAttendanceService.instance;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    // Create a copy of the changes map to avoid concurrent modification
    final changesCopy = Map<String, bool>.from(changes);

    try {
      // Insert each pending attendance into the Firebase-attendance pending collection
      final List<Future<String>> insertFutures = [];
      for (var entry in changesCopy.entries) {
        final workerId = entry.key;
        final isPresent = entry.value;

        String workerName = 'Unknown Worker';
        // Find the worker's name (handle both online and offline workers)
        try {
          if (!workerId.startsWith('offline_')) {
            final workerDoc = await FirebaseFirestore.instance
                .collection('workers')
                .doc(workerId)
                .get();
            if (workerDoc.exists) {
              workerName = workerDoc.data()?['name'] ?? workerName;
            }
          } else {
            workerName = project.offlineMemberNames.firstWhere(
              (name) => 'offline_${name.hashCode}' == workerId,
              orElse: () => 'Offline Worker',
            );
          }
        } catch (e) {
          debugPrint("Could not fetch worker name for batch save: $e");
        }

        insertFutures.add(firebaseDb.addPendingAttendance(
          workerId: workerId,
          workerName: workerName,
          date: today,
          present: isPresent,
          projectId: project.id,
          projectName: project.name,
        ));
      }

      final insertedIds = await Future.wait(insertFutures);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
              '${insertedIds.length} attendance record(s) saved locally. Syncing...'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Trigger sync after saving
      _syncPendingAttendance(showSnackbar: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance records: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      drawer: AppDrawer(
        currentUser: widget.worker,
        onLogout: _logout,
      ),
      appBar: AppBar(
        title: Text('Dashboard - ${widget.worker.name}'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Color.lerp(
                    Theme.of(context).colorScheme.primary, Colors.black, 0.2)!
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.book_outlined),
            tooltip: 'Personal Register',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PersonalProjectsListPage(currentUser: widget.worker),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('company_config')
                .snapshots(),
            builder: (context, snapshot) {
              final isVisible = (snapshot.data?.data()
                      as Map<String, dynamic>?)?['isCalculatorVisible'] ??
                  true;

              if (isVisible || widget.worker.isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.calculate_outlined),
                  tooltip: 'Truss Calculator',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TrussCalculatorPage(isAdmin: widget.worker.isAdmin),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Change Theme',
            onPressed: () => _showThemeChooserDialog(context, themeNotifier),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('memberIds', arrayContains: widget.worker.uid)
            .orderBy('creationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ProjectListShimmer();
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("You are not assigned to any projects yet."),
            );
          }

          final assignedProjects = snapshot.data!.docs
              .map((doc) => Project.fromFirestore(doc))
              .toList();

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: assignedProjects.length,
              itemBuilder: (_, index) {
                final project = assignedProjects[index];
                return AnimatedListItem(
                  index: index,
                  child: _EmployeeProjectTile(
                    key: ValueKey(project.id), // Important for state preservation
                    project: project,
                    currentUser: widget.worker,
                    onSaveAttendance: _saveTodaysAttendance,
                    onUpdateStatus: _updateProjectStatus,
                    onAddOfflineWorker: _addOfflineWorker,
                    onMarkCompleted: _showMarkCompletedDialog,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// A dedicated StatefulWidget for each project tile to manage its own state.
class _EmployeeProjectTile extends StatefulWidget {
  final Project project;
  final Worker currentUser;
  final Function(Project, Map<String, bool>) onSaveAttendance;
  final Function(Project, ProjectStatus) onUpdateStatus;
  final Function(Project, String) onAddOfflineWorker;
  final Function(BuildContext, Project) onMarkCompleted;

  const _EmployeeProjectTile({
    super.key,
    required this.project,
    required this.currentUser,
    required this.onSaveAttendance,
    required this.onUpdateStatus,
    required this.onAddOfflineWorker,
    required this.onMarkCompleted,
  });

  @override
  State<_EmployeeProjectTile> createState() => _EmployeeProjectTileState();
}

class _EmployeeProjectTileState extends State<_EmployeeProjectTile> {
  final Map<String, bool> _attendanceChanges = {};
  final Map<String, bool> _savedAttendance = {};

  @override
  void initState() {
    super.initState();
  }

  void _onAttendanceChanged(String workerId, bool isPresent) {
    if (_savedAttendance.containsKey(workerId)) return; // Prevent changes after saving
    setState(() {
      _attendanceChanges[workerId] = isPresent;
    });
  }

  // Track which members have been marked for today
  final Set<String> _markedMembers = {};

  void _handleSave() {
    widget.onSaveAttendance(widget.project, _attendanceChanges);
    setState(() {
      // Mark attendance as saved locally for each member
      _attendanceChanges.forEach((workerId, isPresent) {
        _savedAttendance[workerId] = isPresent;
      });
      _markedMembers.addAll(_attendanceChanges.keys);
      _attendanceChanges.clear();
    });
  }
  
  void _showAddOfflineWorkerDialog(BuildContext context, Project project) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Offline Worker'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Worker's Full Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                widget.onAddOfflineWorker(project, name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add to Project'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, DateTime?>> _getProjectDateRange(Project project) async {
    final attendanceRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(project.id)
        .collection('attendance');
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

  @override
  Widget build(BuildContext context) {
    final isLeader = widget.project.leaderId == widget.currentUser.uid;
    final payout = widget.project.finalPayouts[widget.currentUser.uid];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        key: PageStorageKey(widget.project.id),
        maintainState: true, // Keep the state when collapsed
        title: Text(widget.project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: payout != null
            ? Text(
                'Your Payout: \$${payout.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Text(
                widget.project.status == ProjectStatus.finished
                    ? 'Status: Finished'
                    : widget.project.status == ProjectStatus.onHold
                        ? 'Status: On Hold'
                        : isLeader
                            ? "You are the Project Leader"
                            : "You are a team member",
              ),
        trailing: Builder(builder: (context) {
          switch (widget.project.status) {
            case ProjectStatus.finished:
              return Chip(
                  label: const Text('Completed'),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer);
            case ProjectStatus.onHold:
              if (!isLeader) return const Chip(label: Text('On Hold'));
              return Row(mainAxisSize: MainAxisSize.min, children: [
                const Chip(label: Text('On Hold')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      widget.onUpdateStatus(widget.project, ProjectStatus.ongoing),
                  child: const Text('Resume'),
                )
              ]);
            case ProjectStatus.ongoing:
              return isLeader
                  ? PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'finish') {
                          widget.onMarkCompleted(context, widget.project);
                        }
                        if (value == 'hold') {
                          widget.onUpdateStatus(widget.project, ProjectStatus.onHold);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'finish', child: Text('Mark as Finished')),
                        const PopupMenuItem(value: 'hold', child: Text('Place On Hold')),
                      ],
                      icon: const Icon(Icons.more_vert))
                  : const SizedBox.shrink();
          }
        }),
        children: [
          if (_attendanceChanges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Today\'s Attendance'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              ),
            ),
          if (widget.project.quotationId != null && isLeader)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('quotations')
                  .doc(widget.project.quotationId)
                  .get(),
              builder: (context, quoteSnapshot) {
                if (!quoteSnapshot.hasData) return const SizedBox.shrink();
                final quotation = Quotation.fromFirestore(quoteSnapshot.data!);
                return ListTile(
                    leading: const Icon(Icons.request_quote_outlined),
                    title: const Text('View Project Quotation'),
                    subtitle: Text('For: ${quotation.clientName}'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                QuotationViewerPage(quotation: quotation))));
              },
            ),
          if (widget.project.status == ProjectStatus.finished)
            FutureBuilder<Map<String, DateTime?>>(
              future: _getProjectDateRange(widget.project),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!['start'] == null) {
                  return const ListTile(
                      subtitle: Text('No attendance was recorded.'));
                }
                final startDate = snapshot.data!['start']!;
                final endDate = snapshot.data!['end']!;
                return ListTile(
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text('Started: ${DateFormat.yMMMd().format(startDate)}'),
                  subtitle: Text('Ended: ${DateFormat.yMMMd().format(endDate)}'),
                );
              },
            ),
          if (widget.project.memberIds.isEmpty)
            const ListTile(title: Text('No members assigned yet.'))
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('workers')
                  .where(FieldPath.documentId, whereIn: widget.project.memberIds)
                  .snapshots(),
              builder: (context, memberSnapshot) {
                if (!memberSnapshot.hasData) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator()));
                }
                final members = memberSnapshot.data!.docs
                    .map((doc) => Worker.fromFirestore(doc))
                    .toList();

                final offlineMembers =
                    (widget.project.offlineMemberNames as List<dynamic>)
                        .cast<String>()
                        .map((name) {
                  return Worker(
                    uid: 'offline_${name.hashCode}',
                    name: name,
                    username: 'Offline Worker',
                    isPlaceholder: true,
                  );
                }).toList();

                final allMembers = [...members, ...offlineMembers];
                allMembers.sort((a, b) => a.name.compareTo(b.name));

                return Column(
                  children: allMembers.map((member) {
                    return _ProjectMemberTile(
                      project: widget.project,
                      member: member,
                      isLeader: isLeader,
                      pendingChange: _attendanceChanges[member.uid],
                      onMarkAttendance: (isPresent) =>
                          _onAttendanceChanged(member.uid, isPresent),
                    );
                  }).toList(),
                );
              },
            ),
          if (isLeader && widget.project.status == ProjectStatus.ongoing)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: OutlinedButton.icon(
                onPressed: () => _showAddOfflineWorkerDialog(context, widget.project),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add Offline Worker'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40)),
              ),
            ),
        ],
      ),
    );
  }
}

// Dialog for theme selection remains the same
void _showThemeChooserDialog(BuildContext context, ThemeNotifier themeNotifier) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setDialogState) {
          return AlertDialog(
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode'),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(
                        value: ThemeMode.system, label: Text('System')),
                  ],
                  selected: {themeNotifier.themeMode},
                  onSelectionChanged: (newSelection) {
                    themeNotifier.setThemeMode(newSelection.first);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 24),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: AppThemeColor.values.map((color) {
                    final isSelected = themeNotifier.appThemeColor == color;
                    return GestureDetector(
                      onTap: () {
                        themeNotifier.setThemeColor(color);
                        setDialogState(() {});
                      },
                      child: CircleAvatar(
                        backgroundColor: color.seedColor,
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ProjectMemberTile extends StatelessWidget {
  final Project project;
  final Worker member;
  final bool isLeader;
  final bool? pendingChange;
  final Function(bool) onMarkAttendance;

  const _ProjectMemberTile({
    required this.project,
    required this.member,
    required this.isLeader,
    required this.pendingChange,
    required this.onMarkAttendance,
  });

  void _showEditAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change status for ${member.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onMarkAttendance(true);
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Mark as Present',
              style: TextStyle(color: Colors.green),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              onMarkAttendance(false);
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Mark as Absent',
              style: TextStyle(color: Colors.red),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return ListTile(
      title: Row(
        children: [
          Text(member.name),
          const SizedBox(width: 8),
          if (member.isPlaceholder)
            Chip(
              label: const Text('Offline'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
            )
        ],
      ),
      subtitle: _AttendanceStatus(
        member: member,
        project: project,
        pendingChange: pendingChange,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceHistoryPage(
              worker: member,
              project: project,
            ),
          ),
        );
      },
      trailing: isLeader && project.status == ProjectStatus.ongoing
          ? _AttendanceControls(
              member: member,
              project: project,
              pendingChange: pendingChange,
              onMarkAttendance: onMarkAttendance,
              onShowEditDialog: () => _showEditAttendanceDialog(context),
            )
          : null,
    );
  }
}

class _AttendanceStatus extends StatelessWidget {
  final Worker member;
  final Project project;
  final bool? pendingChange;

  const _AttendanceStatus({
    required this.member,
    required this.project,
    this.pendingChange,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(project.id)
          .collection('attendance')
          .where('workerId', isEqualTo: member.uid)
          .where('date', isGreaterThanOrEqualTo: startOfToday)
          .where('date', isLessThan: endOfToday)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading status...");
        }

        final bool alreadyMarked =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final bool isPresentOnline =
            alreadyMarked && snapshot.data!.docs.first['present'];

        return Text(
          alreadyMarked
              ? (isPresentOnline ? 'Present (Synced)' : 'Absent (Synced)')
              : (pendingChange != null
                  ? (pendingChange!
                      ? 'Marked as Present (unsaved)'
                      : 'Marked as Absent (unsaved)')
                  : 'Not Marked for Today'),
        );
      },
    );
  }
}

class _AttendanceControls extends StatelessWidget {
  final Worker member;
  final Project project;
  final bool? pendingChange;
  final Function(bool) onMarkAttendance;
  final VoidCallback onShowEditDialog;

  const _AttendanceControls({
    required this.member,
    required this.project,
    required this.pendingChange,
    required this.onMarkAttendance,
    required this.onShowEditDialog,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(project.id)
          .collection('attendance')
          .where('workerId', isEqualTo: member.uid)
          .where('date', isGreaterThanOrEqualTo: startOfToday)
          .where('date', isLessThan: endOfToday)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // Check online saved attendance first
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final isPresentOnline = snapshot.data!.docs.first['present'];
          return Chip(
            label: Text(isPresentOnline ? 'Present' : 'Absent'),
            backgroundColor: isPresentOnline
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
          );
        }

        // Check locally saved attendance (offline)
        final savedStatus = context
            .findAncestorStateOfType<_EmployeeProjectTileState>()
            ?._savedAttendance[member.uid];
        if (savedStatus != null) {
          return Chip(
            label: Text(savedStatus ? 'Present (Offline)' : 'Absent (Offline)'),
            backgroundColor: savedStatus
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            avatar: const Icon(Icons.offline_pin, size: 18),
            // Make chip visually disabled
            labelStyle: TextStyle(color: Theme.of(context).disabledColor),
          );
        }

        // Check pending changes
        if (pendingChange != null) {
          return Chip(
            label: Text(pendingChange == true ? 'Present' : 'Absent'),
            backgroundColor: pendingChange == true
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
          );
        }

        // Show buttons if no attendance is recorded or saved
        return _AttendanceButtonRow(
          pendingChange: pendingChange,
          onMarkAttendance: onMarkAttendance,
        );
      },
    );
  }
}

class _AttendanceButtonRow extends StatelessWidget {
  final bool? pendingChange;
  final Function(bool) onMarkAttendance;

  const _AttendanceButtonRow({
    required this.pendingChange,
    required this.onMarkAttendance,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingChange != null) {
      // If attendance has been marked but not yet saved, show a chip
      return Chip(
        label: Text(pendingChange! ? 'Present' : 'Absent'),
        backgroundColor: pendingChange!
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AttendanceButton(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          tooltip: 'Mark Present',
          isSelected: false,
          onPressed: () => onMarkAttendance(true),
        ),
        _AttendanceButton(
          icon: Icons.highlight_off,
          color: Colors.red,
          tooltip: 'Mark Absent',
          isSelected: false,
          onPressed: () => onMarkAttendance(false),
        ),
      ],
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AttendanceButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return isSelected
        ? IconButton.filled(
            icon: Icon(icon),
            color: Colors.white,
            style: IconButton.styleFrom(backgroundColor: color),
            tooltip: tooltip,
            onPressed: onPressed,
          )
        : IconButton(
            icon: Icon(icon),
            color: color,
            tooltip: tooltip,
            onPressed: onPressed,
          );
  }
}

  