import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import '../../models/pos/bill.dart';
import '../../models/pos/bill_payment.dart';
import '../../services/pos/pos_order_service.dart';
import 'bill_payment_screen.dart';
import '../../services/pos/pos_bill_pdf_service.dart';
import '../../models/pos/active_hotel_stay.dart';
import '../../services/pos/hotel_stay_service.dart';
import '../../widgets/pos/charge_to_room_dialog.dart';
import '../../services/pos/customer_order_service.dart';

class PosBillScreen extends StatefulWidget {
  final int billId;
  final String baseUrl;
  final String token;
  // Customer mode
  final bool customerView;
  final String? customerSessionToken;
  final int? customerOrderId;
  const PosBillScreen({
    super.key,
    required this.billId,
    required this.baseUrl,
    required this.token,
    this.customerView = false,
    this.customerSessionToken,
    this.customerOrderId,
  });

  @override
  State<PosBillScreen> createState() => _PosBillScreenState();
}

class _PosBillScreenState extends State<PosBillScreen> {
  late final PosOrderService _orderService;
  late final CustomerOrderService _customerOrderService;
  late final HotelStayService _hotelStayService;
  Timer? _customerBillTimer;
  Bill? _bill;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _orderService = PosOrderService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _customerOrderService = CustomerOrderService(
      baseUrl: widget.baseUrl,
      token: '',
    );
    _hotelStayService = HotelStayService(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    _loadBill();

    if (widget.customerView) {
      _customerBillTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshCustomerBill(),
      );
    }
  }

  @override
  void dispose() {
    _customerBillTimer?.cancel();

    super.dispose();
  }

  Future<void> _chargeRestaurantBill({
    required int billId,
    required int stayId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/hotel/folio/charge-restaurant-bill'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'billId': billId, 'stayId': stayId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['message'] ?? 'Unable to charge bill to room');
      }

      if (!mounted) return;

      final charge = data['charge'];

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Room Charge Successful'),
            content: Text(
              'Bill ${charge['billNo']} '
              'has been charged to '
              'Room ${charge['roomNo']}.\n\n'
              'Guest: ${charge['guestName']}\n'
              'Folio: ${charge['folioNo']}\n'
              'Amount: ₹${NumberFormat('#,##0.00').format(charge['amount'])}\n'
              'Balance: ₹${NumberFormat('#,##0.00').format(charge['balanceAmount'])}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      // Refresh bill from server.
      await _loadBill();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _chargeToRoom() async {
    if (_bill == null) {
      return;
    }

    try {
      // -------------------------------------------------
      // 1. Load currently checked-in hotel guests
      // -------------------------------------------------

      final stays = await _hotelStayService.getActiveStays(
        outletId: _bill!.outletId ?? 1,
      );

      if (!mounted) return;

      if (stays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No checked-in hotel guests are available.'),
          ),
        );
        return;
      }

      // -------------------------------------------------
      // 2. Select guest / room
      // -------------------------------------------------

      final ActiveHotelStay? selectedStay = await showDialog<ActiveHotelStay>(
        context: context,
        builder: (_) => ChargeToRoomDialog(stays: stays),
      );

      if (!mounted || selectedStay == null) {
        return;
      }

      // -------------------------------------------------
      // 3. Confirm
      // -------------------------------------------------

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Room Charge'),
            content: Text(
              'Charge bill ${_bill!.billNo} '
              'of ₹${_bill!.grandTotal.toStringAsFixed(2)} '
              'to Room ${selectedStay.room.roomNo} '
              'for ${selectedStay.guest.displayName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('CHARGE TO ROOM'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) {
        return;
      }

      // -------------------------------------------------
      // 4. Charge restaurant bill to folio
      // -------------------------------------------------

      await _chargeRestaurantBill(
        billId: _bill!.billId,
        stayId: selectedStay.stayId,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadBill() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Bill bill;

      if (widget.customerView) {
        if (widget.customerSessionToken == null ||
            widget.customerOrderId == null) {
          throw Exception('Customer session information is missing');
        }

        final data = await _customerOrderService.getCustomerBill(
          customerSessionToken: widget.customerSessionToken!,
          orderId: widget.customerOrderId!,
        );

        bill = Bill.fromJson(Map<String, dynamic>.from(data['bill']));
      } else {
        bill = await _orderService.getBill(widget.billId);
      }

      if (!mounted) return;

      setState(() {
        _bill = bill;
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

  Future<void> _refreshCustomerBill() async {
    if (!mounted) return;

    if (!widget.customerView) return;

    // Don't overlap with the initial/manual loading.
    if (_loading) return;

    try {
      if (widget.customerSessionToken == null ||
          widget.customerOrderId == null) {
        return;
      }

      final data = await _customerOrderService.getCustomerBill(
        customerSessionToken: widget.customerSessionToken!,
        orderId: widget.customerOrderId!,
      );

      final bill = Bill.fromJson(Map<String, dynamic>.from(data['bill']));

      if (!mounted) return;

      setState(() {
        _bill = bill;
      });
    } catch (e) {
      // Customer may temporarily lose connectivity.
      // The next cycle will try again.
      debugPrint('Customer bill auto-refresh failed: $e');
    }
  }

  Future<void> _openPayment() async {
    final bill = _bill;

    if (bill == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillPaymentScreen(
          billId: bill.billId,
          grandTotal: bill.grandTotal,
          paidAmount: bill.paidAmount,
          billNo: bill.billNo,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );

    // Payment screen may have changed the bill status/amount.
    // Reload the bill when we return.
    await _loadBill();
  }

  Future<void> _printBill() async {
    final bill = _bill;

    if (bill == null) return;

    try {
      await PosBillPdfService.printThermalBill(
        bill: bill,
        restaurantName: 'YOUR RESTAURANT NAME',
        restaurantAddress: 'Your Address',
        restaurantPhone: 'Your Phone',
        gstin: null,
      );

      /*    await PosBillPdfService.printBill(
        bill: bill,
        restaurantName: 'YOUR RESTAURANT NAME',
        restaurantAddress: 'Your Address',
        restaurantPhone: 'Your Phone',
        gstin: null,
      );*/
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to print bill: $e')));
    }
  }

  Future<void> _shareBill() async {
    final bill = _bill;

    if (bill == null) return;

    try {
      await PosBillPdfService.shareBill(
        bill: bill,
        restaurantName: 'YOUR RESTAURANT NAME',
        restaurantAddress: 'Your Address',
        restaurantPhone: 'Your Phone',
        gstin: null,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to share bill: $e')));
    }
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadBill,
            icon: const Icon(Icons.refresh),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Unable to load bill',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadBill,
                icon: const Icon(Icons.refresh),
                label: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    final bill = _bill;

    if (bill == null) {
      return const Center(child: Text('Bill not found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return _buildDesktopBill(bill);
        }

        return _buildMobileBill(bill);
      },
    );
  }

  Widget _buildDesktopBill(Bill bill) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildBillContent(bill),
        ),
      ),
    );
  }

  Widget _buildMobileBill(Bill bill) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _buildBillContent(bill),
    );
  }

  Widget _buildBillContent(Bill bill) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBillHeader(bill),

            const Divider(height: 32),

            _buildItemsSection(bill),

            const Divider(height: 32),

            _buildTotalsSection(bill),

            const SizedBox(height: 24),

            _buildActionButtons(bill),
          ],
        ),
      ),
    );
  }

  Widget _buildBillHeader(Bill bill) {
    return Column(
      children: [
        const Text(
          'RESTAURANT BILL',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _headerValue('Bill No', bill.billNo ?? '-')),
            Expanded(child: _headerValue('Bill ID', bill.billId.toString())),
            Expanded(
              child: _headerValue('Order ID', bill.orderId?.toString() ?? '-'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildStatus(bill.billStatus),
      ],
    );
  }

  Widget _headerValue(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatus(String status) {
    final isPaid = status.toUpperCase() == 'PAID';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green : null,
        ),
      ),
    );
  }

  Widget _buildItemHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'ITEM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QTY',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'RATE',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'AMOUNT',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(Bill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ITEMS',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),
        _buildItemHeader(),
        ...bill.items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Expanded(
                  flex: 5,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      if (item.variantName != null)
                        Text(
                          item.variantName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: Text(_money(item.qty), textAlign: TextAlign.center),
                ),

                Expanded(
                  flex: 2,
                  child: Text(_money(item.rate), textAlign: TextAlign.right),
                ),

                Expanded(
                  flex: 3,
                  child: Text(
                    _money(item.netAmount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSection(Bill bill) {
    return Column(
      children: [
        _totalRow('Subtotal', bill.subtotal),

        if (bill.itemDiscount > 0)
          _totalRow('Item Discount', bill.itemDiscount),

        if (bill.billDiscount > 0)
          _totalRow('Bill Discount', bill.billDiscount),

        _totalRow('Taxable Amount', bill.taxableAmount),

        _totalRow('Tax', bill.taxAmount),

        if (bill.roundingAmount != 0)
          _totalRow('Rounding', bill.roundingAmount),

        const Divider(),

        _totalRow('Grand Total', bill.grandTotal, bold: true, fontSize: 20),

        const SizedBox(height: 8),

        _totalRow('Paid', bill.paidAmount),

        const SizedBox(height: 8),

        _totalRow('Balance', bill.balanceAmount, bold: true),
      ],
    );
  }

  Widget _totalRow(
    String label,
    double amount, {
    bool bold = false,
    double fontSize = 16,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(_money(amount), style: style),
      ],
    );
  }

  Widget _billInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Bill bill) {
    final isPaid = bill.billStatus.toUpperCase() == 'PAID';

    final isCustomerView = widget.customerView;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 550;

        // --------------------------------------------------
        // Customer view
        //
        // Customer can view/print/share the bill.
        // Payment and Charge To Room are operator actions.
        // --------------------------------------------------

        if (isCustomerView) {
          if (vertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _printBill,
                    icon: const Icon(Icons.print),
                    label: const Text('PRINT BILL'),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _shareBill,
                    icon: const Icon(Icons.share),
                    label: const Text('SHARE'),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printBill,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT BILL'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareBill,
                  icon: const Icon(Icons.share),
                  label: const Text('SHARE'),
                ),
              ),
            ],
          );
        }

        // --------------------------------------------------
        // Existing POS view
        //
        // Keep existing functionality unchanged.
        // --------------------------------------------------

        final buttons = [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _printBill,
              icon: const Icon(Icons.print),
              label: const Text('PRINT BILL'),
            ),
          ),

          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareBill,
              icon: const Icon(Icons.share),
              label: const Text('SHARE'),
            ),
          ),

          Expanded(
            child: ElevatedButton.icon(
              onPressed: isPaid ? null : _openPayment,
              icon: const Icon(Icons.payment),
              label: Text(isPaid ? 'PAID' : 'PAYMENT'),
            ),
          ),

          Expanded(
            child: ElevatedButton.icon(
              onPressed: _chargeToRoom,
              icon: const Icon(Icons.hotel),
              label: const Text('CHARGE TO ROOM'),
            ),
          ),
        ];

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _printBill,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT BILL'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _shareBill,
                  icon: const Icon(Icons.share),
                  label: const Text('SHARE'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isPaid ? null : _openPayment,
                  icon: const Icon(Icons.payment),
                  label: Text(isPaid ? 'PAID' : 'PAYMENT'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _chargeToRoom,
                  icon: const Icon(Icons.hotel),
                  label: const Text('CHARGE TO ROOM'),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            buttons[0],

            const SizedBox(width: 10),

            buttons[1],

            const SizedBox(width: 10),

            buttons[2],

            const SizedBox(width: 10),

            buttons[3],
          ],
        );
      },
    );
  }
}
