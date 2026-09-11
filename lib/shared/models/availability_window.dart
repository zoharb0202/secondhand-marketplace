const String kProductSellerHoursField = 'sellerAvailabilityWindows';

Map<String, dynamic> asStringKeyed(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  return raw.map((key, value) => MapEntry('$key', value));
}

int _asInt(Object? raw, int fallback) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return fallback;
}

class AvailabilityWindow {
  final String? id;
  final int dayOfWeek;
  final TimeRange timeRange;

  AvailabilityWindow({
    this.id,
    required this.dayOfWeek,
    required this.timeRange,
  });

  factory AvailabilityWindow.fromMap(Map<String, dynamic> data, {String? id}) {
    return AvailabilityWindow(
      id: id,
      dayOfWeek: _asInt(data['dayOfWeek'], 1),
      timeRange: TimeRange.fromMap(asStringKeyed(data['timeRange'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {'dayOfWeek': dayOfWeek, 'timeRange': timeRange.toMap()};
  }

  static List<AvailabilityWindow> parseList(Object? raw) {
    if (raw is! List) return const [];
    final out = <AvailabilityWindow>[];
    for (final entry in raw) {
      if (entry is Map) {
        out.add(AvailabilityWindow.fromMap(asStringKeyed(entry)));
      }
    }
    return out;
  }

  String getDayName() {
    switch (dayOfWeek) {
      case 1:
        return 'ראשון';
      case 2:
        return 'שני';
      case 3:
        return 'שלישי';
      case 4:
        return 'רביעי';
      case 5:
        return 'חמישי';
      case 6:
        return 'שישי';
      case 7:
        return 'שבת';
      default:
        return '';
    }
  }

  static int convertDartWeekdayToIsraeli(int dartWeekday) {
    return dartWeekday == 7 ? 1 : dartWeekday + 1;
  }

  static int convertIsraeliToDartWeekday(int israeliDay) {
    return israeliDay == 1 ? 7 : israeliDay - 1;
  }

  AvailabilityWindow copyWith({
    String? id,
    int? dayOfWeek,
    TimeRange? timeRange,
  }) {
    return AvailabilityWindow(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}

class TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  factory TimeRange.fromMap(Map<String, dynamic> data) {
    return TimeRange(
      startHour: _asInt(data['startHour'], 0),
      startMinute: _asInt(data['startMinute'], 0),
      endHour: _asInt(data['endHour'], 0),
      endMinute: _asInt(data['endMinute'], 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  String formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String getFormattedRange() {
    return '${formatTime(startHour, startMinute)} - ${formatTime(endHour, endMinute)}';
  }

  bool contains(DateTime dateTime) {
    final timeInMinutes = dateTime.hour * 60 + dateTime.minute;
    final startInMinutes = startHour * 60 + startMinute;
    final endInMinutes = endHour * 60 + endMinute;

    return timeInMinutes >= startInMinutes && timeInMinutes <= endInMinutes;
  }

  TimeRange copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return TimeRange(
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }
}
