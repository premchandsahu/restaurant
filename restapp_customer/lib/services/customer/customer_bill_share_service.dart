import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CustomerBillShareService {
  static Future<void> shareBillPdf({
    required Uint8List pdfBytes,
    required String billNo,
  }) async {
    final directory = await getTemporaryDirectory();

    final safeBillNo = billNo.trim().isEmpty ? 'customer_bill' : 'bill_$billNo';

    final file = File('${directory.path}/$safeBillNo.pdf');

    await file.writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Bill ${billNo.trim()}',
        text: 'Please find attached bill ${billNo.trim()}.',
      ),
    );
  }
}
