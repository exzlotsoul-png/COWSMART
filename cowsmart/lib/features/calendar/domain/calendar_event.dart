class CalendarEvent {
  final String id;
  final String farmId;
  final String title;
  final DateTime eventDatetime;
  final String? description;
  final String? reminderSetting;
  final String? cowId;
  final String eventType; // 'general', 'health', 'breeding'
  final String? groupId;
  final int? cowCount;
  final List<String> cowIds;
  final List<String> groupApptIds;

  CalendarEvent({
    required this.id,
    required this.farmId,
    required this.title,
    required this.eventDatetime,
    this.description,
    this.reminderSetting,
    this.cowId,
    this.eventType = 'general',
    this.groupId,
    this.cowCount,
    this.cowIds = const [],
    this.groupApptIds = const [],
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final rawCowIds = json['_cow_ids'];
    List<String> parsedCowIds = [];
    if (rawCowIds is List) {
      parsedCowIds = rawCowIds.map((e) => e.toString()).toList();
    }

    final rawApptIds = json['_group_appt_ids'];
    List<String> parsedApptIds = [];
    if (rawApptIds is List) {
      parsedApptIds = rawApptIds.map((e) => e.toString()).toList();
    }

    return CalendarEvent(
      id: (json['calendar_event_id'] ?? json['id']).toString(),
      farmId: json['farm_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventDatetime: DateTime.parse(json['event_datetime']).toLocal(),
      description: json['description']?.toString(),
      reminderSetting: json['reminder_setting']?.toString(),
      cowId: json['cow_id']?.toString(),
      eventType: json['event_type']?.toString() ?? 'general',
      groupId: json['_group_id']?.toString(),
      cowCount: json['_cow_count'] != null ? int.tryParse(json['_cow_count'].toString()) : null,
      cowIds: parsedCowIds,
      groupApptIds: parsedApptIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'farm_id': farmId,
        'title': title,
        'event_datetime': eventDatetime.toIso8601String(),
        'description': description,
        'reminder_setting': reminderSetting,
        'cow_id': cowId,
        'event_type': eventType,
        if (cowIds.isNotEmpty) 'cow_ids': cowIds,
      };

  /// Whether this event is a grouped health appointment
  bool get isGrouped => groupId != null && groupId!.isNotEmpty;

  CalendarEvent copyWith({
    String? title,
    DateTime? eventDatetime,
    String? description,
    String? reminderSetting,
    String? cowId,
    String? eventType,
    List<String>? cowIds,
  }) {
    return CalendarEvent(
      id: id,
      farmId: farmId,
      title: title ?? this.title,
      eventDatetime: eventDatetime ?? this.eventDatetime,
      description: description ?? this.description,
      reminderSetting: reminderSetting ?? this.reminderSetting,
      cowId: cowId ?? this.cowId,
      eventType: eventType ?? this.eventType,
      groupId: groupId,
      cowCount: cowIds != null ? cowIds.length : cowCount,
      cowIds: cowIds ?? this.cowIds,
      groupApptIds: groupApptIds,
    );
  }
}
