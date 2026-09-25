import 'package:flutter/material.dart';

import '../../models/hotel/hotel_folio.dart';
import '../../services/hotel/hotel_folio_service.dart';
import '../../services/hotel/hotel_folio_receipt_pdf_service.dart';

class HotelFolioReceiptScreen extends StatefulWidget {
  final int stayId;
  final String baseUrl;
  final String token;

  const HotelFolioReceiptScreen({
    super.key,
    required this.stayId,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<HotelFolioReceiptScreen> createState() =>
      _HotelFolioReceiptScreenState();
}

class _HotelFolioReceiptScreenState extends State<HotelFolioReceiptScreen> {
  late final HotelFolioService _service;

  HotelFolio? _folio;

  bool _loading = true;
  bool _sharing = false;
  bool _printing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _service = HotelFolioService(baseUrl: widget.baseUrl, token: widget.token);

    _loadFolio();
  }

  // ------------------------------------------------------------
  // LOAD FOLIO
  // ------------------------------------------------------------

  Future<void> _loadFolio() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final folio = await _service.getStayFolio(stayId: widget.stayId);

      if (!mounted) {
        return;
      }

      setState(() {
        _folio = folio;
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

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _shareReceipt() async {
    if (_folio == null || _sharing) {
      return;
    }

    setState(() {
      _sharing = true;
    });

    try {
      await HotelFolioReceiptPdfService.shareFolioReceipt(folio: _folio!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folio receipt PDF ready to share')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share folio receipt: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  Future<void> _printReceipt() async {
    if (_folio == null || _printing) {
      return;
    }

    setState(() {
      _printing = true;
    });

    try {
      await HotelFolioReceiptPdfService.printFolioReceipt(folio: _folio!);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print folio receipt: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // FORMAT DATE
  // ------------------------------------------------------------

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      if (value.length >= 10) {
        return value.substring(0, 10);
      }

      return value;
    }

    final local = parsed.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    return '$day-$month-${local.year}';
  }

  // ------------------------------------------------------------
  // MONEY
  // ------------------------------------------------------------

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  Widget _buildMobilePayments(List<HotelFolioPayment> payments) {
    return Column(
      children: payments.map((payment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        payment.paymentMethod,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    Text(
                      _money(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  'Date: '
                  '${_formatDateTime(payment.createdAt)}',
                ),

                if (payment.referenceNo != null &&
                    payment.referenceNo!.trim().isNotEmpty)
                  Text(
                    'Reference: '
                    '${payment.referenceNo}',
                  ),

                if (payment.remarks != null &&
                    payment.remarks!.trim().isNotEmpty)
                  Text(
                    'Remarks: '
                    '${payment.remarks}',
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesktopPayments(List<HotelFolioPayment> payments) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Payment Method')),
          DataColumn(label: Text('Reference')),
          DataColumn(numeric: true, label: Text('Amount')),
        ],
        rows: payments.map((payment) {
          return DataRow(
            cells: [
              DataCell(Text(_formatDateTime(payment.createdAt))),
              DataCell(Text(payment.paymentMethod)),
              DataCell(Text(payment.referenceNo ?? '-')),
              DataCell(
                Text(
                  _money(payment.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayments(bool isDesktop) {
    final payments = _folio!.payments
        .where((payment) => payment.status == 'SUCCESS')
        .toList();

    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Divider(),

            if (isDesktop)
              _buildDesktopPayments(payments)
            else
              _buildMobilePayments(payments),
          ],
        ),
      ),
    );
  }
  // ------------------------------------------------------------
  // STATUS
  // ------------------------------------------------------------

  Widget _buildStatusChip() {
    final status = _folio?.status ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        status,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ------------------------------------------------------------
  // GUEST / STAY HEADER
  // ------------------------------------------------------------

  Widget _buildGuestHeader(bool isDesktop) {
    final folio = _folio!;

    final guestName = folio.guest.displayName.isEmpty
        ? 'Guest'
        : folio.guest.displayName;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // RECEIPT TITLE
            // --------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'GUEST FOLIO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hotel Stay Receipt',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                _buildStatusChip(),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 12),

            Wrap(
              spacing: 40,
              runSpacing: 18,
              children: [
                _buildInfoItem('Guest', guestName),

                _buildInfoItem('Guest Code', folio.guest.guestCode ?? '-'),

                _buildInfoItem('Phone', folio.guest.phone ?? '-'),

                _buildInfoItem('Folio No', folio.folioNo),

                _buildInfoItem('Stay No', folio.stayNo),

                _buildInfoItem('Room', folio.room.roomNo ?? '-'),

                _buildInfoItem('Room Name', folio.room.roomName ?? '-'),

                _buildInfoItem('Check-In', _formatDate(folio.checkIn)),

                _buildInfoItem(
                  'Expected Check-Out',
                  _formatDate(folio.expectedCheckOut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FOLIO ENTRIES
  // ------------------------------------------------------------

  Widget _buildEntries(bool isDesktop) {
    final folio = _folio!;

    if (folio.entries.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No folio entries found')),
        ),
      );
    }

    if (isDesktop) {
      return _buildDesktopEntries();
    }

    return _buildMobileEntries();
  }

  Widget _buildDesktopEntries() {
    final folio = _folio!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Folio Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Type')),
                DataColumn(numeric: true, label: Text('Qty')),
                DataColumn(numeric: true, label: Text('Rate')),
                DataColumn(numeric: true, label: Text('Amount')),
                DataColumn(numeric: true, label: Text('Tax')),
                DataColumn(numeric: true, label: Text('Total')),
              ],
              rows: folio.entries.map((entry) {
                final taxAmount = entry.taxes.fold<double>(
                  0,
                  (sum, tax) => sum + tax.taxAmount,
                );

                final total = entry.amount + taxAmount;

                return DataRow(
                  cells: [
                    DataCell(Text(_formatDate(entry.entryDate))),
                    DataCell(Text(entry.description)),
                    DataCell(Text(entry.entryType)),
                    DataCell(Text(entry.quantity.toStringAsFixed(2))),
                    DataCell(Text(_money(entry.rate))),
                    DataCell(Text(_money(entry.amount))),
                    DataCell(Text(_money(taxAmount))),
                    DataCell(
                      Text(
                        _money(total),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEntries() {
    final folio = _folio!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Folio Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const Divider(),

            ...folio.entries.map(_buildMobileEntry),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileEntry(HotelFolioEntry entry) {
    final taxAmount = entry.taxes.fold<double>(
      0,
      (sum, tax) => sum + tax.taxAmount,
    );

    final total = entry.amount + taxAmount;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        entry.description,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_formatDate(entry.entryDate)}  •  '
        '${entry.entryType}',
      ),
      trailing: Text(
        _money(total),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        _buildAmountRow('Quantity', entry.quantity.toStringAsFixed(2)),

        _buildAmountRow('Rate', _money(entry.rate)),

        _buildAmountRow('Charge', _money(entry.amount)),

        if (entry.taxes.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Taxes', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),

          ...entry.taxes.map(
            (tax) => _buildAmountRow(
              '${tax.taxName} '
              '(${tax.rate.toStringAsFixed(2)}%)',
              _money(tax.taxAmount),
            ),
          ),
        ],

        const Divider(),

        _buildAmountRow('Entry Total', _money(total), bold: true),
      ],
    );
  }

  Widget _buildAmountRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildSummary() {
    final folio = _folio!;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildSummaryRow('Charges', folio.entryAmount),

            _buildSummaryRow('Tax', folio.taxAmount),

            const Divider(),

            _buildSummaryRow(
              'Grand Total',
              folio.totalAmount,
              bold: true,
              fontSize: 18,
            ),

            const SizedBox(height: 8),

            _buildSummaryRow('Paid', folio.paidAmount),

            _buildSummaryRow('Balance', folio.balanceAmount, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool bold = false,
    double fontSize = 15,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
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
                'Unable to load folio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFolio,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_folio == null) {
      return const Center(child: Text('Folio not found'));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return RefreshIndicator(
      onRefresh: _loadFolio,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildGuestHeader(isDesktop),

          _buildEntries(isDesktop),

          _buildPayments(isDesktop),

          const SizedBox(height: 4),

          _buildSummary(),
        ],
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
        title: const Text('Guest Folio'),
        actions: [
          IconButton(
            tooltip: 'Print',
            onPressed: (_loading || _printing || _folio == null)
                ? null
                : _printReceipt,
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: (_loading || _sharing || _printing || _folio == null)
                ? null
                : _shareReceipt,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadFolio,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
