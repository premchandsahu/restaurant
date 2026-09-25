import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/hotel/hotel_folio.dart';

class HotelFolioReceiptPdfService {
  static Future<Uint8List> generateFolioReceiptPdf({
    required HotelFolio folio,
    String hotelName = 'HOTEL',
    String? hotelAddress,
    String? hotelPhone,
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
              hotelName: hotelName,
              hotelAddress: hotelAddress,
              hotelPhone: hotelPhone,
              gstin: gstin,
            ),
            pw.SizedBox(height: 16),
            _buildStayInformation(folio),
            pw.SizedBox(height: 16),
            _buildEntriesTable(folio),
            pw.SizedBox(height: 16),
            if (folio.payments.isNotEmpty) ...[
              _buildPaymentTable(folio),
              pw.SizedBox(height: 16),
            ],
            _buildSummary(folio),
            pw.SizedBox(height: 22),
            pw.Center(
              child: pw.Text(
                folio.balanceAmount <= 0
                    ? 'PAID IN FULL'
                    : 'BALANCE DUE: INR ${_money(folio.balanceAmount)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Center(
              child: pw.Text(
                'Thank you for staying with us!',
                style: pw.TextStyle(
                  fontSize: 10,
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

  static pw.Widget _buildHeader({
    required String hotelName,
    String? hotelAddress,
    String? hotelPhone,
    String? gstin,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          hotelName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        if (hotelAddress != null && hotelAddress.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              hotelAddress,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        if (hotelPhone != null && hotelPhone.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Phone: $hotelPhone',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        if (gstin != null && gstin.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'GSTIN: $gstin',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        pw.SizedBox(height: 10),
        pw.Text(
          'GUEST FOLIO RECEIPT',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildStayInformation(HotelFolio folio) {
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
            _infoCell('Guest', _guestName(folio)),
            _infoCell('Guest Code', folio.guest.guestCode ?? '-'),
            _infoCell('Folio No', folio.folioNo),
            _infoCell('Stay No', folio.stayNo),
          ],
        ),
        pw.TableRow(
          children: [
            _infoCell('Phone', folio.guest.phone ?? '-'),
            _infoCell('Room', folio.room.roomNo ?? '-'),
            _infoCell('Room Name', folio.room.roomName ?? '-'),
            _infoCell('Status', folio.status),
          ],
        ),
        pw.TableRow(
          children: [
            _infoCell('Check-In', _formatDate(folio.checkIn)),
            _infoCell(
              'Expected Check-Out',
              _formatDate(folio.expectedCheckOut),
            ),
            _infoCell('Stay Status', folio.stayStatus ?? '-'),
            _infoCell('Receipt Type', 'GUEST FOLIO'),
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
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEntriesTable(HotelFolio folio) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FOLIO CHARGES',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 7),
        if (folio.entries.isEmpty)
          pw.Text(
            'No folio entries found',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: [
              '#',
              'DATE',
              'DESCRIPTION',
              'TYPE',
              'QTY',
              'RATE',
              'CHARGE',
              'TAX',
              'TOTAL',
            ],
            data: List.generate(folio.entries.length, (index) {
              final entry = folio.entries[index];
              final taxAmount = entry.taxes.fold<double>(
                0,
                (sum, tax) => sum + tax.taxAmount,
              );
              final total = entry.amount + taxAmount;

              return [
                '${index + 1}',
                _formatDate(entry.entryDate),
                entry.description,
                entry.entryType,
                entry.quantity.toStringAsFixed(2),
                _money(entry.rate),
                _money(entry.amount),
                _money(taxAmount),
                _money(total),
              ];
            }),
          ),
        if (folio.entries.any((entry) => entry.taxes.isNotEmpty)) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Tax details are included in the charge totals above.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildPaymentTable(HotelFolio folio) {
    final payments = folio.payments
        .where((payment) => payment.status == 'SUCCESS')
        .toList();

    if (payments.isEmpty) {
      return pw.SizedBox();
    }

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
          headers: ['DATE', 'PAYMENT METHOD', 'REFERENCE', 'AMOUNT'],
          data: payments.map((payment) {
            return [
              _formatDateTime(payment.createdAt),
              payment.paymentMethod,
              payment.referenceNo ?? '-',
              _money(payment.amount),
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(HotelFolio folio) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 280,
        child: pw.Column(
          children: [
            _totalRow('Charges', folio.entryAmount),
            _totalRow('Tax', folio.taxAmount),
            pw.Divider(),
            _totalRow(
              'GRAND TOTAL',
              folio.totalAmount,
              bold: true,
              fontSize: 13,
            ),
            pw.SizedBox(height: 5),
            _totalRow('Paid', folio.paidAmount),
            _totalRow('Balance', folio.balanceAmount, bold: true),
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
          pw.Text('INR ${_money(amount)}', style: style),
        ],
      ),
    );
  }

  static String _guestName(HotelFolio folio) {
    return folio.guest.displayName.isEmpty ? 'Guest' : folio.guest.displayName;
  }

  static String _money(double value) {
    return value.toStringAsFixed(2);
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }

    final local = parsed.toLocal();

    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.year}';
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  static Future<void> printFolioReceipt({
    required HotelFolio folio,
    String hotelName = 'HOTEL',
    String? hotelAddress,
    String? hotelPhone,
    String? gstin,
  }) async {
    final bytes = await generateFolioReceiptPdf(
      folio: folio,
      hotelName: hotelName,
      hotelAddress: hotelAddress,
      hotelPhone: hotelPhone,
      gstin: gstin,
    );

    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static Future<void> shareFolioReceipt({
    required HotelFolio folio,
    String hotelName = 'HOTEL',
    String? hotelAddress,
    String? hotelPhone,
    String? gstin,
  }) async {
    final bytes = await generateFolioReceiptPdf(
      folio: folio,
      hotelName: hotelName,
      hotelAddress: hotelAddress,
      hotelPhone: hotelPhone,
      gstin: gstin,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Folio_${folio.folioNo.isEmpty ? folio.folioId : folio.folioNo}.pdf',
    );
  }
}
