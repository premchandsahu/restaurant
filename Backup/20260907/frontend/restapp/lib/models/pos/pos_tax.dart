class PosTaxRate {
  final int taxRateId;
  final int taxGroupId;

  final String taxName;
  final String taxType;

  final double rate;
  final bool isInclusive;

  PosTaxRate({
    required this.taxRateId,
    required this.taxGroupId,
    required this.taxName,
    required this.taxType,
    required this.rate,
    required this.isInclusive,
  });

  factory PosTaxRate.fromJson(Map<String, dynamic> json) {
    return PosTaxRate(
      taxRateId: _int(json['tax_rate_id']),
      taxGroupId: _int(json['tax_group_id']),
      taxName: json['tax_name']?.toString() ?? '',
      taxType: json['tax_type']?.toString() ?? '',
      rate: _double(json['rate']),
      isInclusive: _bool(json['is_inclusive']),
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    return value?.toString() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }
}

class PosTaxGroup {
  final int taxGroupId;

  final String taxGroupCode;
  final String taxGroupName;

  final List<PosTaxRate> rates;

  PosTaxGroup({
    required this.taxGroupId,
    required this.taxGroupCode,
    required this.taxGroupName,
    required this.rates,
  });

  double get totalRate {
    return rates.fold(0, (sum, tax) => sum + tax.rate);
  }

  PosTaxRate? get cgst {
    for (final tax in rates) {
      if (tax.taxType == 'CGST') {
        return tax;
      }
    }

    return null;
  }

  PosTaxRate? get sgst {
    for (final tax in rates) {
      if (tax.taxType == 'SGST') {
        return tax;
      }
    }

    return null;
  }

  PosTaxRate? get igst {
    for (final tax in rates) {
      if (tax.taxType == 'IGST') {
        return tax;
      }
    }

    return null;
  }
}
