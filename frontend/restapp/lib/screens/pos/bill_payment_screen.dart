import 'package:flutter/material.dart';

import '../../models/pos/bill_payment.dart';
import '../../services/pos/pos_order_service.dart';

class BillPaymentScreen extends StatefulWidget {
  final int billId;
  final double grandTotal;
  final double paidAmount;
  final String? billNo;
  final String? tableName;
  final String? logicalCode;

  final String baseUrl;
  final String token;

  const BillPaymentScreen({
    super.key,
    required this.billId,
    required this.grandTotal,
    required this.paidAmount,
    this.billNo,
    this.tableName,
    this.logicalCode,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  late final PosOrderService _service;

  late double _grandTotal;
  late double _paidAmount;
  late double _balanceAmount;

  String _paymentMode = 'CASH';

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _referenceController = TextEditingController();

  final TextEditingController _remarksController = TextEditingController();

  bool _processing = false;

  final List<BillPayment> _payments = [];

  @override
  void initState() {
    super.initState();

    _service = PosOrderService(baseUrl: widget.baseUrl, token: widget.token);

    _grandTotal = widget.grandTotal;
    _paidAmount = widget.paidAmount;

    _calculateBalance();

    _amountController.text = _balanceAmount.toStringAsFixed(2);
  }

  void _calculateBalance() {
    _balanceAmount = (_grandTotal - _paidAmount).clamp(0, double.infinity);

    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final bill = await _service.getBill(widget.billId);

      if (!mounted) return;

      setState(() {
        _grandTotal = bill.grandTotal;
        _paidAmount = bill.paidAmount;
        _balanceAmount = bill.balanceAmount;

        _payments
          ..clear()
          ..addAll(bill.payments);

        _amountController.text = _balanceAmount.toStringAsFixed(2);
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to load bill: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    if (_processing) return;

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount');
      return;
    }

    if (amount > _balanceAmount + 0.01) {
      _showMessage(
        'Payment cannot exceed balance '
        '₹${_balanceAmount.toStringAsFixed(2)}',
      );
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _service.addBillPayment(
        billId: widget.billId,
        paymentMode: _paymentMode,
        amount: amount,
        referenceNo: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      );

      // ------------------------------------------------------
      // IMPORTANT:
      // Always reload bill from server after payment
      // ------------------------------------------------------
      final bill = await _service.getBill(widget.billId);

      if (!mounted) return;

      setState(() {
        _grandTotal = bill.grandTotal;
        _paidAmount = bill.paidAmount;
        _balanceAmount = bill.balanceAmount;

        _payments
          ..clear()
          ..addAll(bill.payments);

        _amountController.text = _balanceAmount.toStringAsFixed(2);

        _referenceController.clear();
        _remarksController.clear();
      });

      if (bill.billStatus == 'PAID') {
        _showMessage('Payment completed. Bill is PAID.');
      } else {
        _showMessage(
          'Payment added successfully. '
          'Balance ₹${bill.balanceAmount.toStringAsFixed(2)}',
        );
      }
    } catch (e) {
      _showMessage('Unable to process payment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setFullBalance() {
    setState(() {
      _amountController.text = _balanceAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _balanceAmount <= 0.01;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment / Settlement')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------------------------------------------
                // BILL INFORMATION
                // ------------------------------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow('Bill No', widget.billNo ?? '-'),
                        _infoRow(
                          'Table',
                          widget.logicalCode ?? widget.tableName ?? '-',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ------------------------------------------
                // AMOUNTS
                // ------------------------------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _amountRow('Grand Total', _grandTotal),
                        _amountRow('Paid', _paidAmount),
                        const Divider(),
                        _amountRow('Balance', _balanceAmount, bold: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (!isPaid) ...[
                  const Text(
                    'Payment Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                          'CASH',
                          'UPI',
                          'CARD',
                          'BANK',
                          'WALLET',
                          'CREDIT',
                          'OTHER',
                        ].map((mode) {
                          return ChoiceChip(
                            label: Text(mode),
                            selected: _paymentMode == mode,
                            onSelected: (_) {
                              setState(() {
                                _paymentMode = mode;
                              });
                            },
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Payment Amount',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.done_all),
                        tooltip: 'Full Balance',
                        onPressed: _setFullBalance,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference No',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _addPayment,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment),
                      label: Text(
                        _processing ? 'PROCESSING...' : 'ADD PAYMENT',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ------------------------------------------
                // CURRENT SESSION PAYMENTS
                // ------------------------------------------
                if (_payments.isNotEmpty) ...[
                  const Text(
                    'Payments',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),

                  const SizedBox(height: 8),

                  ..._payments.map(
                    (payment) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle),
                        title: Text(payment.paymentMode),
                        trailing: Text(
                          '₹${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: payment.referenceNo != null
                            ? Text(payment.referenceNo!)
                            : null,
                      ),
                    ),
                  ),
                ],

                if (isPaid) ...[
                  const SizedBox(height: 20),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, size: 60),
                          const SizedBox(height: 10),
                          const Text(
                            'PAYMENT COMPLETED',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bill ₹${_grandTotal.toStringAsFixed(2)} fully paid',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 19 : 16,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}
