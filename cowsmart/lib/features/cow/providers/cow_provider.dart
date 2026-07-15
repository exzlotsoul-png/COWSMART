import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/cow.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import '../domain/culling_record.dart';

class CowState {
  final List<Cow> allCows;
  final String? searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final CowStatus? filterStatus;
  final CowType? filterType;
  final String? filterGender;

  CowState({
    this.allCows = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.filterStatus,
    this.filterType,
    this.filterGender,
  });

  bool get hasActiveFilter =>
      filterStatus != null || filterType != null || filterGender != null;

  List<Cow> get filteredCows {
    var cows = allCows;
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final q = searchQuery!.toLowerCase();
      cows = cows
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.tagNumber.toLowerCase().contains(q),
          )
          .toList();
    }
    if (filterStatus != null) {
      cows = cows.where((c) => c.status == filterStatus).toList();
    }
    if (filterType != null) {
      cows = cows.where((c) => c.type == filterType).toList();
    }
    if (filterGender != null) {
      cows = cows.where((c) => c.gender == filterGender).toList();
    }
    return cows;
  }

  CowState copyWith({
    List<Cow>? allCows,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    Object? filterStatus = _sentinel,
    Object? filterType = _sentinel,
    Object? filterGender = _sentinel,
  }) {
    return CowState(
      allCows: allCows ?? this.allCows,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      filterStatus: filterStatus == _sentinel
          ? this.filterStatus
          : filterStatus as CowStatus?,
      filterType: filterType == _sentinel
          ? this.filterType
          : filterType as CowType?,
      filterGender: filterGender == _sentinel
          ? this.filterGender
          : filterGender as String?,
    );
  }
}

const _sentinel = Object();

class CowNotifier extends Notifier<CowState> {
  late final ApiClient _api;

  @override
  CowState build() {
    _api = ref.watch(apiClientProvider);
    return CowState();
  }

  Future<void> fetchCows(String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[FETCH] กำลังดึงข้อมูลวัวของฟาร์ม $farmId...');
      final response = await _api.get('/cows', query: {'farm_id': farmId});
      final List<dynamic> data = response.data;
      final List<Cow> farmCows = data
          .map((json) => Cow.fromJson(json))
          .toList();

      print('[SUCCESS] ดึงข้อมูลวัวสำเร็จ: ${farmCows.length} ตัว');

      state = state.copyWith(allCows: farmCows, isLoading: false);
    } catch (e) {
      print('[ERROR] ดึงข้อมูลวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter({
    Object? filterStatus = _sentinel,
    Object? filterType = _sentinel,
    Object? filterGender = _sentinel,
  }) {
    state = state.copyWith(
      filterStatus: filterStatus,
      filterType: filterType,
      filterGender: filterGender,
    );
  }

  void clearFilters() {
    state = state.copyWith(
      filterStatus: null,
      filterType: null,
      filterGender: null,
    );
  }

  Future<void> addCow(Cow cow) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[CREATE] กำลังบันทึกข้อมูลวัวใหม่: ${cow.name}...');
      final response = await _api.post('/cows', data: cow.toJson());
      final newCow = Cow.fromJson(response.data);

      print('[SUCCESS] บันทึกข้อมูลวัวสำเร็จ: ${newCow.name}');
      state = state.copyWith(
        allCows: [...state.allCows, newCow],
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] บันทึกข้อมูลวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateCow(Cow cow) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[UPDATE] กำลังแก้ไขข้อมูลวัว: ${cow.id}...');
      final response = await _api.put('/cows/${cow.id}', data: cow.toJson());
      final updated = Cow.fromJson(response.data);

      print('[SUCCESS] แก้ไขข้อมูลวัวสำเร็จ: ${updated.name}');
      state = state.copyWith(
        allCows: state.allCows
            .map((c) => c.id == updated.id ? updated : c)
            .toList(),
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] แก้ไขข้อมูลวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateCowZone(String cowId, String zoneId, String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[UPDATE ZONE] กำลังย้ายวัว $cowId ไปโซน $zoneId...');

      // Find the cow first
      final cow = state.allCows.firstWhere((c) => c.id == cowId);
      final updatedCow = cow.copyWith(zoneId: zoneId);

      // Call API to update cow's zone
      final response = await _api.put(
        '/cows/$cowId',
        data: {...updatedCow.toJson(), 'zone_id': zoneId},
      );

      final result = Cow.fromJson(response.data);
      print('[SUCCESS] ย้ายวัวสำเร็จ: ${result.name} -> โซน $zoneId');

      // Update state
      state = state.copyWith(
        allCows: state.allCows
            .map((c) => c.id == result.id ? result : c)
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      print('[ERROR] ย้ายวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      throw e;
    }
  }

  Future<void> cullCow(CullingRecord record) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[DELETE] กำลังบันทึกการคัดทิ้งวัว: ${record.cowId}...');
      await _api.post('/culling_records', data: record.toJson());

      print('[SUCCESS] บันทึกการคัดทิ้งสำเร็จ');
      state = state.copyWith(
        allCows: state.allCows.where((c) => c.id != record.cowId).toList(),
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] บันทึกการคัดทิ้งไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> restoreCulledCow(String cullingRecordId, Cow cow) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[RESTORE] กำลังกู้คืนวัว: ${cow.tagNumber}...');
      await _api.delete('/culling_records/$cullingRecordId');

      final restoredCow = cow.copyWith(status: CowStatus.normal);

      print('[SUCCESS] กู้คืนวัวสำเร็จ');
      state = state.copyWith(
        allCows: [...state.allCows, restoredCow],
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] กู้คืนวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> cullCowsGroup(List<CullingRecord> records) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[CREATE] กำลังบันทึกการคัดทิ้งแบบกลุ่ม: ${records.length} ตัว...');
      final payload = {
        'records': records.map((r) => r.toJson()).toList(),
      };
      await _api.post('/culling_records', data: payload);

      print('[SUCCESS] บันทึกการคัดทิ้งแบบกลุ่มสำเร็จ');
      final recordCowIds = records.map((r) => r.cowId).toSet();
      state = state.copyWith(
        allCows: state.allCows.where((c) => !recordCowIds.contains(c.id)).toList(),
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] บันทึกการคัดทิ้งแบบกลุ่มไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteCow(String cowId) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      print('[DELETE] กำลังลบข้อมูลวัว: $cowId...');
      await _api.delete('/cows/$cowId');

      print('[SUCCESS] ลบข้อมูลวัวสำเร็จ');
      state = state.copyWith(
        allCows: state.allCows.where((c) => c.id != cowId).toList(),
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      print('[ERROR] ลบข้อมูลวัวไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// อัปเดตน้ำหนักของวัวใน state หน่วยความจำ (ไม่เรียก API ซ้ำ)
  void syncCowWeight(String cowId, double newWeight) {
    state = state.copyWith(
      allCows: state.allCows.map((c) {
        if (c.id == cowId) return c.copyWith(latestWeight: newWeight);
        return c;
      }).toList(),
    );
    print('[SYNC] อัปเดตน้ำหนักวัว $cowId ใน state เป็น $newWeight กก.');
  }

  /// อัปเดตข้อมูลวัวทั้งตัวใน state หน่วยความจำ (ใช้หลังอัปโหลดรูป)
  void syncCow(Cow updatedCow) {
    state = state.copyWith(
      allCows: state.allCows.map((c) {
        if (c.id == updatedCow.id) return updatedCow;
        return c;
      }).toList(),
    );
    print('[SYNC] อัปเดตข้อมูลวัว ${updatedCow.id} ใน state (เช่น รูปภาพใหม่)');
  }

  void clearFlags() {
    state = state.copyWith(errorMessage: null, isSuccess: false);
  }
}

final cowProvider = NotifierProvider<CowNotifier, CowState>(() {
  return CowNotifier();
});

final activeCowsProvider = Provider<List<Cow>>((ref) {
  final currentFarm = ref.watch(farmProvider).currentFarm;
  final cowState = ref.watch(cowProvider);
  if (currentFarm == null) return [];
  return cowState.filteredCows;
});
