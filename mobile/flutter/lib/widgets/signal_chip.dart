import 'package:flutter/material.dart';

class SignalChip extends StatelessWidget {
  final String text;
  const SignalChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(text),
        backgroundColor: Colors.red.shade50,
      );
}
