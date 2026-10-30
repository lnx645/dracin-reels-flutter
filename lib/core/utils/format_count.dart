/// Format angka ala Indonesia untuk jumlah suka/komentar/bagikan.
/// 15200 -> "15,2 rb", 1250000 -> "1,3 jt".
String formatCount(int value) {
  if (value >= 1000000) {
    return '${_oneDecimal(value / 1000000)} jt';
  }
  if (value >= 1000) {
    return '${_oneDecimal(value / 1000)} rb';
  }
  return value.toString();
}

String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  if (text.endsWith('.0')) {
    return text.substring(0, text.length - 2);
  }
  return text.replaceFirst('.', ',');
}

/// Format rupiah tanpa desimal: 15000 -> "Rp15.000".
String formatRupiah(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return 'Rp${buffer.toString()}';
}
