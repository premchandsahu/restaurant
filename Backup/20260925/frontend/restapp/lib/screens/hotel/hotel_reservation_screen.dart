import 'package:flutter/material.dart';
import 'package:restapp/screens/hotel/hotel_edit_reservation_screen.dart';
import 'package:restapp/screens/hotel/hotel_new_reservation_screen.dart';
import 'hotel_checkin_screen.dart';
import '../../models/hotel/hotel_reservation.dart';
import '../../services/api_client.dart';
import '../../services/hotel/hotel_reservation_service.dart';

class HotelReservationScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const HotelReservationScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<HotelReservationScreen> createState() => _HotelReservationScreenState();
}

class _HotelReservationScreenState extends State<HotelReservationScreen> {
  late final HotelReservationService _reservationService;

  final TextEditingController _guestController = TextEditingController();

  final TextEditingController _reservationNoController =
      TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  String _status = 'ALL';

  bool _loading = false;

  String? _errorMessage;

  List<HotelReservation> _reservations = [];

  @override
  void initState() {
    super.initState();

    _reservationService = HotelReservationService(apiClient: widget.apiClient);

    _loadReservations();
  }

  @override
  void dispose() {
    _guestController.dispose();
    _reservationNoController.dispose();

    super.dispose();
  }

  Future<void> _cancelReservation(HotelReservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Reservation'),
          content: Text(
            'Are you sure you want to cancel '
            '${reservation.reservationNo}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('YES, CANCEL'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await widget.apiClient.post(
        '/hotel/reservations/${reservation.reservationId}/cancel',
        {},
      );

      if (!mounted) return;

      if (response['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Unable to cancel reservation.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${reservation.reservationNo} cancelled successfully.'),
        ),
      );

      await _loadReservations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel reservation: $e')),
      );
    }
  }

  // =========================================================
  // LOAD RESERVATIONS
  // =========================================================

  Future<void> _loadReservations() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reservations = await _reservationService.getReservations(
        outletId: widget.outletId,

        status: _status,

        fromDate: _fromDate == null ? null : _formatDate(_fromDate!),

        toDate: _toDate == null ? null : _formatDate(_toDate!),

        guest: _guestController.text.trim(),

        reservationNo: _reservationNoController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _reservations = reservations;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // =========================================================
  // DATE FORMAT
  // =========================================================

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // =========================================================
  // DATE PICKER
  // =========================================================

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _fromDate = picked;

      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
    });
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _toDate = picked;
    });
  }

  // =========================================================
  // CLEAR FILTERS
  // =========================================================

  void _clearFilters() {
    setState(() {
      _guestController.clear();

      _reservationNoController.clear();

      _fromDate = null;

      _toDate = null;

      _status = 'ALL';
    });

    _loadReservations();
  }

  // =========================================================
  // DISPLAY DATE
  // =========================================================

  String _displayDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =========================================================
  // RESERVATION CARD
  // =========================================================

  Widget _buildReservationCard(HotelReservation reservation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: InkWell(
        onTap: () {
          _showReservationDetails(reservation);
        },

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.reservationNo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  _buildStatusBadge(reservation.status),
                ],
              ),

              const SizedBox(height: 10),

              // ------------------------------------------------
              // GUEST
              // ------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 19),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      reservation.guestName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ------------------------------------------------
              // ROOM
              // ------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.hotel_outlined, size: 19),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      '${reservation.roomTypeName ?? '-'}'
                      ' • Room ${reservation.displayRoom}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ------------------------------------------------
              // DATES
              // ------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.date_range_outlined, size: 19),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      '${_formatDateTime(reservation.expectedCheckIn)}'
                      '  →  '
                      '${_formatDateTime(reservation.expectedCheckOut)}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Divider(),

              const SizedBox(height: 5),

              // ------------------------------------------------
              // AMOUNTS
              // ------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rate: ₹${reservation.roomRate.toStringAsFixed(2)}',
                    ),
                  ),

                  Text(
                    'Advance: ₹${reservation.advanceAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATUS BADGE
  // =========================================================

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: _statusBackground(status),
      ),

      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _statusForeground(status),
        ),
      ),
    );
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.green.shade100;

      case 'TENTATIVE':
        return Colors.orange.shade100;

      case 'CHECKED_IN':
        return Colors.blue.shade100;

      case 'CANCELLED':
        return Colors.red.shade100;

      case 'CHECKED_OUT':
        return Colors.grey.shade300;

      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusForeground(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.green.shade800;

      case 'TENTATIVE':
        return Colors.orange.shade800;

      case 'CHECKED_IN':
        return Colors.blue.shade800;

      case 'CANCELLED':
        return Colors.red.shade800;

      default:
        return Colors.grey.shade800;
    }
  }

  // =========================================================
  // DATE/TIME DISPLAY
  // =========================================================

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(value);

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  // =========================================================
  // DETAILS
  // =========================================================

  void _showReservationDetails(HotelReservation reservation) {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text(reservation.reservationNo),

          content: SizedBox(
            width: 450,

            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _detailRow('Status', reservation.status),

                  _detailRow('Guest', reservation.guestName),

                  _detailRow('Phone', reservation.guestPhone ?? '-'),

                  _detailRow('Room Type', reservation.roomTypeName ?? '-'),

                  _detailRow('Room', reservation.roomNo ?? 'Not assigned'),

                  _detailRow(
                    'Check-in',
                    _formatDateTime(reservation.expectedCheckIn),
                  ),

                  _detailRow(
                    'Check-out',
                    _formatDateTime(reservation.expectedCheckOut),
                  ),

                  _detailRow('Adults', reservation.adults.toString()),

                  _detailRow('Children', reservation.children.toString()),

                  _detailRow(
                    'Room Rate',
                    '₹${reservation.roomRate.toStringAsFixed(2)}',
                  ),

                  _detailRow(
                    'Advance',
                    '₹${reservation.advanceAmount.toStringAsFixed(2)}',
                  ),

                  _detailRow(
                    'Booking Source',
                    reservation.bookingSource ?? '-',
                  ),

                  _detailRow('Remarks', reservation.remarks ?? '-'),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),

              child: const Text('CLOSE'),
            ),

            if (reservation.status == 'CONFIRMED' ||
                reservation.status == 'TENTATIVE')
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HotelEditReservationScreen(
                        outletId: widget.outletId,
                        apiClient: widget.apiClient,
                        reservation: reservation,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _loadReservations();
                    }
                  });
                },

                child: const Text('EDIT'),
              ),

            if (reservation.status == 'TENTATIVE' ||
                reservation.status == 'CONFIRMED')
              TextButton.icon(
                onPressed: () {
                  _cancelReservation(reservation);
                },
                icon: const Icon(Icons.cancel),
                label: const Text('CANCEL'),
              ),
            if (reservation.status == 'CONFIRMED')
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HotelCheckinScreen(
                        outletId: widget.outletId,
                        apiClient: widget.apiClient,
                        reservation: reservation,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _loadReservations();
                    }
                  });
                },
                icon: const Icon(Icons.login),
                label: const Text('CHECK IN'),
              ),
          ],
        );
      },
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 120,

            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // =========================================================
  // FILTER AREA
  // =========================================================

  Widget _buildFilters(bool isDesktop) {
    if (isDesktop) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Expanded(
                child: _buildDateField(
                  label: 'From Date',
                  date: _fromDate,
                  onTap: _selectFromDate,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildDateField(
                  label: 'To Date',
                  date: _toDate,
                  onTap: _selectToDate,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: _reservationNoController,

                  decoration: const InputDecoration(
                    labelText: 'Reservation No',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: _guestController,

                  decoration: const InputDecoration(
                    labelText: 'Guest Search',
                    hintText: 'Name / phone',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(width: 150, child: _buildStatusDropdown()),

              const SizedBox(width: 10),

              ElevatedButton.icon(
                onPressed: _loading ? null : _loadReservations,

                icon: const Icon(Icons.search),

                label: const Text('SEARCH'),
              ),

              const SizedBox(width: 6),

              OutlinedButton(
                onPressed: _loading ? null : _clearFilters,

                child: const Text('CLEAR'),
              ),
            ],
          ),
        ),
      );
    }

    // ---------------------------------------------------------
    // MOBILE FILTERS
    // ---------------------------------------------------------

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'From Date',
                    date: _fromDate,
                    onTap: _selectFromDate,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDateField(
                    label: 'To Date',
                    date: _toDate,
                    onTap: _selectToDate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _reservationNoController,

              decoration: const InputDecoration(
                labelText: 'Reservation No',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _guestController,

              decoration: const InputDecoration(
                labelText: 'Guest Search',
                hintText: 'Name / phone',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),

            _buildStatusDropdown(),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _loadReservations,

                    icon: const Icon(Icons.search),

                    label: const Text('SEARCH'),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _clearFilters,

                    child: const Text('CLEAR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DATE FIELD
  // =========================================================

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,

          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),

        child: Text(_displayDate(date)),
      ),
    );
  }

  // =========================================================
  // STATUS DROPDOWN
  // =========================================================

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,

      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
        isDense: true,
      ),

      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('All')),

        DropdownMenuItem(value: 'TENTATIVE', child: Text('Tentative')),

        DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),

        DropdownMenuItem(value: 'CHECKED_IN', child: Text('Checked In')),

        DropdownMenuItem(value: 'CHECKED_OUT', child: Text('Checked Out')),

        DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
      ],

      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _status = value;
        });
      },
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Reservations'),

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed: _loading ? null : _loadReservations,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),

                child: _buildFilters(isDesktop),
              ),

              Expanded(child: _buildReservationList()),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HotelNewReservationScreen(
                outletId: widget.outletId,
                apiClient: widget.apiClient,
              ),
            ),
          ).then((result) {
            if (result == true) {
              _loadReservations();
            }
          });
        },

        icon: const Icon(Icons.add),

        label: const Text('NEW RESERVATION'),
      ),
    );
  }

  // =========================================================
  // LIST
  // =========================================================

  Widget _buildReservationList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.error_outline, size: 48),

              const SizedBox(height: 12),

              Text(_errorMessage!, textAlign: TextAlign.center),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _loadReservations,

                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reservations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.event_busy, size: 50),

            SizedBox(height: 12),

            Text('No reservations found', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReservations,

      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),

        itemCount: _reservations.length,

        itemBuilder: (context, index) {
          return _buildReservationCard(_reservations[index]);
        },
      ),
    );
  }
}
