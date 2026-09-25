import 'package:flutter/material.dart';
import 'package:restapp/models/pos/kitchen_station.dart';
import 'dart:async';
import '../../models/pos/pos_kot.dart';
import '../../services/pos/pos_order_service.dart';

class KitchenDisplayScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const KitchenDisplayScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  late final PosOrderService _orderService;
  List<KitchenStation> _stations = [];
  KitchenStation? _selectedStation;
  final Set<int> _knownKotIds = {};
  bool _loadingStations = true;

  List<PosKot> _kots = [];
  Timer? _refreshTimer;
  Timer? _ageTimer;
  bool _loading = true;
  String? _error;

  void _showNewKOTNotification(List<PosKot> newKots) {
    if (!mounted) {
      return;
    }

    final count = newKots.length;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  count == 1
                      ? 'NEW KOT: '
                            '${newKots.first.kotNo}'
                      : '$count NEW KOTs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _refreshKOTsSilently() async {
    if (_selectedStation == null) {
      return;
    }

    try {
      final kots = await _orderService.getStationKOTs(
        _selectedStation!.kitchenStationId,
      );

      if (!mounted) return;

      final newKots = kots
          .where((kot) => !_knownKotIds.contains(kot.kotId))
          .toList();

      if (newKots.isNotEmpty) {
        debugPrint('KDS: ${newKots.length} NEW KOT(s)');

        for (final kot in newKots) {
          debugPrint(
            'NEW KOT: ${kot.kotId} '
            '${kot.kotNo} '
            '${kot.stationName}',
          );
        }

        _showNewKOTNotification(newKots);
      }

      setState(() {
        _kots = kots;

        _knownKotIds
          ..clear()
          ..addAll(kots.map((kot) => kot.kotId));
      });
    } catch (_) {
      // Background refresh failure should not
      // disturb the current KDS screen.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ageTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _orderService = PosOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadStations();
    // Refresh KOTs every 5 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshKOTsSilently();
    });

    // Refresh KOT age every second.
    _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Color _ageColor(PosKot kot) {
    if (kot.kotDate == null) {
      return Colors.grey;
    }

    final minutes = DateTime.now().difference(kot.kotDate!).inMinutes;

    if (minutes >= 10) {
      return Colors.red;
    }

    if (minutes >= 5) {
      return Colors.orange;
    }

    return Colors.green;
  }

  String _kotAge(PosKot kot) {
    if (kot.kotDate == null) {
      return '--:--';
    }

    final difference = DateTime.now().difference(kot.kotDate!);

    if (difference.isNegative) {
      return '00:00';
    }

    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadStations() async {
    try {
      setState(() {
        _loadingStations = true;
        _error = null;
      });

      final stations = await _orderService.getKitchenStations();

      if (!mounted) return;

      debugPrint('KDS: Received ${stations.length} stations');

      for (final station in stations) {
        debugPrint(
          'KDS STATION: '
          '${station.kitchenStationId} '
          '${station.stationName}',
        );
      }

      setState(() {
        _stations = stations;

        if (stations.isNotEmpty) {
          _selectedStation = stations.first;
        }

        _loadingStations = false;
      });

      debugPrint(
        'KDS: Selected station = '
        '${_selectedStation?.kitchenStationId} '
        '${_selectedStation?.stationName}',
      );

      if (_selectedStation != null) {
        await _loadKOTs();
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingStations = false;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadKOTs() async {
    if (_selectedStation == null) {
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final kots = await _orderService.getStationKOTs(
        _selectedStation!.kitchenStationId,
      );

      if (!mounted) return;

      setState(() {
        _kots = kots;
        _knownKotIds
          ..clear()
          ..addAll(kots.map((kot) => kot.kotId));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateKOTStatus(PosKot kot, String status) async {
    try {
      await _orderService.updateKOTStatus(kotId: kot.kotId, status: status);

      await _loadKOTs();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update KOT: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display'),

        actions: [
          if (_stations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),

              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedStation?.kitchenStationId,

                  dropdownColor: Theme.of(context).colorScheme.surface,

                  items: _stations.map((station) {
                    return DropdownMenuItem<int>(
                      value: station.kitchenStationId,

                      child: Text(station.stationName),
                    );
                  }).toList(),

                  onChanged: (stationId) async {
                    if (stationId == null) {
                      return;
                    }

                    final station = _stations.firstWhere(
                      (s) => s.kitchenStationId == stationId,
                    );

                    _knownKotIds.clear();

                    setState(() {
                      _selectedStation = station;
                      _kots = [];
                    });

                    await _loadKOTs();
                  },
                ),
              ),
            ),

          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadKOTs),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    debugPrint(
      'KDS BUILD: '
      'loadingStations=$_loadingStations '
      'loading=$_loading '
      'kots=${_kots.length} '
      'selected=${_selectedStation?.stationName}',
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadKOTs, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_kots.isEmpty) {
      return const Center(
        child: Text('No KOTs found', style: TextStyle(fontSize: 18)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKOTs,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _kots.length,
        itemBuilder: (context, index) {
          return _buildKOTCard(_kots[index]);
        },
      ),
    );
  }

  Widget _buildKOTCard(PosKot kot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------
            // Header
            // ------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KOT #${kot.kotNo}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (kot.stationName != null)
                        Text(
                          kot.stationName!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _kotAge(kot),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ageColor(kot),
                      ),
                    ),

                    const SizedBox(height: 4),

                    _statusBadge(kot.status),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // ------------------------------------------
            // Order information
            // ------------------------------------------
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),

                const SizedBox(width: 6),

                Text(
                  'Order #${kot.orderId}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ------------------------------------------
            // Items
            // ------------------------------------------
            ...kot.items.map((item) => _buildKOTItem(item)),

            const SizedBox(height: 16),

            // ------------------------------------------
            // Action
            // ------------------------------------------
            _buildActionButtons(kot),
          ],
        ),
      ),
    );
  }

  Widget _buildKOTItem(PosKotItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity
          SizedBox(
            width: 45,
            child: Text(
              _formatQty(item.qty),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (item.variantName != null && item.variantName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      item.variantName!,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),

                if (item.instruction != null && item.instruction!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Note: ${item.instruction}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PosKot kot) {
    switch (kot.status) {
      case 'NEW':
        return _actionButton(
          label: 'ACCEPT',
          onPressed: () => _updateKOTStatus(kot, 'ACCEPTED'),
        );

      case 'ACCEPTED':
        return _actionButton(
          label: 'START PREPARING',
          onPressed: () => _updateKOTStatus(kot, 'PREPARING'),
        );

      case 'PREPARING':
        return _actionButton(
          label: 'READY',
          onPressed: () => _updateKOTStatus(kot, 'READY'),
        );

      case 'READY':
        return _actionButton(
          label: 'SERVED',
          onPressed: () => _updateKOTStatus(kot, 'SERVED'),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'NEW':
        return Colors.orange.shade100;

      case 'ACCEPTED':
        return Colors.blue.shade100;

      case 'PREPARING':
        return Colors.amber.shade100;

      case 'READY':
        return Colors.green.shade100;

      case 'SERVED':
        return Colors.grey.shade200;

      case 'CANCELLED':
        return Colors.red.shade100;

      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'NEW':
        return Colors.orange.shade900;

      case 'ACCEPTED':
        return Colors.blue.shade900;

      case 'PREPARING':
        return Colors.amber.shade900;

      case 'READY':
        return Colors.green.shade900;

      case 'CANCELLED':
        return Colors.red.shade900;

      default:
        return Colors.black87;
    }
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _statusBackground(status),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: _statusTextColor(status),
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }

    return qty.toString();
  }
}
