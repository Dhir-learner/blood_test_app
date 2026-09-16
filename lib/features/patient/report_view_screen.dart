import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/report_service.dart';

/// Opens one lab report. [report] is null for appointments whose report was
/// uploaded before per-test reports existed.
class ReportViewScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;
  final LabReport? report;

  const ReportViewScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
    this.report,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  bool _isLoading = false;

  Future<void> _openReport() async {
    setState(() => _isLoading = true);
    try {
      final service = ReportService();
      final report = widget.report;

      final Uint8List bytes;
      final String fileName;
      final String? contentType;

      if (report != null) {
        bytes = await service.downloadReport(
          appointmentId: widget.appointmentId,
          reportId: report.id,
          chunkCount: report.chunkCount,
        );
        fileName = report.fileName;
        contentType = report.contentType;
      } else {
        final chunkCount = widget.appointmentData['reportChunkCount'] as int?;
        if (chunkCount == null) throw 'This report is unavailable.';
        bytes = await service.downloadLegacyReport(widget.appointmentId, chunkCount);
        fileName = widget.appointmentData['reportName'] as String? ?? 'report.pdf';
        contentType = widget.appointmentData['reportContentType'] as String?;
      }

      // Written to the app's private cache; the previous one is cleared each
      // time so copies don't pile up on the device.
      final tempDir = await getTemporaryDirectory();
      final reportsDir = Directory('${tempDir.path}/reports');
      if (reportsDir.existsSync()) reportsDir.deleteSync(recursive: true);
      reportsDir.createSync(recursive: true);

      final file = File('${reportsDir.path}/${_safeFileName(fileName)}');
      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(file.path, type: contentType);
      if (result.type != ResultType.done) throw result.message;
    } catch (e) {
      debugPrint("Error opening report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not open the report. Please try again.")),
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
    final scheme = Theme.of(context).colorScheme;
    final report = widget.report;
    final data = widget.appointmentData;
    final date = (data['dateTime'] as dynamic)?.toDate();
    final uploaded = report?.uploadedAt ??
        (data['reportUploadedAt'] as dynamic)?.toDate();

    final title = report?.testName ?? data['testType'] as String? ?? 'Blood Test';
    final subtitle = [
      report?.fileName ?? data['reportName'],
      report?.readableSize,
    ].whereType<String>().join(' · ');

    return Scaffold(
      appBar: AppBar(title: const Text("Test report")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.description_outlined,
                          size: 42, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: "Sample collected",
                      value: date == null
                          ? '—'
                          : DateFormat('d MMM y').format(date),
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: "Collected by",
                      value: data['phlebotomistName'] as String? ?? 'Lab staff',
                    ),
                    if (uploaded != null) ...[
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.upload_file_outlined,
                        label: "Report uploaded",
                        value: DateFormat('d MMM y, h:mm a').format(uploaded),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            Text(
              "Only you and the lab can open this report.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? null : _openReport,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new),
              label: Text(_isLoading ? "Opening…" : "Open report"),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 19, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
