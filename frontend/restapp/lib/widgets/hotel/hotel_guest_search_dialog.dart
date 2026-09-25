import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/hotel/hotel_guest.dart';
import '../../services/api_client.dart';
import '../../services/hotel/hotel_guest_service.dart';

class HotelGuestSearchDialog extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;
  final HotelGuest? initialGuest;
  const HotelGuestSearchDialog({
    super.key,
    required this.outletId,
    required this.apiClient,
    this.initialGuest,
  });

  @override
  State<HotelGuestSearchDialog> createState() => _HotelGuestSearchDialogState();
}

class _HotelGuestSearchDialogState extends State<HotelGuestSearchDialog> {
  late final HotelGuestService _guestService;

  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  List<HotelGuest> _guests = [];

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _guestService = HotelGuestService(apiClient: widget.apiClient);

    // Don't load the complete guest master.
    // Search starts when the user types.
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final search = value.trim();

    if (search.isEmpty) {
      setState(() {
        _guests = [];
        _loading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchGuests(search);
    });
  }

  Future<void> _searchGuests(String search) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final guests = await _guestService.searchGuests(
        outletId: widget.outletId,
        search: search,
      );

      if (!mounted) return;

      setState(() {
        _guests = guests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _addNewGuest() async {
    final guest = await showDialog<HotelGuest>(
      context: context,
      builder: (context) {
        return _AddGuestDialog(
          outletId: widget.outletId,
          apiClient: widget.apiClient,
        );
      },
    );

    if (!mounted || guest == null) return;

    Navigator.pop(context, guest);
  }

  String _guestName(HotelGuest guest) {
    final name = '${guest.firstName} ${guest.lastName ?? ''}'.trim();

    return name.isEmpty ? 'Guest' : name;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_search),
          SizedBox(width: 8),
          Text('Select Guest'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search name, phone, email or guest code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _guests = [];
                            _errorMessage = null;
                          });
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(child: _buildResults()),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addNewGuest,
                icon: const Icon(Icons.person_add),
                label: const Text('ADD NEW GUEST'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search guests.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_guests.isEmpty) {
      return const Center(
        child: Text(
          'No guest found.\n\n'
          'Use ADD NEW GUEST to create a new guest.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _guests.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final guest = _guests[index];

        return ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            _guestName(guest),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${guest.guestCode}'
            '${guest.phone != null ? ' • ${guest.phone}' : ''}'
            '${guest.email != null ? '\n${guest.email}' : ''}',
          ),
          isThreeLine: guest.email != null,
          onTap: () {
            Navigator.pop(context, guest);
          },
        );
      },
    );
  }
}

class _AddGuestDialog extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const _AddGuestDialog({required this.outletId, required this.apiClient});

  @override
  State<_AddGuestDialog> createState() => _AddGuestDialogState();
}

class _AddGuestDialogState extends State<_AddGuestDialog> {
  late final HotelGuestService _guestService;

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _idTypeController = TextEditingController();
  final _idNumberController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _guestService = HotelGuestService(apiClient: widget.apiClient);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _idTypeController.dispose();
    _idNumberController.dispose();

    super.dispose();
  }

  Future<void> _saveGuest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final guest = await _guestService.createGuest(
        outletId: widget.outletId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        idType: _idTypeController.text.trim(),
        idNumber: _idNumberController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, guest);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create guest: $e')));
    }
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }

              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Guest'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _textField(
                  label: 'First Name',
                  controller: _firstNameController,
                  requiredField: true,
                ),

                const SizedBox(height: 12),

                _textField(label: 'Last Name', controller: _lastNameController),

                const SizedBox(height: 12),

                _textField(
                  label: 'Phone',
                  controller: _phoneController,
                  requiredField: true,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 12),

                _textField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 12),

                _textField(label: 'Address', controller: _addressController),

                const SizedBox(height: 12),

                _textField(label: 'ID Type', controller: _idTypeController),

                const SizedBox(height: 12),

                _textField(label: 'ID Number', controller: _idNumberController),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _saveGuest,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'SAVING...' : 'SAVE GUEST'),
        ),
      ],
    );
  }
}
