import 'package:intl/intl.dart';

/// "9 September 2026" style, used everywhere a date is shown to a person
/// rather than picked/compared programmatically.
String longDate(DateTime date) => DateFormat('d MMMM y').format(date);

String longDateFromIso(String isoDate) => longDate(DateTime.parse(isoDate));
