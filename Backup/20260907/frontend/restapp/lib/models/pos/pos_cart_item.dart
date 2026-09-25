import 'pos_menu_item.dart';
import 'pos_variant.dart';
import 'pos_modifier_group.dart';
import 'pos_modifier_option.dart';
import 'pos_tax.dart';

class PosCartItem {
  final PosMenuItem menuItem;

  final PosVariant? variant;

  final List<PosSelectedModifier> modifiers;

  double quantity;

  double rate;

  double discountAmount;

  //double taxAmount;

  String? specialInstruction;

  final PosTaxGroup? taxGroup;
  bool isSentToKitchen;
  double sentQuantity;
  double savedQuantity;
  PosCartItem({
    required this.menuItem,
    this.variant,
    this.modifiers = const [],
    this.quantity = 1,
    double? rate,
    this.discountAmount = 0,
    //this.taxAmount = 0,
    this.specialInstruction,
    this.taxGroup,
    this.isSentToKitchen = false,
    this.sentQuantity = 0,
    this.savedQuantity = 0,
  }) : rate = rate ?? variant?.rate ?? menuItem.baseRate;

  double get unsavedQuantity {
    final remaining = quantity - savedQuantity;
    return remaining > 0 ? remaining : 0;
  }

  double get unsentQuantity {
    final remaining = quantity - sentQuantity;
    return remaining > 0 ? remaining : 0;
  }

  // --------------------------------------------------
  // Modifier total
  // --------------------------------------------------

  double get modifierAmount {
    double total = 0;

    for (final modifier in modifiers) {
      total += modifier.option.extraRate * modifier.quantity;
    }

    return total;
  }

  // --------------------------------------------------
  // Unit rate
  // --------------------------------------------------

  double get unitRate {
    return rate + modifierAmount;
  }

  // --------------------------------------------------
  // Gross amount
  // --------------------------------------------------

  double get grossAmount {
    return unitRate * quantity;
  }

  // --------------------------------------------------
  // Taxable amount
  // --------------------------------------------------

  double get taxableAmount {
    return grossAmount - discountAmount;
  }

  double get taxAmount {
    if (taxGroup == null) {
      return 0;
    }

    double tax = 0;

    for (final rate in taxGroup!.rates) {
      if (!rate.isInclusive) {
        tax += taxableAmount * rate.rate / 100;
      }
    }

    return tax;
  }
  // --------------------------------------------------
  // Net amount
  // --------------------------------------------------

  double get netAmount {
    return taxableAmount + taxAmount;
  }

  // --------------------------------------------------
  // Display name
  // --------------------------------------------------

  String get displayName {
    if (variant != null) {
      return '${menuItem.itemName} '
          '- ${variant!.variantName}';
    }

    return menuItem.itemName;
  }

  // --------------------------------------------------
  // Modifier display
  // --------------------------------------------------

  String get modifierDisplay {
    if (modifiers.isEmpty) {
      return '';
    }

    return modifiers.map((modifier) => modifier.option.optionName).join(', ');
  }

  // --------------------------------------------------
  // Check whether two cart lines represent
  // the same item configuration
  // --------------------------------------------------

  bool isSameConfiguration(
    PosMenuItem item,
    PosVariant? selectedVariant,
    List<PosSelectedModifier> selectedModifiers,
  ) {
    if (menuItem.menuItemId != item.menuItemId) {
      return false;
    }

    if (variant?.variantId != selectedVariant?.variantId) {
      return false;
    }

    if (modifiers.length != selectedModifiers.length) {
      return false;
    }

    for (final modifier in modifiers) {
      final matching = selectedModifiers.where(
        (m) =>
            m.group.modifierGroupId == modifier.group.modifierGroupId &&
            m.option.modifierOptionId == modifier.option.modifierOptionId,
      );

      if (matching.isEmpty) {
        return false;
      }
    }

    return true;
  }
}

// ==================================================
// Selected Modifier
// ==================================================

class PosSelectedModifier {
  final PosModifierGroup group;

  final PosModifierOption option;

  double quantity;

  PosSelectedModifier({
    required this.group,
    required this.option,
    this.quantity = 1,
  });
}
