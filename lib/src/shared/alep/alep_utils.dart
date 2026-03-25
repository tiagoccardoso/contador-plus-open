import 'package:intl/intl.dart';

class AlepUtils {
  AlepUtils._();

  static DateTime? parseAlepDate(String? s) {
    if (s == null) return null;
    final raw = s.trim();
    if (raw.isEmpty) return null;

    // Fix timezone +0000 -> +00:00
    final m = RegExp(r'([+-]\d{2})(\d{2})$').firstMatch(raw);
    final fixed = (m != null) ? raw.replaceRange(m.start, m.end, '${m.group(1)}:${m.group(2)}') : raw;
    return DateTime.tryParse(fixed);
  }

  static String formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  static String normalize(String? s) => (s ?? '').trim();
}
