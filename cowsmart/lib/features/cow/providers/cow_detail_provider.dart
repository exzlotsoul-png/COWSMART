import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import '../domain/growth_record.dart';
import '../domain/health_record.dart';
import '../domain/breeding_record.dart';

class CowDetailState {
  final List<GrowthRecord> growthRecords;
  final List<HealthRecord> healthRecords;
  final List<BreedingRecord> breedingRecords;
  final bool isLoading;
  final bool isSaving;
  final bool isSuccess;
  final String? error;

  CowDetailState({
    this.growthRecords = const [],
    this.healthRecords = const [],
    this.breedingRecords = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isSuccess = false,
    this.error,
  });

  CowDetailState copyWith({
    List<GrowthRecord>? growthRecords,
    List<HealthRecord>? healthRecords,
    List<BreedingRecord>? breedingRecords,
    bool? isLoading,
    bool? isSaving,
    bool? isSuccess,
    String? error,
  }) {
    return CowDetailState(
      growthRecords: growthRecords ?? this.growthRecords,
      healthRecords: healthRecords ?? this.healthRecords,
      breedingRecords: breedingRecords ?? this.breedingRecords,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
    );
  }
}

class CowDetailNotifier extends Notifier<CowDetailState> {
  @override
  CowDetailState build() {
    return CowDetailState();
  }

  Future<void> fetchAllData(String cowId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiClientProvider);

      final List<Response> responses = await Future.wait<Response>([
        api.get('/growth_records', query: {'cow_id': cowId}),
        api.get('/health_records', query: {'cow_id': cowId}),
        api.get('/breeding_records', query: {'cow_id': cowId}),
      ]);

      final cowGrowth = (responses[0].data as List)
          .map((j) => GrowthRecord.fromJson(j))
          .toList();
      final cowHealth = (responses[1].data as List)
          .map((j) => HealthRecord.fromJson(j))
          .toList();
      final cowBreeding = (responses[2].data as List)
          .map((j) => BreedingRecord.fromJson(j))
          .toList();

      state = state.copyWith(
        growthRecords: cowGrowth
          ..sort((a, b) => b.recordDate.compareTo(a.recordDate)),
        healthRecords: cowHealth,
        breedingRecords: cowBreeding,
        isLoading: false,
      );
      print('[SUCCESS] ดึงรายละเอียดวัว $cowId สำเร็จ');
    } catch (e) {
      print('[ERROR] ดึงรายละเอียดวัว $cowId: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addGrowthRecord(GrowthRecord record) async {
    state = state.copyWith(isSaving: true, error: null, isSuccess: false);
    try {
      final api = ref.read(apiClientProvider);
      print('[WEIGHT] กำลังบันทึกน้ำหนัก ${record.weight} กก...');
      final response = await api.post('/growth_records', data: record.toJson());
      final newRecord = GrowthRecord.fromJson(response.data);

      // Add to top of list (newest first)
      final updated = [newRecord, ...state.growthRecords];
      state = state.copyWith(
        growthRecords: updated,
        isSaving: false,
        isSuccess: true,
      );

      // Sync latest_weight back to the cows table so BasicInfoTab shows correct weight
      try {
        await api.put(
          '/cows/${record.cowId}',
          data: {'latest_weight': record.weight},
        );
        // Also update the in-memory cow state so CowListScreen shows correct weight immediately
        ref
            .read(cowProvider.notifier)
            .syncCowWeight(record.cowId, record.weight);
        print('[SUCCESS] อัปเดตน้ำหนักล่าสุดในวัวสำเร็จ: ${record.weight} กก.');
      } catch (e) {
        print('อัปเดต latest_weight ในวัวไม่สำเร็จ (ไม่บล็อกหน้าจอ): $e');
      }

      print('บันทึกน้ำหนักสำเร็จ');
    } catch (e) {
      print('บันทึกน้ำหนักไม่สำเร็จ: $e');
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> addHealthRecord(HealthRecord record) async {
    state = state.copyWith(isSaving: true, error: null, isSuccess: false);
    try {
      final api = ref.read(apiClientProvider);
      print('กำลังบันทึกการรักษา...');
      final response = await api.post('/health_records', data: record.toJson());
      final newRecord = HealthRecord.fromJson(response.data);

      final updated = [newRecord, ...state.healthRecords];
      state = state.copyWith(
        healthRecords: updated,
        isSaving: false,
        isSuccess: true,
      );
      print('บันทึกการรักษาสำเร็จ: ${newRecord.id}');
    } catch (e) {
      print('บันทึกการรักษาไม่สำเร็จ: $e');
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> addBreedingRecord(BreedingRecord record) async {
    state = state.copyWith(isSaving: true, error: null, isSuccess: false);
    try {
      final api = ref.read(apiClientProvider);

      // Check if this is an update (record exists in local state with same ID)
      final existingIndex = state.breedingRecords.indexWhere(
        (r) => r.id == record.id,
      );
      final isUpdate = existingIndex >= 0;

      if (isUpdate) {
        // Use PUT to update existing record
        print('[UPDATE] กำลังอัปเดตการผสมพันธุ์: ${record.id}');
        final response = await api.put(
          '/breeding_records/${record.id}',
          data: record.toJson(),
        );
        final updatedRecord = BreedingRecord.fromJson(response.data);

        final updated = [...state.breedingRecords];
        updated[existingIndex] = updatedRecord;

        state = state.copyWith(
          breedingRecords: updated,
          isSaving: false,
          isSuccess: true,
        );
        print('[SUCCESS] อัปเดตการผสมพันธุ์สำเร็จ: ${updatedRecord.id}');
      } else {
        // Use POST for new record
        print('[CREATE] กำลังสร้างการผสมพันธุ์ใหม่...');
        final response = await api.post(
          '/breeding_records',
          data: record.toJson(),
        );
        final newRecord = BreedingRecord.fromJson(response.data);

        final updated = [newRecord, ...state.breedingRecords];
        state = state.copyWith(
          breedingRecords: updated,
          isSaving: false,
          isSuccess: true,
        );
        print('[SUCCESS] บันทึกการผสมพันธุ์สำเร็จ: ${newRecord.id}');
      }
    } catch (e) {
      print('[ERROR] บันทึกการผสมพันธุ์ไม่สำเร็จ: $e');
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  void clearFlags() {
    state = state.copyWith(isSuccess: false, error: null);
  }

  void resetState() {
    state = CowDetailState();
  }
}

final cowDetailProvider = NotifierProvider<CowDetailNotifier, CowDetailState>(
  () => CowDetailNotifier(),
);
