import 'package:flutter/material.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Escapes one value for a CSV cell.
String csvCell(Object? v) {
  final s = v == null ? '' : v.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String csvRow(List<Object?> cells) => cells.map(csvCell).join(',');

/// Shown in place of body-specific features until Male or Female is chosen.
class SexGate extends StatelessWidget {
  final String message;
  final Future<void> Function(String) onSex;
  const SexGate({super.key, required this.message, required this.onSex});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Choose your body type', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text(message),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => onSex('male'), icon: const Icon(Icons.person_outline), label: const Text('Male')),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => onSex('female'), icon: const Icon(Icons.person_outline), label: const Text('Female')),
      const SizedBox(height: 14),
      const Text('Saved on this device only. You can change it any time in Settings.', style: TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}
