import 'package:flutter/material.dart';

import '../../models/pos/pos_cart_item.dart';
import '../../models/pos/pos_order.dart';

class PosBillPreviewScreen extends StatelessWidget {
  final PosOrder order;
  final List<PosCartItem> items;
  final String? logicalTableCode;
  final String? logicalTableName;

  const PosBillPreviewScreen({
    super.key,
    required this.order,
    required this.items,
    this.logicalTableCode,
    this.logicalTableName,
  });

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Preview')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPreview(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildBillBody(),
            ),
          ),
          const Divider(height: 1),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 28),
          const SizedBox(width: 10),

          const Text(
            'BILL PREVIEW',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const Spacer(),

          if (order.orderNo != null) _headerValue('Order No', order.orderNo!),

          const SizedBox(width: 30),

          if (logicalTableCode != null)
            _headerValue('Table', logicalTableCode!),
        ],
      ),
    );
  }

  Widget _headerValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildBillBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrderInfo(),

        const SizedBox(height: 16),

        _buildItemsTable(),

        const SizedBox(height: 20),

        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(width: 380, child: _buildTotals()),
        ),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 35,
        runSpacing: 8,
        children: [
          _infoValue('Order Type', order.orderType),
          _infoValue(
            'Table',
            logicalTableCode ?? 'Table ${order.tableId ?? '-'}',
          ),
          if (logicalTableName != null)
            _infoValue('Table Name', logicalTableName!),
          _infoValue('Guests', '${order.guestCount ?? 1}'),
          _infoValue('Status', order.orderStatus),
        ],
      ),
    );
  }

  Widget _infoValue(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildTableHeader(),

          ...List.generate(items.length, (index) {
            return _buildItemRow(index + 1, items[index]);
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      color: Colors.grey.shade200,
      child: const Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 5,
            child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QTY',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'RATE',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'DISCOUNT',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'AMOUNT',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, PosCartItem item) {
    final amount = item.quantity * item.rate;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$index')),

          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                if (item.variant != null)
                  Text(
                    item.variant!.variantName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                if (item.specialInstruction != null &&
                    item.specialInstruction!.trim().isNotEmpty)
                  Text(
                    item.specialInstruction!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(_money(item.quantity), textAlign: TextAlign.right),
          ),

          Expanded(
            flex: 2,
            child: Text(_money(item.rate), textAlign: TextAlign.right),
          ),

          Expanded(
            flex: 2,
            child: Text(
              _money(item.discountAmount),
              textAlign: TextAlign.right,
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              _money(amount - item.discountAmount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        _totalRow('Subtotal', order.subtotal),

        if (order.itemDiscount > 0)
          _totalRow('Item Discount', order.itemDiscount),

        if (order.billDiscount > 0)
          _totalRow('Bill Discount', order.billDiscount),

        _totalRow('Taxable Amount', order.taxableAmount),

        _totalRow('Tax', order.taxAmount),

        if (order.roundingAmount != 0)
          _totalRow('Rounding', order.roundingAmount),

        const Divider(),

        _totalRow('GRAND TOTAL', order.grandTotal, bold: true, fontSize: 20),
      ],
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool bold = false,
    double fontSize = 15,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_money(value), style: style),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context, false);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('EDIT ORDER'),
          ),

          const Spacer(),

          OutlinedButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('CANCEL'),
          ),

          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('CREATE BILL'),
          ),
        ],
      ),
    );
  }
}
