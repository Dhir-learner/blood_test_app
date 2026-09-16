import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/test_catalog.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/state_views.dart';
import 'phlebotomist_map_screen.dart';

class PhlebotomistHome extends StatelessWidget {
  const PhlebotomistHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final scheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My collections"),
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('phlebotomistId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'assigned')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }

          if (snapshot.hasError) {
            debugPrint("Error loading tasks: ${snapshot.error}");
            return const ErrorView(message: "We couldn't load your tasks.");
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: "All caught up",
              message: "No collections assigned to you right now.",
            );
          }

          // Soonest visit first, so the next stop is always on top.
          final sorted = docs.toList()
            ..sort((a, b) {
              final aDate = (a.data() as Map<String, dynamic>)['dateTime'];
              final bDate = (b.data() as Map<String, dynamic>)['dateTime'];
              if (aDate is! Timestamp || bDate is! Timestamp) return 0;
              return aDate.compareTo(bDate);
            });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  "${sorted.length} stop${sorted.length == 1 ? '' : 's'} today",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }

              final doc = sorted[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              return _TaskCard(
                data: data,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhlebotomistMapScreen(
                      appointmentId: doc.id,
                      appointmentData: data,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TaskCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = (data['dateTime'] as Timestamp?)?.toDate();
    final isToday = date != null &&
        DateUtils.isSameDay(date, DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
                    child: const Icon(Icons.bloodtype_outlined,
                        color: AppTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['patientName'] as String? ?? 'Patient',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          testSummary(data),
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday
                          ? scheme.primary.withValues(alpha: 0.12)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      date == null
                          ? "—"
                          : isToday
                              ? DateFormat('h:mm a').format(date)
                              : DateFormat('d MMM, h:mm a').format(date),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 17, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Flat ${data['flatNumber'] ?? '-'}, Floor ${data['floor'] ?? '-'} · "
                      "${data['address'] ?? ''}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
