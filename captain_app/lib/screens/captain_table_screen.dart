import 'package:captain_app/screens/captain_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/captain_table.dart';
import '../services/captain_auth_service.dart';

class CaptainTableScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final CaptainOutlet outlet;
  final int outletId;
  const CaptainTableScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.outlet,
    required this.outletId,
  });

  @override
  State<CaptainTableScreen> createState() => _CaptainTableScreenState();
}

class _CaptainTableScreenState extends State<CaptainTableScreen> {
  List<CaptainTable> _tables = [];

  Map<int, String> _floorNames = {};
  Map<int, String> _diningAreaNames = {};

  int? _selectedFloorId;
  int? _selectedDiningAreaId;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/outlets/${widget.outlet.outletId}/pos-layout',
        ),
        headers: {
          'Accept': 'application/json',
          if (widget.token.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Invalid response from POS layout API');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ?? 'Unable to load tables'
              : 'Unable to load tables',
        );
      }

      if (decoded is! Map) {
        throw Exception('Invalid POS layout response');
      }

      final data = Map<String, dynamic>.from(decoded);

      // --------------------------------------------
      // Floors
      // --------------------------------------------

      final floors = data['floors'] as List? ?? [];

      final floorNames = <int, String>{};

      for (final item in floors) {
        final floor = Map<String, dynamic>.from(item);

        final id = _toInt(floor['floorId'] ?? floor['floor_id']);

        final name =
            floor['floorName']?.toString() ?? floor['floor_name']?.toString();

        if (id != null && name != null) {
          floorNames[id] = name;
        }
      }

      // --------------------------------------------
      // Dining areas
      // --------------------------------------------

      final diningAreas = data['diningAreas'] ?? data['dining_areas'] ?? [];

      final diningAreaNames = <int, String>{};

      if (diningAreas is List) {
        for (final item in diningAreas) {
          final area = Map<String, dynamic>.from(item);

          final id = _toInt(area['diningAreaId'] ?? area['dining_area_id']);

          final name =
              area['areaName']?.toString() ??
              area['area_name']?.toString() ??
              area['diningAreaName']?.toString() ??
              area['dining_area_name']?.toString();

          if (id != null && name != null) {
            diningAreaNames[id] = name;
          }
        }
      }

      // --------------------------------------------
      // Tables
      // --------------------------------------------

      final tableList = data['tables'] as List? ?? [];

      final loadedTables = tableList
          .map(
            (item) => CaptainTable.fromJson(
              Map<String, dynamic>.from(item),
              floorNames: floorNames,
              diningAreaNames: diningAreaNames,
            ),
          )
          .toList();

      loadedTables.sort((a, b) => a.tableCode.compareTo(b.tableCode));

      if (!mounted) {
        return;
      }

      setState(() {
        _tables = loadedTables;
        _floorNames = floorNames;
        _diningAreaNames = diningAreaNames;

        if (_selectedFloorId == null && _floorNames.isNotEmpty) {
          _selectedFloorId = _floorNames.keys.first;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<CaptainTable> get _filteredTables {
    return _tables.where((table) {
      final floorMatch =
          _selectedFloorId == null || table.floorId == _selectedFloorId;

      final areaMatch =
          _selectedDiningAreaId == null ||
          table.diningAreaId == _selectedDiningAreaId;

      return floorMatch && areaMatch;
    }).toList();
  }

  int _countStatus(String status) {
    return _filteredTables
        .where((table) => table.status.toUpperCase() == status)
        .length;
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return Colors.green;

      case 'OCCUPIED':
        return Colors.orange;

      case 'RESERVED':
        return Colors.blue;

      case 'BILL_REQUESTED':
        return Colors.purple;

      case 'CLEANING':
        return Colors.brown;

      case 'DISABLED':
        return Colors.grey;

      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 115,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
        color: color.withOpacity(0.08),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getTableOrders(CaptainTable table) async {
    final response = await http.get(
      Uri.parse(
        '${widget.baseUrl}/orders/table/${table.tableId}/orders'
        '?outletId=${widget.outlet.outletId}',
      ),
      headers: {
        'Accept': 'application/json',
        if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
      },
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from table orders API');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map
            ? decoded['message']?.toString() ?? 'Unable to load table orders'
            : 'Unable to load table orders',
      );
    }

    if (decoded is! Map) {
      throw Exception('Invalid table orders response');
    }

    final orders = decoded['orders'] as List? ?? [];

    return orders.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _onTableTapped(CaptainTable table) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      final orders = await _getTableOrders(table);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      // --------------------------------------------
      // No active order
      // --------------------------------------------

      if (orders.isEmpty) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(table.tableName),
              content: const Text('There is no active order for this table.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaptainOrderScreen(
                          baseUrl: widget.baseUrl,
                          token: widget.token,
                          table: table,
                          outletId: widget.outletId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('NEW ORDER'),
                ),
              ],
            );
          },
        );

        return;
      }

      // --------------------------------------------
      // Existing orders
      // --------------------------------------------

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.table_restaurant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${table.tableName} '
                    '(${table.tableCode})',
                  ),
                ),
              ],
            ),

            content: SizedBox(
              width: 450,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),

                itemBuilder: (context, index) {
                  final order = orders[index];

                  final orderId = _toInt(order['order_id']);

                  final orderNo =
                      order['order_no']?.toString() ??
                      orderId?.toString() ??
                      '-';

                  final status = order['order_status']?.toString() ?? 'OPEN';

                  final guests = _toInt(order['guest_count']) ?? 1;

                  final total =
                      double.tryParse(
                        order['grand_total']?.toString() ?? '0',
                      ) ??
                      0;

                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: orderId == null
                          ? null
                          : () {
                              Navigator.pop(dialogContext);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CaptainOrderScreen(
                                    baseUrl: widget.baseUrl,
                                    token: widget.token,
                                    table: table,
                                    orderId: orderId,
                                    outletId: widget.outletId,
                                  ),
                                ),
                              );

                              // Existing order screen
                              // will be connected next.
                            },

                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Order #$orderNo',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                Text(
                                  status.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  '$guests '
                                  '${guests == 1 ? 'Guest' : 'Guests'}',
                                ),

                                const Spacer(),

                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('CANCEL'),
              ),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New order screen will be connected next.'),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('NEW ORDER'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load table orders: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget _buildTableCard(CaptainTable table) {
    final color = _statusColor(table.status);

    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTableTapped(table),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(Icons.table_restaurant, size: 30, color: color),
              ),

              const SizedBox(height: 8),

              Text(
                table.tableName.isEmpty ? table.tableCode : table.tableName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                table.tableCode,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 7),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  table.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${table.capacity}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        if (_floorNames.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _floorNames.entries.map((entry) {
                final selected = _selectedFloorId == entry.key;

                return Padding(
                  padding: const EdgeInsets.all(5),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFloorId = entry.key;
                        _selectedDiningAreaId = null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

        if (_diningAreaNames.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ChoiceChip(
                  label: const Text('All Areas'),
                  selected: _selectedDiningAreaId == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedDiningAreaId = null;
                    });
                  },
                ),

                ..._diningAreaNames.entries.map((entry) {
                  final selected = _selectedDiningAreaId == entry.key;

                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedDiningAreaId = entry.key;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Captain Tables')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 45, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadTables,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tables = _filteredTables;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.outlet.outletName),
        actions: [
          IconButton(onPressed: _loadTables, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: Column(
        children: [
          // ----------------------------------
          // Summary
          // ----------------------------------
          SizedBox(
            height: 78,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  _buildSummaryCard(
                    'ALL',
                    tables.length,
                    Icons.table_restaurant,
                    Colors.blueGrey,
                  ),

                  _buildSummaryCard(
                    'AVAILABLE',
                    _countStatus('AVAILABLE'),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),

                  _buildSummaryCard(
                    'OCCUPIED',
                    _countStatus('OCCUPIED'),
                    Icons.people,
                    Colors.orange,
                  ),

                  _buildSummaryCard(
                    'RESERVED',
                    _countStatus('RESERVED'),
                    Icons.event_seat,
                    Colors.blue,
                  ),

                  _buildSummaryCard(
                    'BILL REQUESTED',
                    _countStatus('BILL_REQUESTED'),
                    Icons.receipt_long,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ----------------------------------
          // Filters
          // ----------------------------------
          _buildFilters(),

          const Divider(height: 1),

          // ----------------------------------
          // Tables
          // ----------------------------------
          Expanded(
            child: tables.isEmpty
                ? const Center(child: Text('No tables available'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 190,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      return _buildTableCard(tables[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}
