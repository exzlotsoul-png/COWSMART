class CalendarEvent {
  final String id;
  final String farmId;
  final String title;
  final DateTime eventDatetime;
  final String? description;
  final String? reminderSetting;
  final String? cowId;

  CalendarEvent({
    required this.id,
    required this.farmId,
    required this.title,
    required this.eventDatetime,
    this.description,
    this.reminderSetting,
    this.cowId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: (json['calendar_event_id'] ?? json['id']).toString(),
      farmId: json['farm_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventDatetime: DateTime.parse(json['event_datetime']),
      description: json['description']?.toString(),
      reminderSetting: json['reminder_setting']?.toString(),
      cowId: json['cow_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'farm_id': farmId,
        'title': title,
        'event_datetime': eventDatetime.toIso8601String(),
        'description': description,
        'reminder_setting': reminderSetting,
        'cow_id': cowId,
      };

  CalendarEvent copyWith({
    String? title,
    DateTime? eventDatetime,
    String? description,
    String? reminderSetting,
    String? cowId,
  }) {
    return CalendarEvent(
      id: id,
      farmId: farmId,
      title: title ?? this.title,
      eventDatetime: eventDatetime ?? this.eventDatetime,
      description: description ?? this.description,
      reminderSetting: reminderSetting ?? this.reminderSetting,
      cowId: cowId ?? this.cowId,
    );
  }
}
