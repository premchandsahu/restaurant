import 'package:flutter/material.dart';
import 'package:restapp/screens/pos/pos_order_screen.dart';
import '../../services/pos/pos_order_service.dart';
import '../../models/pos/pos_layout.dart';
import '../../models/pos/restaurant_table.dart';
import '../../services/api_client.dart';
import '../../widgets/restaurant_table_card.dart';

class RestaurantTableScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const RestaurantTableScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<RestaurantTableScreen> createState() => _RestaurantTableScreenState();
}

class _RestaurantTableScreenState extends State<RestaurantTableScreen> {
  PosLayout? layout;
  late PosOrderService _orderService;
  int? selectedFloorId;
  int? selectedDiningAreaId;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _orderService = PosOrderService(
      baseUrl: widget.apiClient.baseUrl,
      token: widget.apiClient.token ?? '',
    );
    loadLayout();
  }

  Widget _buildTableSummary() {
    final tables = filteredTables;

    int countStatus(String status) {
      return tables.where((t) => t.status == status).length;
    }

    final total = tables.length;
    final available = countStatus('AVAILABLE');
    final occupied = countStatus('OCCUPIED');
    final reserved = countStatus('RESERVED');
    final billRequested = countStatus('BILL_REQUESTED');

    return SizedBox(
      height: 72,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _summaryCard(
              title: 'ALL',
              count: total,
              icon: Icons.table_restaurant,
              color: Colors.blueGrey,
            ),

            _summaryCard(
              title: 'AVAILABLE',
              count: available,
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),

            _summaryCard(
              title: 'OCCUPIED',
              count: occupied,
              icon: Icons.people,
              color: Colors.orange,
            ),

            _summaryCard(
              title: 'RESERVED',
              count: reserved,
              icon: Icons.event_seat,
              color: Colors.blue,
            ),

            _summaryCard(
              title: 'BILL REQUESTED',
              count: billRequested,
              icon: Icons.receipt_long,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMergeOrderDialog(
    RestaurantTable table,
    int sourceOrderId,
  ) async {
    final orders = await _orderService.getTableOrders(
      tableId: table.tableId,
      outletId: widget.outletId,
    );

    final targetOrders = orders
        .where(
          (order) =>
              order.orderId != sourceOrderId &&
              ![
                'BILLED',
                'PAID',
                'CANCELLED',
                'VOID',
                'MERGED',
              ].contains(order.orderStatus),
        )
        .toList();

    if (!mounted) {
      return;
    }

    if (targetOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other active order is available for merging'),
        ),
      );

      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.merge_type),
              SizedBox(width: 8),
              Text('Merge Order'),
            ],
          ),

          content: SizedBox(
            width: 450,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Select the target order:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ...targetOrders.map((order) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),

                      title: Text(
                        '${order.logicalCode ?? ''} '
                        '• Order #${order.orderId}',
                      ),

                      subtitle: Text(
                        '₹${order.grandTotal.toStringAsFixed(2)}'
                        ' • ${order.orderStatus}',
                      ),

                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                      onTap: () {
                        Navigator.pop(context);

                        _confirmMergeOrder(
                          table,
                          sourceOrderId,
                          order.orderId,
                          order.logicalCode ?? 'Target',
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmMergeOrder(
    RestaurantTable table,
    int sourceOrderId,
    int targetOrderId,
    String targetLogicalCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Merge'),

          content: Text(
            'Merge Order #$sourceOrderId '
            'into $targetLogicalCode '
            '(Order #$targetOrderId)?\n\n'
            'The source order will be marked as MERGED '
            'and its items will become part of the target order.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('MERGE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _mergeOrders(table, sourceOrderId, targetOrderId);
  }

  Future<void> _mergeOrders(
    RestaurantTable table,
    int sourceOrderId,
    int targetOrderId,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,

        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      await _orderService.mergeOrders(
        sourceOrderId: sourceOrderId,
        targetOrderId: targetOrderId,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orders merged successfully')),
      );

      await loadLayout();
    } catch (e) {
      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 2),

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

  Future<void> loadLayout() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final response = await widget.apiClient.get(
        '/outlets/${widget.outletId}/pos-layout',
      );

      final result = PosLayout.fromJson(response);

      debugPrint('POS LAYOUT TABLES: ${result.tables.length}');

      for (final table in result.tables) {
        debugPrint(
          'TABLE: ${table.tableId} '
          '${table.tableCode} '
          '${table.tableName} '
          'floor=${table.floorId} '
          'area=${table.diningAreaId} '
          'status=${table.status}',
        );
      }

      setState(() {
        layout = result;

        if (result.floors.isNotEmpty) {
          selectedFloorId = result.floors.first.floorId;
        }

        selectedDiningAreaId = null;

        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  List<RestaurantTable> get filteredTables {
    if (layout == null) {
      return [];
    }

    return layout!.tables.where((table) {
      final floorMatch =
          selectedFloorId == null || table.floorId == selectedFloorId;

      final areaMatch =
          selectedDiningAreaId == null ||
          table.diningAreaId == selectedDiningAreaId;

      return floorMatch && areaMatch;
    }).toList();
  }

  void _openExistingOrder(RestaurantTable table, int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosOrderScreen(
          outletId: widget.outletId,
          tableId: table.tableId,
          orderId: orderId,
          baseUrl: widget.apiClient.baseUrl,
          token: widget.apiClient.token ?? '',
        ),
      ),
    );
  }

  void _openNewOrder(RestaurantTable table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosOrderScreen(
          outletId: widget.outletId,
          tableId: table.tableId,
          orderId: null,
          baseUrl: widget.apiClient.baseUrl,
          token: widget.apiClient.token ?? '',
        ),
      ),
    );
  }

  Widget _buildOrderStatus(String status) {
    IconData icon;

    switch (status) {
      case 'OPEN':
        icon = Icons.edit;

        break;

      case 'CONFIRMED':
        icon = Icons.check_circle_outline;

        break;

      case 'PREPARING':
        icon = Icons.restaurant;

        break;

      case 'READY':
        icon = Icons.notifications_active;

        break;

      case 'SERVED':
        icon = Icons.room_service;

        break;

      case 'BILLED':
        icon = Icons.receipt_long;

        break;

      default:
        icon = Icons.info_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(icon, size: 16),

        const SizedBox(width: 4),

        Text(
          status,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _orderInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _transferOrder(
    RestaurantTable sourceTable,
    RestaurantTable destinationTable,
    int orderId,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      await _orderService.transferOrderTable(
        orderId: orderId,
        newTableId: destinationTable.tableId,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order transferred from '
            '${sourceTable.tableCode} to '
            '${destinationTable.tableCode}',
          ),
        ),
      );

      await loadLayout();
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to transfer order: $e')));
    }
  }

  Future<void> _showTransferTableDialog(
    RestaurantTable sourceTable,
    int orderId,
  ) async {
    final availableTables = filteredTables
        .where(
          (t) =>
              t.tableId != sourceTable.tableId &&
              t.status != 'RESERVED' &&
              t.status != 'DISABLED' &&
              t.status != 'CLEANING',
        )
        .toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No table is available for transfer')),
      );

      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.swap_horiz),
              SizedBox(width: 8),
              Text('Transfer Table'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: availableTables.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final destination = availableTables[index];

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      Icons.table_restaurant,
                      color: destination.status == 'OCCUPIED'
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: Text(
                      destination.tableName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${destination.tableCode} • '
                      '${destination.status.replaceAll('_', ' ')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(dialogContext);

                      await _transferOrder(sourceTable, destination, orderId);
                    },
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
          ],
        );
      },
    );
  }

  Future<void> onTableSelected(RestaurantTable table) async {
    try {
      // --------------------------------------------------
      // Show loading
      // --------------------------------------------------

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      final orders = await _orderService.getTableOrders(
        tableId: table.tableId,
        outletId: widget.outletId,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // --------------------------------------------------
      // No active orders
      // --------------------------------------------------

      if (orders.isEmpty) {
        _openNewOrder(table);
        return;
      }

      // --------------------------------------------------
      // Existing logical orders
      // --------------------------------------------------

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==========================================
                  // HEADER
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(
                            Icons.table_restaurant,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.tableName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                '${table.tableCode} • '
                                '${orders.length} active '
                                '${orders.length == 1 ? 'order' : 'orders'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // ==========================================
                  // ORDER LIST
                  // ==========================================
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      shrinkWrap: true,
                      itemCount: orders.length,

                      separatorBuilder: (_, __) {
                        return const SizedBox(height: 10);
                      },

                      itemBuilder: (context, index) {
                        final order = orders[index];

                        final logicalCode =
                            order.logicalCode ?? table.tableCode;

                        final guests = order.guestCount ?? 1;

                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(dialogContext);

                              _openExistingOrder(table, order.orderId);
                            },

                            child: Padding(
                              padding: const EdgeInsets.all(14),

                              child: Column(
                                children: [
                                  // --------------------------------
                                  // Logical table + status
                                  // --------------------------------
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          logicalCode,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Text(
                                          'Order #${order.orderNo}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      _buildOrderStatus(order.orderStatus),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // --------------------------------
                                  // Order details
                                  // --------------------------------
                                  Row(
                                    children: [
                                      _orderInfo(
                                        Icons.people_outline,
                                        '$guests '
                                        '${guests == 1 ? 'Guest' : 'Guests'}',
                                      ),

                                      const Spacer(),

                                      Text(
                                        '₹${order.grandTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // --------------------------------
                                  // OPEN ORDER
                                  // --------------------------------
                                  SizedBox(
                                    width: double.infinity,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(
                                              Icons.merge_type,
                                              size: 18,
                                            ),
                                            label: const Text('MERGE'),
                                            onPressed: () {
                                              Navigator.pop(context);

                                              _showMergeOrderDialog(
                                                table,
                                                order.orderId,
                                              );
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(dialogContext);

                                              _showTransferTableDialog(
                                                table,
                                                order.orderId,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.swap_horiz,
                                              size: 18,
                                            ),
                                            label: const Text('TRANSFER'),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(dialogContext);

                                              _openExistingOrder(
                                                table,
                                                order.orderId,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit_note,
                                              size: 18,
                                            ),
                                            label: const Text('OPEN ORDER'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ==========================================
                  // BOTTOM ACTIONS
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('CANCEL'),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);

                              _openNewOrder(table);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('NEW ORDER'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      // In case loading dialog is still open
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load table orders: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Text(error!),

              const SizedBox(height: 16),

              ElevatedButton(onPressed: loadLayout, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = layout!;
    debugPrint('FILTERED TABLES: ${filteredTables.length}');
    return Scaffold(
      appBar: AppBar(
        title: Text(data.outlet.outletName),

        actions: [
          IconButton(onPressed: loadLayout, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: Column(
        children: [
          // -----------------------------
          // FLOOR
          // -----------------------------
          SizedBox(
            height: 55,

            child: ListView(
              scrollDirection: Axis.horizontal,

              padding: const EdgeInsets.symmetric(horizontal: 8),

              children: data.floors.map((floor) {
                final selected = selectedFloorId == floor.floorId;

                return Padding(
                  padding: const EdgeInsets.all(5),

                  child: ChoiceChip(
                    label: Text(floor.floorName),

                    selected: selected,

                    onSelected: (_) {
                      setState(() {
                        selectedFloorId = floor.floorId;

                        selectedDiningAreaId = null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // -----------------------------
          // DINING AREAS
          // -----------------------------
          SizedBox(
            height: 50,

            child: ListView(
              scrollDirection: Axis.horizontal,

              padding: const EdgeInsets.symmetric(horizontal: 8),

              children: [
                ChoiceChip(
                  label: const Text('All'),

                  selected: selectedDiningAreaId == null,

                  onSelected: (_) {
                    setState(() {
                      selectedDiningAreaId = null;
                    });
                  },
                ),

                ...data.diningAreas.map((area) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),

                    child: ChoiceChip(
                      label: Text(area.areaName),

                      selected: selectedDiningAreaId == area.diningAreaId,

                      onSelected: (_) {
                        setState(() {
                          selectedDiningAreaId = area.diningAreaId;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const Divider(height: 1),

          // -----------------------------
          // TABLE SUMMARY
          // -----------------------------
          _buildTableSummary(),

          const Divider(height: 1),

          // -----------------------------
          // TABLES
          // -----------------------------
          Expanded(
            child: filteredTables.isEmpty
                ? const Center(child: Text('No tables available'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),

                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 185,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),

                    itemCount: filteredTables.length,

                    itemBuilder: (context, index) {
                      final table = filteredTables[index];

                      return RestaurantTableCard(
                        table: table,
                        onTap: () => onTableSelected(table),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
