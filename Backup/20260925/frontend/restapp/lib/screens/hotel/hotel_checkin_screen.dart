import 'package:flutter/material.dart';

import '../../models/hotel/hotel_reservation.dart';
import '../../services/api_client.dart';
import 'hotel_folio_screen.dart';

class HotelCheckinScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;
  final HotelReservation reservation;

  const HotelCheckinScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
    required this.reservation,
  });

  @override
  State<HotelCheckinScreen> createState() => _HotelCheckinScreenState();
}

class _HotelCheckinScreenState extends State<HotelCheckinScreen> {
  List<Map<String, dynamic>> _availableRooms = [];

  int? _selectedRoomId;

  bool _loadingRooms = false;
  bool _checkingIn = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // If a room is already assigned to the reservation,
    // keep that room selected.
    _selectedRoomId = widget.reservation.roomId;

    if (_selectedRoomId == null) {
      _loadAvailableRooms();
    }
  }

  String _dateForApi(String date) {
    if (date.length >= 10) {
      return date.substring(0, 10);
    }

    return date;
  }

  String _formatDate(String date) {
    if (date.length < 10) {
      return date;
    }

    final parts = date.substring(0, 10).split('-');

    if (parts.length != 3) {
      return date;
    }

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _loadAvailableRooms() async {
    setState(() {
      _loadingRooms = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.apiClient
          .post('/hotel/rooms/availability', {
            'outletId': widget.outletId,
            'roomTypeId': widget.reservation.roomTypeId,
            'fromDate': _dateForApi(widget.reservation.expectedCheckIn),
            'toDate': _dateForApi(widget.reservation.expectedCheckOut),
          });

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() {
          _loadingRooms = false;
          _errorMessage =
              response['message'] ?? 'Unable to load available rooms.';
        });

        return;
      }

      final List<dynamic> rooms = response['availableRooms'] as List? ?? [];

      setState(() {
        _availableRooms = rooms
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        _loadingRooms = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRooms = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _roomDisplayName(Map<String, dynamic> room) {
    final roomNo =
        room['roomNo'] ?? room['roomNumber'] ?? room['room_no'] ?? '';

    final roomName = room['roomName'] ?? room['room_name'] ?? '';

    if (roomName.toString().trim().isEmpty) {
      return roomNo.toString();
    }

    return '$roomNo - $roomName';
  }

  int? _roomId(Map<String, dynamic> room) {
    final value = room['roomId'] ?? room['room_id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _checkIn() async {
    if (widget.reservation.status != 'CONFIRMED') {
      _showMessage('Only confirmed reservations can be checked in.');
      return;
    }

    final roomId = _selectedRoomId;

    if (roomId == null) {
      _showMessage('Please select a room before check-in.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Check-in'),
          content: Text(
            'Check in ${widget.reservation.guestName} '
            'to ${widget.reservation.roomTypeName ?? 'room'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CHECK IN'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _checkingIn = true;
    });

    try {
      final response = await widget.apiClient.post('/hotel/stays/check-in', {
        'outletId': widget.outletId,
        'reservationId': widget.reservation.reservationId,
        'roomId': roomId,
        'checkIn': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() {
          _checkingIn = false;
        });

        _showMessage(response['message'] ?? 'Unable to complete check-in.');

        return;
      }
      final stayData = response['stay'];

      if (stayData is! Map) {
        _showMessage(
          'Check-in succeeded, but stay information was not returned.',
        );

        setState(() {
          _checkingIn = false;
        });

        return;
      }

      final stayId = int.tryParse(stayData['stayId']?.toString() ?? '');

      if (stayId == null) {
        _showMessage('Check-in succeeded, but stayId was not returned.');

        setState(() {
          _checkingIn = false;
        });

        return;
      }

      // Create/get folio immediately after check-in.
      final folioResponse = await widget.apiClient.post(
        '/hotel/stays/$stayId/folio',
        {},
      );

      if (!mounted) return;

      if (folioResponse['success'] != true) {
        setState(() {
          _checkingIn = false;
        });

        _showMessage(
          folioResponse['message'] ??
              'Check-in succeeded, but the folio could not be created.',
        );

        return;
      }

      // Open folio immediately.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HotelFolioScreen(
            stayId: stayId,
            baseUrl: widget.apiClient.baseUrl,
            token: widget.apiClient.token ?? '',
          ),
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checkingIn = false;
      });

      _showMessage('Check-in failed: $e');
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> response) async {
    final stay = response['stay'] ?? response['data'];

    String message = 'Guest checked in successfully.';

    if (stay is Map) {
      final stayNo = stay['stayNo'] ?? stay['stay_no'];

      if (stayNo != null) {
        message =
            'Guest checked in successfully.\n\n'
            'Stay: $stayNo';
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Check-in Complete'),
            ],
          ),
          content: Text(message),
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

  Widget _buildGuestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guest',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              widget.reservation.guestName,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            if (widget.reservation.guestCode != null)
              Text(
                'Guest Code: '
                '${widget.reservation.guestCode}',
              ),
            if (widget.reservation.guestPhone != null)
              Text(
                'Phone: '
                '${widget.reservation.guestPhone}',
              ),
            if (widget.reservation.guestEmail != null)
              Text(
                'Email: '
                '${widget.reservation.guestEmail}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              widget.reservation.reservationNo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Room Type: '
              '${widget.reservation.roomTypeName ?? '-'}',
            ),
            Text(
              'Check-in: '
              '${_formatDate(widget.reservation.expectedCheckIn)}',
            ),
            Text(
              'Check-out: '
              '${_formatDate(widget.reservation.expectedCheckOut)}',
            ),
            Text('Adults: ${widget.reservation.adults}'),
            Text('Children: ${widget.reservation.children}'),
            Text(
              'Rate: ₹'
              '${widget.reservation.roomRate.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSection() {
    final assignedRoomId = widget.reservation.roomId;

    if (assignedRoomId != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hotel),
                title: Text(
                  widget.reservation.roomNo ?? 'Room $assignedRoomId',
                ),
                subtitle: Text(
                  widget.reservation.roomName ??
                      widget.reservation.roomTypeName ??
                      '',
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Room',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loadingRooms)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Column(
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loadAvailableRooms,
                    icon: const Icon(Icons.refresh),
                    label: const Text('RETRY'),
                  ),
                ],
              )
            else if (_availableRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No available rooms found '
                  'for this reservation.',
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedRoomId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.hotel),
                ),
                hint: const Text('Select room'),
                items: _availableRooms
                    .map((room) {
                      final roomId = _roomId(room);

                      if (roomId == null) {
                        return null;
                      }

                      return DropdownMenuItem<int>(
                        value: roomId,
                        child: Text(
                          _roomDisplayName(room),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoomId = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCheckIn = widget.reservation.status == 'CONFIRMED';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Check-in '
          '${widget.reservation.reservationNo}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGuestCard(),

                const SizedBox(height: 16),

                _buildReservationCard(),

                const SizedBox(height: 16),

                _buildRoomSection(),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: !canCheckIn || _checkingIn ? null : _checkIn,
                    icon: _checkingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_checkingIn ? 'CHECKING IN...' : 'CHECK IN'),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
