import 'package:flutter/material.dart';
import 'edit_user_page.dart';
import '../models/worker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  void _confirmDeleteUser(BuildContext context, Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${worker.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteUser(worker);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Worker worker) {
    FirebaseFirestore.instance
        .collection(FirestoreCollections.workers)
        .doc(worker.uid)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Color.lerp(Theme.of(context).colorScheme.primary, Colors.black, 0.2)!
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(FirestoreCollections.workers).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final workers = snapshot.data!.docs
              .map((doc) => Worker.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
              return ListTile(
                title: Text(worker.name),
                subtitle: Text(worker.username),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit User',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditUserPage(worker: worker),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete User',
                      onPressed: () => _confirmDeleteUser(context, worker),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
