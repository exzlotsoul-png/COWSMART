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
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/app_toast.dart';

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
                            selectedColor: Colors.green[700]!,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'หญ้า' ? Colors.green[700]! : AppColors.brd(context)),
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
                            selectedColor: Colors.orange[800]!,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'ข้น' ? Colors.orange[800]! : AppColors.brd(context)),
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
                            selectedColor: Colors.blue[700]!,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(color: _selectedCategory == 'เสริม' ? Colors.blue[700]! : AppColors.brd(context)),
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
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'รวม ${totalQuantity.toStringAsFixed(1)} กก. (${NumberFormat('#,##0').format(totalCost)} ฿)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          if (item.cowIds != null && item.cowIds!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CowIcon(size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'วัว: ${item.cowIds!.length} ตัว',
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
                            )
                          else
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
                Expanded(
                  child: Text(
                    AppDateUtils.formatThaiDate(item.recordedAt, includeTime: true),
                    style: TextStyle(fontSize: 12, color: AppColors.text(context), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tooltip: 'ตัวเลือก',
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showFeedDialog(context, initialItem: item);
                    } else if (val == 'delete') {
                      _confirmDeleteItem(context, item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text('แก้ไขรายการ'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          SizedBox(width: 8),
                          Text('ลบรายการ', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, FeedItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('ยืนยันการลบ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('คุณต้องการลบบันทึก "${item.name}" ใช่หรือไม่?', style: const TextStyle(fontSize: 15)),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final currentFarm = ref.read(farmProvider).currentFarm;
                    if (currentFarm != null) {
                      await ref.read(feedProvider.notifier).deleteFeed(item.id);
                      if (context.mounted) {
                        AppFeedback.showWarning(context, 'ลบรายการอาหารเรียบร้อยแล้ว');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('ลบ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCowSelectionModal(
    BuildContext context,
    List<Cow> cows,
    List<Zone> zones,
    Set<String> selectedCowIds,
    ValueChanged<Set<String>> onSelectionChanged,
  ) {
    final searchController = TextEditingController();
    String searchQuery = '';
    String? filterZoneId;
    final tempSelected = Set<String>.from(selectedCowIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredCows = cows.where((c) {
            final matchesQuery = searchQuery.isEmpty ||
                c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                c.tagNumber.toLowerCase().contains(searchQuery.toLowerCase());
            final matchesZone = filterZoneId == null || c.zoneId == filterZoneId;
            return matchesQuery && matchesZone;
          }).toList();

          final isAllSelected = filteredCows.isNotEmpty &&
              filteredCows.every((c) => tempSelected.contains(c.id));

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brd(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const CowIcon(size: 24, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'เลือกวัวที่ให้อาหาร',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'เลือกแล้ว ${tempSelected.length} ตัว',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อ หรือ เบอร์วัว...',
                      hintStyle: TextStyle(color: AppColors.hint(context), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() => searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfAlt(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                  ),
                ),

                // Zone Filter Chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('ทุกโซน', style: TextStyle(fontSize: 12)),
                          selected: filterZoneId == null,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfAlt(context),
                          side: BorderSide(
                            color: filterZoneId == null ? AppColors.primary : AppColors.brd(context),
                          ),
                          labelStyle: TextStyle(
                            color: filterZoneId == null ? Colors.white : AppColors.text(context),
                            fontWeight: filterZoneId == null ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setModalState(() => filterZoneId = null),
                        ),
                      ),
                      ...zones.map((zone) {
                        final isSel = filterZoneId == zone.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(zone.name, style: const TextStyle(fontSize: 12)),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfAlt(context),
                            side: BorderSide(
                              color: isSel ? AppColors.primary : AppColors.brd(context),
                            ),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.text(context),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setModalState(() => filterZoneId = zone.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Select All / Deselect All Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        'พบ ${filteredCows.length} ตัว',
                        style: TextStyle(fontSize: 13, color: AppColors.subText(context)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: filteredCows.isEmpty
                            ? null
                            : () {
                                setModalState(() {
                                  if (isAllSelected) {
                                    for (final c in filteredCows) {
                                      tempSelected.remove(c.id);
                                    }
                                  } else {
                                    for (final c in filteredCows) {
                                      tempSelected.add(c.id);
                                    }
                                  }
                                });
                              },
                        icon: Icon(
                          isAllSelected ? Icons.deselect : Icons.select_all,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          isAllSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมดในรายการ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Cow List
                Expanded(
                  child: filteredCows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint(context)),
                              const SizedBox(height: 8),
                              Text(
                                'ไม่พบข้อมูลวัว',
                                style: TextStyle(color: AppColors.subText(context)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: filteredCows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final cow = filteredCows[idx];
                            final isChecked = tempSelected.contains(cow.id);
                            final zoneObj = zones.cast<Zone?>().firstWhere(
                                  (z) => z?.id == cow.zoneId,
                                  orElse: () => null,
                                );

                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  if (isChecked) {
                                    tempSelected.remove(cow.id);
                                  } else {
                                    tempSelected.add(cow.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : AppColors.surfAlt(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isChecked ? AppColors.primary : AppColors.brd(context),
                                    width: isChecked ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        color: AppColors.cardBg(context),
                                        child: (cow.imageFullUrl != null || cow.imageUrl != null)
                                            ? Image.network(
                                                cow.imageFullUrl ?? cow.imageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: CowIcon(size: 22, color: AppColors.primary),
                                                ),
                                              )
                                            : const Center(
                                                child: CowIcon(size: 22, color: AppColors.primary),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  cow.name.isNotEmpty ? cow.name : cow.tagNumber,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: AppColors.text(context),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  cow.tagNumber,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'โซน: ${zoneObj?.name ?? cow.zoneId} • เพศ: ${cow.gender == 'M' ? 'ผู้' : 'เมีย'}',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.subText(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            tempSelected.add(cow.id);
                                          } else {
                                            tempSelected.remove(cow.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Done Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    border: Border(top: BorderSide(color: AppColors.brd(context))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        onSelectionChanged(tempSelected);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'ยืนยันการเลือก (${tempSelected.length} ตัว)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFeedDialog(BuildContext context, {FeedItem? initialItem}) {
    final isEdit = initialItem != null;
    final nameController = TextEditingController(text: initialItem?.name ?? '');
    final quantityController = TextEditingController(
      text: initialItem != null ? initialItem.quantity.toString() : '',
    );
    final costController = TextEditingController(
      text: initialItem != null ? initialItem.cost.toString() : '',
    );
    final noteController = TextEditingController(text: initialItem?.notes ?? '');

    String selectedCategory = initialItem?.category.id ?? 'grass';
    if (!['grass', 'concentrate', 'supplement'].contains(selectedCategory)) {
      selectedCategory = 'grass';
    }

    String targetType = (initialItem?.cowIds != null && initialItem!.cowIds!.isNotEmpty)
        ? 'cow'
        : 'zone';

    String? selectedZoneId = initialItem?.zoneId;
    final Set<String> selectedCowIds = initialItem?.cowIds != null
        ? Set<String>.from(initialItem!.cowIds!)
        : {};

    String? nameError;
    String? qtyError;
    String? cowSelectionError;
    DateTime selectedDate = initialItem?.recordedAt ?? DateTime.now();

    final zones = ref.read(zoneProvider).zones;
    final cows = ref.read(cowProvider).allCows;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.brd(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'แก้ไขการให้อาหาร' : 'บันทึกการให้อาหาร',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextField(
                  controller: nameController,
                  style: TextStyle(color: AppColors.text(context)),
                  decoration: InputDecoration(
                    labelText: 'ชื่ออาหาร / วัตถุดิบ',
                    hintText: 'เช่น หญ้าเนเปียร์, ฟาง, รำข้าว',
                    hintStyle: TextStyle(color: AppColors.hint(context)),
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 14),

                // Category chips
                Text(
                  'หมวดหมู่อาหาร',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('หญ้า / อาหารหยาบ')),
                        selected: selectedCategory == 'grass',
                        selectedColor: Colors.green[700]!,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(
                          color: selectedCategory == 'grass' ? Colors.green[700]! : AppColors.brd(context),
                        ),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'grass' ? Colors.white : AppColors.text(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setBottomSheetState(() => selectedCategory = 'grass'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('อาหารข้น')),
                        selected: selectedCategory == 'concentrate',
                        selectedColor: Colors.orange[800]!,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(
                          color: selectedCategory == 'concentrate' ? Colors.orange[800]! : AppColors.brd(context),
                        ),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'concentrate' ? Colors.white : AppColors.text(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setBottomSheetState(() => selectedCategory = 'concentrate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('อาหารเสริม')),
                        selected: selectedCategory == 'supplement',
                        selectedColor: Colors.blue[700]!,
                        backgroundColor: AppColors.surfAlt(context),
                        side: BorderSide(
                          color: selectedCategory == 'supplement' ? Colors.blue[700]! : AppColors.brd(context),
                        ),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'supplement' ? Colors.white : AppColors.text(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setBottomSheetState(() => selectedCategory = 'supplement'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Target Type: Zone vs Cow
                Text(
                  'รูปแบบการให้',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setBottomSheetState(() {
                            targetType = 'zone';
                            cowSelectionError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: targetType == 'zone'
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfAlt(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: targetType == 'zone'
                                  ? AppColors.primary
                                  : AppColors.brd(context),
                              width: targetType == 'zone' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                                color: targetType == 'zone' ? AppColors.primary : AppColors.subText(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ให้เป็นโซน',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: targetType == 'zone' ? AppColors.primary : AppColors.subText(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setBottomSheetState(() {
                            targetType = 'cow';
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: targetType == 'cow'
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfAlt(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: targetType == 'cow'
                                  ? AppColors.primary
                                  : AppColors.brd(context),
                              width: targetType == 'cow' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CowIcon(
                                size: 18,
                                color: targetType == 'cow' ? AppColors.primary : AppColors.subText(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ระบุรายตัว',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: targetType == 'cow' ? AppColors.primary : AppColors.subText(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Zone Selector (when targetType == 'zone')
                if (targetType == 'zone') ...[
                  DropdownButtonFormField<String?>(
                    initialValue: selectedZoneId,
                    dropdownColor: AppColors.cardBg(context),
                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'ให้ในโซน (ระบุโซนที่ให้อาหาร)',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surfAlt(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('ทุกโซน / ไม่ระบุโซน', style: TextStyle(color: AppColors.text(context))),
                      ),
                      ...zones.map(
                        (z) => DropdownMenuItem<String?>(
                          value: z.id,
                          child: Text(z.name, style: TextStyle(color: AppColors.text(context))),
                        ),
                      ),
                    ],
                    onChanged: (val) => setBottomSheetState(() => selectedZoneId = val),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // Cow Multi-Select Button (when targetType == 'cow')
                  InkWell(
                    onTap: () {
                      _showCowSelectionModal(
                        context,
                        cows,
                        zones,
                        selectedCowIds,
                        (newSelection) {
                          setBottomSheetState(() {
                            selectedCowIds.clear();
                            selectedCowIds.addAll(newSelection);
                            if (selectedCowIds.isNotEmpty) {
                              cowSelectionError = null;
                            }
                          });
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfAlt(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cowSelectionError != null ? AppColors.error : AppColors.brd(context),
                          width: cowSelectionError != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const CowIcon(size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'เลือกวัวที่ให้อาหาร',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.subText(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedCowIds.isEmpty
                                      ? 'แตะเพื่อเลือกวัว (เลือกได้หลายตัว)'
                                      : 'เลือกแล้ว ${selectedCowIds.length} ตัว (${cows.where((c) => selectedCowIds.contains(c.id)).map((c) => c.name.isNotEmpty ? c.name : c.tagNumber).take(3).join(', ')}${selectedCowIds.length > 3 ? '...' : ''})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selectedCowIds.isEmpty ? FontWeight.normal : FontWeight.bold,
                                    color: selectedCowIds.isEmpty ? AppColors.hint(context) : AppColors.text(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'เลือก',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cowSelectionError != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        cowSelectionError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // Quantity and Cost fields row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'ปริมาณ (กก.)',
                          prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.surfAlt(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          errorText: qtyError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'มูลค่า (บาท)',
                          prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.surfAlt(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date Picker Button
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setBottomSheetState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      border: Border.all(color: AppColors.brd(context)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'วันที่บันทึก: ${AppDateUtils.formatThaiDate(selectedDate)}',
                          style: TextStyle(fontSize: 15, color: AppColors.text(context), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Note field
                TextField(
                  controller: noteController,
                  style: TextStyle(color: AppColors.text(context)),
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ (ถ้ามี)',
                    hintText: 'รายละเอียดเพิ่มเติม...',
                    hintStyle: TextStyle(color: AppColors.hint(context)),
                    prefixIcon: const Icon(Icons.notes_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final qty = double.tryParse(quantityController.text) ?? 0;
                      final cost = double.tryParse(costController.text) ?? 0;

                      setBottomSheetState(() {
                        nameError = name.isEmpty ? 'กรุณากรอกชื่อ' : null;
                        qtyError = qty <= 0 ? 'ระบุปริมาณ' : null;
                        if (targetType == 'cow' && selectedCowIds.isEmpty) {
                          cowSelectionError = 'กรุณาเลือกวัวอย่างน้อย 1 ตัว';
                        } else {
                          cowSelectionError = null;
                        }
                      });

                      if (nameError != null || qtyError != null || cowSelectionError != null) {
                        return;
                      }

                      final currentFarm = ref.read(farmProvider).currentFarm;
                      if (currentFarm == null) return;

                      final category = FeedCategory.fromString(selectedCategory);

                      final item = FeedItem(
                        id: isEdit ? initialItem.id : '',
                        farmId: currentFarm.id,
                        zoneId: targetType == 'zone' ? selectedZoneId : null,
                        cowIds: targetType == 'cow' ? selectedCowIds.toList() : null,
                        name: name,
                        category: category,
                        quantity: qty,
                        cost: cost,
                        recordedAt: selectedDate,
                        notes: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                      );

                      Navigator.pop(ctx);
                      if (isEdit) {
                        await ref.read(feedProvider.notifier).updateFeed(item);
                        if (context.mounted) {
                          AppFeedback.showSuccess(context, 'แก้ไขรายการอาหารเรียบร้อยแล้ว');
                        }
                      } else {
                        await ref.read(feedProvider.notifier).addFeed(item);
                        if (context.mounted) {
                          AppFeedback.showSuccess(context, 'บันทึกรายการอาหารเรียบร้อยแล้ว');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isEdit ? 'บันทึกการแก้ไข' : 'บันทึกข้อมูล',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
