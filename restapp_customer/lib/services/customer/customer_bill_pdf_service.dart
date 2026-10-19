import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomerBillPdfService {
  static Future<Uint8List> generateBillPdf({
    required Map<String, dynamic> billData,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
    final rawBill = billData['bill'];

    if (rawBill is! Map) {
      throw Exception('Invalid bill data');
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

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            _buildHeader(
              bill: bill,
              restaurantName: restaurantName,
              restaurantAddress: restaurantAddress,
              restaurantPhone: restaurantPhone,
              gstin: gstin,
            ),

            pw.SizedBox(height: 18),

            _buildBillInformation(bill),

            pw.SizedBox(height: 18),

            _buildItemsTable(items),

            pw.SizedBox(height: 18),

            _buildTotals(bill: bill, discounts: discounts),

            if (taxes.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTaxTable(taxes),
            ],

            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildPaymentTable(payments),
            ],

            if (_string(bill['remarks']).isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildRemarks(_string(bill['remarks'])),
            ],

            pw.SizedBox(height: 28),

            pw.Center(
              child: pw.Text(
                'Thank you for your visit!',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ----------------------------------------------------------
  // Header
  // ----------------------------------------------------------

  static pw.Widget _buildHeader({
    required Map<String, dynamic> bill,
    required String restaurantName,
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          restaurantName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),

        if (restaurantAddress != null && restaurantAddress.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              restaurantAddress,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

        if (restaurantPhone != null && restaurantPhone.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Phone: $restaurantPhone',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

        if (gstin != null && gstin.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'GSTIN: $gstin',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

        pw.SizedBox(height: 8),

        pw.Text(
          'TAX INVOICE / BILL',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Bill Information
  // ----------------------------------------------------------

  static pw.Widget _buildBillInformation(Map<String, dynamic> bill) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Bill No', _string(bill['bill_no'])),
                _infoRow('Order No', _string(bill['order_no'])),
                _infoRow('Order Type', _string(bill['order_type'])),
              ],
            ),
          ),

          pw.SizedBox(width: 30),

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Table', _tableText(bill)),
                _infoRow('Bill Date', _formatDate(bill['bill_date'])),
                _infoRow('Bill Status', _string(bill['bill_status'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '-' : value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Items
  // ----------------------------------------------------------

  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    final rows = <List<String>>[
      ['Qty', 'Item', 'Rate', 'Amount'],
    ];

    for (final item in items) {
      final qty = _toDouble(item['qty']);
      final rate = _toDouble(item['rate']);

      final amount = _toDouble(item['net_amount'] ?? item['gross_amount']);

      var itemName = _string(item['item_name']);

      final variantName = _string(item['variant_name']);

      if (variantName.isNotEmpty) {
        itemName = '$itemName - $variantName';
      }

      rows.add([
        _quantity(qty),
        itemName.isEmpty ? 'Item' : itemName,
        _money(rate),
        _money(amount),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FixedColumnWidth(40),
        1: pw.FlexColumnWidth(5),
        2: pw.FixedColumnWidth(60),
        3: pw.FixedColumnWidth(70),
      },
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;

        final isHeader = index == 0;

        return pw.TableRow(
          children: row.map((cell) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              child: pw.Text(
                cell,
                textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: isHeader ? 9 : 8.5,
                  fontWeight: isHeader
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------
  // Totals
  // ----------------------------------------------------------

  static pw.Widget _buildTotals({
    required Map<String, dynamic> bill,
    required List<Map<String, dynamic>> discounts,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 280,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', _toDouble(bill['subtotal'])),

            if (_toDouble(bill['item_discount']) > 0)
              _totalRow('Item Discount', -_toDouble(bill['item_discount'])),

            if (_toDouble(bill['bill_discount']) > 0)
              _totalRow('Bill Discount', -_toDouble(bill['bill_discount'])),

            // Detailed discount lines, when provided.
            ...discounts.map(
              (discount) => _totalRow(
                _string(discount['discount_name']).isEmpty
                    ? 'Discount'
                    : _string(discount['discount_name']),
                -_toDouble(discount['discount_amount']),
                small: true,
              ),
            ),

            _totalRow('Taxable Amount', _toDouble(bill['taxable_amount'])),

            _totalRow('Tax', _toDouble(bill['tax_amount'])),

            if (_toDouble(bill['rounding_amount']) != 0)
              _totalRow('Rounding', _toDouble(bill['rounding_amount'])),

            pw.Divider(),

            _totalRow(
              'GRAND TOTAL',
              _toDouble(bill['grand_total']),
              bold: true,
              fontSize: 13,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount, {
    bool bold = false,
    double fontSize = 9,
    bool small = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: small ? 8 : fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            _money(amount),
            style: pw.TextStyle(
              fontSize: small ? 8 : fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Tax
  // ----------------------------------------------------------

  static pw.Widget _buildTaxTable(List<Map<String, dynamic>> taxes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tax Details',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(60),
            2: pw.FixedColumnWidth(90),
          },
          children: [
            pw.TableRow(
              children: [
                _tableCell('Tax', header: true),
                _tableCell('Rate', header: true),
                _tableCell('Tax Amount', header: true),
              ],
            ),

            ...taxes.map(
              (tax) => pw.TableRow(
                children: [
                  _tableCell(
                    _string(tax['tax_name']).isEmpty
                        ? 'Tax'
                        : _string(tax['tax_name']),
                  ),
                  _tableCell('${_toDouble(tax['rate']).toStringAsFixed(2)}%'),
                  _tableCell(_money(tax['tax_amount'])),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Payments
  // ----------------------------------------------------------

  static pw.Widget _buildPaymentTable(List<Map<String, dynamic>> payments) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment Details',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(100),
          },
          children: [
            pw.TableRow(
              children: [
                _tableCell('Payment Mode', header: true),
                _tableCell('Amount', header: true),
              ],
            ),

            ...payments.map((payment) {
              final mode = _string(
                payment['payment_mode'] ?? payment['payment_type'],
              );

              return pw.TableRow(
                children: [
                  _tableCell(mode.isEmpty ? 'Payment' : mode),
                  _tableCell(_money(payment['amount'])),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Remarks
  // ----------------------------------------------------------

  static pw.Widget _buildRemarks(String remarks) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Remarks',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(remarks, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------

  static pw.Widget _tableCell(String text, {bool header = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static String _string(dynamic value) {
    return value?.toString() ?? '';
  }

  static String _money(dynamic value) {
    return '₹${_toDouble(value).toStringAsFixed(2)}';
  }

  static String _quantity(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static String _formatDate(dynamic value) {
    final text = _string(value);

    if (text.isEmpty) return '-';

    if (text.length >= 10) {
      return text.substring(0, 10);
    }

    return text;
  }

  static String _tableText(Map<String, dynamic> bill) {
    final code = _string(bill['table_code']);

    if (code.isNotEmpty) {
      return code;
    }

    final name = _string(bill['table_name']);

    return name;
  }
}
