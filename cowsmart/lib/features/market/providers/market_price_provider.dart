import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/market_price.dart';

class MarketPriceState {
  final MarketPrice? latest;
  final List<MarketPrice> byCategory;
  final bool isLoading;
  final String? errorMessage;

  MarketPriceState({
    this.latest,
    this.byCategory = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MarketPriceState copyWith({
    MarketPrice? latest,
    List<MarketPrice>? byCategory,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MarketPriceState(
      latest: latest ?? this.latest,
      byCategory: byCategory ?? this.byCategory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MarketPriceNotifier extends Notifier<MarketPriceState> {
  late final ApiClient _api;

  @override
  MarketPriceState build() {
    _api = ref.watch(apiClientProvider);
    return MarketPriceState();
  }

  Future<void> fetchLatest({String animalType = 'cattle'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.get(
        '/market_prices',
        query: {'animal_type': animalType},
      );
      final data = response.data as Map<String, dynamic>;

      final latest = data['latest'] != null
          ? MarketPrice.fromJson(data['latest'])
          : null;

      final byCategory = (data['by_category'] as List<dynamic>? ?? [])
          .map((j) => MarketPrice.fromJson(j))
          .toList();

      state = state.copyWith(
        latest: latest,
        byCategory: byCategory,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addPrice({
    required double pricePerKg,
    required DateTime effectiveDate,
    String animalType = 'cattle',
    String? category,
    String? source,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.post('/market_prices', data: {
        'animal_type': animalType,
        'category': category,
        'price_per_kg': pricePerKg,
        'effective_date': effectiveDate.toIso8601String().split('T')[0],
        'source': source,
        'note': note,
      });
      await fetchLatest(animalType: animalType);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final marketPriceProvider =
    NotifierProvider<MarketPriceNotifier, MarketPriceState>(() {
  return MarketPriceNotifier();
});
