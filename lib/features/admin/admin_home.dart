import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => AuthService().signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Pending"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AppointmentList(status: 'pending'),
            AppointmentList(status: 'completed'),
          ],
        ),
      ),
    );
  }
}

class AppointmentList extends StatelessWidget {
  final String status;
  const AppointmentList({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $status appointments."));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['dateTime'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(data['testType'] ?? 'Blood Test'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Patient: ${data['patientName'] ?? 'Unknown'}"),
                    Text("Date: ${DateFormat('MMM d, y - h:mm a').format(date)}"),
                    if (status == 'completed' && data['phlebotomistName'] != null)
                      Text("Collected by: ${data['phlebotomistName']}"),
                  ],
                ),
                trailing: status == 'pending'
                    ? ElevatedButton(
                        onPressed: () => _showAssignDialog(context, doc.id),
                        child: const Text("Assign"),
                      )
                    : IconButton(
                        icon: const Icon(Icons.upload_file, color: Colors.blue),
                        onPressed: () => _showUploadReportDialog(context, doc.id),
                      ),
              ),
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

  void _showUploadReportDialog(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => UploadReportDialog(appointmentId: appointmentId),
    );
  }
}

class UploadReportDialog extends StatefulWidget {
  final String appointmentId;
  const UploadReportDialog({super.key, required this.appointmentId});

  @override
  State<UploadReportDialog> createState() => _UploadReportDialogState();
}

class _UploadReportDialogState extends State<UploadReportDialog> {
  File? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await StorageService().uploadReport(widget.appointmentId, _selectedFile!);
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .update({'reportUrl': url});
        if (mounted) Navigator.pop(context);
      } else {
        throw "Upload failed";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Upload Report"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFile != null)
            Text("Selected: ${p.basename(_selectedFile!.path)}")
          else
            const Text("No file selected"),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: const Text("Pick Document"),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _selectedFile == null || _isUploading ? null : _upload,
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
  String? _selectedPhlebotomistId;
  String? _selectedPhlebotomistName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Assign Phlebotomist"),
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'phlebotomist')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          
          final phlebotomists = snapshot.data!.docs;
          
          if (phlebotomists.isEmpty) {
            return const Text("No phlebotomists found.");
          }

          return DropdownButtonFormField<String>(
            initialValue: _selectedPhlebotomistId,
            hint: const Text("Select Phlebotomist"),
            items: phlebotomists.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: doc.id,
                child: Text(data['name'] ?? data['email']),
                onTap: () {
                  _selectedPhlebotomistName = data['name'] ?? data['email'];
                },
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedPhlebotomistId = val);
            },
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _selectedPhlebotomistId == null
              ? null
              : () async {
                  await FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(widget.appointmentId)
                      .update({
                    'status': 'assigned',
                    'phlebotomistId': _selectedPhlebotomistId,
                    'phlebotomistName': _selectedPhlebotomistName,
                  });
                  if (mounted) Navigator.pop(context);
                },
          child: const Text("Assign"),
        ),
      ],
    );
  }
}
