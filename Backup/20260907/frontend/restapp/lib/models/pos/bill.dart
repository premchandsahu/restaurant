import 'bill_payment.dart';

class BillItem {
  final int billItemId;
  final int billId;
  final int orderItemId;
  final int menuItemId;
  final int? variantId;

  final String itemName;
  final String? variantName;

  final double qty;
  final double rate;
  final double grossAmount;
  final double discountAmount;
  final double taxableAmount;
  final double taxAmount;
  final double netAmount;

  BillItem({
    required this.billItemId,
    required this.billId,
    required this.orderItemId,
    required this.menuItemId,
    this.variantId,
    required this.itemName,
    this.variantName,
    required this.qty,
    required this.rate,
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.netAmount,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      billItemId: json['bill_item_id'],
      billId: json['bill_id'],
      orderItemId: json['order_item_id'],
      menuItemId: json['menu_item_id'],
      variantId: json['variant_id'],

      itemName: json['item_name'] ?? '',
      variantName: json['variant_name'],

      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,

      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0,

      grossAmount:
          double.tryParse(json['gross_amount']?.toString() ?? '0') ?? 0,

      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,

      taxableAmount:
          double.tryParse(json['taxable_amount']?.toString() ?? '0') ?? 0,

      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,

      netAmount: double.tryParse(json['net_amount']?.toString() ?? '0') ?? 0,
    );
  }
}

class BillTax {
  final int billTaxId;
  final int billId;
  final int taxRateId;

  final String taxName;
  final String taxType;

  final double rate;
  final double taxableAmount;
  final double taxAmount;

  BillTax({
    required this.billTaxId,
    required this.billId,
    required this.taxRateId,
    required this.taxName,
    required this.taxType,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory BillTax.fromJson(Map<String, dynamic> json) {
    return BillTax(
      billTaxId: json['bill_tax_id'],
      billId: json['bill_id'],
      taxRateId: json['tax_rate_id'],

      taxName: json['tax_name'] ?? '',
      taxType: json['tax_type'] ?? '',

      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0,

      taxableAmount:
          double.tryParse(json['taxable_amount']?.toString() ?? '0') ?? 0,

      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,
    );
  }
}

class Bill {
  final int billId;
  final String? billNo;

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

  final int? orderId;
  final int? outletId;
  final int? terminalId;

  final String? billType;
  final String? remarks;

  final DateTime? billDate;
  final DateTime? billTime;

  final String? orderNo;
  final String? orderType;

  final int? tableId;
  final int? logicalTableId;

  final String? tableCode;
  final String? tableName;

  final List<BillItem> items;
  final List<BillTax> taxes;
  final List<BillPayment> payments;

  Bill({
    required this.billId,
    this.billNo,

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

    this.orderId,
    this.outletId,
    this.terminalId,

    this.billType,
    this.remarks,

    this.billDate,
    this.billTime,

    this.orderNo,
    this.orderType,

    this.tableId,
    this.logicalTableId,

    this.tableCode,
    this.tableName,

    required this.items,
    required this.taxes,
    required this.payments,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final itemList = json['items'] as List? ?? [];

    final taxList = json['taxes'] as List? ?? [];

    final paymentList = json['payments'] as List? ?? [];

    return Bill(
      billId: json['bill_id'],

      billNo: json['bill_no'],

      billStatus: json['bill_status'] ?? 'DRAFT',

      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,

      itemDiscount:
          double.tryParse(json['item_discount']?.toString() ?? '0') ?? 0,

      billDiscount:
          double.tryParse(json['bill_discount']?.toString() ?? '0') ?? 0,

      taxableAmount:
          double.tryParse(json['taxable_amount']?.toString() ?? '0') ?? 0,

      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,

      roundingAmount:
          double.tryParse(json['rounding_amount']?.toString() ?? '0') ?? 0,

      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0,

      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,

      balanceAmount:
          double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0,

      orderId: json['order_id'],
      outletId: json['outlet_id'],
      terminalId: json['terminal_id'],

      billType: json['bill_type'],
      remarks: json['remarks'],

      billDate: json['bill_date'] != null
          ? DateTime.tryParse(json['bill_date'].toString())
          : null,

      billTime: json['bill_time'] != null
          ? DateTime.tryParse(json['bill_time'].toString())
          : null,

      orderNo: json['order_no']?.toString(),
      orderType: json['order_type'],

      tableId: json['table_id'],
      logicalTableId: json['logical_table_id'],

      tableCode: json['table_code'],
      tableName: json['table_name'],

      items: itemList
          .map((item) => BillItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),

      taxes: taxList
          .map((tax) => BillTax.fromJson(Map<String, dynamic>.from(tax)))
          .toList(),

      payments: paymentList
          .map(
            (payment) =>
                BillPayment.fromJson(Map<String, dynamic>.from(payment)),
          )
          .toList(),
    );
  }
}
