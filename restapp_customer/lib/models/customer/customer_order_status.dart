class CustomerOrderStatus {
  final CustomerSession customerSession;
  final CustomerTable table;
  final List<CustomerOrder> orders;

  CustomerOrderStatus({
    required this.customerSession,
    required this.table,
    required this.orders,
  });

  factory CustomerOrderStatus.fromJson(Map<String, dynamic> json) {
    return CustomerOrderStatus(
      customerSession: CustomerSession.fromJson(json['customer_session'] ?? {}),
      table: CustomerTable.fromJson(json['table'] ?? {}),
      orders: (json['orders'] as List? ?? [])
          .map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerSession {
  final int? customerSessionId;
  final String? customerName;

  CustomerSession({this.customerSessionId, this.customerName});

  factory CustomerSession.fromJson(Map<String, dynamic> json) {
    return CustomerSession(
      customerSessionId: json['customer_session_id'],
      customerName: json['customer_name'],
    );
  }
}

class CustomerTable {
  final int? tableId;

  CustomerTable({this.tableId});

  factory CustomerTable.fromJson(Map<String, dynamic> json) {
    return CustomerTable(tableId: json['table_id']);
  }
}

class CustomerOrder {
  final int orderId;
  final String? orderNo;
  final String? orderStatus;
  final int? tableId;
  final int? logicalTableId;
  final String? logicalCode;
  final String? logicalName;

  final double subtotal;
  final double itemDiscount;
  final double billDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double roundingAmount;
  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;

  final bool billRequested;
  final String? billRequestedAt;

  final String? createdAt;
  final String? updatedAt;

  final List<CustomerOrderItem> items;

  CustomerOrder({
    required this.orderId,
    this.orderNo,
    this.orderStatus,
    this.tableId,
    this.logicalTableId,
    this.logicalCode,
    this.logicalName,
    this.subtotal = 0,
    this.itemDiscount = 0,
    this.billDiscount = 0,
    this.taxableAmount = 0,
    this.taxAmount = 0,
    this.roundingAmount = 0,
    this.grandTotal = 0,
    this.paidAmount = 0,
    this.balanceAmount = 0,
    this.billRequested = false,
    this.billRequestedAt,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      orderId: _toInt(json['order_id']) ?? 0,
      orderNo: json['order_no']?.toString(),
      orderStatus: json['order_status']?.toString(),

      tableId: _toInt(json['table_id']),
      logicalTableId: _toInt(json['logical_table_id']),
      logicalCode: json['logical_code']?.toString(),
      logicalName: json['logical_name']?.toString(),

      subtotal: _toDouble(json['subtotal']),
      itemDiscount: _toDouble(json['item_discount']),
      billDiscount: _toDouble(json['bill_discount']),
      taxableAmount: _toDouble(json['taxable_amount']),
      taxAmount: _toDouble(json['tax_amount']),
      roundingAmount: _toDouble(json['rounding_amount']),
      grandTotal: _toDouble(json['grand_total']),
      paidAmount: _toDouble(json['paid_amount']),
      balanceAmount: _toDouble(json['balance_amount']),

      billRequested: _toBool(json['bill_requested']),

      billRequestedAt: json['bill_requested_at']?.toString(),

      createdAt: json['created_at']?.toString(),

      updatedAt: json['updated_at']?.toString(),

      items: (json['items'] as List? ?? [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerOrderItem {
  final int orderItemId;
  final int lineNo;

  final int? menuItemId;
  final int? variantId;

  final String? itemName;
  final String? variantName;

  final double qty;
  final String? status;
  final String? specialInstruction;

  CustomerOrderItem({
    required this.orderItemId,
    required this.lineNo,
    this.menuItemId,
    this.variantId,
    this.itemName,
    this.variantName,
    this.qty = 0,
    this.status,
    this.specialInstruction,
  });

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    return CustomerOrderItem(
      orderItemId: _toInt(json['order_item_id']) ?? 0,

      lineNo: _toInt(json['line_no']) ?? 0,

      menuItemId: _toInt(json['menu_item_id']),

      variantId: _toInt(json['variant_id']),

      itemName: json['item_name']?.toString(),

      variantName: json['variant_name']?.toString(),

      qty: _toDouble(json['qty']),

      status: json['status']?.toString(),

      specialInstruction: json['special_instruction']?.toString(),
    );
  }
}

// ---------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------

int? _toInt(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

bool _toBool(dynamic value) {
  if (value == true || value == 1) {
    return true;
  }

  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }

  return false;
}
