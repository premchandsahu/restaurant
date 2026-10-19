import 'dart:async';

import 'package:restapp_customer/services/customer/customer_bill_pdf_service.dart';
import 'package:restapp_customer/services/customer/customer_bill_share_service.dart';
import 'package:flutter/material.dart';

class CustomerBillScreen extends StatefulWidget {
  final Map<String, dynamic> billData;

  const CustomerBillScreen({super.key, required this.billData});

  @override
  State<CustomerBillScreen> createState() => _CustomerBillScreenState();
}

class _CustomerBillScreenState extends State<CustomerBillScreen> {
  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  bool _sharing = false;

  Future<void> _shareBill() async {
    if (_sharing) {
      return;
    }

    final rawBill = widget.billData['bill'];

    if (rawBill is! Map) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid bill data')));
      return;
    }

    final bill = Map<String, dynamic>.from(rawBill);

    final billNo = bill['bill_no']?.toString() ?? '';

    setState(() {
      _sharing = true;
    });

    try {
      final pdfBytes = await CustomerBillPdfService.generateBillPdf(
        billData: widget.billData,
      );

      await CustomerBillShareService.shareBillPdf(
        pdfBytes: pdfBytes,
        billNo: billNo,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to share bill: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  String _money(dynamic value) {
    return '₹${_toDouble(value).toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    final text = _stringValue(value);

    if (text.isEmpty) {
      return '';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final rawBill = widget.billData['bill'];

    if (rawBill is! Map) {
      return const Scaffold(
        body: Center(child: Text('Invalid bill information')),
      );
    }

    final bill = Map<String, dynamic>.from(rawBill);

    final items = (bill['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final taxes = (bill['taxes'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final discounts = (bill['discounts'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final payments = (bill['payments'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final billNo = _stringValue(bill['bill_no']);
    final billStatus = _stringValue(bill['bill_status']).toUpperCase();

    final orderNo = _stringValue(bill['order_no']);
    final orderType = _stringValue(bill['order_type']);

    final tableCode = _stringValue(bill['table_code']);
    final tableName = _stringValue(bill['table_name']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
        actions: [
          IconButton(
            tooltip: 'Share Bill',
            onPressed: _sharing ? null : _shareBill,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeader(
              context,
              billNo: billNo,
              billStatus: billStatus,
              orderNo: orderNo,
              orderType: orderType,
              tableCode: tableCode,
              tableName: tableName,
              billDate: bill['bill_date'],
              billTime: bill['bill_time'],
            ),

            const SizedBox(height: 12),

            _buildItemsSection(items),

            const SizedBox(height: 12),

            _buildTotalsSection(bill: bill, discounts: discounts, taxes: taxes),

            const SizedBox(height: 12),

            _buildPaymentSection(bill: bill, payments: payments),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String billNo,
    required String billStatus,
    required String orderNo,
    required String orderType,
    required String tableCode,
    required String tableName,
    required dynamic billDate,
    required dynamic billTime,
  }) {
    final tableText = tableCode.isNotEmpty
        ? tableCode
        : tableName.isNotEmpty
        ? tableName
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    billNo.isEmpty ? 'Bill' : 'Bill #$billNo',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (billStatus.isNotEmpty) _buildStatusChip(billStatus),
              ],
            ),

            const SizedBox(height: 12),

            if (orderNo.isNotEmpty) _buildInfoRow('Order No', orderNo),

            if (orderType.isNotEmpty) _buildInfoRow('Order Type', orderType),

            if (tableText.isNotEmpty) _buildInfoRow('Table', tableText),

            if (_formatDate(billDate).isNotEmpty)
              _buildInfoRow('Bill Date', _formatDate(billDate)),

            if (_formatDate(billTime).isNotEmpty)
              _buildInfoRow('Bill Time', _formatDate(billTime)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(List<Map<String, dynamic>> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (items.isEmpty)
              const Text('No bill items')
            else ...[
              ...items.map(_buildItem),

              const Divider(height: 24),

              Row(
                children: const [
                  SizedBox(
                    width: 34,
                    child: Text(
                      'Qty',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Amount',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final itemName = _stringValue(item['item_name']).isEmpty
        ? 'Item'
        : _stringValue(item['item_name']);

    final variantName = _stringValue(item['variant_name']);

    final qty = _toDouble(item['qty']);

    final amount = _toDouble(item['net_amount'] ?? item['gross_amount']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(qty % 1 == 0 ? qty.toInt().toString() : qty.toString()),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),

                if (variantName.isNotEmpty)
                  Text(
                    variantName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                if (_toDouble(item['rate']) > 0)
                  Text(
                    'Rate: ${_money(item['rate'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 80,
            child: Text(
              _money(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection({
    required Map<String, dynamic> bill,
    required List<Map<String, dynamic>> discounts,
    required List<Map<String, dynamic>> taxes,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bill Summary',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _buildAmountRow('Subtotal', bill['subtotal']),

            if (_toDouble(bill['item_discount']) > 0)
              _buildAmountRow(
                'Item Discount',
                -_toDouble(bill['item_discount']),
              ),

            if (_toDouble(bill['bill_discount']) > 0)
              _buildAmountRow(
                'Bill Discount',
                -_toDouble(bill['bill_discount']),
              ),

            // Detailed discounts, when present.
            if (discounts.isNotEmpty) ...[
              const SizedBox(height: 4),

              ...discounts.map(
                (discount) => _buildAmountRow(
                  _stringValue(discount['discount_name']).isEmpty
                      ? 'Discount'
                      : _stringValue(discount['discount_name']),
                  -_toDouble(discount['discount_amount']),
                  small: true,
                ),
              ),
            ],

            _buildAmountRow('Taxable Amount', bill['taxable_amount']),

            if (taxes.isNotEmpty) ...[
              const SizedBox(height: 4),

              ...taxes.map((tax) {
                final taxName = _stringValue(tax['tax_name']).isEmpty
                    ? 'Tax'
                    : _stringValue(tax['tax_name']);

                return _buildAmountRow(taxName, tax['tax_amount'], small: true);
              }),
            ],

            _buildAmountRow('Tax', bill['tax_amount']),

            if (_toDouble(bill['rounding_amount']) != 0)
              _buildAmountRow('Rounding', bill['rounding_amount']),

            const Divider(height: 24),

            _buildAmountRow(
              'Grand Total',
              bill['grand_total'],
              bold: true,
              fontSize: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection({
    required Map<String, dynamic> bill,
    required List<Map<String, dynamic>> payments,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _buildAmountRow('Paid', bill['paid_amount']),

            _buildAmountRow(
              'Balance',
              bill['balance_amount'],
              bold: _toDouble(bill['balance_amount']) > 0,
            ),

            if (payments.isNotEmpty) ...[
              const Divider(height: 24),

              const Text(
                'Payment Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              ...payments.map((payment) {
                final mode = _stringValue(
                  payment['payment_mode'] ?? payment['payment_type'],
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(mode.isEmpty ? 'Payment' : mode)),
                      Text(
                        _money(payment['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    dynamic value, {
    bool bold = false,
    double fontSize = 14,
    bool small = false,
  }) {
    final style = TextStyle(
      fontSize: small ? 12 : fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money(value), style: style),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isPaid = status == 'PAID';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isPaid ? Colors.green : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}
