import 'package:flutter/material.dart';
import 'package:restapp/screens/hotel/hotel_folio_receipt_screen.dart';
import 'package:restapp/services/api_client.dart';
import '../../services/pos/hotel_stay_service.dart';
import '../../models/hotel/hotel_folio.dart';
import '../../services/hotel/hotel_folio_service.dart';
import '../../widgets/hotel/add_folio_charge_dialog.dart';
import '../../widgets/hotel/folio_payment_dialog.dart';
import '../../models/pos/pos_tax.dart';
import '../../models/pos/pos_tax_service.dart';

class HotelFolioScreen extends StatefulWidget {
  final int stayId;
  final String baseUrl;
  final String token;

  const HotelFolioScreen({
    super.key,
    required this.stayId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<HotelFolioScreen> createState() => _HotelFolioScreenState();
}

class _HotelFolioScreenState extends State<HotelFolioScreen> {
  late final HotelFolioService _service;
  late final PosTaxService _taxService;
  HotelFolio? _folio;
  List<PosTaxGroup> _taxGroups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _service = HotelFolioService(baseUrl: widget.baseUrl, token: widget.token);
    _taxService = PosTaxService(baseUrl: widget.baseUrl, token: widget.token);
    _loadTaxGroups();
    _loadFolio();
  }

  Future<void> _loadTaxGroups() async {
    try {
      final groups = await _taxService.getTaxGroups();

      if (!mounted) {
        return;
      }

      setState(() {
        _taxGroups = groups;
      });
    } catch (e) {
      debugPrint('Unable to load tax groups: $e');
    }
  }

  _openFolioReceipt() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelFolioReceiptScreen(
          stayId: widget.stayId,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _checkout() async {
    if (_folio == null) {
      return;
    }

    // ---------------------------------------------------------
    // 1. Validate stay status
    // ---------------------------------------------------------

    if (_folio!.stayStatus != 'CHECKED_IN') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guest cannot be checked out. '
            'Current stay status: ${_folio!.stayStatus ?? 'UNKNOWN'}',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // 2. Validate folio status
    // ---------------------------------------------------------

    if (_folio!.status != 'OPEN') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Folio cannot be checked out. '
            'Current folio status: ${_folio!.status}',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // 3. Validate outstanding balance
    // ---------------------------------------------------------

    if (_folio!.balanceAmount > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Outstanding balance is '
            '₹${_folio!.balanceAmount.toStringAsFixed(2)}. '
            'Please collect payment before checkout.',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // 4. Confirmation dialog
    // ---------------------------------------------------------

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Check-Out'),

          content: SizedBox(
            width: 420,

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // Guest
                Text(
                  'Guest: ${_folio!.guest.displayName.isEmpty ? 'Guest' : _folio!.guest.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 6),

                // Room
                Text('Room: ${_folio!.room.roomNo ?? '-'}'),

                const SizedBox(height: 6),

                // Stay
                Text('Stay No: ${_folio!.stayNo}'),

                const SizedBox(height: 16),

                const Divider(),

                const SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total'),
                    Text('₹${_folio!.totalAmount.toStringAsFixed(2)}'),
                  ],
                ),

                const SizedBox(height: 6),

                // Paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Paid'),
                    Text('₹${_folio!.paidAmount.toStringAsFixed(2)}'),
                  ],
                ),

                const SizedBox(height: 6),

                // Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${_folio!.balanceAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade100,
                  ),

                  child: const Text(
                    'After checkout, the room will be moved '
                    'to CLEANING.',
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.logout),
              label: const Text('CHECK-OUT'),
            ),
          ],
        );
      },
    );

    // User cancelled
    if (confirmed != true) {
      return;
    }

    // ---------------------------------------------------------
    // 5. Call checkout API
    // ---------------------------------------------------------

    try {
      setState(() {
        _loading = true;
      });

      final service = HotelStayService(
        baseUrl: widget.baseUrl,
        token: widget.token,
      );

      final result = await service.checkOut(stayId: _folio!.stayId);

      if (!mounted) {
        return;
      }

      // -------------------------------------------------------
      // 6. Checkout successful
      // -------------------------------------------------------

      setState(() {
        _loading = false;
      });

      await showDialog(
        context: context,

        builder: (context) {
          return AlertDialog(
            title: const Text('Check-Out Successful'),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Guest: ${_folio!.guest.displayName.isEmpty ? 'Guest' : _folio!.guest.displayName}',
                ),

                const SizedBox(height: 6),

                Text('Room: ${_folio!.room.roomNo ?? '-'}'),

                const SizedBox(height: 12),

                const Text('Guest has been checked out successfully.'),

                const SizedBox(height: 8),

                const Text('The room has been moved to CLEANING.'),
              ],
            ),

            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      // -------------------------------------------------------
      // 7. Return to previous screen
      // -------------------------------------------------------
      //Navigator.pop(context);

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  Future<void> _makePayment() async {
    if (_folio == null) {
      return;
    }

    final balance = _folio!.balanceAmount;

    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no outstanding balance.')),
      );

      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return FolioPaymentDialog(balance: balance);
      },
    );

    if (result == null) {
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await _service.addFolioPayment(
        folioId: _folio!.folioId,
        stayId: _folio!.stayId,
        paymentMethod: result['paymentMethod'],
        amount: result['amount'],
        referenceNo: result['referenceNo'],
        remarks: result['remarks'],
      );

      await _loadFolio();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _addCharge() async {
    if (_folio == null) {
      return;
    }

    // -------------------------------------------------
    // Open charge dialog
    // -------------------------------------------------

    final result = await showDialog<AddFolioChargeResult>(
      context: context,

      builder: (_) => AddFolioChargeDialog(taxGroups: _taxGroups),
    );

    if (!mounted || result == null) {
      return;
    }

    // -------------------------------------------------
    // Show progress
    // -------------------------------------------------

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      await _service.addFolioCharge(
        stayId: _folio!.stayId,
        entryType: result.entryType,
        description: result.description,
        quantity: result.quantity,
        rate: result.rate,
        taxGroupId: result.taxGroupId,
        remarks: result.remarks,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      await _loadFolio();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folio charge added successfully')),
      );
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

  Future<void> _loadFolio() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folio = await _service.getStayFolio(stayId: widget.stayId);

      if (!mounted) return;

      setState(() {
        _folio = folio;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Folio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFolio,
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
              const Icon(Icons.error_outline, size: 48),

              const SizedBox(height: 12),

              Text(_error!, textAlign: TextAlign.center),

              const SizedBox(height: 16),

              ElevatedButton(onPressed: _loadFolio, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_folio == null) {
      return const Center(child: Text('Folio not found'));
    }

    return RefreshIndicator(
      onRefresh: _loadFolio,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildGuestCard(),

          const SizedBox(height: 12),

          _buildSummaryCard(),

          const SizedBox(height: 12),

          _buildEntriesCard(),
        ],
      ),
    );
  }

  Widget _buildGuestCard() {
    final folio = _folio!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hotel),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    folio.folioNo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _statusChip(folio.status),
              ],
            ),

            const Divider(),

            Text(
              folio.guest.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            if (folio.guest.phone != null) Text(folio.guest.phone!),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.meeting_room, size: 18),

                const SizedBox(width: 6),

                Text('Room ${folio.room.roomNo ?? '-'}'),

                const SizedBox(width: 20),

                Text(folio.stayNo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final folio = _folio!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _amountRow('Charges', folio.entryAmount),

            _amountRow('Tax', folio.taxAmount),

            const Divider(),

            _amountRow('Total', folio.totalAmount, bold: true),

            _amountRow('Paid', folio.paidAmount),

            const Divider(),

            _amountRow('Balance', folio.balanceAmount, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesCard() {
    final entries = _folio!.entries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      'Folio Entries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: _folio!.status == 'OPEN' ? _addCharge : null,

                  icon: const Icon(Icons.add, size: 18),

                  label: const Text('ADD CHARGE'),
                ),
                ElevatedButton.icon(
                  onPressed: (_folio != null && _folio!.balanceAmount > 0)
                      ? _makePayment
                      : null,
                  icon: const Icon(Icons.payment),
                  label: const Text('PAYMENT'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (_folio != null &&
                          _folio!.status == 'OPEN' &&
                          _folio!.stayStatus == 'CHECKED_IN' &&
                          _folio!.balanceAmount <= 0.01)
                      ? _checkout
                      : null,
                  icon: const Icon(Icons.logout),
                  label: const Text('CHECK-OUT'),
                ),
                ElevatedButton.icon(
                  onPressed: _openFolioReceipt,
                  icon: const Icon(Icons.receipt),
                  label: const Text('Folio Receipt'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No charges posted')),
              )
            else
              ...entries.map(_buildEntry),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(HotelFolioEntry entry) {
    final taxTotal = entry.taxes.fold<double>(
      0,
      (sum, tax) => sum + tax.taxAmount,
    );

    final entryTotal = entry.amount + taxTotal;

    // ---------------------------------------------------------
    // No tax
    // ---------------------------------------------------------

    if (entry.taxes.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),

        leading: CircleAvatar(child: Icon(_entryIcon(entry.entryType))),

        title: Text(entry.description),

        subtitle: Text(entry.entryType),

        trailing: Text(
          '₹${entryTotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    // ---------------------------------------------------------
    // Tax applicable
    // ---------------------------------------------------------

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),

      leading: CircleAvatar(child: Icon(_entryIcon(entry.entryType))),

      title: Text(entry.description),

      subtitle: Text(entry.entryType),

      trailing: Text(
        '₹${entryTotal.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              _entryAmountRow('Charge', entry.amount),

              const Divider(),

              ...entry.taxes.map((tax) {
                return _entryAmountRow(
                  '${tax.taxName} (${tax.rate.toStringAsFixed(2)}%)',
                  tax.taxAmount,
                );
              }),

              const Divider(),

              _entryAmountRow('Entry Total', entryTotal, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryAmountRow(String title, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  IconData _entryIcon(String type) {
    switch (type) {
      case 'RESTAURANT':
        return Icons.restaurant;

      case 'ROOM_CHARGE':
        return Icons.hotel;

      case 'LAUNDRY':
        return Icons.local_laundry_service;

      case 'MINIBAR':
        return Icons.local_bar;

      case 'SERVICE':
        return Icons.room_service;

      default:
        return Icons.receipt_long;
    }
  }

  Widget _amountRow(String title, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Chip(label: Text(status));
  }
}
