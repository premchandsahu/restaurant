import 'package:flutter/material.dart';

/// Shared responsive shell for POS master screens.
/// Keep API calls, models, and master-specific business rules in each screen.
class MasterEntryScaffold extends StatelessWidget {
  final String title;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final Widget form;
  final Widget list;
  final double formWidth;
  final double compactFormHeight;
  final double wideBreakpoint;

  const MasterEntryScaffold({
    super.key,
    required this.title,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onRetry,
    required this.form,
    required this.list,
    this.formWidth = 420,
    this.compactFormHeight = 410,
    this.wideBreakpoint = 1000,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : () => onRefresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= wideBreakpoint) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: formWidth,
                            height: constraints.maxHeight,
                            child: form,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: list),
                        ],
                      );
                    }

                    final formHeight = constraints.maxHeight < compactFormHeight
                        ? constraints.maxHeight * 0.58
                        : compactFormHeight;

                    return Column(
                      children: [
                        SizedBox(height: formHeight, child: form),
                        const Divider(height: 1),
                        Expanded(child: list),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(errorMessage ?? 'Unable to load data.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh),
                label: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent text input used by master forms.
class MasterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const MasterTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Consistent dropdown field for master forms.
class MasterDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T?>? validator;

  const MasterDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// Consistent tap-to-search selector (for category, tax group, customer, etc.).
class MasterLookupField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool enabled;

  const MasterLookupField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
          enabled: enabled,
        ),
        child: Text(
          hasValue ? value! : placeholder,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: enabled
                ? (hasValue
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor)
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}

/// Standard Save/Update and Clear actions for master forms.
class MasterSaveActions extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSave;
  final VoidCallback onClear;

  const MasterSaveActions({
    super.key,
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(isEditing ? 'UPDATE' : 'SAVE'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isSaving ? null : onClear,
          child: const Text('CLEAR'),
        ),
      ],
    );
  }
}

/// Shared heading and record count above a master list.
class MasterListHeader extends StatelessWidget {
  final String title;
  final int count;

  const MasterListHeader({
    super.key,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Text('($count)', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Shared searchable list input with an integrated clear action.
class MasterSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const MasterSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
