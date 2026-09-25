import 'package:flutter/material.dart';
import 'package:restapp/models/pos/pos_tax.dart';

import '../../models/pos/pos_cart_item.dart';
import '../../models/pos/pos_menu_item.dart';
import '../../models/pos/pos_variant.dart';
import '../../models/pos/pos_modifier_group.dart';
import '../../models/pos/pos_modifier_option.dart';
import '../../services/pos/pos_menu_service.dart';

class PosItemSelectionDialog extends StatefulWidget {
  final PosMenuDetails details;
  final PosTaxGroup? taxGroup;
  const PosItemSelectionDialog({
    super.key,
    required this.details,
    this.taxGroup,
  });

  @override
  State<PosItemSelectionDialog> createState() => _PosItemSelectionDialogState();
}

class _PosItemSelectionDialogState extends State<PosItemSelectionDialog> {
  PosVariant? _selectedVariant;

  final Map<int, PosModifierOption> _singleSelections = {};

  final Map<int, Set<int>> _multipleSelections = {};

  double _quantity = 1;

  @override
  void initState() {
    super.initState();

    _initializeDefaults();
  }

  // --------------------------------------------------
  // Initialize default variant/modifiers
  // --------------------------------------------------

  void _initializeDefaults() {
    final variants = widget.details.variants;

    if (variants.isNotEmpty) {
      final defaultVariants = variants.where((variant) => variant.isDefault);

      if (defaultVariants.isNotEmpty) {
        _selectedVariant = defaultVariants.first;
      } else {
        _selectedVariant = variants.first;
      }
    }

    for (final group in widget.details.modifierGroups) {
      if (group.selectionType == 'SINGLE') {
        final options = group.options;

        if (group.minSelection > 0 && options.isNotEmpty) {
          _singleSelections[group.modifierGroupId] = options.first;
        }
      } else {
        _multipleSelections[group.modifierGroupId] = <int>{};
      }
    }
  }

  // --------------------------------------------------
  // Validate selections
  // --------------------------------------------------

  String? _validate() {
    for (final group in widget.details.modifierGroups) {
      if (group.selectionType == 'SINGLE') {
        final selected = _singleSelections[group.modifierGroupId];

        if (group.minSelection > 0 && selected == null) {
          return 'Please select '
              '${group.groupName}';
        }
      } else {
        final selected = _multipleSelections[group.modifierGroupId] ?? {};

        if (selected.length < group.minSelection) {
          return 'Please select at least '
              '${group.minSelection} option(s) '
              'from ${group.groupName}';
        }

        if (selected.length > group.maxSelection) {
          return 'You can select maximum '
              '${group.maxSelection} option(s) '
              'from ${group.groupName}';
        }
      }
    }

    return null;
  }

  // --------------------------------------------------
  // Build selected modifiers
  // --------------------------------------------------

  List<PosSelectedModifier> _buildSelectedModifiers() {
    final List<PosSelectedModifier> result = [];

    for (final group in widget.details.modifierGroups) {
      if (group.selectionType == 'SINGLE') {
        final option = _singleSelections[group.modifierGroupId];

        if (option != null) {
          result.add(PosSelectedModifier(group: group, option: option));
        }
      } else {
        final selectedIds = _multipleSelections[group.modifierGroupId] ?? {};

        for (final option in group.options) {
          if (selectedIds.contains(option.modifierOptionId)) {
            result.add(PosSelectedModifier(group: group, option: option));
          }
        }
      }
    }

    return result;
  }

  // --------------------------------------------------
  // Add to cart
  // --------------------------------------------------

  void _addToCart() {
    final error = _validate();

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));

      return;
    }

    final modifiers = _buildSelectedModifiers();

    final cartItem = PosCartItem(
      menuItem: widget.details.item,

      variant: _selectedVariant,

      modifiers: modifiers,

      quantity: _quantity,

      rate: _selectedVariant?.rate ?? widget.details.item.baseRate,

      taxGroup: widget.taxGroup,
    );

    Navigator.pop(context, cartItem);
  }

  // --------------------------------------------------
  // Quantity
  // --------------------------------------------------

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity <= 1) {
      return;
    }

    setState(() {
      _quantity--;
    });
  }

  // --------------------------------------------------
  // Build
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final item = widget.details.item;

    return AlertDialog(
      title: Text(item.itemName),

      content: SizedBox(
        width: 500,

        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ======================================
              // Variants
              // ======================================
              if (widget.details.variants.isNotEmpty) ...[
                const Text(
                  'Select Variant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 8),

                ...widget.details.variants.map((variant) {
                  return RadioListTile<PosVariant>(
                    contentPadding: EdgeInsets.zero,

                    title: Text(variant.variantName),

                    secondary: Text('₹${variant.rate.toStringAsFixed(2)}'),

                    value: variant,

                    groupValue: _selectedVariant,

                    onChanged: (value) {
                      setState(() {
                        _selectedVariant = value;
                      });
                    },
                  );
                }),
              ],

              // ======================================
              // Modifiers
              // ======================================
              ...widget.details.modifierGroups.map(
                (group) => _buildModifierGroup(group),
              ),

              const SizedBox(height: 15),

              // ======================================
              // Quantity
              // ======================================
              const Text(
                'Quantity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  IconButton(
                    onPressed: _decrementQuantity,

                    icon: const Icon(Icons.remove_circle_outline),
                  ),

                  SizedBox(
                    width: 45,

                    child: Center(
                      child: Text(
                        _formatQuantity(_quantity),

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: _incrementQuantity,

                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },

          child: const Text('CANCEL'),
        ),

        ElevatedButton(onPressed: _addToCart, child: const Text('ADD TO CART')),
      ],
    );
  }

  // --------------------------------------------------
  // Modifier group
  // --------------------------------------------------

  Widget _buildModifierGroup(PosModifierGroup group) {
    final isSingle = group.selectionType == 'SINGLE';

    return Padding(
      padding: const EdgeInsets.only(top: 15),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            group.groupName,

            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 3),

          Text(
            isSingle
                ? 'Select ${group.minSelection} option'
                : 'Select up to ${group.maxSelection} options',

            style: TextStyle(
              fontSize: 12,

              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 5),

          if (isSingle)
            ...group.options.map((option) {
              return RadioListTile<PosModifierOption>(
                contentPadding: EdgeInsets.zero,

                title: Text(option.optionName),

                secondary: option.extraRate > 0
                    ? Text('+₹${option.extraRate.toStringAsFixed(2)}')
                    : null,

                value: option,

                groupValue: _singleSelections[group.modifierGroupId],

                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      _singleSelections[group.modifierGroupId] = value;
                    }
                  });
                },
              );
            })
          else
            ...group.options.map((option) {
              final selected =
                  _multipleSelections[group.modifierGroupId]?.contains(
                    option.modifierOptionId,
                  ) ??
                  false;

              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,

                title: Text(option.optionName),

                secondary: option.extraRate > 0
                    ? Text('+₹${option.extraRate.toStringAsFixed(2)}')
                    : null,

                value: selected,

                onChanged: (value) {
                  _toggleMultipleModifier(group, option, value ?? false);
                },
              );
            }),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Multiple modifier selection
  // --------------------------------------------------

  void _toggleMultipleModifier(
    PosModifierGroup group,
    PosModifierOption option,
    bool selected,
  ) {
    setState(() {
      final selectedIds = _multipleSelections[group.modifierGroupId] ?? <int>{};

      if (selected) {
        if (selectedIds.length >= group.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum ${group.maxSelection} '
                'options allowed',
              ),
            ),
          );

          return;
        }

        selectedIds.add(option.modifierOptionId);
      } else {
        selectedIds.remove(option.modifierOptionId);
      }

      _multipleSelections[group.modifierGroupId] = selectedIds;
    });
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toStringAsFixed(3);
  }
}
