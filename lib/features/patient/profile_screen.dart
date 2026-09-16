import 'package:flutter/material.dart';

import '../../core/services/address_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/state_views.dart';
import 'address_editor_screen.dart';

/// Where a patient keeps their contact details and saved addresses.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressService = AddressService();

  bool _loading = true;
  bool _saving = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final profile = await FirestoreService().getUserProfile(user.uid);
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?['name'] as String? ?? '';
      _phoneController.text = profile?['phone'] as String? ?? '';
      _email = profile?['email'] as String? ?? user.email ?? '';
      _loading = false;
    });
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveDetails() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) return _notify("Please enter your name");
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      return _notify("Enter a valid phone number");
    }

    setState(() => _saving = true);
    try {
      await FirestoreService().updateProfile(user.uid, name, phone);
      if (mounted) _notify("Details saved");
    } catch (e) {
      debugPrint("Save profile error: $e");
      if (mounted) _notify("Could not save. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAddress(SavedAddress address) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Delete ${address.label}?"),
        content: const Text("This address will be removed from your saved list."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _addressService.deleteAddress(user.uid, address.id);
    } catch (e) {
      debugPrint("Delete address error: $e");
      if (mounted) _notify("Could not delete the address.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My profile")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.primaryContainer,
                              child: Text(
                                (_nameController.text.isEmpty
                                        ? _email
                                        : _nameController.text)
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _email,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "Patient account",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: "Full name",
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Mobile number",
                            helperText: "The collector calls you on this number",
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving ? null : _saveDetails,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Text("Save details"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "SAVED ADDRESSES",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddressEditorScreen()),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<SavedAddress>>(
                  stream: _addressService.watchAddresses(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      debugPrint("Address load error: ${snapshot.error}");
                      return const ErrorView(
                          message: "We couldn't load your addresses.");
                    }

                    final addresses = snapshot.data ?? [];
                    if (addresses.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Icon(Icons.home_outlined,
                                  size: 34, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              const Text(
                                "No saved addresses yet",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Save an address once and pick it in a tap "
                                "every time you book.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: addresses
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AddressCard(
                                  address: a,
                                  onEdit: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddressEditorScreen(existing: a),
                                    ),
                                  ),
                                  onDelete: () => _deleteAddress(a),
                                  onMakeDefault: () => _addressService
                                      .setDefault(user.uid, a.id),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "Default",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.doorLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(address.doorLine,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    address.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
                if (value == 'default') onMakeDefault();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text("Edit")),
                if (!address.isDefault)
                  const PopupMenuItem(
                      value: 'default', child: Text("Set as default")),
                const PopupMenuItem(value: 'delete', child: Text("Delete")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
