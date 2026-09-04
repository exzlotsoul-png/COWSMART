import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import '../../providers/market_price_provider.dart';
import '../../domain/market_price.dart';

class MarketPriceHistoryScreen extends ConsumerStatefulWidget {
  const MarketPriceHistoryScreen({super.key});

  @override
  ConsumerState<MarketPriceHistoryScreen> createState() => _MarketPriceHistoryScreenState();
}

class _MarketPriceHistoryScreenState extends ConsumerState<MarketPriceHistoryScreen> {
  String _searchQuery = '';
  String _selectedYear = 'all';
  String _selectedMonth = 'all';
  String _selectedCategory = 'all';

  final List<Map<String, String>> _thaiMonths = const [
    {'value': 'all', 'name': 'ทุกเดือน'},
    {'value': '01', 'name': 'มกราคม'},
    {'value': '02', 'name': 'กุมภาพันธ์'},
    {'value': '03', 'name': 'มีนาคม'},
    {'value': '04', 'name': 'เมษายน'},
    {'value': '05', 'name': 'พฤษภาคม'},
    {'value': '06', 'name': 'มิถุนายน'},
    {'value': '07', 'name': 'กรกฎาคม'},
    {'value': '08', 'name': 'สิงหาคม'},
    {'value': '09', 'name': 'กันยายน'},
    {'value': '10', 'name': 'ตุลาคม'},
    {'value': '11', 'name': 'พฤศจิกายน'},
    {'value': '12', 'name': 'ธันวาคม'},
  ];

  final List<Map<String, String>> _availableYears = const [
    {'value': 'all', 'name': 'ทุกปี'},
    {'value': '2569', 'name': '2569'},
    {'value': '2568', 'name': '2568'},
    {'value': '2567', 'name': '2567'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrices();
    });
  }

  void _loadPrices() {
    ref.read(marketPriceProvider.notifier).fetchLatest(
          year: _selectedYear,
          month: _selectedMonth,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketPriceProvider);
    final formatter = NumberFormat('#,##0.00');

    // Filter items
    final filtered = state.allPrices.filter((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          (item.category != null && item.category!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          (item.source != null && item.source!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          (item.note != null && item.note!.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesCat = _selectedCategory == 'all' || item.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('ประวัติราคากลางทั้งหมด'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(color: AppColors.text(context)),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาหมวดหมู่, สัปดาห์, แหล่งที่มา...',
                    hintStyle: TextStyle(color: AppColors.hint(context)),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.subText(context)),
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Year & Month Filters Row
                Row(
                  children: [
                    // Year
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfAlt(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.brd(context)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedYear,
                            isDense: true,
                            dropdownColor: AppColors.cardBg(context),
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _availableYears.map((y) {
                              return DropdownMenuItem<String>(
                                value: y['value'],
                                child: Text('ปี ${y['name']}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedYear = val);
                                _loadPrices();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Month
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfAlt(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.brd(context)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMonth,
                            isDense: true,
                            dropdownColor: AppColors.cardBg(context),
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _thaiMonths.map((m) {
                              return DropdownMenuItem<String>(
                                value: m['value'],
                                child: Text(m['name']!),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedMonth = val);
                                _loadPrices();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total counts bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'พบทั้งหมด ${filtered.length} รายการ',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                if (_selectedYear != 'all' || _selectedMonth != 'all' || _searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedYear = 'all';
                        _selectedMonth = 'all';
                        _searchQuery = '';
                      });
                      _loadPrices();
                    },
                    child: const Text(
                      'ล้างตัวกรอง',
                      style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // List content
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'ไม่พบข้อมูลประวัติราคาในช่วงเวลาที่เลือก',
                          style: TextStyle(color: AppColors.textHint, fontSize: 13),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadPrices(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final item = filtered[idx];
                            return _buildHistoryCard(item, formatter);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(MarketPrice price, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  price.category ?? 'โคเนื้อทั่วไป',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.text(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '฿ ${formatter.format(price.pricePerKg)} / กก.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.subText(context)),
              const SizedBox(width: 4),
              Text(
                AppDateUtils.formatThaiDate(price.effectiveDate),
                style: TextStyle(fontSize: 11, color: AppColors.subText(context)),
              ),
              const SizedBox(width: 12),
              Icon(Icons.source_outlined, size: 13, color: AppColors.subText(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  price.source ?? 'NABC AGRI API',
                  style: TextStyle(fontSize: 11, color: AppColors.subText(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (price.note != null && price.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                price.note!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _ListFilter<T> on List<T> {
  List<T> filter(bool Function(T element) test) {
    final result = <T>[];
    for (var element in this) {
      if (test(element)) {
        result.add(element);
      }
    }
    return result;
  }
}
