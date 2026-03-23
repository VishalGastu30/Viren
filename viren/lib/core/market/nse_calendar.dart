import 'package:intl/intl.dart';

class NseCalendar {
  // Common NSE Holidays (Settlement & Trading)
  static const List<String> holidays2024 = [
    '2024-01-22', '2024-01-26', '2024-03-08', '2024-03-25', '2024-03-29',
    '2024-04-11', '2024-04-17', '2024-05-01', '2024-05-20', '2024-06-17',
    '2024-07-17', '2024-08-15', '2024-10-02', '2024-11-01', '2024-11-15',
    '2024-12-25'
  ];

  static const List<String> holidays2025 = [
    '2025-02-26', '2025-03-14', '2025-03-31', '2025-04-10', '2025-04-14',
    '2025-04-18', '2025-05-01', '2025-08-15', '2025-08-27', '2025-10-02',
    '2025-10-21', '2025-10-22', '2025-11-05', '2025-12-25'
  ];

  static const List<String> holidays2026 = [
    '2026-01-26', '2026-02-14', '2026-03-03', '2026-03-20', '2026-04-03',
    '2026-04-14', '2026-05-01', '2026-05-24', '2026-08-15', '2026-09-15',
    '2026-10-02', '2026-11-08', '2026-11-24', '2026-12-25'
  ];

  static bool isMarketDay(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }
    
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (date.year == 2024 && holidays2024.contains(dateStr)) return false;
    if (date.year == 2025 && holidays2025.contains(dateStr)) return false;
    if (date.year == 2026 && holidays2026.contains(dateStr)) return false;
    
    return true;
  }

  static DateTime nearestTradingDay(DateTime date) {
    DateTime checkDate = date;
    // Look backward up to 5 days
    for (int i = 0; i < 5; i++) {
      if (isMarketDay(checkDate)) {
        return checkDate;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return date; // Fallback
  }
}
