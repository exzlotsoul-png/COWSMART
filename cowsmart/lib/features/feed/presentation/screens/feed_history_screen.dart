import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
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
      backgroundColor: AppColors.bg(context),
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                          const Expanded(
                            child: Text(
                              'ประวัติการให้อาหารทั้งหมด',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                            tooltip: 'รีเฟรช',
                            onPressed: () {
                              if (currentFarm != null) {
                                ref.read(feedProvider.notifier).fetchFeedInventory(currentFarm.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ค้นหาและกรองประวัติการให้อาหารย้อนหลัง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Filter Section ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range picker row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showCustomDateRangePicker(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _dateRange != null ? AppColors.primary : AppColors.brd(context)),
                                borderRadius: BorderRadius.circular(12),
                                color: _dateRange != null ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surfAlt(context),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dateRange != null
                                          ? AppDateUtils.formatThaiDateRange(_dateRange!.start, _dateRange!.end)
                                          : 'เลือกช่วงวันที่ (วันเริ่ม - วันสิ้นสุด)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _dateRange != null ? FontWeight.bold : FontWeight.normal,
                                        color: AppColors.text(context),
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
                            icon: const Icon(Icons.close_rounded, color: Colors.red),
                            tooltip: 'ล้างวันที่',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาด้วยชื่ออาหารหรือหมวดหมู่...',
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.hint(context)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        filled: true,
                        fillColor: AppColors.surfAlt(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),

                    // Category chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ทั้งหมด', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            selected: _selectedCategory == null,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == null ? AppColors.primary : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: _selectedCategory == null ? Colors.white : AppColors.text(context),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCategory = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('หญ้า', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            selected: _selectedCategory == 'หญ้า',
                            selectedColor: Colors.green,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'หญ้า' ? Colors.green : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: _selectedCategory == 'หญ้า' ? Colors.white : AppColors.text(context),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedCategory = selected ? 'หญ้า' : null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('ข้น', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            selected: _selectedCategory == 'ข้น',
                            selectedColor: Colors.orange,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'ข้น' ? Colors.orange : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: _selectedCategory == 'ข้น' ? Colors.white : AppColors.text(context),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedCategory = selected ? 'ข้น' : null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('เสริม', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            selected: _selectedCategory == 'เสริม',
                            selectedColor: Colors.blue,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'เสริม' ? Colors.blue : AppColors.brd(context)),
                            labelStyle: TextStyle(
                              color: _selectedCategory == 'เสริม' ? Colors.white : AppColors.text(context),
                              fontWeight: FontWeight.bold,
                            ),
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
            ),
          ),

          // Summary Results Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'พบ ${filteredItems.length} รายการ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                  ),
                  Text(
                    'รวม ${totalQuantity.toStringAsFixed(1)} กก. (${NumberFormat('#,##0').format(totalCost)} ฿)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),

          // Feed items list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: feedState.isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : filteredItems.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined, size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              const Text(
                                'ไม่พบประวัติการให้อาหาร',
                                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildHistoryCard(item),
                            );
                          },
                          childCount: filteredItems.length,
                        ),
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
        categoryColor = Colors.green[700]!;
        categoryIcon = Icons.grass_rounded;
        break;
      case 'concentrate':
        categoryColor = Colors.orange[800]!;
        categoryIcon = Icons.grain_rounded;
        break;
      case 'supplement':
        categoryColor = Colors.blue[700]!;
        categoryIcon = Icons.medication_rounded;
        break;
      default:
        categoryColor = Colors.grey[700]!;
        categoryIcon = Icons.inventory_2_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.category.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    'โซน: $zoneText',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0').format(item.cost)} ฿',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity.toStringAsFixed(1)} กก.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.subText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'หมายเหตุ: ${item.notes}',
                  style: TextStyle(fontSize: 12, color: AppColors.subText(context)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.formatThaiDate(item.recordedAt, includeTime: true),
                  style: TextStyle(fontSize: 12, color: AppColors.text(context), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDateRangePicker(BuildContext context) {
    final now = DateTime.now();
    DateTime tempStart = _dateRange?.start ?? DateTime(now.year, now.month, 1);
    DateTime tempEnd = _dateRange?.end ?? now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysCount = tempEnd.difference(tempStart).inDays + 1;

            void applyPreset(DateTime start, DateTime end) {
              setModalState(() {
                tempStart = start;
                tempEnd = end;
              });
            }

            Widget buildPresetChip({required String label, required VoidCallback onTap}) {
              return ActionChip(
                label: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text(context))),
                backgroundColor: AppColors.surfAlt(context),
                side: BorderSide(color: AppColors.brd(context)),
                onPressed: onTap,
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'เลือกช่วงเวลาดูประวัติ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: Icon(Icons.close_rounded, color: AppColors.subText(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Presets Label
                    Text(
                      'ตัวเลือกด่วน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.subText(context),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildPresetChip(
                          label: '7 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 6)), today);
                          },
                        ),
                        buildPresetChip(
                          label: '30 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 29)), today);
                          },
                        ),
                        buildPresetChip(
                          label: 'เดือนนี้',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, today.month, 1), today);
                          },
                        ),
                        buildPresetChip(
                          label: 'เดือนที่แล้ว',
                          onTap: () {
                            final today = DateTime.now();
                            final firstOfLastMonth = DateTime(today.year, today.month - 1, 1);
                            final lastOfLastMonth = DateTime(today.year, today.month, 0);
                            applyPreset(firstOfLastMonth, lastOfLastMonth);
                          },
                        ),
                        buildPresetChip(
                          label: 'ปีนี้ (พ.ศ. ${now.year + 543})',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, 1, 1), today);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Custom Date Pickers Label
                    Text(
                      'ระบุช่วงวันที่เอง',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.subText(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่เริ่มต้น',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfAlt(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ตั้งแต่วันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.hint(context), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempStart),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.hint(context), size: 18),
                        ),
                        // End Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่สิ้นสุด',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfAlt(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ถึงวันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.hint(context), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempEnd),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Days Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.text(context)),
                          const SizedBox(width: 6),
                          Text(
                            'รวมระยะเวลาเลือกทั้งหมด $daysCount วัน',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dateRange = DateTimeRange(start: tempStart, end: tempEnd);
                        });
                        Navigator.pop(modalContext);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('ตกลง / ดูรายงานช่วงเวลานี้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
