import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/project.dart';
import '../models/worker.dart';

class AttendanceHistoryPage extends StatelessWidget {
  final Worker worker;
  final Project project;

  const AttendanceHistoryPage({
    super.key,
    required this.worker,
    required this.project,
  });

  // This function now performs the Firestore query.
  Future<List<Attendance>> _fetchAttendanceHistory() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(project.id)
        .collection('attendance')
        .where('workerId', isEqualTo: worker.uid)
        .orderBy('date', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => Attendance.fromFirestore(doc))
        .toList();
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
          '${worker.name}\'s Attendance',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Project: ${project.name}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha:0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Attendance>>(
        future: _fetchAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load attendance history.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No attendance records found for ${worker.name}.'),
            );
          }

          final records = snapshot.data!;

          // The grouping logic is the same as your old code, which is great!
          final Map<String, List<Attendance>> groupedRecords = {};
          for (var record in records) {
            String monthKey = DateFormat('MMMM yyyy').format(record.date);
            groupedRecords[monthKey] ??= [];
            groupedRecords[monthKey]!.add(record);
          }
          final monthKeys = groupedRecords.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: monthKeys.length,
            itemBuilder: (context, index) {
              final month = monthKeys[index];
              final monthRecords = groupedRecords[month]!;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text(
                    month,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: index == 0,
                  children: monthRecords.map((record) {
                    return ListTile(
                      leading: record.present
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                            )
                          : Icon(Icons.cancel, color: Colors.red.shade600),
                      title: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(record.date),
                      ),
                      trailing: Text(
                        record.present ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: record.present
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
