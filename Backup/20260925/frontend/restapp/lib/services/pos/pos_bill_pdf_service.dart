import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/pos/bill.dart';

class PosBillPdfService {
  static Future<Uint8List> generateBillPdf({
    required Bill bill,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
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

            _buildItemsTable(bill),

            pw.SizedBox(height: 18),

            _buildTotals(bill),

            if (bill.taxes.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTaxTable(bill),
            ],

            if (bill.payments.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildPaymentTable(bill),
            ],

            if (bill.remarks != null && bill.remarks!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildRemarks(bill.remarks!),
            ],

            pw.SizedBox(height: 25),

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

  static pw.Widget _thermalSeparator() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        '--------------------------------',
        style: const pw.TextStyle(fontSize: 7),
      ),
    );
  }

  static pw.Widget _thermalPayments(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'PAYMENT',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 3),

        ...bill.payments.map(
          (payment) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                payment.paymentMode,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                _money(payment.amount),
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _thermalRemarks(String remarks) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Remarks:',
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(remarks, style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }

  static Future<Uint8List> generateThermalBillPdf({
    required Bill bill,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
    // 80mm thermal paper.
    //
    // 80mm = approximately 226.77 points.
    //
    // Keep margins small because thermal printers have
    // very limited printable width.
    const pageWidth = 226.77;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          pageWidth,
          double.infinity,
          marginAll: 8,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _thermalHeader(
                restaurantName: restaurantName,
                restaurantAddress: restaurantAddress,
                restaurantPhone: restaurantPhone,
                gstin: gstin,
              ),

              _thermalSeparator(),

              _thermalBillInfo(bill),

              _thermalSeparator(),

              _thermalItems(bill),

              _thermalSeparator(),

              _thermalTotals(bill),

              if (bill.taxes.isNotEmpty) ...[
                _thermalSeparator(),
                _thermalTaxes(bill),
              ],

              if (bill.payments.isNotEmpty) ...[
                _thermalSeparator(),
                _thermalPayments(bill),
              ],

              if (bill.remarks != null && bill.remarks!.trim().isNotEmpty) ...[
                _thermalSeparator(),
                _thermalRemarks(bill.remarks!),
              ],

              pw.SizedBox(height: 12),

              pw.Center(
                child: pw.Text(
                  'Thank You!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.Center(
                child: pw.Text(
                  'Visit Again',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _thermalHeader({
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
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),

        if (restaurantAddress != null && restaurantAddress.trim().isNotEmpty)
          pw.Text(
            restaurantAddress,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),

        if (restaurantPhone != null && restaurantPhone.trim().isNotEmpty)
          pw.Text(
            'Ph: $restaurantPhone',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),

        if (gstin != null && gstin.trim().isNotEmpty)
          pw.Text(
            'GSTIN: $gstin',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),

        pw.SizedBox(height: 4),

        pw.Text(
          'BILL',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _thermalBillInfo(Bill bill) {
    return pw.Column(
      children: [
        _thermalInfoRow('Bill No', bill.billNo ?? '-'),
        _thermalInfoRow('Order', bill.orderNo ?? '-'),
        _thermalInfoRow('Table', bill.tableCode ?? '-'),
        _thermalInfoRow('Date', _formatDate(bill.billDate)),
        _thermalInfoRow('Type', bill.orderType ?? '-'),
      ],
    );
  }

  static pw.Widget _thermalInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 55,
          child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _thermalItems(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Text(
                'ITEM',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(
              width: 25,
              child: pw.Text(
                'QTY',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(
              width: 40,
              child: pw.Text(
                'RATE',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(
              width: 45,
              child: pw.Text(
                'AMOUNT',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 3),

        ...bill.items.map((item) {
          final itemName =
              item.variantName != null && item.variantName!.trim().isNotEmpty
              ? '${item.itemName} - ${item.variantName}'
              : item.itemName;

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Text(
                    itemName,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),

                pw.SizedBox(
                  width: 25,
                  child: pw.Text(
                    _money(item.qty),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),

                pw.SizedBox(
                  width: 40,
                  child: pw.Text(
                    _money(item.rate),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),

                pw.SizedBox(
                  width: 45,
                  child: pw.Text(
                    _money(item.netAmount),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _thermalTotals(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _thermalTotalRow('Subtotal', bill.subtotal),

        if (bill.itemDiscount > 0)
          _thermalTotalRow('Item Discount', -bill.itemDiscount),

        if (bill.billDiscount > 0)
          _thermalTotalRow('Bill Discount', -bill.billDiscount),

        _thermalTotalRow('Taxable', bill.taxableAmount),

        _thermalTotalRow('Tax', bill.taxAmount),

        if (bill.roundingAmount != 0)
          _thermalTotalRow('Rounding', bill.roundingAmount),

        pw.SizedBox(height: 3),

        _thermalTotalRow('GRAND TOTAL', bill.grandTotal, bold: true),

        pw.SizedBox(height: 3),

        _thermalTotalRow('Paid', bill.paidAmount),

        _thermalTotalRow('Balance', bill.balanceAmount, bold: true),
      ],
    );
  }

  static Future<void> printThermalBill({
    required Bill bill,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
    final bytes = await generateThermalBillPdf(
      bill: bill,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      gstin: gstin,
    );

    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static pw.Widget _thermalTotalRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 9 : 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _money(amount),
            style: pw.TextStyle(
              fontSize: bold ? 9 : 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalTaxes(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'TAX DETAILS',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 3),

        ...bill.taxes.map(
          (tax) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${tax.taxName} @ ${_money(tax.rate)}%',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                _money(tax.taxAmount),
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeader({
    required Bill bill,
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
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
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
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Phone: $restaurantPhone',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

        if (gstin != null && gstin.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'GSTIN: $gstin',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

        pw.SizedBox(height: 10),

        pw.Text(
          'BILL',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 8),

        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildBillInformation(Bill bill) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            _infoCell('Bill No', bill.billNo ?? '-'),
            _infoCell('Order No', bill.orderNo ?? '-'),
            _infoCell('Table', bill.tableCode ?? '-'),
            _infoCell('Status', bill.billStatus),
          ],
        ),
        pw.TableRow(
          children: [
            _infoCell('Date', _formatDate(bill.billDate)),
            _infoCell('Order Type', bill.orderType ?? '-'),
            _infoCell('Table Name', bill.tableName ?? '-'),
            _infoCell('Bill Type', bill.billType ?? '-'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ITEMS',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 7),

        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(45),
            3: const pw.FixedColumnWidth(60),
            4: const pw.FixedColumnWidth(65),
            5: const pw.FixedColumnWidth(65),
          },
          headers: ['#', 'ITEM', 'QTY', 'RATE', 'DISCOUNT', 'AMOUNT'],
          data: List.generate(bill.items.length, (index) {
            final item = bill.items[index];

            final itemName =
                item.variantName != null && item.variantName!.trim().isNotEmpty
                ? '${item.itemName} - ${item.variantName}'
                : item.itemName;

            return [
              '${index + 1}',
              itemName,
              _money(item.qty),
              _money(item.rate),
              _money(item.discountAmount),
              _money(item.netAmount),
            ];
          }),
        ),
      ],
    );
  }

  static pw.Widget _buildTotals(Bill bill) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 300,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', bill.subtotal),

            if (bill.itemDiscount > 0)
              _totalRow('Item Discount', -bill.itemDiscount),

            if (bill.billDiscount > 0)
              _totalRow('Bill Discount', -bill.billDiscount),

            _totalRow('Taxable Amount', bill.taxableAmount),

            _totalRow('Tax', bill.taxAmount),

            if (bill.roundingAmount != 0)
              _totalRow('Rounding', bill.roundingAmount),

            pw.Divider(),

            _totalRow('GRAND TOTAL', bill.grandTotal, bold: true, fontSize: 14),

            pw.SizedBox(height: 5),

            _totalRow('Paid', bill.paidAmount),

            _totalRow('Balance', bill.balanceAmount, bold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount, {
    bool bold = false,
    double fontSize = 10,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(_money(amount), style: style),
        ],
      ),
    );
  }

  static pw.Widget _buildTaxTable(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TAX DETAILS',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 6),

        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headers: ['Tax', 'Type', 'Rate %', 'Taxable', 'Tax Amount'],
          data: bill.taxes.map((tax) {
            return [
              tax.taxName,
              tax.taxType,
              _money(tax.rate),
              _money(tax.taxableAmount),
              _money(tax.taxAmount),
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentTable(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAYMENT DETAILS',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 6),

        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headers: ['Payment Mode', 'Amount', 'Reference', 'Status'],
          data: bill.payments.map((payment) {
            return [
              payment.paymentMode,
              _money(payment.amount),
              payment.referenceNo ?? '-',
              payment.status,
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildRemarks(String remarks) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Remarks',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(remarks, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static String _money(double value) {
    return value.toStringAsFixed(2);
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  static Future<void> printBill({
    required Bill bill,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
    final bytes = await generateBillPdf(
      bill: bill,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      gstin: gstin,
    );

    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static Future<void> shareBill({
    required Bill bill,
    String restaurantName = 'RESTAURANT',
    String? restaurantAddress,
    String? restaurantPhone,
    String? gstin,
  }) async {
    final bytes = await generateBillPdf(
      bill: bill,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      gstin: gstin,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Bill_${bill.billNo ?? bill.billId}.pdf',
    );
  }
}
