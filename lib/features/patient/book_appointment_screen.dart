import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/appointment_service.dart';
import '../../core/services/firestore_service.dart';
import 'map_picker_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _testTypeController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;
  bool _isLoading = false;

  final AppointmentService _appointmentService = AppointmentService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService(); // To get user name if needed, or just pass from prev screen

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _pickLocation() async {
    final location = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );
    if (location != null) setState(() => _selectedLocation = location);
  }

  void _submit() async {
    if (_testTypeController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and pick a location")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Combine date and time
        final dateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        // Ideally fetch name from Firestore, but for now using email or placeholder
        // In a real app, we'd have a UserProvider
        String name = user.email ?? "Unknown"; 

        await _appointmentService.createAppointment(
          patientId: user.uid,
          patientName: name, // Should be real name
          testType: _testTypeController.text.trim(),
          dateTime: dateTime,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Appointment Booked Successfully!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book Appointment")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _testTypeController,
                decoration: const InputDecoration(
                  labelText: "Test Type (e.g., CBC, Lipid Profile)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedDate == null
                    ? "Pick Date"
                    : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedTime == null
                    ? "Pick Time"
                    : "Time: ${_selectedTime!.format(context)}"),
                trailing: const Icon(Icons.access_time),
                onTap: _pickTime,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedLocation == null
                    ? "Pick Location on Map"
                    : "Location Selected"),
                subtitle: _selectedLocation != null
                    ? Text("${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}")
                    : null,
                trailing: const Icon(Icons.map),
                onTap: _pickLocation,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Book Appointment"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
