// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get weeklyHabits => 'My Weekly Habits';

  @override
  String get addHabitTooltip => 'Add Habit';

  @override
  String get noHabitsForThisDay => 'You have no habits for this day.';

  @override
  String get dayLetterL => 'M';

  @override
  String get dayLetterM => 'T';

  @override
  String get dayLetterW => 'W';

  @override
  String get dayLetterJ => 'T';

  @override
  String get dayLetterV => 'F';

  @override
  String get dayLetterS => 'S';

  @override
  String get dayLetterD => 'S';
}
