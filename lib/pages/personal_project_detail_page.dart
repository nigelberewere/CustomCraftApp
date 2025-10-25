import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/personal_project.dart';
import '../models/personal_worker.dart';
import '../models/worker.dart'; // Import the main Worker model

class PersonalProjectDetailPage extends StatefulWidget {
  final PersonalProject project;
  final Worker currentUser; // FIX: Add currentUser to receive it
  const PersonalProjectDetailPage({
    super.key,
    required this.project,
    required this.currentUser,
  });

  @override
  State<PersonalProjectDetailPage> createState() =>
      _PersonalProjectDetailPageState();
}

class _PersonalProjectDetailPageState extends State<PersonalProjectDetailPage> {
  late String _projectName;

  @override
  void initState() {
    super.initState();
    _projectName = widget.project.name;
  }

  // FIX: Use the currentUser's UID to build the correct path to the project
  DocumentReference get _projectRef => FirebaseFirestore.instance
      .collection('workers')
      .doc(widget.currentUser.uid)
      .collection('personal_projects')
      .doc(widget.project.id);

  void _showAddWorkerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Member Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _projectRef.collection('members').add({
                  'name': name,
                  'dateAdded': Timestamp.now(),
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProjectNameDialog() {
    final controller = TextEditingController(text: _projectName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Register Name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _projectRef.update({'name': newName});
                setState(() {
                  _projectName = newName;
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(PersonalWorker worker) {
    final controller = TextEditingController(text: worker.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Member'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showDeleteConfirmDialog(worker);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _projectRef.collection('members').doc(worker.id).update({
                  'name': newName,
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(PersonalWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please Confirm'),
        content: Text(
          'Are you sure you want to delete ${worker.name}? All their attendance records for this register will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              // FIX: Capture navigator before async gap to avoid use_build_context_synchronously warning.
              final navigator = Navigator.of(ctx); 
              await _projectRef.collection('members').doc(worker.id).delete();
              if (!navigator.mounted) return;
              navigator.pop();
            },
            child: Text(
              'Confirm Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance(PersonalWorker worker, bool isPresent) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));
    final attendanceCollection = _projectRef.collection('attendance');

    final querySnapshot = await attendanceCollection
        .where('memberId', isEqualTo: worker.id)
        .where('date', isGreaterThanOrEqualTo: startOfToday)
        .where('date', isLessThan: endOfToday)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docId = querySnapshot.docs.first.id;
      await attendanceCollection.doc(docId).update({'isPresent': isPresent});
    } else {
      await attendanceCollection.add({
        'date': Timestamp.now(),
        'isPresent': isPresent,
        'memberId': worker.id,
        'memberName': worker.name,
      });
    }
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
          _projectName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            tooltip: 'Edit Register Name',
            onPressed: _showEditProjectNameDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _projectRef
            .collection('members')
            .orderBy('dateAdded')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!.docs
              .map((doc) => PersonalWorker.fromFirestore(doc))
              .toList();

          if (members.isEmpty) {
            return const Center(child: Text('No members have been added yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final worker = members[index];
              return _MemberTile(
                projectRef: _projectRef,
                worker: worker,
                onMarkAttendance: (isPresent) =>
                    _markAttendance(worker, isPresent),
                onEditMember: () => _showEditMemberDialog(worker),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        label: const Text('Add Member'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final DocumentReference projectRef;
  final PersonalWorker worker;
  final Function(bool) onMarkAttendance;
  final VoidCallback onEditMember;

  const _MemberTile({
    required this.projectRef,
    required this.worker,
    required this.onMarkAttendance,
    required this.onEditMember,
  });

  void _showEditAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change status for ${worker.name}'),
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
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return Card(
      child: ListTile(
        onLongPress: onEditMember,
        title: Text(worker.name),
        subtitle: StreamBuilder<QuerySnapshot>(
          stream: projectRef
              .collection('attendance')
              .where('memberId', isEqualTo: worker.id)
              .where('isPresent', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            final presentCount = snapshot.data?.docs.length ?? 0;
            return Text('Present: $presentCount day(s)');
          },
        ),
        trailing: StreamBuilder<QuerySnapshot>(
          stream: projectRef
              .collection('attendance')
              .where('memberId', isEqualTo: worker.id)
              .where('date', isGreaterThanOrEqualTo: startOfToday)
              .where('date', isLessThan: endOfToday)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(width: 96);

            if (snapshot.data!.docs.isNotEmpty) {
              final todayRecord = snapshot.data!.docs.first;
              final isPresent = todayRecord['isPresent'] as bool;
              return GestureDetector(
                onTap: () => _showEditAttendanceDialog(context),
                child: Chip(
                  label: Text(isPresent ? 'Present' : 'Absent'),
                  backgroundColor: isPresent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                ),
              );
            } else {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    tooltip: 'Mark Present',
                    onPressed: () => onMarkAttendance(true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_off, color: Colors.red),
                    tooltip: 'Mark Absent',
                    onPressed: () => onMarkAttendance(false),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
