import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/report_service.dart';

class ReportViewScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const ReportViewScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  bool _isLoading = false;

  Future<void> _openReport() async {
    final chunkCount = widget.appointmentData['reportChunkCount'] as int?;
    if (chunkCount == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await ReportService()
          .downloadReport(widget.appointmentId, chunkCount);

      // Reports are written to the app's private cache. The previous one is
      // cleared each time so copies don't pile up on the device.
      final tempDir = await getTemporaryDirectory();
      final reportsDir = Directory('${tempDir.path}/reports');
      if (reportsDir.existsSync()) reportsDir.deleteSync(recursive: true);
      reportsDir.createSync(recursive: true);

      final name = widget.appointmentData['reportName'] as String? ?? 'report.pdf';
      final file = File('${reportsDir.path}/${_safeFileName(name)}');
      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(
        file.path,
        type: widget.appointmentData['reportContentType'] as String?,
      );
      if (result.type != ResultType.done) {
        throw result.message;
      }
    } catch (e) {
      debugPrint("Error opening report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the report. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Keeps a crafted file name from escaping the reports directory.
  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'report' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.appointmentData['dateTime'] as dynamic).toDate();

    return Scaffold(
      appBar: AppBar(title: const Text("Test Report")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(Icons.description, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              widget.appointmentData['testType'] ?? 'Blood Test',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(Icons.calendar_today, "Date", DateFormat('MMM d, yyyy').format(date)),
            _infoRow(Icons.person, "Phlebotomist",
                widget.appointmentData['phlebotomistName'] ?? 'Assigned Staff'),
            _infoRow(Icons.check_circle, "Status", "Completed"),
            const Spacer(),
            const Text(
              "Your report is ready for viewing. Click the button below to open the secure document.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _openReport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isLoading ? "Opening..." : "View Full Report",
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}
