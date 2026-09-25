import 'package:flutter/material.dart';

import '../../models/pos/pos_tax.dart';

class AddFolioChargeResult {
  final String entryType;
  final String description;
  final double quantity;
  final double rate;
  final int? taxGroupId;
  final String? remarks;

  AddFolioChargeResult({
    required this.entryType,
    required this.description,
    required this.quantity,
    required this.rate,
    this.taxGroupId,
    this.remarks,
  });
}

class AddFolioChargeDialog extends StatefulWidget {
  final List<PosTaxGroup> taxGroups;

  const AddFolioChargeDialog({super.key, required this.taxGroups});

  @override
  State<AddFolioChargeDialog> createState() => _AddFolioChargeDialogState();
}

class _AddFolioChargeDialogState extends State<AddFolioChargeDialog> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();

  final _quantityController = TextEditingController(text: '1');

  final _rateController = TextEditingController();

  final _remarksController = TextEditingController();

  String _entryType = 'ROOM_CHARGE';

  int? _taxGroupId;

  final List<Map<String, String>> _chargeTypes = [
    {'value': 'ROOM_CHARGE', 'label': 'Room Charge'},
    {'value': 'LAUNDRY', 'label': 'Laundry'},
    {'value': 'MINIBAR', 'label': 'Minibar'},
    {'value': 'SERVICE', 'label': 'Service'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;

    final rate = double.tryParse(_rateController.text.trim()) ?? 0;

    Navigator.pop(
      context,
      AddFolioChargeResult(
        entryType: _entryType,

        description: _descriptionController.text.trim(),

        quantity: quantity,

        rate: rate,

        taxGroupId: _taxGroupId,

        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Folio Charge'),

      content: SizedBox(
        width: 500,

        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // -------------------------------------------------
                // Charge type
                // -------------------------------------------------
                DropdownButtonFormField<String>(
                  value: _entryType,

                  decoration: const InputDecoration(
                    labelText: 'Charge Type',
                    border: OutlineInputBorder(),
                  ),

                  items: _chargeTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),

                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _entryType = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Description
                // -------------------------------------------------
                TextFormField(
                  controller: _descriptionController,

                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Laundry - 5 garments',
                    border: OutlineInputBorder(),
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Quantity + Rate
                // -------------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,

                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),

                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),

                        validator: (value) {
                          final qty = double.tryParse(value?.trim() ?? '');

                          if (qty == null || qty <= 0) {
                            return 'Invalid quantity';
                          }

                          return null;
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: TextFormField(
                        controller: _rateController,

                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),

                        decoration: const InputDecoration(
                          labelText: 'Rate',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),

                        validator: (value) {
                          final rate = double.tryParse(value?.trim() ?? '');

                          if (rate == null || rate < 0) {
                            return 'Invalid rate';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Tax Group
                // -------------------------------------------------
                DropdownButtonFormField<int?>(
                  value: _taxGroupId,

                  decoration: const InputDecoration(
                    labelText: 'Tax Group',
                    border: OutlineInputBorder(),
                  ),

                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Tax'),
                    ),

                    ...widget.taxGroups.map((group) {
                      return DropdownMenuItem<int?>(
                        value: group.taxGroupId,
                        child: Text(group.taxGroupName),
                      );
                    }),
                  ],

                  onChanged: (value) {
                    setState(() {
                      _taxGroupId = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Remarks
                // -------------------------------------------------
                TextFormField(
                  controller: _remarksController,

                  maxLines: 2,

                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),

          child: const Text('CANCEL'),
        ),

        ElevatedButton.icon(
          onPressed: _save,

          icon: const Icon(Icons.save),

          label: const Text('SAVE'),
        ),
      ],
    );
  }
}
