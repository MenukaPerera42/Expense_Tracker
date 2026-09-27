/// Pure month-navigation helpers for the dashboard's month selector.
///
/// A "month" is represented by a local [DateTime] pinned to its first day,
/// midnight ([normalize] produces that shape from any [DateTime]), so every
/// other helper here can compare months with plain equality instead of
/// separately comparing year and month fields.
abstract final class MonthNavigation {
  /// Normalizes [date] to the first instant of its local-calendar month.
  static DateTime normalize(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month);
  }

  static DateTime previous(DateTime month) {
    final normalized = normalize(month);
    return normalized.month == 1
        ? DateTime(normalized.year - 1, 12)
        : DateTime(normalized.year, normalized.month - 1);
  }

  /// The following month — capped at the current month, so the dashboard
  /// can never navigate into a month that hasn't happened yet.
  static DateTime next(DateTime month, {DateTime? now}) {
    final normalized = normalize(month);
    final currentMonth = normalize(now ?? DateTime.now());
    if (!isBeforeMonth(normalized, currentMonth)) return normalized;
    return normalized.month == 12
        ? DateTime(normalized.year + 1, 1)
        : DateTime(normalized.year, normalized.month + 1);
  }

  static bool isCurrentMonth(DateTime month, {DateTime? now}) =>
      normalize(month) == normalize(now ?? DateTime.now());

  static bool isSameMonth(DateTime a, DateTime b) =>
      normalize(a) == normalize(b);

  static bool isBeforeMonth(DateTime a, DateTime b) {
    final na = normalize(a);
    final nb = normalize(b);
    return na.year < nb.year || (na.year == nb.year && na.month < nb.month);
  }
}
