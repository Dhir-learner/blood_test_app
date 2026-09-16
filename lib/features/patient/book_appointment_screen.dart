import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../core/constants/test_catalog.dart';
import '../../core/services/address_service.dart';
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
  final _flatNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _notesController = TextEditingController();
  final _newLabelController = TextEditingController();

  final List<BloodTest> _selectedTests = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;
  String? _selectedAddress;

  List<SavedAddress> _savedAddresses = [];
  SavedAddress? _chosenSaved;
  bool _saveThisAddress = false;
  bool _isLoading = false;

  final _appointmentService = AppointmentService();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _addressService = AddressService();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _flatNumberController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    _newLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final user = _authService.currentUser;
    if (user == null) return;
    try {
      final addresses = await _addressService.getAddresses(user.uid);
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses;
        // Pre-select the default address so booking is one tap lighter.
        final preferred = addresses.where((a) => a.isDefault).firstOrNull ??
            (addresses.length == 1 ? addresses.first : null);
        if (preferred != null) _applySaved(preferred);
      });
    } catch (e) {
      debugPrint("Could not load saved addresses: $e");
    }
  }

  void _applySaved(SavedAddress address) {
    _chosenSaved = address;
    _selectedLocation = LatLng(address.latitude, address.longitude);
    _selectedAddress = address.address;
    _flatNumberController.text = address.flatNumber;
    _floorController.text = address.floor;
    _saveThisAddress = false;
  }

  int get _total =>
      _selectedTests.fold<int>(0, (running, t) => running + t.priceInRupees);

  bool get _needsFasting => _selectedTests.any((t) => t.fastingRequired);

  Future<void> _pickTests() async {
    final result = await showModalBottomSheet<List<BloodTest>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TestPickerSheet(initialSelection: _selectedTests),
    );
    if (result != null) {
      setState(() {
        _selectedTests
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _chooseAddress() async {
    if (_savedAddresses.isEmpty) return _pickNewLocation();

    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    "Where should we collect?",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            ..._savedAddresses.map(
              (a) => ListTile(
                leading: Icon(
                  a.isDefault ? Icons.star_rounded : Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(a.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [a.doorLine, a.address].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, a),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text("Use a new location"),
              onTap: () => Navigator.pop(sheetContext, 'new'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice is SavedAddress) {
      setState(() => _applySaved(choice));
    } else if (choice == 'new') {
      await _pickNewLocation();
    }
  }

  Future<void> _pickNewLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null) {
      setState(() {
        _chosenSaved = null;
        _selectedLocation = result['location'] as LatLng;
        _selectedAddress = result['address'] as String;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_selectedTests.isEmpty) return _notify("Please choose at least one test");
    if (_selectedDate == null) return _notify("Please pick a date");
    if (_selectedTime == null) return _notify("Please pick a time");
    if (_selectedLocation == null) return _notify("Please choose an address");
    if (_flatNumberController.text.trim().isEmpty) {
      return _notify("Please enter your flat or house number");
    }
    if (_floorController.text.trim().isEmpty) {
      return _notify("Please enter the floor");
    }

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (!dateTime.isAfter(DateTime.now())) {
      return _notify("Please pick a time in the future");
    }

    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _firestoreService.getUserProfile(user.uid);
        final name = (profile?['name'] as String?)?.trim();
        final phone = (profile?['phone'] as String?)?.trim();

        await _appointmentService.createAppointment(
          patientId: user.uid,
          patientName:
              (name != null && name.isNotEmpty) ? name : (user.email ?? "Unknown"),
          patientPhone: phone ?? '',
          tests: _selectedTests,
          dateTime: dateTime,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _selectedAddress ?? "Unknown Address",
          flatNumber: _flatNumberController.text.trim(),
          floor: _floorController.text.trim(),
          notes: _notesController.text.trim(),
        );

        // Optionally remember this address for next time.
        if (_saveThisAddress && _chosenSaved == null) {
          final label = _newLabelController.text.trim();
          await _addressService.addAddress(
            user.uid,
            SavedAddress(
              id: '',
              label: label.isEmpty ? 'Home' : label,
              flatNumber: _flatNumberController.text.trim(),
              floor: _floorController.text.trim(),
              address: _selectedAddress ?? '',
              latitude: _selectedLocation!.latitude,
              longitude: _selectedLocation!.longitude,
              isDefault: _savedAddresses.isEmpty,
            ),
          );
        }

        if (mounted) _showSuccessSheet();
      }
    } catch (e) {
      debugPrint("Booking error: $e");
      if (mounted) _notify("Could not book the appointment. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              "Booking confirmed",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              _selectedTests.length == 1
                  ? "We'll assign a collector and notify you."
                  : "${_selectedTests.length} tests booked in one visit. "
                      "You'll get a report for each.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.pop(context);
              },
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Book a test")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _SectionLabel("Tests"),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickTests,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.science_outlined,
                          color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTests.isEmpty
                                ? "Choose tests"
                                : "${_selectedTests.length} test"
                                    "${_selectedTests.length == 1 ? '' : 's'} selected",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _selectedTests.isEmpty
                                ? "Pick one or more — a single visit covers them all"
                                : _selectedTests.map((t) => t.shortName).join(', '),
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, fontSize: 12.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          if (_needsFasting) ...[
            const SizedBox(height: 12),
            const _FastingNotice(),
          ],
          const SizedBox(height: 22),
          _SectionLabel("When"),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  label: "Date",
                  value: _selectedDate == null
                      ? "Select"
                      : DateFormat('d MMM').format(_selectedDate!),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerTile(
                  icon: Icons.access_time,
                  label: "Time",
                  value: _selectedTime == null
                      ? "Select"
                      : _selectedTime!.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionLabel("Where"),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _chooseAddress,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _chosenSaved != null
                          ? Icons.bookmark_rounded
                          : Icons.location_on_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _chosenSaved?.label ??
                                (_selectedLocation == null
                                    ? (_savedAddresses.isEmpty
                                        ? "Pick location on map"
                                        : "Choose an address")
                                    : "New location"),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_selectedAddress != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              _selectedAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(_savedAddresses.isEmpty
                        ? Icons.map_outlined
                        : Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flatNumberController,
                  decoration: const InputDecoration(labelText: "Flat / House no."),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _floorController,
                  decoration: const InputDecoration(labelText: "Floor"),
                ),
              ),
            ],
          ),
          if (_selectedLocation != null && _chosenSaved == null) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              value: _saveThisAddress,
              onChanged: (v) => setState(() => _saveThisAddress = v),
              title: const Text("Save this address"),
              subtitle: const Text("Reuse it next time in one tap"),
              contentPadding: EdgeInsets.zero,
            ),
            if (_saveThisAddress)
              TextField(
                controller: _newLabelController,
                decoration: const InputDecoration(
                  labelText: "Label",
                  hintText: "Home, Work…",
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Notes for the collector (optional)",
              hintText: "Landmark, gate code, preferred arm…",
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(
        total: _total,
        testCount: _selectedTests.length,
        isLoading: _isLoading,
        onSubmit: _submit,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FastingNotice extends StatelessWidget {
  const _FastingNotice();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE08600);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.no_food_outlined, color: amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "One or more of these tests needs fasting. Avoid food for 8–12 "
              "hours before the visit; water is fine. Please confirm with the lab.",
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  final int total;
  final int testCount;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _BookingBar({
    required this.total,
    required this.testCount,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  testCount <= 1 ? "Total" : "Total · $testCount tests",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                Text(
                  total == 0 ? "—" : "₹$total",
                  style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text("Confirm booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select catalogue. Returns the chosen tests when "Done" is tapped.
class _TestPickerSheet extends StatefulWidget {
  final List<BloodTest> initialSelection;
  const _TestPickerSheet({required this.initialSelection});

  @override
  State<_TestPickerSheet> createState() => _TestPickerSheetState();
}

class _TestPickerSheetState extends State<_TestPickerSheet> {
  late final Set<String> _selectedIds =
      widget.initialSelection.map((t) => t.id).toSet();

  int get _total => kBloodTests
      .where((t) => _selectedIds.contains(t.id))
      .fold<int>(0, (running, t) => running + t.priceInRupees);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Choose tests",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        "Pick as many as you need — one visit covers them all",
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              itemCount: kBloodTests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final test = kBloodTests[index];
                final selected = _selectedIds.contains(test.id);

                return Card(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.08)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selected
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedIds.remove(test.id);
                      } else {
                        _selectedIds.add(test.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (_) => setState(() {
                              if (selected) {
                                _selectedIds.remove(test.id);
                              } else {
                                _selectedIds.add(test.id);
                              }
                            }),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        test.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5),
                                      ),
                                    ),
                                    Text(
                                      "₹${test.priceInRupees}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  test.description,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _Tag(icon: Icons.schedule, label: test.reportTime),
                                    const SizedBox(width: 8),
                                    _Tag(
                                      icon: test.fastingRequired
                                          ? Icons.no_food_outlined
                                          : Icons.restaurant_outlined,
                                      label: test.fastingRequired
                                          ? "Fasting"
                                          : "No fasting",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_selectedIds.length} selected",
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        _total == 0 ? "—" : "₹$_total",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        kBloodTests
                            .where((t) => _selectedIds.contains(t.id))
                            .toList(),
                      ),
                      child: const Text("Done"),
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

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
