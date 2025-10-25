import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/worker.dart';

class HelpPage extends StatefulWidget {
  // NEW: Accepts the current user
  final Worker currentUser;
  const HelpPage({super.key, required this.currentUser});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  bool _isLeader = false;

  @override
  void initState() {
    super.initState();
    _checkIfLeader();
  }

  // NEW: Logic to check if the current user is a leader of any project
  Future<void> _checkIfLeader() async {
    // 1. Create a query to find any project where the current user is the leader.
    final query = FirebaseFirestore.instance
        .collection('projects')
        .where('leaderId', isEqualTo: widget.currentUser.uid)
        .limit(1); // We use limit(1) because we only need to find one match.

    // 2. Execute the query.
    final querySnapshot = await query.get();

    // 3. If we found any documents, the user is a leader.
    if (querySnapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _isLeader = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // UPDATED: This section is now only visible to admins
          if (widget.currentUser.isAdmin)
            const _FaqSection(
              title: 'For Admins',
              faqs: [
                _FaqItem(
                  question: 'How does the project payroll process work?',
                  answer:
                      '1. Mark a project as "Finished" from the dashboard.\n2. A "Projects Pending Budget" card will appear at the top.\n3. Tap "Enter Budget", input the total amount, and save.\n4. The system will automatically calculate and distribute the payout to each worker based on their logged attendance.',
                ),
                _FaqItem(
                  question: 'How do I manage users?',
                  answer:
                      'Navigate to the "User Management" page from the icon in the top bar. From there, you can view all users, tap the edit icon to change their details, or tap the delete icon to remove them.',
                ),
              ],
            ),

          // UPDATED: This section is now only visible to project leaders (and admins)
          if (_isLeader || widget.currentUser.isAdmin)
            const _FaqSection(
              title: 'For Project Leaders',
              faqs: [
                _FaqItem(
                  question: 'How do I add an offline worker?',
                  answer:
                      'When viewing a project you lead, expand it to see the member list. Tap the "Add Offline Worker" button at the bottom. This creates a temporary placeholder for marking attendance until an admin creates an official account.',
                ),
                _FaqItem(
                  question: 'How do I change a project\'s status?',
                  answer:
                      'On your dashboard, find the project you are leading. Tap the three-dot menu icon on the right to "Mark as Finished" or "Place On Hold". If a project is on hold, a "Resume" button will appear.',
                ),
              ],
            ),

          const _FaqSection(
            title: 'For All Users',
            faqs: [
              _FaqItem(
                question: 'How do I see my payout?',
                answer:
                    'Once an admin has finished a project and calculated the payroll, the payout amount will automatically appear under the project name on your dashboard.',
              ),
              _FaqItem(
                question: 'What is the "Personal Register"?',
                answer:
                    'The Personal Register is your own private space to track small, personal projects and members that are not part of the main company\'s system. This data is stored securely in your cloud account and is not visible to anyone else.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper widgets to keep the code clean
class _FaqSection extends StatelessWidget {
  final String title;
  final List<_FaqItem> faqs;
  const _FaqSection({required this.title, required this.faqs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
          ...faqs,
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Text(answer)),
      ],
    );
  }
}
