import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/zone.dart';

class ZoneState {
  final List<Zone> zones;
  final bool isLoading;
  final String? errorMessage;

  ZoneState({this.zones = const [], this.isLoading = false, this.errorMessage});

  ZoneState copyWith({
    List<Zone>? zones,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ZoneState(
      zones: zones ?? this.zones,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ZoneNotifier extends Notifier<ZoneState> {
  late final ApiClient _api;

  @override
  ZoneState build() {
    _api = ref.watch(apiClientProvider);
    return ZoneState();
  }

  Future<void> fetchZones(String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.get('/zones', query: {'farm_id': farmId});
      final List<dynamic> data = response.data;
      final List<Zone> zones = data.map((json) => Zone.fromJson(json)).toList();

      state = state.copyWith(zones: zones, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final zoneProvider = NotifierProvider<ZoneNotifier, ZoneState>(() {
  return ZoneNotifier();
});
