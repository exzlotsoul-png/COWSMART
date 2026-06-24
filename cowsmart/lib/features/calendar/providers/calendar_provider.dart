import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/calendar_event.dart';

class CalendarState {
  final List<CalendarEvent> events;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  Map<DateTime, List<CalendarEvent>> get eventsByDay {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      final day = DateTime(
        e.eventDatetime.year,
        e.eventDatetime.month,
        e.eventDatetime.day,
      );
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  List<CalendarEvent> eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return eventsByDay[key] ?? [];
  }

  CalendarState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CalendarNotifier extends Notifier<CalendarState> {
  late final ApiClient _api;

  @override
  CalendarState build() {
    _api = ref.watch(apiClientProvider);
    return CalendarState();
  }

  Future<void> fetchEvents(String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.get(
        '/calendar_events',
        query: {'farm_id': farmId},
      );
      final list = (response.data as List<dynamic>)
          .map((j) => CalendarEvent.fromJson(j))
          .toList();
      list.sort((a, b) => a.eventDatetime.compareTo(b.eventDatetime));
      state = state.copyWith(events: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> addEvent(CalendarEvent event) async {
    state = state.copyWith(isSaving: true);
    try {
      final response = await _api.post(
        '/calendar_events',
        data: event.toJson(),
      );
      final created = CalendarEvent.fromJson(response.data);
      state = state.copyWith(
        events: [...state.events, created],
        isSaving: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateEvent(CalendarEvent event) async {
    state = state.copyWith(isSaving: true);
    try {
      final response = await _api.put(
        '/calendar_events/${event.id}',
        data: event.toJson(),
      );
      final updated = CalendarEvent.fromJson(response.data);
      state = state.copyWith(
        events: state.events
            .map((e) => e.id == updated.id ? updated : e)
            .toList(),
        isSaving: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _api.delete('/calendar_events/$id');
      state = state.copyWith(
        events: state.events.where((e) => e.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final calendarProvider = NotifierProvider<CalendarNotifier, CalendarState>(() {
  return CalendarNotifier();
});
