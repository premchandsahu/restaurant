import 'package:flutter/material.dart';

import '../../models/hotel/hotel_active_stay.dart';
import '../../services/api_client.dart';
import '../../services/hotel/hotel_active_stay_service.dart';
import 'hotel_folio_screen.dart';

class HotelInhouseScreen extends StatefulWidget {
  final int outletId;
  final ApiClient apiClient;

  const HotelInhouseScreen({
    super.key,
    required this.outletId,
    required this.apiClient,
  });

  @override
  State<HotelInhouseScreen> createState() => _HotelInhouseScreenState();
}

class _HotelInhouseScreenState extends State<HotelInhouseScreen> {
  late final HotelActiveStayService _stayService;

  List<HotelActiveStay> _stays = [];

  bool _loading = true;
  String? _errorMessage;

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _stayService = HotelActiveStayService(apiClient: widget.apiClient);

    _loadStays();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _checkoutAmountRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 15,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Future<void> _showOutstandingBalanceDialog(
    HotelActiveStay stay,
    double totalAmount,
    double paidAmount,
    double balanceAmount,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 10),
              Text('Outstanding Balance'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stay.guestName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _checkoutAmountRow('Total', totalAmount),
              _checkoutAmountRow('Paid', paidAmount),
              const Divider(),
              _checkoutAmountRow('Balance', balanceAmount, bold: true),
              const SizedBox(height: 12),
              const Text(
                'Please settle the outstanding '
                'folio balance before checking out.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CLOSE'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openFolio(stay);
              },
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('OPEN FOLIO'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCheckoutSuccessDialog(
    HotelActiveStay stay,
    Map<String, dynamic> response,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Check-out Complete'),
            ],
          ),
          content: Text(
            '${stay.guestName} has been checked out '
            'from room ${stay.roomNo ?? '-'} successfully.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkOut(HotelActiveStay stay) async {
    try {
      // ---------------------------------------------------------
      // First get the latest folio
      // ---------------------------------------------------------
      final folioResponse = await widget.apiClient.get(
        '/hotel/stays/${stay.stayId}/folio',
      );

      if (!mounted) return;

      if (folioResponse['success'] != true) {
        _showMessage(folioResponse['message'] ?? 'Unable to load guest folio.');
        return;
      }

      final folio = Map<String, dynamic>.from(folioResponse['folio']);

      final totalAmount = _toDouble(folio['totalAmount']);

      final paidAmount = _toDouble(folio['paidAmount']);

      final balanceAmount = _toDouble(folio['balanceAmount']);

      // ---------------------------------------------------------
      // Balance must be settled before checkout
      // ---------------------------------------------------------
      if (balanceAmount > 0.01) {
        await _showOutstandingBalanceDialog(
          stay,
          totalAmount,
          paidAmount,
          balanceAmount,
        );

        return;
      }

      // ---------------------------------------------------------
      // Confirm checkout
      // ---------------------------------------------------------
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Check-out'),
            content: Text(
              'Check out ${stay.guestName} '
              'from room ${stay.roomNo ?? '-'}?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('CHECK OUT'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      // ---------------------------------------------------------
      // Call checkout API
      // ---------------------------------------------------------
      final response = await widget.apiClient.post(
        '/hotel/stays/${stay.stayId}/check-out',
        {},
      );

      if (!mounted) return;

      if (response['success'] != true) {
        _showMessage(response['message'] ?? 'Unable to complete check-out.');
        return;
      }

      await _showCheckoutSuccessDialog(stay, response);

      if (!mounted) return;

      await _loadStays();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Check-out failed: $e');
    }
  }

  void _openFolio(HotelActiveStay stay) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelFolioScreen(
          stayId: stay.stayId,
          baseUrl: widget.apiClient.baseUrl,
          token: widget.apiClient.token ?? '',
        ),
      ),
    );
  }

  Future<void> _loadStays() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final stays = await _stayService.getActiveStays(
        outletId: widget.outletId,
      );

      if (!mounted) return;

      setState(() {
        _stays = stays;
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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    if (value.length >= 10) {
      final date = value.substring(0, 10);
      final parts = date.split('-');

      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    return value;
  }

  List<HotelActiveStay> get _filteredStays {
    final search = _searchText.trim().toLowerCase();

    if (search.isEmpty) {
      return _stays;
    }

    return _stays.where((stay) {
      return stay.stayNo.toLowerCase().contains(search) ||
          stay.guestName.toLowerCase().contains(search) ||
          (stay.guestCode ?? '').toLowerCase().contains(search) ||
          (stay.guestPhone ?? '').toLowerCase().contains(search) ||
          (stay.roomNo ?? '').toLowerCase().contains(search);
    }).toList();
  }

  void _showStayDetails(HotelActiveStay stay) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Stay ${stay.stayNo}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detail('Guest', stay.guestName),
                  _detail('Guest Code', stay.guestCode ?? '-'),
                  _detail('Phone', stay.guestPhone ?? '-'),
                  const Divider(),
                  _detail('Room', stay.displayRoom),
                  _detail('Room Type', stay.roomTypeName ?? '-'),
                  _detail('Check-in', _formatDate(stay.checkIn)),
                  _detail(
                    'Expected Check-out',
                    _formatDate(stay.expectedCheckOut),
                  ),
                  _detail('Adults', stay.adults.toString()),
                  _detail('Children', stay.children.toString()),
                  _detail('Room Rate', '₹${stay.roomRate.toStringAsFixed(2)}'),
                  _detail('Status', stay.status),
                ],
              ),
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
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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

  Widget _buildStayCard(HotelActiveStay stay) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          _showStayDetails(stay);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hotel),
                    const SizedBox(height: 2),
                    Text(
                      stay.roomNo ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stay.guestName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stay.stayNo}'
                      ' • ${stay.roomTypeName ?? '-'}',
                    ),
                    const SizedBox(height: 4),
                    Text('${stay.guestPhone ?? ''}'),
                    const SizedBox(height: 6),
                    Text(
                      'Check-in: '
                      '${_formatDate(stay.checkIn)}'
                      '   '
                      'Check-out: '
                      '${_formatDate(stay.expectedCheckOut)}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(label: Text(stay.status)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${stay.roomRate.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _openFolio(stay);
                        },
                        icon: const Icon(
                          Icons.account_balance_wallet,
                          size: 18,
                        ),
                        label: const Text('FOLIO'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _checkOut(stay);
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('CHECK OUT'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stays = _filteredStays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-House Guests'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadStays,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
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
                      onPressed: _loadStays,
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchText = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Search guest, phone, room or stay',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${stays.length} in-house guest'
                          '${stays.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: stays.isEmpty
                            ? const Center(
                                child: Text('No in-house guests found.'),
                              )
                            : ListView.builder(
                                itemCount: stays.length,
                                itemBuilder: (context, index) {
                                  return _buildStayCard(stays[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
