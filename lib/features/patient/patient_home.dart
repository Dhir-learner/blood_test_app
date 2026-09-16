import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/test_catalog.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/appointment_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import 'appointment_detail_screen.dart';
import 'book_appointment_screen.dart';
import 'profile_screen.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  final _appointmentService = AppointmentService();
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final profile = await FirestoreService().getUserProfile(user.uid);
    if (!mounted) return;
    setState(() => _name = (profile?['name'] as String?)?.split(' ').first);
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _loadName(); // the name may have changed
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(name: _name, onProfile: _openProfile),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _appointmentService.getPatientAppointments(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingList();
                  }

                  if (snapshot.hasError) {
                    debugPrint("Error loading appointments: ${snapshot.error}");
                    return ErrorView(
                      message: "We couldn't load your appointments.",
                      onRetry: () => setState(() {}),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return EmptyState(
                      icon: Icons.science_outlined,
                      title: "No appointments yet",
                      message:
                          "Book a blood test and our collector will visit you at home.",
                      action: FilledButton.icon(
                        onPressed: _openBooking,
                        icon: const Icon(Icons.add),
                        label: const Text("Book a test"),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(200, 50)),
                      ),
                    );
                  }

                  final upcoming = docs.where((d) {
                    final status = (d.data() as Map<String, dynamic>)['status'];
                    return status == 'pending' || status == 'assigned';
                  }).length;

                  return RefreshIndicator(
                    onRefresh: () async => _loadName(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              upcoming > 0
                                  ? "$upcoming upcoming"
                                  : "Past appointments",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        final doc = docs[index - 1];
                        return _AppointmentCard(
                          data: doc.data() as Map<String, dynamic>,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(
                                appointmentId: doc.id,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBooking,
        icon: const Icon(Icons.add),
        label: const Text("Book a test"),
      ),
    );
  }

  void _openBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookAppointmentScreen()),
    );
  }
}

class _Header extends StatelessWidget {
  final String? name;
  final VoidCallback onProfile;

  const _Header({this.name, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bloodtype_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null ? "Welcome" : "Hi, $name",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  "Your appointments",
                  style:
                      TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: themeController.isDark ? "Light mode" : "Dark mode",
            icon: Icon(themeController.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: themeController.toggle,
          ),
          IconButton(
            tooltip: "Profile and addresses",
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: onProfile,
          ),
          IconButton(
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _AppointmentCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = data['status'] as String? ?? 'pending';
    final style = StatusStyle.of(status, Theme.of(context).brightness);
    final date = (data['dateTime'] as Timestamp?)?.toDate();
    final tests = bookedTestsOf(data);

    // Newer bookings track a report per test; older ones had a single report.
    final reportCount = data['reportCount'] as int? ??
        (data['reportChunkCount'] != null ? 1 : 0);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testSummary(data),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date == null
                          ? "—"
                          : DateFormat('EEE, d MMM · h:mm a').format(date),
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        StatusBadge(status, compact: true),
                        if (reportCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 13, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  reportCount == 1
                                      ? "Report ready"
                                      : "$reportCount reports",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (tests.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            "${tests.length} tests",
                            style: TextStyle(
                                fontSize: 11.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
