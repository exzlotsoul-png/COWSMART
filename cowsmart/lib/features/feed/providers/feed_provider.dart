import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/feed.dart';

class FeedState {
  final bool isLoading;
  final String? errorMessage;
  final List<FeedItem> inventory;

  FeedState({
    this.isLoading = false,
    this.errorMessage,
    this.inventory = const [],
  });

  FeedState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<FeedItem>? inventory,
  }) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inventory: inventory ?? this.inventory,
    );
  }
}

class FeedNotifier extends Notifier<FeedState> {
  late final ApiClient _api;

  @override
  FeedState build() {
    _api = ref.watch(apiClientProvider);
    return FeedState();
  }

  Future<void> fetchFeedInventory(String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[FETCH] กำลังดึงข้อมูลคลังอาหารของฟาร์ม $farmId...');
      final response = await _api.get(
        '/feed_inventories',
        query: {'farm_id': farmId},
      );
      final List<dynamic> data = response.data;
      final List<FeedItem> inventory = data
          .map((json) => FeedItem.fromJson(json))
          .toList();

      print('[SUCCESS] ดึงข้อมูลคลังอาหารสำเร็จ: ${inventory.length} รายการ');
      state = state.copyWith(inventory: inventory, isLoading: false);
    } catch (e) {
      print('[ERROR] ดึงข้อมูลคลังอาหารไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addFeed(FeedItem item) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[CREATE] กำลังเพิ่มอาหารใหม่: ${item.name}...');
      final response = await _api.post(
        '/feed_inventories',
        data: item.toJson(),
      );
      final newFeed = FeedItem.fromJson(response.data);

      print('[SUCCESS] เพิ่มอาหารสำเร็จ: ${newFeed.name}');
      state = state.copyWith(
        isLoading: false,
        inventory: [...state.inventory, newFeed],
      );
    } catch (e) {
      print('[ERROR] เพิ่มอาหารไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateFeed(FeedItem item) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[UPDATE] กำลังแก้ไขข้อมูลอาหาร: ${item.id}...');
      final response = await _api.put(
        '/feed_inventories/${item.id}',
        data: item.toJson(),
      );
      final updated = FeedItem.fromJson(response.data);

      print('[SUCCESS] แก้ไขข้อมูลอาหารสำเร็จ: ${updated.name}');
      state = state.copyWith(
        isLoading: false,
        inventory: state.inventory
            .map((f) => f.id == updated.id ? updated : f)
            .toList(),
      );
    } catch (e) {
      print('[ERROR] แก้ไขบันทึกไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteFeed(String feedId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[DELETE] กำลังลบอาหาร: $feedId...');
      await _api.delete('/feed_inventories/$feedId');

      print('[SUCCESS] ลบอาหารสำเร็จ');
      state = state.copyWith(
        isLoading: false,
        inventory: state.inventory.where((f) => f.id != feedId).toList(),
      );
    } catch (e) {
      print('[ERROR] ลบอาหารไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});
