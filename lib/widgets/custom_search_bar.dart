import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const CustomSearchBar({super.key, required this.controller, this.hint = 'Search...'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }
}