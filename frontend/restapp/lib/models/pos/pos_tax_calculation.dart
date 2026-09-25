class PosTaxCalculation {
  final double taxableAmount;

  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;

  final double totalTax;

  PosTaxCalculation({
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
  }) : totalTax = cgstAmount + sgstAmount + igstAmount;
}
