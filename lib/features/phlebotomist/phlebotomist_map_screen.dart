import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _completeTask() async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId)
        .update({'status': 'completed'});
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task Marked as Completed")),
      );
    }
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
                const SizedBox(height: 16),
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
