import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/market_price.dart';

class MarketPriceState {
  final MarketPrice? latest;
  final List<MarketPrice> byCategory;
  final List<MarketPrice> allPrices;
  final Map<String, List<MarketPrice>> history;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;

  MarketPriceState({
    this.latest,
    this.byCategory = const [],
    this.allPrices = const [],
    this.history = const {},
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
  });

  MarketPriceState copyWith({
    MarketPrice? latest,
    List<MarketPrice>? byCategory,
    List<MarketPrice>? allPrices,
    Map<String, List<MarketPrice>>? history,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
  }) {
    return MarketPriceState(
      latest: latest ?? this.latest,
      byCategory: byCategory ?? this.byCategory,
      allPrices: allPrices ?? this.allPrices,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// ดึงราคากลางโคพันธุ์ลูกผสม ขนาดกลาง (สศก. / NABC)
  double get nabcCentralPrice {
    try {
      final match = allPrices.firstWhere(
        (p) => (p.category != null && p.category!.contains('โคพันธุ์ลูกผสม')) ||
               (p.source != null && p.source!.contains('NABC')),
      );
      if (match.pricePerKg > 0) return match.pricePerKg;
    } catch (_) {
      try {
        final match = byCategory.firstWhere(
          (p) => (p.category != null && p.category!.contains('โคพันธุ์ลูกผสม')) ||
                 (p.source != null && p.source!.contains('NABC')),
        );
        if (match.pricePerKg > 0) return match.pricePerKg;
      } catch (_) {}
    }
    return 95.43; // default fallback
  }

  /// ดึงราคาตามชื่อหมวดหมู่ (เช่น 'ลูกผสมบราห์มัน (>400')
  double? getPriceForCategory(String keyword) {
    try {
      final match = allPrices.firstWhere(
        (p) => p.category != null && p.category!.contains(keyword),
      );
      return match.pricePerKg > 0 ? match.pricePerKg : null;
    } catch (_) {
      try {
        final match = byCategory.firstWhere(
          (p) => p.category != null && p.category!.contains(keyword),
        );
        return match.pricePerKg > 0 ? match.pricePerKg : null;
      } catch (_) {
        return null;
      }
    }
  }

  /// คำนวณราคาต่อกิโลกรัมตามสายพันธุ์และน้ำหนักตัวของวัว
  /// หากสายพันธุ์ไม่มีในราคาตลาดของกรมปศุสัตว์ ให้อิงตาม "ราคากลางโคพันธุ์ลูกผสม ขนาดกลาง" (สศก. / NABC)
  double calculatePricePerKg({String? breedName, double weight = 0.0}) {
    final bName = (breedName ?? '').toLowerCase().trim();

    // 1. ตระกูลบราห์มัน (Brahman)
    if (bName.contains('บราห์มัน') || bName.contains('brahman')) {
      if (weight > 400) {
        final p = getPriceForCategory('ลูกผสมบราห์มัน (>400');
        if (p != null) return p;
      } else {
        final p = getPriceForCategory('ลูกผสมบราห์มัน (>250');
        if (p != null) return p;
      }
    }

    // 2. ตระกูลพื้นเมืองไทย (Thai Native)
    if (bName.contains('พื้นเมือง') || bName.contains('native')) {
      if (weight > 250) {
        final p = getPriceForCategory('พื้นเมืองไทย (>250');
        if (p != null) return p;
      } else {
        final p = getPriceForCategory('พื้นเมืองไทย (≤250') ?? getPriceForCategory('พื้นเมืองไทย (<=250');
        if (p != null) return p;
      }
    }

    // 3. ตระกูลลูกผสมยุโรป (European Crossbred เช่น ชาร์โรเลส์, เฮียฟอร์ด, ซิมเมนทัล, ลิมูซิน)
    if (bName.contains('ยุโรป') ||
        bName.contains('ชาร์โรเลส์') ||
        bName.contains('charolais') ||
        bName.contains('เฮียฟอร์ด') ||
        bName.contains('hereford') ||
        bName.contains('ซิมเมนทัล') ||
        bName.contains('simmental') ||
        bName.contains('ลิมูซิน') ||
        bName.contains('limousin')) {
      if (weight > 400) {
        final p = getPriceForCategory('ลูกผสมยุโรป (>400');
        if (p != null) return p;
      } else {
        final p = getPriceForCategory('ลูกผสมยุโรป (>250');
        if (p != null) return p;
      }
    }

    // 4. พันธุ์อื่นๆ ที่ไม่มีในราคาตลาด หรือระบุไม่ชัดเจน
    // ให้อิงตาม "ราคากลางโคพันธุ์ลูกผสม ขนาดกลาง" (สศก. / NABC)
    return nabcCentralPrice;
  }

  /// คำนวณมูลค่ารวมของวัว (น้ำหนักตัว × ราคาต่อ กก. ตามตลาด)
  double calculateEstimatedValue({String? breedName, double weight = 0.0}) {
    if (weight <= 0) return 0.0;
    final pricePerKg = calculatePricePerKg(breedName: breedName, weight: weight);
    return weight * pricePerKg;
  }
}

class MarketPriceNotifier extends Notifier<MarketPriceState> {
  late final ApiClient _api;

  @override
  MarketPriceState build() {
    _api = ref.watch(apiClientProvider);
    Future.microtask(() => fetchLatest());
    return MarketPriceState();
  }

  Future<void> fetchLatest({
    String animalType = 'cattle',
    String? year,
    String? month,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final Map<String, dynamic> queryParams = {'animal_type': animalType};
      if (year != null && year != 'all') {
        queryParams['year'] = year;
      }
      if (month != null && month != 'all') {
        queryParams['month'] = month;
      }

      final response = await _api.get(
        '/market_prices',
        query: queryParams,
      );
      final data = response.data as Map<String, dynamic>;

      final latest = data['latest'] != null
          ? MarketPrice.fromJson(data['latest'])
          : null;

      final byCategory = (data['by_category'] as List<dynamic>? ?? [])
          .map((j) => MarketPrice.fromJson(j))
          .toList();

      final allPrices = (data['data'] as List<dynamic>? ?? [])
          .map((j) => MarketPrice.fromJson(j))
          .toList();

      state = state.copyWith(
        latest: latest,
        byCategory: byCategory,
        allPrices: allPrices,
        isLoading: false,
      );

      // Fetch history in background for charts
      fetchHistory(animalType: animalType, year: year ?? '2569', month: month ?? '08');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> syncLivePrice({
    String animalType = 'cattle',
    String? yearTh,
    String? month,
  }) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final Map<String, dynamic> payload = {'animal_type': animalType};
      if (yearTh != null && yearTh != 'all') {
        payload['year_th'] = yearTh;
      }
      if (month != null && month != 'all') {
        payload['month'] = month;
      }

      await _api.post('/market_prices/sync', data: payload);
      await fetchLatest(animalType: animalType, year: yearTh, month: month);
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchHistory({
    String animalType = 'cattle',
    int? days,
    String? year,
    String? month,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {'animal_type': animalType};
      if (days != null && days > 0) {
        queryParams['days'] = days;
      }
      if (year != null && year != 'all') {
        queryParams['year'] = year;
      }
      if (month != null && month != 'all') {
        queryParams['month'] = month;
      }

      final response = await _api.get(
        '/market_prices/history',
        query: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final rawHistory = data['history'] as Map<String, dynamic>? ?? {};

      final Map<String, List<MarketPrice>> parsedHistory = {};
      rawHistory.forEach((key, list) {
        if (list is List) {
          parsedHistory[key] = list.map((j) => MarketPrice.fromJson(j)).toList();
        }
      });

      state = state.copyWith(history: parsedHistory);
    } catch (_) {}
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
