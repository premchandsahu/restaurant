import 'pos_order_item.dart';

class PosOrder {
  final int orderId;
  final String orderUuid;
  final String orderNo;

  final int outletId;
  final int? terminalId;

  final String orderType;
  final String orderStatus;

  final int? tableId;
  final int? logicalTableId;
  final String? logicalCode;
  final String? logicalName;
  final int? customerId;

  final int? guestCount;

  final String? remarks;

  final double subtotal;
  final double itemDiscount;
  final double billDiscount;

  final double taxableAmount;
  final double taxAmount;
  final double roundingAmount;

  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;

  final List<PosOrderItem> items;

  PosOrder({
    required this.orderId,
    required this.orderUuid,
    required this.orderNo,
    required this.outletId,
    this.terminalId,
    required this.orderType,
    required this.orderStatus,
    this.tableId,
    this.logicalTableId,
    this.logicalCode,
    this.logicalName,
    this.customerId,
    this.guestCount,
    this.remarks,
    required this.subtotal,
    required this.itemDiscount,
    required this.billDiscount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.roundingAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.balanceAmount,
    this.items = const [],
  });

  factory PosOrder.fromJson(Map<String, dynamic> json) {
    return PosOrder(
      orderId: _intValue(json['order_id'] ?? json['orderId']),

      orderUuid:
          json['order_uuid']?.toString() ?? json['orderUuid']?.toString() ?? '',

      orderNo:
          json['order_no']?.toString() ?? json['orderNo']?.toString() ?? '',

      outletId: _intValue(json['outlet_id'] ?? json['outletId']),

      terminalId: _nullableInt(json['terminal_id'] ?? json['terminalId']),

      orderType:
          json['order_type']?.toString() ?? json['orderType']?.toString() ?? '',

      orderStatus:
          json['order_status']?.toString() ??
          json['orderStatus']?.toString() ??
          '',

      tableId: _nullableInt(json['table_id'] ?? json['tableId']),
      logicalTableId: _nullableInt(
        json['logical_table_id'] ?? json['logicalTableId'],
      ),

      logicalCode:
          json['logical_code']?.toString() ?? json['logicalCode']?.toString(),

      logicalName:
          json['logical_name']?.toString() ?? json['logicalName']?.toString(),
      customerId: _nullableInt(json['customer_id'] ?? json['customerId']),

      guestCount: _nullableInt(json['guest_count'] ?? json['guestCount']),

      remarks: json['remarks']?.toString(),

      subtotal: _double(json['subtotal']),

      itemDiscount: _double(json['item_discount'] ?? json['itemDiscount']),

      billDiscount: _double(json['bill_discount'] ?? json['billDiscount']),

      taxableAmount: _double(json['taxable_amount'] ?? json['taxableAmount']),

      taxAmount: _double(json['tax_amount'] ?? json['taxAmount']),

      roundingAmount: _double(
        json['rounding_amount'] ?? json['roundingAmount'],
      ),

      grandTotal: _double(json['grand_total'] ?? json['grandTotal']),

      paidAmount: _double(json['paid_amount'] ?? json['paidAmount']),

      balanceAmount: _double(json['balance_amount'] ?? json['balanceAmount']),

      items:
          (json['items'] as List?)
              ?.map((e) => PosOrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
  static int _intValue(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static double _double(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
