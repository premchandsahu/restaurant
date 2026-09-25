class InventorySupplierLedger {
  final InventorySupplierLedgerSupplier supplier;
  final InventorySupplierLedgerPeriod period;
  final InventorySupplierLedgerSummary summary;
  final List<InventorySupplierLedgerTransaction> transactions;

  const InventorySupplierLedger({
    required this.supplier,
    required this.period,
    required this.summary,
    required this.transactions,
  });

  factory InventorySupplierLedger.fromJson(Map<String, dynamic> json) {
    return InventorySupplierLedger(
      supplier: InventorySupplierLedgerSupplier.fromJson(
        Map<String, dynamic>.from(json['supplier'] as Map? ?? {}),
      ),
      period: InventorySupplierLedgerPeriod.fromJson(
        Map<String, dynamic>.from(json['period'] as Map? ?? {}),
      ),
      summary: InventorySupplierLedgerSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
      transactions: (json['transactions'] as List? ?? const [])
          .map(
            (e) => InventorySupplierLedgerTransaction.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class InventorySupplierLedgerSupplier {
  final int supplierId;
  final String supplierCode;
  final String supplierName;
  final String? mobile;
  final String? email;
  final String? gstin;

  const InventorySupplierLedgerSupplier({
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.mobile,
    required this.email,
    required this.gstin,
  });

  factory InventorySupplierLedgerSupplier.fromJson(Map<String, dynamic> json) {
    return InventorySupplierLedgerSupplier(
      supplierId: _int(json['supplierId']),
      supplierCode: json['supplierCode']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      gstin: json['gstin']?.toString(),
    );
  }
}

class InventorySupplierLedgerPeriod {
  final String fromDate;
  final String toDate;

  const InventorySupplierLedgerPeriod({
    required this.fromDate,
    required this.toDate,
  });

  factory InventorySupplierLedgerPeriod.fromJson(Map<String, dynamic> json) {
    return InventorySupplierLedgerPeriod(
      fromDate: json['fromDate']?.toString() ?? '',
      toDate: json['toDate']?.toString() ?? '',
    );
  }
}

class InventorySupplierLedgerSummary {
  final double masterOpeningBalance;
  final double historicalPurchasesBeforeFromDate;
  final double historicalPaymentsBeforeFromDate;
  final double openingBalance;
  final double totalPurchases;
  final double totalPayments;
  final double closingBalance;
  final double payableBalance;
  final double advanceBalance;

  const InventorySupplierLedgerSummary({
    required this.masterOpeningBalance,
    required this.historicalPurchasesBeforeFromDate,
    required this.historicalPaymentsBeforeFromDate,
    required this.openingBalance,
    required this.totalPurchases,
    required this.totalPayments,
    required this.closingBalance,
    required this.payableBalance,
    required this.advanceBalance,
  });

  factory InventorySupplierLedgerSummary.fromJson(Map<String, dynamic> json) {
    return InventorySupplierLedgerSummary(
      masterOpeningBalance: _double(json['masterOpeningBalance']),
      historicalPurchasesBeforeFromDate: _double(
        json['historicalPurchasesBeforeFromDate'],
      ),
      historicalPaymentsBeforeFromDate: _double(
        json['historicalPaymentsBeforeFromDate'],
      ),
      openingBalance: _double(json['openingBalance']),
      totalPurchases: _double(json['totalPurchases']),
      totalPayments: _double(json['totalPayments']),
      closingBalance: _double(json['closingBalance']),
      payableBalance: _double(json['payableBalance']),
      advanceBalance: _double(json['advanceBalance']),
    );
  }
}

class InventorySupplierLedgerTransaction {
  final int transactionId;
  final String transactionDate;
  final String transactionType;
  final String? referenceNo;
  final int? referenceId;
  final String? description;
  final double debit;
  final double credit;
  final String? paymentMode;
  final String? remarks;
  final double runningBalance;

  const InventorySupplierLedgerTransaction({
    required this.transactionId,
    required this.transactionDate,
    required this.transactionType,
    required this.referenceNo,
    required this.referenceId,
    required this.description,
    required this.debit,
    required this.credit,
    required this.paymentMode,
    required this.remarks,
    required this.runningBalance,
  });

  factory InventorySupplierLedgerTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventorySupplierLedgerTransaction(
      transactionId: _int(json['transactionId']),
      transactionDate: json['transactionDate']?.toString() ?? '',
      transactionType: json['transactionType']?.toString() ?? '',
      referenceNo: json['referenceNo']?.toString(),
      referenceId: json['referenceId'] == null
          ? null
          : _int(json['referenceId']),
      description: json['description']?.toString(),
      debit: _double(json['debit']),
      credit: _double(json['credit']),
      paymentMode: json['paymentMode']?.toString(),
      remarks: json['remarks']?.toString(),
      runningBalance: _double(json['runningBalance']),
    );
  }
}

class InventorySupplierOutstanding {
  final int supplierId;
  final String supplierCode;
  final String supplierName;
  final double openingBalance;
  final double totalPurchases;
  final double totalPayments;
  final double accountBalance;
  final double payableBalance;
  final double advanceBalance;

  const InventorySupplierOutstanding({
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.openingBalance,
    required this.totalPurchases,
    required this.totalPayments,
    required this.accountBalance,
    required this.payableBalance,
    required this.advanceBalance,
  });

  factory InventorySupplierOutstanding.fromJson(Map<String, dynamic> json) {
    return InventorySupplierOutstanding(
      supplierId: _int(json['supplier']?['supplierId']),
      supplierCode: json['supplier']?['supplierCode']?.toString() ?? '',
      supplierName: json['supplier']?['supplierName']?.toString() ?? '',
      openingBalance: _double(json['summary']?['openingBalance']),
      totalPurchases: _double(json['summary']?['totalPurchases']),
      totalPayments: _double(json['summary']?['totalPayments']),
      accountBalance: _double(json['summary']?['accountBalance']),
      payableBalance: _double(json['summary']?['payableBalance']),
      advanceBalance: _double(json['summary']?['advanceBalance']),
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
