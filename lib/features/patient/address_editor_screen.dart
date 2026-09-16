import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/address_service.dart';
import '../../core/services/auth_service.dart';
import 'map_picker_screen.dart';

/// Add or edit one saved address.
class AddressEditorScreen extends StatefulWidget {
  final SavedAddress? existing;

  const AddressEditorScreen({super.key, this.existing});

  @override
  State<AddressEditorScreen> createState() => _AddressEditorScreenState();
}

class _AddressEditorScreenState extends State<AddressEditorScreen> {
  static const _quickLabels = ['Home', 'Work', 'Parents', 'Other'];

  final _labelController = TextEditingController();
  final _flatController = TextEditingController();
  final _floorController = TextEditingController();

  LatLng? _location;
  String _address = '';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _labelController.text = existing.label;
      _flatController.text = existing.flatNumber;
      _floorController.text = existing.floor;
      _address = existing.address;
      _isDefault = existing.isDefault;
      _location = LatLng(existing.latitude, existing.longitude);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _flatController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _location = result['location'] as LatLng;
        _address = result['address'] as String;
      });
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return _notify("Give this address a name, like Home");
    if (_location == null) return _notify("Pick the location on the map");
    if (_flatController.text.trim().isEmpty) {
      return _notify("Enter your flat or house number");
    }

    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final service = AddressService();
      final address = SavedAddress(
        id: widget.existing?.id ?? '',
        label: label,
        flatNumber: _flatController.text.trim(),
        floor: _floorController.text.trim(),
        address: _address,
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        isDefault: _isDefault,
      );

      if (widget.existing == null) {
        await service.addAddress(user.uid, address);
      } else {
        await service.updateAddress(user.uid, address);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Save address error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        _notify("Could not save the address. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit address" : "Add address")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            "NAME",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _quickLabels.map((label) {
              final selected = _labelController.text.trim() == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _labelController.text = label),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: "Label",
              hintText: "Home, Work, Mum's place…",
              prefixIcon: Icon(Icons.bookmark_outline),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            "LOCATION",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickLocation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: scheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _location == null ? "Pick on map" : "Location set",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              _address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.map_outlined),
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
                  controller: _flatController,
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
          const SizedBox(height: 10),
          SwitchListTile(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: const Text("Use as my default address"),
            subtitle: const Text("Pre-selected when you book a test"),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(isEditing ? "Save changes" : "Save address"),
          ),
        ],
      ),
    );
  }
}
