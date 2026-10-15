/// Calendar periods use the same device-local dates as the program display.
enum ProgramDateFilter { all, today, tomorrow, thisWeek }

({DateTime from, DateTime before})? programDateRange(
  ProgramDateFilter filter, {
  DateTime? now,
}) {
  if (filter == ProgramDateFilter.all) return null;
  final local = (now ?? DateTime.now()).toLocal();
  final day = switch (filter) {
    ProgramDateFilter.tomorrow => local.day + 1,
    ProgramDateFilter.thisWeek => local.day - (local.weekday - DateTime.monday),
    _ => local.day,
  };
  final from = DateTime(local.year, local.month, day);
  final before = DateTime(
    local.year,
    local.month,
    day + (filter == ProgramDateFilter.thisWeek ? 7 : 1),
  );
  return (from: from, before: before);
}
