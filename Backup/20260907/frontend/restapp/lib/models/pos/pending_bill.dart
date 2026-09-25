class PendingBill {
  final int billId;
  final String? billUuid;
  final int? outletId;
  final int? terminalId;
  final int? orderId;

  final String? billNo;
  final String? billDate;
  final String? billTime;

  final String billType;
  final String billStatus;

  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;

  final String? orderNo;
  final String? orderType;

  final int? tableId;
  final int? logicalTableId;

  final String? tableCode;
  final String? tableName;

  final String? logicalCode;
  final String? logicalName;

  final String? customerName;

  PendingBill({
    required this.billId,
    this.billUuid,
    this.outletId,
    this.terminalId,
    this.orderId,
    this.billNo,
    this.billDate,
    this.billTime,
    required this.billType,
    required this.billStatus,
    required this.grandTotal,
    required this.paidAmount,
    required this.balanceAmount,
    this.orderNo,
    this.orderType,
    this.tableId,
    this.logicalTableId,
    this.tableCode,
    this.tableName,
    this.logicalCode,
    this.logicalName,
    this.customerName,
  });

  factory PendingBill.fromJson(Map<String, dynamic> json) {
    return PendingBill(
      billId: int.parse(json['bill_id'].toString()),
      billUuid: json['bill_uuid'],

      outletId: json['outlet_id'] == null
          ? null
          : int.parse(json['outlet_id'].toString()),

      terminalId: json['terminal_id'] == null
          ? null
          : int.parse(json['terminal_id'].toString()),

      orderId: json['order_id'] == null
          ? null
          : int.parse(json['order_id'].toString()),

      billNo: json['bill_no']?.toString(),
      billDate: json['bill_date']?.toString(),
      billTime: json['bill_time']?.toString(),

      billType: json['bill_type']?.toString() ?? 'NORMAL',

      billStatus: json['bill_status']?.toString() ?? 'FINAL',

      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0,

      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,

      balanceAmount:
          double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0,

      orderNo: json['order_no']?.toString(),
      orderType: json['order_type']?.toString(),

      tableId: json['table_id'] == null
          ? null
          : int.parse(json['table_id'].toString()),

      logicalTableId: json['logical_table_id'] == null
          ? null
          : int.parse(json['logical_table_id'].toString()),

      tableCode: json['table_code']?.toString(),

      tableName: json['table_name']?.toString(),

      logicalCode: json['logical_code']?.toString(),

      logicalName: json['logical_name']?.toString(),

      customerName: json['customer_name']?.toString(),
    );
  }
}
