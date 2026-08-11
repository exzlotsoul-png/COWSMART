import 'package:intl/intl.dart';

class AppDateUtils {
  static const List<String> thaiMonthsFull = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const List<String> thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  /// Formats date to Thai B.E. format: e.g. "12 สิงหาคม 2569" or "12 ส.ค. 2569"
  static String formatThaiDate(
    DateTime? date, {
    bool useFullMonth = false,
    bool includeTime = false,
    String fallback = '-',
  }) {
    if (date == null) return fallback;
    final day = date.day;
    final monthName = useFullMonth
        ? thaiMonthsFull[date.month - 1]
        : thaiMonthsShort[date.month - 1];
    final yearBE = date.year + 543;
    final dateStr = '$day $monthName $yearBE';

    if (includeTime) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$dateStr $hour:$minute น.';
    }
    return dateStr;
  }

  /// Helper to parse String or DateTime dynamic input
  static String formatDynamicDate(
    dynamic rawDate, {
    bool useFullMonth = false,
    bool includeTime = false,
    String fallback = '-',
  }) {
    if (rawDate == null) return fallback;
    if (rawDate is DateTime) {
      return formatThaiDate(rawDate, useFullMonth: useFullMonth, includeTime: includeTime, fallback: fallback);
    }
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return formatThaiDate(parsed, useFullMonth: useFullMonth, includeTime: includeTime, fallback: fallback);
      }
    }
    return fallback;
  }

  /// Formats date range: e.g. "1 ส.ค. 2569 - 15 ส.ค. 2569"
  static String formatThaiDateRange(
    DateTime start,
    DateTime end, {
    bool useFullMonth = false,
  }) {
    return '${formatThaiDate(start, useFullMonth: useFullMonth)} - ${formatThaiDate(end, useFullMonth: useFullMonth)}';
  }

  /// Formats month and B.E. year: e.g. "สิงหาคม 2569"
  static String formatThaiMonthYear(
    DateTime? date, {
    bool useFullMonth = true,
    String fallback = '-',
  }) {
    if (date == null) return fallback;
    final monthName = useFullMonth
        ? thaiMonthsFull[date.month - 1]
        : thaiMonthsShort[date.month - 1];
    final yearBE = date.year + 543;
    return '$monthName $yearBE';
  }

  /// Formats time: e.g. "08:00 น."
  static String formatThaiTime(dynamic timeInput, {String fallback = '-'}) {
    if (timeInput == null) return fallback;
    if (timeInput is DateTime) {
      final hour = timeInput.hour.toString().padLeft(2, '0');
      final minute = timeInput.minute.toString().padLeft(2, '0');
      return '$hour:$minute น.';
    }
    return fallback;
  }
}
