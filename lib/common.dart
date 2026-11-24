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
