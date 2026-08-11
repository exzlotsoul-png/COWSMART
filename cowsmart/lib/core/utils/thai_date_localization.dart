import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ThaiMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const ThaiMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'th';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final base = await GlobalMaterialLocalizations.delegate.load(locale);
    return ThaiMaterialLocalizations(base);
  }

  @override
  bool shouldReload(ThaiMaterialLocalizationsDelegate old) => false;
}

class ThaiMaterialLocalizations extends DefaultMaterialLocalizations {
  final MaterialLocalizations delegate;

  ThaiMaterialLocalizations(this.delegate);

  @override
  String formatYear(DateTime date) {
    return (date.year + 543).toString();
  }

  @override
  String formatMonthYear(DateTime date) {
    final monthNames = [
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
      'ธันวาคม'
    ];
    return '${monthNames[date.month - 1]} พ.ศ. ${date.year + 543}';
  }

  @override
  String formatMediumDate(DateTime date) {
    final monthNamesShort = [
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
      'ธ.ค.'
    ];
    final dayOfWeekNamesShort = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
    final dayOfWeek = dayOfWeekNamesShort[date.weekday % 7];
    return '$dayOfWeek ${date.day} ${monthNamesShort[date.month - 1]}';
  }

  @override
  String formatFullDate(DateTime date) {
    final monthNamesFull = [
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
      'ธันวาคม'
    ];
    final dayOfWeekNamesFull = [
      'วันอาทิตย์',
      'วันจันทร์',
      'วันอังคาร',
      'วันพุธ',
      'วันพฤหัสบดี',
      'วันศุกร์',
      'วันเสาร์'
    ];
    final dayOfWeek = dayOfWeekNamesFull[date.weekday % 7];
    return '$dayOfWeekที่ ${date.day} ${monthNamesFull[date.month - 1]} พ.ศ. ${date.year + 543}';
  }

  @override
  String formatCompactDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  String formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  String formatShortMonthDay(DateTime date) {
    final monthNamesShort = [
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
      'ธ.ค.'
    ];
    return '${date.day} ${monthNamesShort[date.month - 1]}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return (delegate as dynamic).noSuchMethod(invocation);
  }
}
