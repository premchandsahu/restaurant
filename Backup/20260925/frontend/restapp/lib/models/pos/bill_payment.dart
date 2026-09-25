class BillPayment {
  final int? paymentId;
  final String? paymentUuid;
  final int billId;
  final String paymentMode;
  final double amount;
  final String? referenceNo;
  final int? receivedBy;
  final String? remarks;
  final String status;
  final DateTime? paymentDate;

  BillPayment({
    this.paymentId,
    this.paymentUuid,
    required this.billId,
    required this.paymentMode,
    required this.amount,
    this.referenceNo,
    this.receivedBy,
    this.remarks,
    required this.status,
    this.paymentDate,
  });

  factory BillPayment.fromJson(Map<String, dynamic> json) {
    return BillPayment(
      paymentId: json['payment_id'],
      paymentUuid: json['payment_uuid'],
      billId: json['bill_id'],
      paymentMode: json['payment_mode'] ?? 'CASH',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      referenceNo: json['reference_no'],
      receivedBy: json['received_by'],
      remarks: json['remarks'],
      status: json['status'] ?? 'SUCCESS',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString())
          : null,
    );
  }
}
