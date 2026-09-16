import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/test_catalog.dart';

class PhlebotomistMapScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const PhlebotomistMapScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<PhlebotomistMapScreen> createState() => _PhlebotomistMapScreenState();
}

class _PhlebotomistMapScreenState extends State<PhlebotomistMapScreen> {
  late LatLng _patientLocation;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    final geoPoint = widget.appointmentData['location'] as GeoPoint;
    _patientLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  // Sends the phlebotomist to the patient's door with turn-by-turn directions.
  Future<void> _openDirections() async {
    final destination = '${_patientLocation.latitude},${_patientLocation.longitude}';

    // Starts navigation straight away in Google Maps on Android, no app chooser.
    final navigation = Uri.parse('google.navigation:q=$destination&mode=d');
    // Used when Google Maps isn't installed, and on iOS.
    final webMaps = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    try {
      if (await launchUrl(navigation, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint("Google Maps navigation unavailable, falling back: $e");
    }

    try {
      if (!await launchUrl(webMaps, mode: LaunchMode.externalApplication)) {
        throw 'No app available to show directions';
      }
    } catch (e) {
      debugPrint("Error opening directions: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps.")),
        );
      }
    }
  }

  Future<void> _callPatient() async {
    final phone = (widget.appointmentData['patientPhone'] as String?)?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No phone number on this booking.")),
      );
      return;
    }

    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'No dialer available';
      }
    } catch (e) {
      debugPrint("Error starting call: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not start the call.")),
        );
      }
    }
  }

  Future<void> _completeTask() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCompleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({'status': 'completed'});
    } catch (e) {
      debugPrint("Complete task error: $e");
      if (mounted) setState(() => _isCompleting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Could not update the task. Please try again.")),
      );
      return;
    }

    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text("Marked as collected")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.appointmentData;
    final date = (data['dateTime'] as Timestamp?)?.toDate();
    final notes = (data['notes'] as String?)?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Collection")),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _patientLocation,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bloodtestapp',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _patientLocation,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'directions',
                    onPressed: _openDirections,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text("Directions"),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['patientName'] as String? ?? 'Patient',
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: bookedTestsOf(data).map((test) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    test['name'] as String? ?? 'Test',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _callPatient,
                        icon: const Icon(Icons.call),
                        tooltip: "Call patient",
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.door_front_door_outlined,
                    text:
                        "Flat ${data['flatNumber'] ?? '-'}, Floor ${data['floor'] ?? '-'}",
                    bold: true,
                  ),
                  if (data['address'] != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                        icon: Icons.location_on_outlined, text: data['address']),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.schedule,
                      text: DateFormat('EEE, d MMM · h:mm a').format(date),
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.sticky_note_2_outlined, text: notes),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _isCompleting ? null : _completeTask,
                    icon: _isCompleting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isCompleting
                        ? "Saving…"
                        : "Mark as collected"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;

  const _InfoRow({required this.icon, required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
