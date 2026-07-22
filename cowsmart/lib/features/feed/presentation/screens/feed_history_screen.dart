import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/feed/providers/feed_provider.dart';
import 'package:cowsmart/features/feed/domain/feed.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';

class FeedHistoryScreen extends ConsumerStatefulWidget {
  const FeedHistoryScreen({super.key});

  @override
  ConsumerState<FeedHistoryScreen> createState() => _FeedHistoryScreenState();
}

class _FeedHistoryScreenState extends ConsumerState<FeedHistoryScreen> {
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFarm = ref.watch(farmProvider).currentFarm;
    final feedState = ref.watch(feedProvider);
    final allItems = feedState.inventory;

    // Filter items by date range, category, and search query
    final filteredItems = allItems.where((item) {
      if (_dateRange != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 0, 0, 0);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
        if (item.recordedAt.isBefore(start) || item.recordedAt.isAfter(end)) {
          return false;
        }
      }
      if (_selectedCategory != null && item.category.apiValue != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.name.toLowerCase().contains(q);
        final matchCategory = item.category.name.toLowerCase().contains(q);
        if (!matchName && !matchCategory) return false;
      }
      return true;
    }).toList();

    // Sort by recordedAt descending
    filteredItems.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final totalQuantity = filteredItems.fold<double>(0, (sum, i) => sum + i.quantity);
    final totalCost = filteredItems.fold<double>(0, (sum, i) => sum + i.cost);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ประวัติการให้อาหารทั้งหมด'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () {
              if (currentFarm != null) {
                ref.read(feedProvider.notifier).fetchFeedInventory(currentFarm.id);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section: Date Range Picker, Preset Chips & Search bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range picker row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            initialDateRange: _dateRange ?? DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 7)),
                              end: DateTime.now(),
                            ),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            helpText: 'เลือกช่วงวันที่ (เริ่มต้น - สิ้นสุด)',
                            cancelText: 'ยกเลิก',
                            confirmText: 'ตกลง',
                            saveText: 'ตกลง',
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _dateRange != null ? AppColors.primary : AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                            color: _dateRange != null ? AppColors.primary.withValues(alpha: 0.05) : Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateRange != null
                                      ? '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)}  ถึง  ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'
                                      : 'เลือกช่วงวันที่ (วันไหนถึงวันไหน)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _dateRange != null ? FontWeight.bold : FontWeight.normal,
                                    color: _dateRange != null ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _dateRange = null),
                        icon: const Icon(Icons.clear, color: Colors.red),
                        tooltip: 'ล้างวันที่',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Quick Date Range Presets
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: const Text('7 วันล่าสุด', style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _dateRange = DateTimeRange(
                              start: now.subtract(const Duration(days: 7)),
                              end: now,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('30 วันล่าสุด', style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _dateRange = DateTimeRange(
                              start: now.subtract(const Duration(days: 30)),
                              end: now,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('เดือนนี้', style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final now = DateTime.now();
                          final start = DateTime(now.year, now.month, 1);
                          final end = DateTime(now.year, now.month + 1, 0);
                          setState(() {
                            _dateRange = DateTimeRange(start: start, end: end);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยชื่ออาหารหรือหมวดหมู่...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ทั้งหมด'),
                        selected: _selectedCategory == null,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('หญ้า'),
                        selected: _selectedCategory == 'หญ้า',
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setState(() => _selectedCategory = selected ? 'หญ้า' : null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('ข้น'),
                        selected: _selectedCategory == 'ข้น',
                        selectedColor: Colors.orange.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setState(() => _selectedCategory = selected ? 'ข้น' : null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('เสริม'),
                        selected: _selectedCategory == 'เสริม',
                        selectedColor: Colors.purple.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setState(() => _selectedCategory = selected ? 'เสริม' : null);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Summary Header Bar
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'พบ ${filteredItems.length} รายการ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  'รวม ${totalQuantity.toStringAsFixed(1)} กก. (${NumberFormat('#,##0').format(totalCost)} ฿)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ],
            ),
          ),

          // Feed items list
          Expanded(
            child: feedState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feed_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'ไม่พบประวัติการให้อาหาร',
                              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildHistoryCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(FeedItem item) {
    final zones = ref.watch(zoneProvider).zones;
    final zoneObj = (item.zoneId != null && item.zoneId!.isNotEmpty)
        ? zones.cast<Zone?>().firstWhere((z) => z?.id == item.zoneId, orElse: () => null)
        : null;
    final zoneText = zoneObj != null
        ? zoneObj.name
        : (item.zoneId != null && item.zoneId!.isNotEmpty ? item.zoneId! : 'ทุกโซน');

    Color categoryColor;
    IconData categoryIcon;
    switch (item.category.id) {
      case 'grass':
        categoryColor = Colors.green;
        categoryIcon = Icons.grass;
        break;
      case 'concentrate':
        categoryColor = Colors.orange;
        categoryIcon = Icons.grain;
        break;
      case 'supplement':
        categoryColor = Colors.purple;
        categoryIcon = Icons.science;
        break;
      default:
        categoryColor = Colors.blue;
        categoryIcon = Icons.inventory_2;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: categoryColor.withValues(alpha: 0.12),
          child: Icon(categoryIcon, color: categoryColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Text(
              '${item.quantity.toStringAsFixed(1)} กก.',
              style: TextStyle(fontWeight: FontWeight.bold, color: categoryColor, fontSize: 15),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'หมวดหมู่: ${item.category.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  'มูลค่า: ${NumberFormat('#,##0').format(item.cost)} ฿',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'โซน: $zoneText',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm น.').format(item.recordedAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'หมายเหตุ: ${item.notes}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
