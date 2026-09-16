import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/appointment_service.dart';
import 'book_appointment_screen.dart';
import 'report_view_screen.dart';

class PatientHome extends StatelessWidget {
  const PatientHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final appointmentService = AppointmentService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Appointments"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: appointmentService.getPatientAppointments(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint("Error loading appointments: ${snapshot.error}");
                  return const Center(child: Text("Could not load appointments."));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No appointments yet."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['dateTime'] as Timestamp).toDate();
                    final status = data['status'] ?? 'pending';
                    final hasReport = data['reportChunkCount'] != null;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status),
                          child: Icon(_getStatusIcon(status), color: Colors.white),
                        ),
                        title: Text(data['testType'] ?? 'Blood Test'),
                        subtitle: Text(DateFormat('MMM d, y - h:mm a').format(date)),
                        trailing: hasReport
                            ? IconButton(
                                icon: const Icon(Icons.description, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReportViewScreen(
                                        appointmentId: doc.id,
                                        appointmentData: data,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Text(status.toUpperCase(), style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookAppointmentScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'assigned': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.access_time;
      case 'assigned': return Icons.person;
      case 'completed': return Icons.check;
      default: return Icons.help;
    }
  }
}
