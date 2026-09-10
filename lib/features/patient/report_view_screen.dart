import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ReportViewScreen extends StatelessWidget {
  final Map<String, dynamic> appointmentData;

  const ReportViewScreen({super.key, required this.appointmentData});

  Future<void> _launchURL(BuildContext context) async {
    final String? urlString = appointmentData['reportUrl'];
    if (urlString == null || urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening report: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (appointmentData['dateTime'] as dynamic).toDate();
    
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
              appointmentData['testType'] ?? 'Blood Test',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(Icons.calendar_today, "Date", DateFormat('MMM d, yyyy').format(date)),
            _infoRow(Icons.person, "Phlebotomist", appointmentData['phlebotomistName'] ?? 'Assigned Staff'),
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
                onPressed: () => _launchURL(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("View Full Report", style: TextStyle(fontSize: 18)),
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
