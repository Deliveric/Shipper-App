import 'package:flutter/material.dart';

String fmt(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

/// "2026-11-07 11:48 PM" -> DateTime
DateTime? parseDate(String s) {
  final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?)?', caseSensitive: false).firstMatch(s);
  if (m == null) return null;
  var h = int.tryParse(m[4] ?? '0') ?? 0;
  final ap = (m[6] ?? '').toUpperCase();
  if (ap == 'PM' && h < 12) h += 12;
  if (ap == 'AM' && h == 12) h = 0;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), h, int.tryParse(m[5] ?? '0') ?? 0);
}


Color statusColor(String en) {
  const m = {
    'Out For Delivery': Color(0xFF7FB3E8),
    'Warehouse Received': Color(0xFFE2964E),
    'Time Scheduled': Color(0xFFF2C75C),
    'Returned to warehouse': Color(0xFFFF8C82),
    'Warehouse Received (re Try)': Color(0xFFC8742A),
    'Time scheduled line': Color(0xFFD9B36A),
    'Cancelled': Color(0xFF8D877A),
    'Replacement - Return': Color(0xFFB79BE0),
    'Hold (Follow with Shipper)': Color(0xFFE58FB0),
    'Returned & Cost Paid': Color(0xFFE07A6E),
    'Partial Return': Color(0xFF6FDC94),
    'Refused Received & Payment': Color(0xFF9AA6B8),
    'Pickup Request': Color(0xFFA9A395),
  };
  return m[en] ?? const Color(0xFFE2964E);
}
