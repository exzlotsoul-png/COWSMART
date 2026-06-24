import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/farm.dart';

class FarmState {
  final List<Farm> farms;
  final Farm? currentFarm;
  final bool isLoading;
  final String? errorMessage;

  FarmState({
    this.farms = const [],
    this.currentFarm,
    this.isLoading = false,
    this.errorMessage,
  });

  FarmState copyWith({
    List<Farm>? farms,
    Farm? currentFarm,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FarmState(
      farms: farms ?? this.farms,
      currentFarm: currentFarm ?? this.currentFarm,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FarmNotifier extends Notifier<FarmState> {
  late final ApiClient _api;

  @override
  FarmState build() {
    _api = ref.watch(apiClientProvider);
    // Initial fetch
    Future.microtask(() => fetchFarms());
    return FarmState();
  }

  Future<void> fetchFarms() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[FETCH] กำลังดึงข้อมูลฟาร์ม...');
      final response = await _api.get('/farms');
      final List<dynamic> data = response.data;
      final List<Farm> farms = data.map((json) => Farm.fromJson(json)).toList();

      print('[SUCCESS] ดึงข้อมูลฟาร์มสำเร็จ: ${farms.length} รายการ');
      state = state.copyWith(
        farms: farms,
        currentFarm: farms.isNotEmpty ? farms.first : null,
        isLoading: false,
      );
    } catch (e) {
      print('[ERROR] ดึงข้อมูลฟาร์มไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Farm?> addFarm({
    required String name,
    required String address,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post(
        '/farms',
        data: {'name': name, 'address': address, 'image_url': imageUrl},
      );
      final newFarm = Farm.fromJson(response.data);
      state = state.copyWith(
        farms: [...state.farms, newFarm],
        currentFarm: newFarm,
        isLoading: false,
      );
      print('[SUCCESS] สร้างฟาร์มสำเร็จ: ${newFarm.name}');
      return newFarm;
    } catch (e) {
      print('[ERROR] สร้างฟาร์มไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  void selectFarm(Farm farm) {
    state = state.copyWith(currentFarm: farm);
  }

  Future<void> updateFarm({
    required String farmId,
    required String name,
    required String address,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.put(
        '/farms/$farmId',
        data: {
          'name': name,
          'address': address,
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      final updatedFarm = Farm.fromJson(response.data);
      state = state.copyWith(
        farms: state.farms
            .map((f) => f.id == farmId ? updatedFarm : f)
            .toList(),
        currentFarm: state.currentFarm?.id == farmId
            ? updatedFarm
            : state.currentFarm,
        isLoading: false,
      );
      print('[SUCCESS] อัปเดตฟาร์มสำเร็จ: $name');
    } catch (e) {
      print('[ERROR] อัปเดตฟาร์มไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final farmProvider = NotifierProvider<FarmNotifier, FarmState>(() {
  return FarmNotifier();
});
