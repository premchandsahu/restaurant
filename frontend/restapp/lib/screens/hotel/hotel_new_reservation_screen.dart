import 'package:flutter/material.dart';
import 'package:restapp/widgets/hotel/hotel_guest_search_dialog.dart';

import '../../models/hotel/hotel_guest.dart';
import '../../models/hotel/hotel_room_type.dart';
import '../../services/api_client.dart';
import '../../services/hotel/hotel_guest_service.dart';
import '../../services/hotel/hotel_room_type_service.dart';

class HotelNewReservationScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const HotelNewReservationScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<HotelNewReservationScreen> createState() =>
      _HotelNewReservationScreenState();
}

class _HotelNewReservationScreenState extends State<HotelNewReservationScreen> {
  late final HotelGuestService _guestService;
  late final HotelRoomTypeService _roomTypeService;

  final _formKey = GlobalKey<FormState>();

  List<HotelGuest> _guests = [];
  List<HotelRoomType> _roomTypes = [];

  HotelGuest? _selectedGuest;
  HotelRoomType? _selectedRoomType;

  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));

  final TextEditingController _adultsController = TextEditingController(
    text: '2',
  );
  final TextEditingController _childrenController = TextEditingController(
    text: '0',
  );
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _advanceController = TextEditingController(
    text: '0',
  );
  final TextEditingController _remarksController = TextEditingController();

  String _bookingSource = 'DIRECT';

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _guestService = HotelGuestService(apiClient: widget.apiClient);
    _roomTypeService = HotelRoomTypeService(apiClient: widget.apiClient);

    _loadMasters();
  }

  @override
  void dispose() {
    _adultsController.dispose();
    _childrenController.dispose();
    _rateController.dispose();
    _advanceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectGuest() async {
    final guest = await showDialog<HotelGuest>(
      context: context,
      builder: (_) {
        return HotelGuestSearchDialog(
          outletId: widget.outletId,
          apiClient: widget.apiClient,
        );
      },
    );

    if (!mounted || guest == null) return;

    setState(() {
      _selectedGuest = guest;
    });
  }

  Widget _buildGuestSelector() {
    final guest = _selectedGuest;

    String guestText;

    if (guest == null) {
      guestText = 'Select guest';
    } else {
      final name = '${guest.firstName ?? ''} ${guest.lastName ?? ''}'.trim();

      guestText =
          '${guest.guestCode} - '
          '${name.isEmpty ? 'Guest' : name}'
          '${guest.phone != null ? ' (${guest.phone})' : ''}';
    }

    return InkWell(
      onTap: _selectGuest,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Guest',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person),
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(
          guestText,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: guest == null
                ? Theme.of(context).inputDecorationTheme.hintStyle?.color
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _loadMasters() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final roomTypes = await _roomTypeService.getRoomTypes(
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _roomTypes = roomTypes;
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

  void _onRoomTypeChanged(HotelRoomType? roomType) {
    setState(() {
      _selectedRoomType = roomType;

      if (roomType != null) {
        _rateController.text = roomType.baseRate.toStringAsFixed(2);
      }
    });
  }

  Future<void> _selectDate({required bool checkIn}) async {
    final initialDate = checkIn ? _checkInDate : _checkOutDate;

    final firstDate = checkIn
        ? DateTime.now()
        : _checkInDate.add(const Duration(days: 1));

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (checkIn) {
        _checkInDate = selected;

        if (!_checkOutDate.isAfter(_checkInDate)) {
          _checkOutDate = _checkInDate.add(const Duration(days: 1));
        }
      } else {
        _checkOutDate = selected;
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  Future<void> _checkAvailability() async {
    if (_selectedRoomType == null) {
      _showMessage('Please select a room type.');
      return;
    }

    try {
      final response = await widget.apiClient
          .post('/hotel/rooms/availability', {
            'outletId': widget.outletId,
            'roomTypeId': _selectedRoomType!.roomTypeId,
            'fromDate': _dateForApi(_checkInDate),
            'toDate': _dateForApi(_checkOutDate),
          });

      if (!mounted) return;

      if (response['success'] != true) {
        _showMessage(response['message'] ?? 'Unable to check availability.');
        return;
      }

      final rooms = response['availableRooms'] as List? ?? [];

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Room Availability'),
            content: SizedBox(
              width: 450,
              child: rooms.isEmpty
                  ? const Text('No rooms are available for the selected dates.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = Map<String, dynamic>.from(rooms[index]);

                        return ListTile(
                          leading: const Icon(Icons.hotel),
                          title: Text(
                            '${room['roomNo'] ?? room['roomNumber'] ?? ''}',
                          ),
                          subtitle: Text('${room['roomName'] ?? ''}'),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showMessage('Availability check failed: $e');
    }
  }

  String _dateForApi(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveReservation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGuest == null) {
      _showMessage('Please select a guest.');
      return;
    }

    if (_selectedRoomType == null) {
      _showMessage('Please select a room type.');
      return;
    }

    if (!_checkOutDate.isAfter(_checkInDate)) {
      _showMessage('Check-out date must be after check-in date.');
      return;
    }

    final adults = int.tryParse(_adultsController.text.trim()) ?? 0;

    final children = int.tryParse(_childrenController.text.trim()) ?? 0;

    final roomRate = double.tryParse(_rateController.text.trim()) ?? 0;

    final advance = double.tryParse(_advanceController.text.trim()) ?? 0;

    if (adults <= 0) {
      _showMessage('Adults must be at least 1.');
      return;
    }

    if (roomRate < 0 || advance < 0) {
      _showMessage('Rate and advance cannot be negative.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await widget.apiClient.post('/hotel/reservations', {
        'outletId': widget.outletId,
        'guestId': _selectedGuest!.guestId,
        'roomTypeId': _selectedRoomType!.roomTypeId,
        'roomId': null,
        'expectedCheckIn': _dateForApi(_checkInDate),
        'expectedCheckOut': _dateForApi(_checkOutDate),
        'adults': adults,
        'children': children,
        'roomRate': roomRate,
        'advanceAmount': advance,
        'bookingSource': _bookingSource,
        'remarks': _remarksController.text.trim(),
      });

      if (!mounted) return;

      if (response['success'] != true) {
        _showMessage(response['message'] ?? 'Unable to create reservation.');

        setState(() {
          _saving = false;
        });

        return;
      }

      final reservation = response['reservation'] ?? response['data'];

      final reservationNo = reservation is Map
          ? reservation['reservationNo']?.toString()
          : null;

      await _showSuccessDialog(
        reservationNo ?? 'Reservation created successfully',
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Unable to create reservation: $e');
    }
  }

  Future<void> _showSuccessDialog(String reservationNo) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Reservation Created'),
            ],
          ),
          content: Text(
            'Reservation $reservationNo has been created successfully.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildGuestDropdown() {
    return DropdownButtonFormField<HotelGuest>(
      value: _selectedGuest,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Guest',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      hint: const Text('Select guest'),
      items: _guests.map((guest) {
        final name = '${guest.firstName} ${guest.lastName}'.trim();

        return DropdownMenuItem<HotelGuest>(
          value: guest,
          child: Text(
            '${guest.guestCode} - $name'
            '${guest.phone != null ? ' (${guest.phone})' : ''}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedGuest = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Select guest';
        }
        return null;
      },
    );
  }

  Widget _buildRoomTypeDropdown() {
    return DropdownButtonFormField<HotelRoomType>(
      value: _selectedRoomType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Room Type',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.hotel),
      ),
      hint: const Text('Select room type'),
      items: _roomTypes.map((roomType) {
        return DropdownMenuItem<HotelRoomType>(
          value: roomType,
          child: Text(
            '${roomType.typeCode} - ${roomType.typeName}'
            '  ₹${roomType.baseRate.toStringAsFixed(2)}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _onRoomTypeChanged,
      validator: (value) {
        if (value == null) {
          return 'Select room type';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }

              if (int.tryParse(value.trim()) == null) {
                return 'Enter a valid number';
              }

              return null;
            }
          : null,
    );
  }

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: '₹ ',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }

        if (double.tryParse(value.trim()) == null) {
          return 'Enter a valid amount';
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Reservation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadMasters,
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionTitle('Guest & Room', Icons.hotel),
                            const SizedBox(height: 12),

                            if (isWide)
                              Row(
                                children: [
                                  Expanded(child: _buildGuestSelector()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildRoomTypeDropdown()),
                                ],
                              )
                            else ...[
                              _buildGuestSelector(),
                              const SizedBox(height: 16),
                              _buildRoomTypeDropdown(),
                            ],

                            const SizedBox(height: 24),

                            _buildSectionTitle(
                              'Stay Details',
                              Icons.date_range,
                            ),
                            const SizedBox(height: 12),

                            if (isWide)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateField(
                                      label: 'Check-in Date',
                                      date: _checkInDate,
                                      onTap: () => _selectDate(checkIn: true),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDateField(
                                      label: 'Check-out Date',
                                      date: _checkOutDate,
                                      onTap: () => _selectDate(checkIn: false),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildDateField(
                                label: 'Check-in Date',
                                date: _checkInDate,
                                onTap: () => _selectDate(checkIn: true),
                              ),
                              const SizedBox(height: 16),
                              _buildDateField(
                                label: 'Check-out Date',
                                date: _checkOutDate,
                                onTap: () => _selectDate(checkIn: false),
                              ),
                            ],

                            const SizedBox(height: 16),

                            if (isWide)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Adults',
                                      controller: _adultsController,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Children',
                                      controller: _childrenController,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildNumberField(
                                label: 'Adults',
                                controller: _adultsController,
                              ),
                              const SizedBox(height: 16),
                              _buildNumberField(
                                label: 'Children',
                                controller: _childrenController,
                              ),
                            ],

                            const SizedBox(height: 24),

                            OutlinedButton.icon(
                              onPressed: _checkAvailability,
                              icon: const Icon(Icons.search),
                              label: const Text('CHECK ROOM AVAILABILITY'),
                            ),

                            const SizedBox(height: 24),

                            _buildSectionTitle('Charges', Icons.currency_rupee),
                            const SizedBox(height: 12),

                            if (isWide)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAmountField(
                                      label: 'Room Rate',
                                      controller: _rateController,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildAmountField(
                                      label: 'Advance Amount',
                                      controller: _advanceController,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildAmountField(
                                label: 'Room Rate',
                                controller: _rateController,
                              ),
                              const SizedBox(height: 16),
                              _buildAmountField(
                                label: 'Advance Amount',
                                controller: _advanceController,
                              ),
                            ],

                            const SizedBox(height: 24),

                            _buildSectionTitle(
                              'Booking Information',
                              Icons.info_outline,
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: _bookingSource,
                              decoration: const InputDecoration(
                                labelText: 'Booking Source',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'DIRECT',
                                  child: Text('Direct'),
                                ),
                                DropdownMenuItem(
                                  value: 'PHONE',
                                  child: Text('Phone'),
                                ),
                                DropdownMenuItem(
                                  value: 'WALK_IN',
                                  child: Text('Walk-in'),
                                ),
                                DropdownMenuItem(
                                  value: 'ONLINE',
                                  child: Text('Online'),
                                ),
                                DropdownMenuItem(
                                  value: 'AGENT',
                                  child: Text('Agent'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  _bookingSource = value;
                                });
                              },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _remarksController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Remarks',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),

                            const SizedBox(height: 28),

                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveReservation,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  _saving ? 'SAVING...' : 'CREATE RESERVATION',
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
