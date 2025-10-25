import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/project.dart';
import '../constants/firestore_constants.dart';

class AdminAttendanceViewerPage extends StatefulWidget {
  const AdminAttendanceViewerPage({super.key});

  @override
  State<AdminAttendanceViewerPage> createState() =>
      _AdminAttendanceViewerPageState();
}

class _AdminAttendanceViewerPageState extends State<AdminAttendanceViewerPage> {
  Project? _selectedProject;
  String? _selectedProjectId;
  DateTime? _selectedDate;

  Future<void> _pickDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      if (!mounted) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Widget _buildProjectSummaryCard() {
    final project = _selectedProject!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.projects)
          .doc(project.id)
          .collection(FirestoreCollections.attendance)
          .where(FirestoreFields.present, isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: Text("Loading Summary...")),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final summary = <String, int>{};
        for (final doc in snapshot.data!.docs) {
          final workerName = doc[FirestoreFields.workerName] as String;
          summary[workerName] = (summary[workerName] ?? 0) + 1;
        }
        final sortedEntries = summary.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary for ${project.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(height: 16),
                ...sortedEntries.map((entry) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(child: Text(entry.value.toString())),
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value == 1 ? 'Day Present' : 'Days Present',
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllProjectsOverview(DateTime date, List<Project> allProjects) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final stream = FirebaseFirestore.instance
        .collectionGroup(FirestoreCollections.attendance)
        .where(FirestoreFields.projectId, isNotEqualTo: null)
        .where(FirestoreFields.date, isGreaterThanOrEqualTo: start)
        .where(FirestoreFields.date, isLessThan: end)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No attendance records found for this day.'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final projectIdsWithAttendanceToday = docs
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)[FirestoreFields.projectId] as String?,
            )
            .where((id) => id != null)
            .toSet();

        final activeProjectsCount = allProjects.where((project) {
          return project.status == ProjectStatus.ongoing &&
              projectIdsWithAttendanceToday.contains(project.id);
        }).length;

        final Set<String> presentWorkerIds = {};
        final Set<String> absentWorkerIds = {};
        final Map<String, List<String>> presentByProject = {};
        final Map<String, List<String>> absentByProject = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final workerId = data[FirestoreFields.workerId]?.toString();
          final workerName = data[FirestoreFields.workerName]?.toString() ?? 'Unknown Worker';
          final projectName =
              data[FirestoreFields.projectName]?.toString() ?? 'Unknown Project';
          final present = data[FirestoreFields.present] as bool? ?? false;

          if (present) {
            if (workerId != null) presentWorkerIds.add(workerId);
            presentByProject.putIfAbsent(projectName, () => []).add(workerName);
          } else {
            if (workerId != null) absentWorkerIds.add(workerId);
            absentByProject.putIfAbsent(projectName, () => []).add(workerName);
          }
        }

        final totalPresent = presentWorkerIds.length;
        final totalAbsent = absentWorkerIds.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                DateFormat.yMMMMEEEEd().format(date),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Row(
              children: [
                _SummaryCard(
                  title: 'Total Present',
                  value: totalPresent.toString(),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                _SummaryCard(
                  title: 'Total Absent',
                  value: totalAbsent.toString(),
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                _SummaryCard(
                  title: 'Active Projects',
                  value: activeProjectsCount.toString(),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (presentByProject.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Present Workers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...presentByProject.entries.map(
                (entry) => _ProjectWorkerList(
                  projectName: entry.key,
                  workerNames: entry.value,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (absentByProject.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Absent Workers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...absentByProject.entries.map(
                (entry) => _ProjectWorkerList(
                  projectName: entry.key,
                  workerNames: entry.value,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProjectSpecificView(Query query) {
    return Column(
      children: [
        if (_selectedProject != null) _buildProjectSummaryCard(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Error loading data. Ensure the Firestore index is created.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No attendance records match the selected filters.',
                  ),
                );
              }

              final records = snapshot.data!.docs
                  .map((doc) => Attendance.fromFirestore(doc))
                  .toList();
              final Map<DateTime, List<Attendance>> groupedByDay = {};
              for (var record in records) {
                final dayKey = DateTime(
                  record.date.year,
                  record.date.month,
                  record.date.day,
                );
                groupedByDay[dayKey] ??= [];
                groupedByDay[dayKey]!.add(record);
              }
              final dateKeys = groupedByDay.keys.toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: dateKeys.length,
                itemBuilder: (context, index) {
                  final date = dateKeys[index];
                  final recordsForDay = groupedByDay[date]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          DateFormat.yMMMMEEEEd().format(date),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...recordsForDay.map((attendance) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              attendance.present
                                  ? Icons.check_circle_outline
                                  : Icons.highlight_off,
                              color: attendance.present
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(attendance.workerName),
                            subtitle: Text(
                              "Project: ${attendance.projectName}",
                            ),
                            trailing: Text(
                              attendance.present ? 'Present' : 'Absent',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        title: Text(
          'Attendance Viewer',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(FirestoreCollections.projects).snapshots(),
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (projectSnapshot.hasError) {
            return const Center(child: Text('Could not load projects.'));
          }

          final allProjects = projectSnapshot.data!.docs
              .map((doc) => Project.fromFirestore(doc))
              .toList();

          Query query = FirebaseFirestore.instance.collectionGroup(
            FirestoreCollections.attendance,
          );
          if (_selectedProject != null) {
            query = query.where(FirestoreFields.projectId, isEqualTo: _selectedProject!.id);
          }
          if (_selectedDate != null) {
            final start = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
            );
            final end = start.add(const Duration(days: 1));
            query = query.where(
              FirestoreFields.date,
              isGreaterThanOrEqualTo: start,
              isLessThan: end,
            );
          }
          query = query.orderBy(FirestoreFields.date, descending: true);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedProjectId,
                        hint: const Text('All Projects'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Projects'),
                          ),
                          ...allProjects.map((project) {
                            return DropdownMenuItem<String?>(
                              value: project.id,
                              child: Text(project.name),
                            );
                          }),
                        ],
                        onChanged: (projectId) {
                          setState(() {
                            _selectedProjectId = projectId;
                            if (projectId == null) {
                              _selectedProject = null;
                            } else {
                              _selectedProject = allProjects.firstWhere(
                                (p) => p.id == projectId,
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedDate == null
                            ? 'Pick Date'
                            : DateFormat.yMMMd().format(_selectedDate!),
                      ),
                      onPressed: () => _pickDate(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _selectedProject == null
                    ? SingleChildScrollView(
                        child: _buildAllProjectsOverview(
                          _selectedDate ?? DateTime.now(),
                          allProjects,
                        ),
                      )
                    : _buildProjectSpecificView(query),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectWorkerList extends StatelessWidget {
  final String projectName;
  final List<String> workerNames;
  const _ProjectWorkerList({
    required this.projectName,
    required this.workerNames,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueNames = workerNames.toSet().toList();
    uniqueNames.sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        child: ExpansionTile(
          title: Text(projectName),
          subtitle: Text('${uniqueNames.length} worker(s)'),
          children: uniqueNames
              .map(
                (name) => ListTile(
                  dense: true,
                  title: Text(name),
                  leading: const Icon(Icons.person_outline),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
