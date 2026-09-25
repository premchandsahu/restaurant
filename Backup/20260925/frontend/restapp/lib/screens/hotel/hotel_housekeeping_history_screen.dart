import 'package:flutter/material.dart';

import '../../models/hotel/hotel_housekeeping_history.dart';
import '../../services/hotel/hotel_housekeeping_service.dart';

class HotelHousekeepingHistoryScreen extends StatefulWidget {
  final int outletId;
  final String baseUrl;
  final String token;

  const HotelHousekeepingHistoryScreen({
    super.key,
    required this.outletId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<HotelHousekeepingHistoryScreen> createState() =>
      _HotelHousekeepingHistoryScreenState();
}

class _HotelHousekeepingHistoryScreenState
    extends State<HotelHousekeepingHistoryScreen> {
  late final HotelHousekeepingService _service;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));

  DateTime _toDate = DateTime.now();

  int? _selectedRoomId;

  Map<int, String> _roomOptions = {};

  List<HotelHousekeepingHistory> _history = [];

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _service = HotelHousekeepingService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );

    _loadHistory();
  }

  // ------------------------------------------------------------
  // LOAD HISTORY
  // ------------------------------------------------------------

  Future<void> _loadHistory() async {
    if (_fromDate.isAfter(_toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From Date cannot be after To Date.')),
      );

      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final history = await _service.getHousekeepingHistory(
        outletId: widget.outletId,
        fromDate: _formatApiDate(_fromDate),
        toDate: _formatApiDate(_toDate),
        roomId: _selectedRoomId,
      );

      if (!mounted) {
        return;
      }

      // Build room list from an unfiltered history response.
      if (_selectedRoomId == null) {
        final options = <int, String>{};

        for (final item in history) {
          options[item.roomId] = 'Room ${item.roomNo}';
        }

        _roomOptions = options;
      }

      setState(() {
        _history = history;
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
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _fromDate = selected;

      if (_fromDate.isAfter(_toDate)) {
        _toDate = selected;
      }
    });
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _toDate = selected;
    });
  }

  // ------------------------------------------------------------
  // DATE FORMAT
  // ------------------------------------------------------------

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatDisplayDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }

  // ------------------------------------------------------------
  // DATE/TIME DISPLAY
  // ------------------------------------------------------------

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();

    final date = _formatDisplayDate(local);

    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
        ? 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$date $hour:$minute $period';
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) {
      return '-';
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours hr';
    }

    return '$hours hr $remaining min';
  }

  // ------------------------------------------------------------
  // STATUS CHIP
  // ------------------------------------------------------------

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  Widget _buildFilters(bool isDesktop) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isDesktop ? 155 : 145,
              child: InkWell(
                onTap: _selectFromDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDisplayDate(_fromDate)),
                ),
              ),
            ),

            SizedBox(
              width: isDesktop ? 155 : 145,
              child: InkWell(
                onTap: _selectToDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'To Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDisplayDate(_toDate)),
                ),
              ),
            ),

            SizedBox(
              width: isDesktop ? 190 : 180,
              child: DropdownButtonFormField<int?>(
                value: _selectedRoomId,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Rooms'),
                  ),
                  ..._roomOptions.entries.map(
                    (entry) => DropdownMenuItem<int?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRoomId = value;
                  });
                },
              ),
            ),

            ElevatedButton.icon(
              onPressed: _loading ? null : _loadHistory,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),

            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _selectedRoomId = null;

                        _fromDate = DateTime.now().subtract(
                          const Duration(days: 7),
                        );

                        _toDate = DateTime.now();
                      });

                      _loadHistory();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildSummary() {
    final completedCount = _history
        .where((item) => item.status == 'COMPLETED')
        .length;

    final startedCount = _history
        .where((item) => item.status == 'STARTED')
        .length;

    final completedDurations = _history
        .where(
          (item) => item.status == 'COMPLETED' && item.durationMinutes != null,
        )
        .map((item) => item.durationMinutes!)
        .toList();

    double averageMinutes = 0;

    if (completedDurations.isNotEmpty) {
      final total = completedDurations.reduce((a, b) => a + b);

      averageMinutes = total / completedDurations.length;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 30,
          runSpacing: 12,
          children: [
            _buildSummaryItem('Total', _history.length.toString()),
            _buildSummaryItem('Completed', completedCount.toString()),
            _buildSummaryItem('Started', startedCount.toString()),
            _buildSummaryItem(
              'Avg. Time',
              completedDurations.isEmpty
                  ? '-'
                  : '${averageMinutes.toStringAsFixed(0)} min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DESKTOP TABLE
  // ------------------------------------------------------------

  Widget _buildDesktopTable() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Room')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Started')),
            DataColumn(label: Text('Completed')),
            DataColumn(label: Text('Duration')),
          ],
          rows: _history.map((item) {
            return DataRow(
              cells: [
                DataCell(Text('Room ${item.roomNo}')),
                DataCell(Text(item.roomTypeName ?? item.roomTypeCode ?? '-')),
                DataCell(_buildStatusChip(item.status)),
                DataCell(Text(_formatDateTime(item.startedAt))),
                DataCell(Text(_formatDateTime(item.completedAt))),
                DataCell(Text(_formatDuration(item.durationMinutes))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MOBILE CARD
  // ------------------------------------------------------------

  Widget _buildMobileCard(HotelHousekeepingHistory item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${item.roomNo}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.roomTypeName ?? item.roomTypeCode ?? 'Room'),
                    ],
                  ),
                ),
                _buildStatusChip(item.status),
              ],
            ),

            const SizedBox(height: 12),

            const Divider(),

            const SizedBox(height: 8),

            _buildHistoryRow(
              Icons.play_circle_outline,
              'Started',
              _formatDateTime(item.startedAt),
            ),

            const SizedBox(height: 8),

            _buildHistoryRow(
              Icons.check_circle_outline,
              'Completed',
              _formatDateTime(item.completedAt),
            ),

            const SizedBox(height: 8),

            _buildHistoryRow(
              Icons.timer_outlined,
              'Duration',
              _formatDuration(item.durationMinutes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  // ------------------------------------------------------------
  // BODY
  // ------------------------------------------------------------

  Widget _buildBody(bool isDesktop) {
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
                'Unable to load housekeeping history',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 56),
                SizedBox(height: 12),
                Text(
                  'No housekeeping history found',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildSummary(),
          if (isDesktop)
            _buildDesktopTable()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: _history.map(_buildMobileCard).toList()),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Housekeeping History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(isDesktop),
          Expanded(child: _buildBody(isDesktop)),
        ],
      ),
    );
  }
}
