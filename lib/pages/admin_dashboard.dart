import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:customcraft_app/widgets/animated_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';
import '../models/project.dart';
import '../models/worker.dart';
import '../models/quotation.dart';
import '../widgets/project_list_shimmer.dart';
import 'quotation_viewer_page.dart';
import '../theme_notifier.dart';
import 'admin_attendance_viewer_page.dart';
import 'edit_project_page.dart';
import 'financials_page.dart';
import 'quotation_history_page.dart';
import 'truss_calculator_page.dart';
import 'user_management_page.dart';
import '../services/project_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class AdminDashboard extends StatefulWidget {
  final Worker worker;
  const AdminDashboard({super.key, required this.worker});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(
          () => setState(() => _searchQuery = _searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  void _showMarkCompletedDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please Confirm'),
        content: Text(
          'Do you want to mark the project "${project.name}" as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ProjectService.updateProjectStatus(
                  project, ProjectStatus.finished);
              Navigator.of(ctx).pop();
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  // UPDATED: Now an async function that shows a results dialog on success.
  void _showBudgetDialog(BuildContext context, Project project) {
    final payoutPoolController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
  bool isProcessing = false;
        return StatefulBuilder(builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Text('Calculate Payroll for ${project.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: payoutPoolController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Payout Pool (Amount to distribute)',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter an amount.';
                      }
                      if (double.tryParse(val) == null ||
                          double.parse(val) < 0) {
                        return 'Please enter a valid positive number.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isProcessing = true);
                          final totalPayoutPool =
                              double.parse(payoutPoolController.text);

                          // Capture relevant navigation/messenger before awaiting
                          final savedDialogNavigator = Navigator.of(ctx);
                          final savedAppMessenger = ScaffoldMessenger.of(context);

                          try {
              final results =
                await ProjectService.calculateAndSavePayouts(
                  project, totalPayoutPool);
              if (!mounted) return;
              // Use captured navigator/messenger after await
              savedDialogNavigator.pop(); // Close budget dialog
              _showCalculationResultsDialog(
                savedDialogNavigator.context, project.name, results);
                          } catch (e) {
                            if (mounted) {
                              savedAppMessenger.showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Error calculating payouts: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => isProcessing = false);
                            }
                          }
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Calculate & Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // UPDATED: This dialog no longer shows profit/loss.
  void _showCalculationResultsDialog(BuildContext context, String projectName,
      Map<String, double> results) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final totalPayout = results['totalPayout'] ?? 0.0;
    final workersPaid = results['workersPaid']?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
            title: Text('Calculation Complete for "$projectName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_rounded),
              title: Text(currencyFormat.format(totalPayout)),
              subtitle: Text('Total distributed to $workersPaid worker(s)'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final projectController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String? selectedQuotationId;
          return AlertDialog(
            title: const Text('Create New Project'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: projectController,
                  decoration: const InputDecoration(labelText: 'Project Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('quotations')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!.docs
                        .map(
                          (doc) => DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          doc['clientName'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList();
                    return DropdownButtonFormField<String>(
                      initialValue: selectedQuotationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Link to Quotation (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...items,
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedQuotationId = v),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = projectController.text.trim();
                  if (name.isNotEmpty) {
                    final newProject = Project(
                      name: name,
                      creationDate: DateTime.now(),
                      quotationId: selectedQuotationId,
                    );
                    FirebaseFirestore.instance
                        .collection('projects')
                        .add(newProject.toMap());
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteProjectConfirmDialog(BuildContext context, Project project) {
    final outerContext = context;
    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Please Confirm'),
              content: Text(
                'Are you sure you want to delete the project "${project.name}"? This will unassign all workers and cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(outerContext).colorScheme.error,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    setDialogState(() => isLoading = true);
                    final NavigatorState navigator = Navigator.of(ctx);
                    final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(outerContext);
                    try {
                      await ProjectService.deleteProject(
                          context, project);
                      if (mounted) navigator.pop();
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error deleting project: $e'),
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
                      : Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(outerContext).colorScheme.onError,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showUnassignConfirmDialog(
      BuildContext context,
      Project project,
      Worker worker,
      ) async {
    final outerContext = context;
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Please Confirm'),
              content: Text(
                'Are you sure you want to unassign ${worker.name} from the project "${project.name}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(outerContext).colorScheme.error,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    setDialogState(() => isLoading = true);
                    final NavigatorState navigator = Navigator.of(ctx);
                    final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(outerContext);
                    try {
                      await ProjectService.unassignWorker(
                          project, worker);
                      if (mounted) navigator.pop();
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content:
                          Text('Error unassigning worker: $e'),
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
                      : Text(
                    'Unassign',
                    style: TextStyle(
                      color: Theme.of(outerContext).colorScheme.onError,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPendingBudgets(List<Project> projects) {
    final pendingProjects = projects
        .where((p) => p.status == ProjectStatus.finished && p.finalPayouts.isEmpty)
        .toList();
    if (pendingProjects.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects Pending Payroll',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            ...pendingProjects.map(
              (project) => ListTile(
                title: Text(project.name),
                trailing: ElevatedButton(
                  onPressed: () => _showBudgetDialog(context, project),
                  child: const Text('Calculate Payroll'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
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
        title: const Text('Admin Dashboard'),
        // FIX: Ensure text and icons are readable against the primary color.
        foregroundColor: Theme.of(context).colorScheme.onPrimary, // Set text/icon color
        // ENHANCEMENT: Add a subtle gradient to the AppBar.
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
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Financial Insights',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FinancialsPage()),
              );
            },
          ),
          IconButton(
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
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'View All Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAttendanceViewerPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'User Management',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Change Theme',
            onPressed: () => _showThemeChooserDialog(context, themeNotifier),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Projects',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('workers')
                  .where('isAdmin', isEqualTo: false)
                  .snapshots(),
              builder: (context, workerSnapshot) {
                if (workerSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const ProjectListShimmer();
                }
                if (workerSnapshot.hasError) {
                  return const Center(child: Text('Error loading workers.'));
                }

                final allWorkers = workerSnapshot.data!.docs
                    .map((d) => Worker.fromFirestore(d))
                    .toList();
                final Map<String, Worker> workerMap = {
                  for (var w in allWorkers) w.uid: w,
                };

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .orderBy('creationDate', descending: true)
                      .snapshots(),
                  builder: (context, projectSnapshot) {
                    if (projectSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const ProjectListShimmer();
                    }
                    if (projectSnapshot.hasError) {
                      return const Center(
                          child: Text('Something went wrong.'));
                    }

                    final allProjects = projectSnapshot.data!.docs
                        .map((d) => Project.fromFirestore(d))
                        .toList();
                    final pendingBudgetsWidget = _buildPendingBudgets(
                      allProjects,
                    );

                    final filteredProjects = allProjects
                        .where(
                          (p) => p.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                        .toList();

                    if (allProjects.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.folder_off_outlined,
                        title: 'No Projects Yet',
                        message:
                        "Tap the '+' button below to create your first project.",
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: Column(
                        children: [
                          if (_searchQuery.isEmpty) pendingBudgetsWidget,
                          if (filteredProjects.isEmpty)
                            const Expanded(
                              child: EmptyStateWidget(
                                icon: Icons.search_off,
                                title: 'No Results Found',
                                message:
                                "Your search did not match any projects.",
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                padding:
                                const EdgeInsets.fromLTRB(8, 0, 8, 160),
                                itemCount: filteredProjects.length,
                                itemBuilder: (_, index) {
                                  final project = filteredProjects[index];
                                  final Worker? leader =
                                  workerMap[project.leaderId];

                                  return AnimatedListItem(
                                    index: index,
                                    child: ProjectListItem(
                                      key: ValueKey(project.id),
                                      project: project,
                                      leader: leader,
                                      allWorkers: allWorkers,
                                      workerMap: workerMap,
                                      onMarkCompleted: () =>
                                          _showMarkCompletedDialog(
                                              context, project),
                                      onUpdateStatus: (status) =>
                                          ProjectService.updateProjectStatus(
                                              project, status),
                                      onEdit: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditProjectPage(project: project),
                                        ),
                                      ),
                                      onDelete: () =>
                                          _showDeleteProjectConfirmDialog(
                                              context, project),
                                      onUnassign: (w) async =>
                                          await _showUnassignConfirmDialog(
                                              context, project, w),
                                      onAssign: (w, {bool leader = false}) =>
                                          ProjectService.assignWorker(project, w,
                                              leader: leader),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuotationHistoryPage()),
            ),
            heroTag: 'quotations_fab',
            label: const Text('Quotations'),
            icon: const Icon(Icons.request_quote),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: () => _showCreateProjectDialog(context),
            heroTag: 'add_project_fab',
            label: const Text('New Project'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

// NEW: A dialog to choose both theme mode and color.
void _showThemeChooserDialog(BuildContext context, ThemeNotifier themeNotifier) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // Use a StatefulBuilder to manage the state of the selections within the dialog.
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
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ],
                  selected: {themeNotifier.themeMode},
                  onSelectionChanged: (newSelection) {
                    themeNotifier.setThemeMode(newSelection.first);
                    // We need to call setDialogState to rebuild the dialog with the new selection.
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

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.4 * 255).round()),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectListItem extends StatefulWidget {
  const ProjectListItem({
    super.key,
    required this.project,
    required this.leader,
    required this.allWorkers,
    required this.workerMap,
    required this.onMarkCompleted,
    required this.onUpdateStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onUnassign,
    required this.onAssign,
  });

  final Project project;
  final Worker? leader;
  final List<Worker> allWorkers;
  final Map<String, Worker> workerMap;
  final VoidCallback onMarkCompleted;
  final Function(ProjectStatus) onUpdateStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(Worker) onUnassign;
  final Future<void> Function(Worker, {bool leader}) onAssign;

  @override
  State<ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends State<ProjectListItem> {
  late Project _project;
  final Map<String, bool> _isProcessing = {};

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  @override
  void didUpdateWidget(ProjectListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project != oldWidget.project) {
      setState(() {
        _project = widget.project;
      });
    }
  }

  void _handleAssign(Worker worker, {bool isLeader = false}) {
    setState(() {
      _isProcessing[worker.uid] = true;
      if (!_project.memberIds.contains(worker.uid)) {
        _project.memberIds.add(worker.uid);
      }
      if (isLeader) {
        _project.leaderId = worker.uid;
      }
    });

    widget.onAssign(worker, leader: isLeader).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing.remove(worker.uid));
      }
    });
  }

  void _handleUnassign(Worker worker) {
    setState(() {
      _isProcessing[worker.uid] = true;
      _project.memberIds.remove(worker.uid);
      if (_project.leaderId == worker.uid) {
        _project.leaderId = null;
      }
    });

    widget.onUnassign(worker).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing.remove(worker.uid));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ExpansionTile(
        key: PageStorageKey(_project.id),
        title: Text(_project.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_project.status == ProjectStatus.finished
            ? 'Status: Finished'
            : _project.status == ProjectStatus.onHold
            ? 'Status: On Hold'
            : widget.leader != null
            ? 'Leader: ${widget.leader!.name}'
            : 'No leader assigned'),
        trailing: Builder(builder: (context) {
          switch (_project.status) {
            case ProjectStatus.finished:
              return Chip(
                  label: const Text('Completed'),
                  backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                      color:
                      Theme.of(context).colorScheme.onPrimaryContainer));
            case ProjectStatus.onHold:
              return Row(mainAxisSize: MainAxisSize.min, children: [
                const Chip(label: Text('On Hold')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () =>
                        widget.onUpdateStatus(ProjectStatus.ongoing),
                    child: const Text('Resume'))
              ]);
            case ProjectStatus.ongoing:
              return PopupMenuButton(
                  onSelected: (value) {
                    if (value == 'finish') widget.onMarkCompleted();
                    if (value == 'hold') {
                      widget.onUpdateStatus(ProjectStatus.onHold);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'finish',
                        child: Text('Mark as Finished')),
                    const PopupMenuItem(
                        value: 'hold', child: Text('Place On Hold')),
                  ],
                  icon: const Icon(Icons.more_vert));
          }
        }),
        children: [
          if (_project.quotationId != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('quotations')
                  .doc(_project.quotationId)
                  .get(),
              builder: (context, quoteSnapshot) {
                if (!quoteSnapshot.hasData) return const SizedBox.shrink();
                final quotation =
                Quotation.fromFirestore(quoteSnapshot.data!);
                return ListTile(
                    leading: const Icon(Icons.request_quote_outlined),
                    title: const Text('View Project Quotation'),
                    subtitle: Text('For: ${quotation.clientName}'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QuotationViewerPage(
                                quotation: quotation))));
              },
            ),
          if (_project.status == ProjectStatus.finished) // Display date range for finished projects
            FutureBuilder<Map<String, DateTime?>>(
              future: ProjectService.getProjectDateRange(_project),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                      subtitle: Text("Loading date range..."));
                }
                if (!snapshot.hasData || snapshot.data!['start'] == null) {
                  return const ListTile(
                    leading: Icon(Icons.date_range_outlined),
                    subtitle: Text('No attendance was recorded.'),
                  );
                }
                final startDate = snapshot.data!['start']!;
                final endDate = snapshot.data!['end']!;
                return ListTile(
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text(
                      'Started: ${DateFormat.yMMMd().format(startDate)}'),
                  subtitle:
                      Text('Ended: ${DateFormat.yMMMd().format(endDate)}'),
                );
              },
            ),
          if (_project.status == ProjectStatus.finished)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Theme.of(context).colorScheme.error),
                    onPressed: widget.onDelete,
                    icon: Icon(Icons.delete,
                        color: Theme.of(context).colorScheme.onError),
                    label: Text('Delete Project',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onError)),
                  ),
                ],
              ),
            ),
          if (_project.status == ProjectStatus.ongoing)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child:
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit')),
                  TextButton.icon(
                      onPressed: widget.onDelete,
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
                      label: Text('Delete',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))
                ])),
          const Divider(),
          ListTile(
            title: Text("Team Members",
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: const Text('Assign workers to this project'),
          ),
          ..._project.memberIds.map((memberId) {
            final worker = widget.workerMap[memberId];
            if (worker == null) return const SizedBox.shrink();

            final isLeader = _project.leaderId == worker.uid;
            final payout = _project.finalPayouts[worker.uid];
            final bool isProcessing = _isProcessing[worker.uid] ?? false;

            return ListTile(
              title: Text(worker.name),
              subtitle: payout != null && _project.budget > 0.0
                  ? Text('Payout: \$${payout.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green))
                  : null,
              trailing: isProcessing
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : isLeader
                  ? Chip(
                  label: const Text('Leader'),
                  backgroundColor:
                  Theme.of(context).colorScheme.tertiaryContainer)
                  : _project.status != ProjectStatus.ongoing
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: () => _handleUnassign(worker),
                    child: const Text('Unassign')),
                ElevatedButton(
                    onPressed: () =>
                        _handleAssign(worker, isLeader: true),
                    child: const Text('Make Leader'))
              ]),
            );
          }),
          if (_project.status != ProjectStatus.finished)
            ListTile(
              title: const Text('Assign a Worker'),
              trailing: PopupMenuButton<Worker>(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Assign a worker',
                onSelected: (worker) => _handleAssign(worker),
                itemBuilder: (context) {
                  final assignableWorkers = widget.allWorkers
                      .where((w) => !_project.memberIds.contains(w.uid))
                      .toList();
                  if (assignableWorkers.isEmpty) {
                    return [
                      const PopupMenuItem(
                          enabled: false,
                          child: Text('No workers to assign'))
                    ];
                  }
                  return assignableWorkers.map((worker) {
                    return PopupMenuItem<Worker>(
                      value: worker,
                      child: Text(worker.name),
                    );
                  }).toList();
                },
              ),
            ),
        ],
      ),
    );
  }
}
