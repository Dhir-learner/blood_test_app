import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/test_catalog.dart';
import '../../core/services/appointment_service.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import 'report_view_screen.dart';

/// Everything the patient needs to know about one booking, live from Firestore.
class AppointmentDetailScreen extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Appointment")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Error loading appointment: ${snapshot.error}");
            return const ErrorView(message: "We couldn't load this appointment.");
          }
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: "Appointment not found",
              message: "It may have been removed.",
            );
          }

          return _Body(appointmentId: appointmentId, data: data);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const _Body({required this.appointmentId, required this.data});

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cancel this appointment?"),
        content: const Text(
            "The collector will no longer visit. You can always book again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep it"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Cancel booking"),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppointmentService().cancelAppointment(appointmentId);
      messenger.showSnackBar(
        const SnackBar(content: Text("Appointment cancelled")),
      );
    } catch (e) {
      debugPrint("Cancel error: $e");
      messenger.showSnackBar(
        const SnackBar(content: Text("Could not cancel. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = data['status'] as String? ?? 'pending';
    final date = (data['dateTime'] as Timestamp?)?.toDate();
    final tests = bookedTestsOf(data);
    final canCancel = status == 'pending' || status == 'assigned';
    final anyFasting = tests.any(
        (t) => findTestById(t['id'] as String?)?.fastingRequired ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tests.length == 1
                    ? (tests.first['name'] as String? ?? 'Blood Test')
                    : "${tests.length} tests",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(status),
          ],
        ),
        if (data['price'] != null) ...[
          const SizedBox(height: 6),
          Text(
            "₹${data['price']}",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary),
          ),
        ],
        const SizedBox(height: 24),
        _StatusTimeline(status: status),
        const SizedBox(height: 24),
        _ReportsSection(appointmentId: appointmentId, data: data, tests: tests),
        const SizedBox(height: 20),
        _TestsCard(tests: tests, anyFasting: anyFasting),
        const SizedBox(height: 14),
        _DetailCard(
          title: "Visit details",
          rows: [
            _Row(Icons.event_outlined, "When",
                date == null ? "—" : DateFormat('EEEE, d MMM y · h:mm a').format(date)),
            _Row(Icons.home_outlined, "Address",
                "Flat ${data['flatNumber'] ?? '-'}, Floor ${data['floor'] ?? '-'}\n${data['address'] ?? ''}"),
            if ((data['notes'] as String?)?.isNotEmpty ?? false)
              _Row(Icons.sticky_note_2_outlined, "Notes", data['notes']),
            if (data['phlebotomistName'] != null)
              _Row(Icons.person_outline, "Collector", data['phlebotomistName']),
          ],
        ),
        if (canCancel) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.close),
            label: const Text("Cancel appointment"),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ],
    );
  }
}

/// One row per booked test: open its report, or say it's still being prepared.
class _ReportsSection extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> tests;

  const _ReportsSection({
    required this.appointmentId,
    required this.data,
    required this.tests,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final legacyChunks = data['reportChunkCount'] as int?;

    return StreamBuilder<List<LabReport>>(
      stream: ReportService().watchReports(appointmentId),
      builder: (context, snapshot) {
        final reports = {for (final r in snapshot.data ?? <LabReport>[]) r.id: r};

        // A report uploaded before per-test reports existed.
        if (reports.isEmpty && legacyChunks != null) {
          return Card(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              leading: Icon(Icons.description_outlined,
                  color: scheme.onPrimaryContainer),
              title: const Text("Your report is ready",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportViewScreen(
                      appointmentId: appointmentId,
                      appointmentData: data,
                    ),
                  ),
                ),
                child: const Text("View"),
              ),
            ),
          );
        }

        if (reports.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tests.length > 1
                          ? "Reports appear here as the lab finishes each test."
                          : "Your report appears here once the lab uploads it.",
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "REPORTS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...tests.map((test) {
              final id = test['id'] as String? ?? '';
              final report = reports[id];
              final name = test['name'] as String? ?? 'Test';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  color: report != null
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(
                          report != null
                              ? Icons.description_outlined
                              : Icons.hourglass_empty,
                          size: 20,
                          color: report != null
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              Text(
                                report != null
                                    ? "Ready · ${report.readableSize}"
                                    : "Awaiting lab",
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (report != null)
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportViewScreen(
                                  appointmentId: appointmentId,
                                  appointmentData: data,
                                  report: report,
                                ),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(80, 38)),
                            child: const Text("View"),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _TestsCard extends StatelessWidget {
  final List<Map<String, dynamic>> tests;
  final bool anyFasting;

  const _TestsCard({required this.tests, required this.anyFasting});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TESTS BOOKED",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...tests.map((test) {
              final known = findTestById(test['id'] as String?);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test['name'] as String? ?? 'Test',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (known != null)
                            Text(
                              known.description,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    if (test['price'] != null)
                      Text(
                        "₹${test['price']}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              );
            }),
            if (anyFasting) ...[
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.no_food_outlined,
                      size: 18, color: Color(0xFFE08600)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Fasting needed: no food for 8–12 hours before the visit. "
                      "Water is fine.",
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == 'cancelled') {
      final style = StatusStyle.of(status, Theme.of(context).brightness);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(style.icon, color: style.color),
            const SizedBox(width: 12),
            const Expanded(child: Text("This appointment was cancelled.")),
          ],
        ),
      );
    }

    const steps = ['pending', 'assigned', 'completed'];
    const labels = ['Booked', 'Collector assigned', 'Sample collected'];
    final current = steps.indexOf(status).clamp(0, steps.length - 1);

    return Column(
      children: List.generate(steps.length, (i) {
        final done = i <= current;
        final isLast = i == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(
                      color: done ? scheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? scheme.primary : scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: i < current
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 22, top: 2),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: done ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Row {
  final IconData icon;
  final String label;
  final String value;
  _Row(this.icon, this.label, this.value);
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _DetailCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final row in rows) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(row.value,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              if (row != rows.last) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
