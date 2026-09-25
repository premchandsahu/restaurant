class BillHistory {
  final int billId;
  final String? billUuid;
  final int outletId;
  final int? terminalId;
  final int? orderId;

  final String billNo;
  final String? billDate;
  final String? billTime;
  final String? billType;
  final String billStatus;

  final double subtotal;
  final double itemDiscount;
  final double billDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double roundingAmount;
  final double grandTotal;

  final double paidAmount;
  final double balanceAmount;

  final String? remarks;

  final String? orderNo;
  final String? orderType;
  final String? orderStatus;

  final int? tableId;
  final int? logicalTableId;

  final String? tableCode;
  final String? tableName;

  final String? logicalCode;
  final String? logicalName;

  final int? customerId;
  final String? customerName;

  const BillHistory({
    required this.billId,
    required this.billUuid,
    required this.outletId,
    required this.terminalId,
    required this.orderId,
    required this.billNo,
    required this.billDate,
    required this.billTime,
    required this.billType,
    required this.billStatus,
    required this.subtotal,
    required this.itemDiscount,
    required this.billDiscount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.roundingAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.balanceAmount,
    required this.remarks,
    required this.orderNo,
    required this.orderType,
    required this.orderStatus,
    required this.tableId,
    required this.logicalTableId,
    required this.tableCode,
    required this.tableName,
    required this.logicalCode,
    required this.logicalName,
    required this.customerId,
    required this.customerName,
  });

  factory BillHistory.fromJson(Map<String, dynamic> json) {
    return BillHistory(
      billId: _toInt(json['bill_id']),
      billUuid: json['bill_uuid']?.toString(),
      outletId: _toInt(json['outlet_id']),
      terminalId: _toNullableInt(json['terminal_id']),
      orderId: _toNullableInt(json['order_id']),

      billNo: json['bill_no']?.toString() ?? '',
      billDate: json['bill_date']?.toString(),
      billTime: json['bill_time']?.toString(),
      billType: json['bill_type']?.toString(),
      billStatus: json['bill_status']?.toString() ?? '',

      subtotal: _toDouble(json['subtotal']),
      itemDiscount: _toDouble(json['item_discount']),
      billDiscount: _toDouble(json['bill_discount']),
      taxableAmount: _toDouble(json['taxable_amount']),
      taxAmount: _toDouble(json['tax_amount']),
      roundingAmount: _toDouble(json['rounding_amount']),
      grandTotal: _toDouble(json['grand_total']),

      paidAmount: _toDouble(json['paid_amount']),
      balanceAmount: _toDouble(json['balance_amount']),

      remarks: json['remarks']?.toString(),

      orderNo: json['order_no']?.toString(),
      orderType: json['order_type']?.toString(),
      orderStatus: json['order_status']?.toString(),

      tableId: _toNullableInt(json['table_id']),
      logicalTableId: _toNullableInt(json['logical_table_id']),

      tableCode: json['table_code']?.toString(),
      tableName: json['table_name']?.toString(),

      logicalCode: json['logical_code']?.toString(),
      logicalName: json['logical_name']?.toString(),

      customerId: _toNullableInt(json['customer_id']),
      customerName: json['customer_name']?.toString(),
    );
  }

  bool get isPaid => balanceAmount <= 0.01;

  bool get isPending => balanceAmount > 0.01;

  String get displayTable {
    if (logicalCode != null && logicalCode!.isNotEmpty) {
      return logicalCode!;
    }

    if (tableCode != null && tableCode!.isNotEmpty) {
      return tableCode!;
    }

    return '-';
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
