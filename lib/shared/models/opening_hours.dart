import 'availability_window.dart';

class TimeSlot {
  final DateTime start;
  final DateTime end;

  const TimeSlot({required this.start, required this.end});

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

int storedDayOfWeekFor(DateTime date) => (date.weekday % 7) + 1;

List<TimeSlot> expandWindows(
  List<AvailabilityWindow> windows, {
  required DateTime from,
  int days = 14,
}) {
  final out = <TimeSlot>[];
  final day0 = DateTime(from.year, from.month, from.day);
  for (var offset = 0; offset < days; offset++) {
    final date = day0.add(Duration(days: offset));
    final dow = storedDayOfWeekFor(date);
    for (final w in windows) {
      if (w.dayOfWeek != dow) continue;
      final r = w.timeRange;
      var start = DateTime(
        date.year,
        date.month,
        date.day,
        r.startHour,
        r.startMinute,
      );
      final end = DateTime(
        date.year,
        date.month,
        date.day,
        r.endHour,
        r.endMinute,
      );
      if (!end.isAfter(start) || !end.isAfter(from)) continue;
      if (start.isBefore(from)) start = from;
      out.add(TimeSlot(start: start, end: end));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

bool isOpenAt(List<AvailabilityWindow> windows, DateTime at) {
  final dow = storedDayOfWeekFor(at);
  final minutes = at.hour * 60 + at.minute;
  for (final w in windows) {
    if (w.dayOfWeek != dow) continue;
    final r = w.timeRange;
    final start = r.startHour * 60 + r.startMinute;
    final end = r.endHour * 60 + r.endMinute;
    if (minutes >= start && minutes < end) return true;
  }
  return false;
}
