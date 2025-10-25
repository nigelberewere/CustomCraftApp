import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/personal_project.dart';
import '../models/worker.dart';
import 'personal_project_detail_page.dart';

class PersonalProjectsListPage extends StatelessWidget {
  final Worker currentUser;
  const PersonalProjectsListPage({super.key, required this.currentUser});

  void _showCreateProjectDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false; // State for the dialog's create button

    showDialog(
      context: context,
      barrierDismissible: !isLoading, // Prevent closing dialog while loading
      builder: (ctx) => StatefulBuilder(
        // Use StatefulBuilder to manage the state within the dialog
        builder: (dialogContext, setDialogState) {
          // Capture navigator, messenger and dialog theme color here to avoid
          // using the inner BuildContext across async gaps (prevents use_build_context_synchronously).
          final NavigatorState dialogNavigator = Navigator.of(dialogContext);
          final ScaffoldMessengerState dialogMessenger = ScaffoldMessenger.of(dialogContext);
          final Color dialogErrorColor = Theme.of(dialogContext).colorScheme.error;
          return AlertDialog(
            title: const Text('Create Personal Register'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Register Name'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
                ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) {
                          dialogMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                        });

                        try {
                          // FIX: Write to a subcollection within the user's document
                          // Capture messenger and navigator prior to async call
                          final capturedMessenger = dialogMessenger;
                          final capturedNavigator = dialogNavigator;

                          await FirebaseFirestore.instance
                              .collection('workers')
                              .doc(currentUser.uid)
                              .collection('personal_projects')
                              .add({
                                'name': name,
                                'ownerUid': currentUser.uid,
                                'creationDate': Timestamp.now(),
                              });

                          if (capturedNavigator.canPop()) {
                            capturedNavigator.pop();
                          }
                          capturedMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Personal register created successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                          });
                          // Use captured dialogErrorColor instead of Theme.of(dialogContext)
                          dialogMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to create register. Please check Firestore security rules.',
                              ),
                              backgroundColor: dialogErrorColor,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmAndDelete(BuildContext context, PersonalProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please Confirm'),
        content: Text(
          'Are you sure you want to delete the register "${project.name}"? This will remove all members and attendance records.',
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
              Navigator.of(ctx).pop();
              await _deletePersonalProject(context, project);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePersonalProject(
    BuildContext context,
    PersonalProject project,
  ) async {
    final projRef = FirebaseFirestore.instance
        .collection('workers')
        .doc(currentUser.uid)
        .collection('personal_projects')
        .doc(project.id);

    final scaffold = ScaffoldMessenger.of(context);

    try {
      // A Cloud Function is the most robust solution for deleting subcollections.
      // This client-side approach is an alternative but can be less reliable
      // if the user goes offline during the process.

      // 1. Delete members subcollection
      final membersSnapshot = await projRef.collection('members').get();
      for (final doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      // You would add similar logic here for other subcollections like 'attendance_records'

      // 2. Delete the project document itself
      await projRef.delete();

      scaffold.showSnackBar(
        SnackBar(content: Text('Register "${project.name}" deleted.')),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Failed to delete register. Please try again. Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary, // Makes back arrow match text color
        ),
        title: Text(
          'My Personal Registers',
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
        // FIX: Read from the subcollection within the user's document
        stream: FirebaseFirestore.instance
            .collection('workers')
            .doc(currentUser.uid)
            .collection('personal_projects')
            .orderBy('creationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Something went wrong. Please check your Firestore security rules.\nError: ${snapshot.error}',
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no personal registers. Tap + to create one.',
              ),
            );
          }

          final personalProjects = snapshot.data!.docs
              .map((doc) => PersonalProject.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: personalProjects.length,
            itemBuilder: (context, index) {
              final project = personalProjects[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(project.name),
                  subtitle: StreamBuilder<QuerySnapshot>(
                    // FIX: Point to the members subcollection correctly
                    stream: FirebaseFirestore.instance
                        .collection('workers')
                        .doc(currentUser.uid)
                        .collection('personal_projects')
                        .doc(project.id)
                        .collection('members')
                        .snapshots(),
                    builder: (context, memberSnapshot) {
                      final count = memberSnapshot.data?.docs.length ?? 0;
                      return Text('$count member(s)');
                    },
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'open') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // FIX: Pass the currentUser to the detail page
                            builder: (_) => PersonalProjectDetailPage(
                              project: project,
                              currentUser: currentUser,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        _confirmAndDelete(context, project);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      // FIX: Pass the currentUser to the detail page
                      builder: (_) => PersonalProjectDetailPage(
                        project: project,
                        currentUser: currentUser,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateProjectDialog(context),
        tooltip: 'New Personal Register',
        child: const Icon(Icons.add),
      ),
    );
  }
}
