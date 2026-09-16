import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/test_catalog.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lab dashboard"),
        actions: [
          IconButton(
            tooltip: themeController.isDark ? "Light mode" : "Dark mode",
            icon: Icon(themeController.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: themeController.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search patient or test…",
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: scheme.primary,
                indicatorColor: scheme.primary,
                tabs: const [
                  Tab(text: "Pending"),
                  Tab(text: "Assigned"),
                  Tab(text: "Completed"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AppointmentList(status: 'pending', query: _query),
          AppointmentList(status: 'assigned', query: _query),
          AppointmentList(status: 'completed', query: _query),
        ],
      ),
    );
  }
}

class AppointmentList extends StatelessWidget {
  final String status;
  final String query;

  const AppointmentList({super.key, required this.status, this.query = ''});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingList();
        }

        if (snapshot.hasError) {
          debugPrint("Error loading appointments: ${snapshot.error}");
          return const ErrorView(message: "We couldn't load appointments.");
        }

        var docs = snapshot.data?.docs ?? [];

        if (query.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['patientName'] as String? ?? '').toLowerCase();
            final test = (data['testType'] as String? ?? '').toLowerCase();
            return name.contains(query) || test.contains(query);
          }).toList();
        }

        if (docs.isEmpty) {
          return EmptyState(
            icon: query.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
            title: query.isNotEmpty ? "No matches" : "Nothing here",
            message: query.isNotEmpty
                ? "No $status appointments match your search."
                : "There are no $status appointments right now.",
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _AdminCard(
              data: data,
              status: status,
              onAssign: () => _showAssignDialog(context, doc.id),
              onUpload: () => _showUploadReportDialog(context, doc.id, data),
            );
          },
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AssignPhlebotomistDialog(appointmentId: appointmentId),
    );
  }

  void _showUploadReportDialog(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) => UploadReportDialog(
        appointmentId: appointmentId,
        appointmentData: data,
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String status;
  final VoidCallback onAssign;
  final VoidCallback onUpload;

  const _AdminCard({
    required this.data,
    required this.status,
    required this.onAssign,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = (data['dateTime'] as Timestamp?)?.toDate();
    final hasReport = data['reportChunkCount'] != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
                  child: Text(
                    (data['patientName'] as String? ?? '?')
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['patientName'] as String? ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['testType'] as String? ?? 'Blood Test',
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  date == null
                      ? "—"
                      : DateFormat('d MMM y · h:mm a').format(date),
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (data['price'] != null)
                  Text(
                    "₹${data['price']}",
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
              ],
            ),
            if (data['phlebotomistName'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    "${data['phlebotomistName']}",
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (status == 'pending')
              FilledButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.person_add_alt),
                label: const Text("Assign collector"),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
              )
            else if (status == 'completed')
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: Icon(hasReport ? Icons.check_circle_outline : Icons.upload_file),
                label: Text(hasReport ? "Replace report" : "Upload report"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: hasReport ? const Color(0xFF2E7D32) : null,
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Uploads one report per booked test, so a three-test visit gets three files.
class UploadReportDialog extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const UploadReportDialog({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<UploadReportDialog> createState() => _UploadReportDialogState();
}

class _UploadReportDialogState extends State<UploadReportDialog> {
  final _reportService = ReportService();
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _selectedTest;
  bool _isUploading = false;

  late final List<Map<String, dynamic>> _tests =
      bookedTestsOf(widget.appointmentData);

  @override
  void initState() {
    super.initState();
    if (_tests.length == 1) _selectedTest = _tests.first;
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file != null) {
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    final test = _selectedTest;
    if (file == null || test == null) return;

    setState(() => _isUploading = true);
    try {
      await _reportService.uploadReport(
        appointmentId: widget.appointmentId,
        testId: test['id'] as String? ?? 'report',
        testName: test['name'] as String? ?? 'Report',
        file: file,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is String ? e : "Upload failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _selectedFile;

    return AlertDialog(
      title: const Text("Upload report"),
      content: SizedBox(
        width: 340,
        child: StreamBuilder<List<LabReport>>(
          stream: _reportService.watchReports(widget.appointmentId),
          builder: (context, snapshot) {
            final uploaded = {
              for (final r in snapshot.data ?? <LabReport>[]) r.id: r
            };

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tests.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "WHICH TEST IS THIS REPORT FOR?",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ..._tests.map((test) {
                    final id = test['id'] as String? ?? '';
                    final selected = _selectedTest?['id'] == id;
                    final done = uploaded.containsKey(id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedTest = test),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? scheme.primary
                                  : scheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                done
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: done
                                    ? const Color(0xFF2E7D32)
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      test['name'] as String? ?? 'Test',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5),
                                    ),
                                    if (done)
                                      Text(
                                        "Report uploaded — choosing this replaces it",
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          file == null
                              ? Icons.cloud_upload_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 30,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          file?.name ?? "No file selected",
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "PDF, JPG or PNG · up to 4 MB",
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(file == null ? "Choose file" : "Choose another"),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed:
              file == null || _selectedTest == null || _isUploading ? null : _upload,
          child: const Text("Upload"),
        ),
      ],
    );
  }
}

class AssignPhlebotomistDialog extends StatefulWidget {
  final String appointmentId;
  const AssignPhlebotomistDialog({super.key, required this.appointmentId});

  @override
  State<AssignPhlebotomistDialog> createState() => _AssignPhlebotomistDialogState();
}

class _AssignPhlebotomistDialogState extends State<AssignPhlebotomistDialog> {
  String? _selectedId;
  String? _selectedName;
  bool _isSaving = false;

  Future<void> _assign() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'status': 'assigned',
        'phlebotomistId': _selectedId,
        'phlebotomistName': _selectedName,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Assign error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not assign. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text("Assign collector"),
      content: SizedBox(
        width: 320,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'phlebotomist')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final staff = snapshot.data?.docs ?? [];
            if (staff.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "No phlebotomists yet. Create an account, then set its role "
                  "to 'phlebotomist' in the Firebase console.",
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: staff.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? data['email'] as String? ?? 'Staff';
                final selected = _selectedId == doc.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _selectedId = doc.id;
                      _selectedName = name;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              name.characters.first.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          if (selected)
                            Icon(Icons.check_circle, color: scheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _selectedId == null || _isSaving ? null : _assign,
          child: const Text("Assign"),
        ),
      ],
    );
  }
}
