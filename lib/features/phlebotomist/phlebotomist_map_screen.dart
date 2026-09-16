import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _completeTask() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({'status': 'completed'});
    } catch (e) {
      debugPrint("Complete task error: $e");
      messenger.showSnackBar(
        const SnackBar(content: Text("Could not update the task. Please try again.")),
      );
      return;
    }

    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text("Task Marked as Completed")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Location")),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
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
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Patient: ${widget.appointmentData['patientName']}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Test: ${widget.appointmentData['testType']}"),
                const SizedBox(height: 8),
                Text(
                  "Flat ${widget.appointmentData['flatNumber'] ?? '-'}"
                  ", Floor ${widget.appointmentData['floor'] ?? '-'}",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (widget.appointmentData['address'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.appointmentData['address'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openDirections,
                  icon: const Icon(Icons.directions),
                  label: const Text("Get Directions in Google Maps"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _completeTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Mark as Collected / Completed"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
