import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_client.dart';

class RestaurantTableQrScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const RestaurantTableQrScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<RestaurantTableQrScreen> createState() =>
      _RestaurantTableQrScreenState();
}

class _RestaurantTableQrScreenState extends State<RestaurantTableQrScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _tables = [];

  // ------------------------------------------------------------
  // CUSTOMER QR LANDING URL
  //
  // IMPORTANT:
  // Do not use the REST API URL here.
  //
  // Replace this later with the public URL that will open the
  // customer application / download page.
  // ------------------------------------------------------------

  static const String _customerQrBaseUrl =
      'http:/api.jaihindplaster.com:5000/order';

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  // ------------------------------------------------------------
  // LOAD TABLES
  // ------------------------------------------------------------

  Future<void> _loadTables() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await widget.apiClient.get(
        '/customer-order/admin/qr-tables'
        '?outletId=${widget.outletId}',
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to load restaurant tables',
        );
      }

      final List<dynamic> rows = response['tables'] ?? [];

      setState(() {
        _tables = rows.map((row) => Map<String, dynamic>.from(row)).toList();

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ------------------------------------------------------------
  // QR URL
  // ------------------------------------------------------------

  String _qrUrl(Map<String, dynamic> table) {
    final token = table['tableUUUid']?.toString() ?? '';

    return '$_customerQrBaseUrl/$token';
  }

  // ------------------------------------------------------------
  // SHOW QR
  // ------------------------------------------------------------

  void _showQr(BuildContext context, Map<String, dynamic> table) {
    final tableName = table['tableName']?.toString() ?? '';

    final tableCode = table['tableCode']?.toString() ?? '';

    final url = _qrUrl(table);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('$tableCode - $tableName'),

          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: url, version: QrVersions.auto, size: 250),

                const SizedBox(height: 16),

                Text(
                  'Scan to Order',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TABLE CARD
  // ------------------------------------------------------------

  Widget _buildTableCard(Map<String, dynamic> table) {
    final tableCode = table['tableCode']?.toString() ?? '';

    final tableName = table['tableName']?.toString() ?? '';

    final capacity = table['capacity']?.toString() ?? '';

    final status = table['status']?.toString() ?? '';

    final qrToken = table['tableUUUid']?.toString() ?? '';

    return Card(
      elevation: 2,

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const Icon(Icons.table_restaurant, size: 28),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tableCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        tableName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade200,
                  ),

                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text('Capacity: $capacity', style: const TextStyle(fontSize: 13)),

            const SizedBox(height: 4),

            Text(
              'QR Token: $qrToken',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _showQr(context, table);
                },

                icon: const Icon(Icons.qr_code),

                label: const Text('VIEW QR'),
              ),
            ),
          ],
        ),
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
        title: const Text('Restaurant Table QR'),

        actions: [
          IconButton(
            onPressed: _loadTables,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.error_outline, size: 50),

              const SizedBox(height: 12),

              Text(_error!, textAlign: TextAlign.center),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _loadTables,

                icon: const Icon(Icons.refresh),

                label: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tables.isEmpty) {
      return const Center(child: Text('No restaurant tables found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        final crossAxisCount = isDesktop ? 4 : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(16),

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,

            crossAxisSpacing: 12,

            mainAxisSpacing: 12,

            childAspectRatio: isDesktop ? 1.25 : 0.85,
          ),

          itemCount: _tables.length,

          itemBuilder: (context, index) {
            return _buildTableCard(_tables[index]);
          },
        );
      },
    );
  }
}
