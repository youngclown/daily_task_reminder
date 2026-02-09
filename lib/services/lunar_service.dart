import 'package:lunar/lunar.dart';

class LunarService {
  static final LunarService instance = LunarService._init();

  LunarService._init();

  // Convert solar date to lunar date
  Lunar solarToLunar(DateTime solarDate) {
    final solar = Solar.fromDate(solarDate);
    return solar.getLunar();
  }

  // Convert lunar date to solar date (simplified version)
  Solar lunarToSolar(int year, int month, int day, {bool isLeapMonth = false}) {
    // Use simplified version without leap month handling for now
    final lunar = Lunar.fromYmd(year, month, day);
    return lunar.getSolar();
  }

  // Get this year's solar date for a lunar birthday
  DateTime getLunarBirthdayThisYear(DateTime lunarBirthDate, int targetYear) {
    final lunar = solarToLunar(lunarBirthDate);

    try {
      // Simplified: use year, month, day without leap month
      final lunarThisYear = Lunar.fromYmd(
        targetYear,
        lunar.getMonth(),
        lunar.getDay(),
      );
      final solar = lunarThisYear.getSolar();
      return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
    } catch (e) {
      // If the lunar date doesn't exist this year, return approximate date
      return DateTime(targetYear, lunarBirthDate.month, lunarBirthDate.day);
    }
  }

  // Get next lunar birthday
  DateTime getNextLunarBirthday(DateTime lunarBirthDate) {
    final now = DateTime.now();
    final thisYearBirthday = getLunarBirthdayThisYear(lunarBirthDate, now.year);

    if (thisYearBirthday.isAfter(now)) {
      return thisYearBirthday;
    } else {
      // Get next year's birthday
      final nextYear = now.year + 1;
      final lunar = solarToLunar(lunarBirthDate);

      try {
        final lunarNextYear = Lunar.fromYmd(
          nextYear,
          lunar.getMonth(),
          lunar.getDay(),
        );
        final solar = lunarNextYear.getSolar();
        return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      } catch (e) {
        return DateTime(nextYear, lunarBirthDate.month, lunarBirthDate.day);
      }
    }
  }

  // Format lunar date as string
  String formatLunarDate(DateTime solarDate) {
    final lunar = solarToLunar(solarDate);
    // Simplified: don't show leap month for now
    return '음력 ${lunar.getYear()}년 ${lunar.getMonth()}월 ${lunar.getDay()}일';
  }

  // Get adjusted date for holidays (weekend to weekday)
  DateTime adjustForHolidays(DateTime date, {bool moveToPrevious = false}) {
    // If Saturday (6), move to Friday or Monday
    // If Sunday (7), move to Friday or Monday
    if (date.weekday == DateTime.saturday) {
      return moveToPrevious
          ? date.subtract(const Duration(days: 1)) // Friday
          : date.add(const Duration(days: 2)); // Monday
    } else if (date.weekday == DateTime.sunday) {
      return moveToPrevious
          ? date.subtract(const Duration(days: 2)) // Friday
          : date.add(const Duration(days: 1)); // Monday
    }
    return date;
  }

  // Get the target date for a monthly task
  DateTime getMonthlyTaskDate(int dayOfMonth, bool adjustForHolidays,
      {bool isLunar = false}) {
    final now = DateTime.now();
    DateTime targetDate;

    if (isLunar) {
      // For lunar calendar
      try {
        final lunar = Lunar.fromYmd(now.year, now.month, dayOfMonth);
        final solar = lunar.getSolar();
        targetDate = DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      } catch (e) {
        targetDate = DateTime(now.year, now.month, dayOfMonth);
      }
    } else {
      // For solar calendar
      targetDate = DateTime(now.year, now.month, dayOfMonth);
    }

    // If the date has passed, get next month's date
    if (targetDate.isBefore(now)) {
      if (isLunar) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        try {
          final lunar = Lunar.fromYmd(nextYear, nextMonth, dayOfMonth);
          final solar = lunar.getSolar();
          targetDate =
              DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
        } catch (e) {
          targetDate = DateTime(nextYear, nextMonth, dayOfMonth);
        }
      } else {
        targetDate = DateTime(
          now.month == 12 ? now.year + 1 : now.year,
          now.month == 12 ? 1 : now.month + 1,
          dayOfMonth,
        );
      }
    }

    if (adjustForHolidays) {
      targetDate = this.adjustForHolidays(targetDate);
    }

    return targetDate;
  }
}
