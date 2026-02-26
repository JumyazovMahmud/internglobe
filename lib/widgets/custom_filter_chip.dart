import 'package:flutter/material.dart';

class CustomFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;
  final Color? backgroundColor;

  const CustomFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: selectedColor ?? Theme.of(context).colorScheme.primary.withOpacity(0.2),
      backgroundColor: backgroundColor,
      checkmarkColor: selected ? Theme.of(context).colorScheme.onPrimary : null,
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}