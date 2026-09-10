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
  final _flatNumberController = TextEditingController();
  final _floorController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;

  final AppointmentService _appointmentService = AppointmentService();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _testTypeController.dispose();
    _flatNumberController.dispose();
    _floorController.dispose();
    super.dispose();
  }

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
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );
    
    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        _selectedAddress = result['address'] as String;
      });
    }
  }

  void _submit() async {
    if (_testTypeController.text.isEmpty ||
        _flatNumberController.text.isEmpty ||
        _floorController.text.isEmpty ||
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
          address: _selectedAddress ?? "Unknown Address",
          flatNumber: _flatNumberController.text.trim(),
          floor: _floorController.text.trim(),
        );
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Booking Successful"),
              content: const Text("Your appointment has been successfully created. We will notify you when a phlebotomist is assigned."),
              actions: [
                TextButton(
                  onPressed: () {
                    // Pop dialog
                    Navigator.pop(context);
                    // Pop BookAppointmentScreen to return to Home
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
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
                subtitle: _selectedAddress != null
                    ? Text(_selectedAddress!, maxLines: 2, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: const Icon(Icons.map),
                onTap: _pickLocation,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _flatNumberController,
                      decoration: const InputDecoration(
                        labelText: "Flat/House Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _floorController,
                      decoration: const InputDecoration(
                        labelText: "Floor",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
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
