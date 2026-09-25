import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/hotel/hotel_housekeeping_room.dart';
import '../../services/hotel/hotel_housekeeping_service.dart';

class HotelHousekeepingScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const HotelHousekeepingScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<HotelHousekeepingScreen> createState() =>
      _HotelHousekeepingScreenState();
}

class _HotelHousekeepingScreenState extends State<HotelHousekeepingScreen> {
  late final HotelHousekeepingService _service;

  List<HotelHousekeepingRoom> _rooms = [];

  bool _loading = true;
  String? _errorMessage;

  final Set<int> _processingRoomIds = {};

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _service = HotelHousekeepingService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadRooms();

    // Refresh elapsed-time display every minute.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD ROOMS
  // ------------------------------------------------------------

  Future<void> _loadRooms() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _service.getHousekeepingRooms(
        outletId: widget.outletId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ------------------------------------------------------------
  // START HOUSEKEEPING
  // ------------------------------------------------------------

  Future<void> _startHousekeeping(HotelHousekeepingRoom room) async {
    if (_processingRoomIds.contains(room.roomId)) {
      return;
    }

    setState(() {
      _processingRoomIds.add(room.roomId);
    });

    try {
      await _service.startHousekeeping(roomId: room.roomId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Housekeeping started for Room ${room.roomNo}')),
      );

      await _loadRooms();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start housekeeping: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRoomIds.remove(room.roomId);
        });
      }
    }
  }

  // ------------------------------------------------------------
  // COMPLETE HOUSEKEEPING
  // ------------------------------------------------------------

  Future<void> _completeHousekeeping(HotelHousekeepingRoom room) async {
    if (_processingRoomIds.contains(room.roomId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Complete Housekeeping'),
          content: Text('Mark Room ${room.roomNo} as clean and available?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _processingRoomIds.add(room.roomId);
    });

    try {
      await _service.completeHousekeeping(roomId: room.roomId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Housekeeping completed for Room ${room.roomNo}'),
        ),
      );

      await _loadRooms();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete housekeeping: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRoomIds.remove(room.roomId);
        });
      }
    }
  }

  // ------------------------------------------------------------
  // FORMAT START TIME
  // ------------------------------------------------------------

  String _formatStartedAt(DateTime? startedAt) {
    if (startedAt == null) {
      return '-';
    }

    final local = startedAt.toLocal();

    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
        ? 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ------------------------------------------------------------
  // ELAPSED TIME
  // ------------------------------------------------------------

  String _elapsedTime(DateTime? startedAt) {
    if (startedAt == null) {
      return '-';
    }

    final now = DateTime.now();

    final localStart = startedAt.toLocal();

    Duration duration = now.difference(localStart);

    if (duration.isNegative) {
      duration = Duration.zero;
    }

    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  // ------------------------------------------------------------
  // ROOM CARD
  // ------------------------------------------------------------

  Widget _buildRoomCard(HotelHousekeepingRoom room) {
    final isDirty = room.housekeepingStatus == 'DIRTY';

    final isInProgress = room.housekeepingStatus == 'IN_PROGRESS';

    final isProcessing = _processingRoomIds.contains(room.roomId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------
            // HEADER
            // ------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNo}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        room.roomTypeName ?? room.roomTypeCode ?? 'Room',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),

                      if (room.floorNo != null) Text('Floor ${room.floorNo}'),
                    ],
                  ),
                ),

                _buildStatusChip(room.housekeepingStatus),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(),

            const SizedBox(height: 8),

            // ------------------------------------------------
            // STATUS INFORMATION
            // ------------------------------------------------
            if (isDirty) ...[
              const Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Waiting for housekeeping'),
                ],
              ),
            ],

            if (isInProgress) ...[
              Row(
                children: [
                  const Icon(Icons.play_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Started: '
                    '${_formatStartedAt(room.startedAt)}',
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Elapsed: '
                    '${_elapsedTime(room.startedAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ------------------------------------------------
            // ACTION
            // ------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isProcessing
                    ? null
                    : isDirty
                    ? () => _startHousekeeping(room)
                    : isInProgress
                    ? () => _completeHousekeeping(room)
                    : null,
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isDirty ? Icons.play_arrow : Icons.check),
                label: Text(
                  isProcessing
                      ? 'Please wait...'
                      : isDirty
                      ? 'START HOUSEKEEPING'
                      : isInProgress
                      ? 'COMPLETE HOUSEKEEPING'
                      : 'ACTION',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // STATUS CHIP
  // ------------------------------------------------------------

  Widget _buildStatusChip(String status) {
    String label;

    if (status == 'DIRTY') {
      label = 'DIRTY';
    } else if (status == 'IN_PROGRESS') {
      label = 'IN PROGRESS';
    } else {
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildSummary() {
    final dirtyCount = _rooms
        .where((room) => room.housekeepingStatus == 'DIRTY')
        .length;

    final inProgressCount = _rooms
        .where((room) => room.housekeepingStatus == 'IN_PROGRESS')
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _buildSummaryItem('Pending', dirtyCount),

            _buildSummaryItem('In Progress', inProgressCount),

            _buildSummaryItem('Total', _rooms.length),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BODY
  // ------------------------------------------------------------

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),

              const SizedBox(height: 12),

              const Text(
                'Unable to load housekeeping rooms',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(_errorMessage!, textAlign: TextAlign.center),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _loadRooms,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: _rooms.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 56),
                      SizedBox(height: 12),
                      Text(
                        'No rooms waiting for housekeeping',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _rooms.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummary();
                }

                return _buildRoomCard(_rooms[index - 1]);
              },
            ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Housekeeping'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadRooms,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
