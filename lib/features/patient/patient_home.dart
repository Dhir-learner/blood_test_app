import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/appointment_service.dart';
import 'book_appointment_screen.dart';

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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No appointments yet."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['dateTime'] as Timestamp).toDate();
                    final status = data['status'] ?? 'pending';
                    final reportUrl = data['reportUrl'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status),
                          child: Icon(_getStatusIcon(status), color: Colors.white),
                        ),
                        title: Text(data['testType'] ?? 'Blood Test'),
                        subtitle: Text(DateFormat('MMM d, y - h:mm a').format(date)),
                        trailing: reportUrl != null
                            ? IconButton(
                                icon: const Icon(Icons.description, color: Colors.blue),
                                onPressed: () {
                                  // TODO: Navigate to Report View
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Report"),
                                      content: const Text("Report viewing to be implemented (Mock: Report is ready!)"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Close"),
                                        )
                                      ],
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
      case 'pending': return Colors.orange != null ? Icons.access_time : Icons.error; // Hacky check
      case 'assigned': return Icons.person;
      case 'completed': return Icons.check;
      default: return Icons.help;
    }
  }
}
