import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/feed/providers/feed_provider.dart';
import 'package:cowsmart/features/feed/domain/feed.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';

class FeedInventoryScreen extends ConsumerStatefulWidget {
  const FeedInventoryScreen({super.key});

  @override
  ConsumerState<FeedInventoryScreen> createState() =>
      _FeedInventoryScreenState();
}

class _FeedInventoryScreenState extends ConsumerState<FeedInventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(feedProvider.notifier).fetchFeedInventory(currentFarm.id);
        // ดึง zones เฉพาะถ้ายังไม่เคย load ไว้
        if (!ref.read(zoneProvider).isLoaded) {
          ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
        }
        // ดึง cows ไว้สำหรับเลือกระบุรายตัว
        if (!ref.read(cowProvider).isLoaded) {
          ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: feedState.errorMessage != null
          ? Center(child: Text(feedState.errorMessage!))
          : CustomScrollView(
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                        child: Column(
                          children: [
                            const Text(
                              'การให้อาหาร',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'บันทึก สรุปมูลค่า และติดตามการให้อาหารในฟาร์ม',
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

                // ── Body Content ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildBodyContent(context, feedState),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'feed_inventory_fab',
        onPressed: () => _showAddFeedDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'บันทึกการให้อาหาร',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, FeedState state) {
    if (state.isLoading && state.inventory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final allItems = List.of(state.inventory)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));


    // Calculate totals for ALL time
    final totalQuantity = allItems.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalCost = allItems.fold<double>(
      0,
      (sum, item) => sum + item.cost,
    );

    // Category breakdown from ALL items
    final categoryMap = <String, double>{};
    final categoryCostMap = <String, double>{};
    for (final item in allItems) {
      final catName = item.category.name;
      categoryMap[catName] = (categoryMap[catName] ?? 0) + item.quantity;
      categoryCostMap[catName] = (categoryCostMap[catName] ?? 0) + item.cost;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards Row 1
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'รายการทั้งหมด',
                value: '${allItems.length} รายการ',
                icon: Icons.list_alt_rounded,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'ปริมาณรวม',
                value: '${totalQuantity.toStringAsFixed(1)} กก.',
                icon: Icons.scale_rounded,
                color: Colors.blue[700]!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary Cards Row 2
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'มูลค่ารวม',
                value: '${NumberFormat('#,##0').format(totalCost)} ฿',
                icon: Icons.payments_rounded,
                color: Colors.green[700]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                title: 'ราคาเฉลี่ย/กก.',
                value: totalQuantity > 0
                    ? '${(totalCost / totalQuantity).toStringAsFixed(1)} ฿'
                    : '- ฿',
                icon: Icons.analytics_rounded,
                color: Colors.orange[800]!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category Breakdown
        if (categoryMap.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'สัดส่วนตามหมวดหมู่',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.text(context),
                  ),
                ),
              ],
            ),
          ),
          _buildCategoryBreakdown(context, categoryMap, categoryCostMap, totalQuantity),
          const SizedBox(height: 24),
        ],

        // Feed List Header
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ประวัติการให้อาหารล่าสุด',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.text(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => context.push('/feed_history'),
              icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'ดูทั้งหมด',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (allItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'ยังไม่มีบันทึกประวัติการให้อาหาร',
                  style: TextStyle(color: AppColors.subText(context), fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else ...[
          ...allItems.take(5).map((item) => _buildFeedCard(context, item)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/feed_history'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                allItems.length > 5
                    ? 'ดูประวัติทั้งหมด (${allItems.length} รายการ)'
                    : 'ดูประวัติและการกรองทั้งหมด',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
                backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 60), // Space for FAB
        ],
      ],
    );
  }

  Color _getCategoryColorByName(String name) {
    if (name.contains('หญ้า') || name.contains('หยาบ')) {
      return Colors.green[700]!;
    } else if (name.contains('ข้น') || name.contains('เม็ด')) {
      return Colors.orange[800]!;
    } else if (name.contains('เสริม') || name.contains('แร่ธาตุ')) {
      return Colors.blue[700]!;
    }
    return Colors.grey[700]!;
  }

  Widget _buildCategoryBreakdown(BuildContext context, Map<String, double> categoryMap, Map<String, double> categoryCostMap, double total) {
    final entries = categoryMap.entries.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar chart
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Row(
                    children: entries.map((e) {
                      final ratio = e.value / total;
                      final catColor = _getCategoryColorByName(e.key);
                      return Expanded(
                        flex: (ratio * 100).round().clamp(1, 100),
                        child: Container(color: catColor),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            // Legend
            ...entries.map((e) {
              final catName = e.key;
              final qty = e.value;
              final cost = categoryCostMap[catName] ?? 0;
              final pct = total > 0 ? (qty / total * 100).toStringAsFixed(0) : '0';
              final catColor = _getCategoryColorByName(catName);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${qty.toStringAsFixed(1)} กก. ($pct%)',
                            style: TextStyle(fontSize: 13, color: AppColors.subText(context), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${NumberFormat('#,##0').format(cost)} ฿',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subText(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedCard(BuildContext context, FeedItem item) {
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(categoryIcon, color: categoryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.text(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                              fontWeight: FontWeight.w700,
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
                        fontSize: 18,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
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
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfAlt(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'หมายเหตุ: ${item.notes}',
                  style: TextStyle(fontSize: 13, color: AppColors.subText(context)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    AppDateUtils.formatThaiDate(item.recordedAt, includeTime: true),
                    style: TextStyle(fontSize: 13, color: AppColors.text(context), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showFeedDialog(context, initialItem: item),
                  tooltip: 'แก้ไขรายการ',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDeleteItem(context, item),
                  tooltip: 'ลบรายการ',
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
                  child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
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
                      hintText: 'ค้นหาชื่อ หรือ เบอร์หู...',
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

  void _showAddFeedDialog(BuildContext context) {
    _showFeedDialog(context);
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
                    labelText: 'ชื่ออาหาร / รายการ',
                    hintText: 'เช่น หญ้าเนเปียร์, อาหารข้น 16%...',
                    hintStyle: TextStyle(color: AppColors.hint(context)),
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 14),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: AppColors.cardBg(context),
                  style: TextStyle(color: AppColors.text(context), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'หมวดหมู่อาหาร',
                    prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfAlt(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'grass', child: Text('หญ้า / อาหารหยาบ', style: TextStyle(color: AppColors.text(context)))),
                    DropdownMenuItem(value: 'concentrate', child: Text('อาหารข้น', style: TextStyle(color: AppColors.text(context)))),
                    DropdownMenuItem(value: 'supplement', child: Text('อาหารเสริม / แร่ธาตุ', style: TextStyle(color: AppColors.text(context)))),
                  ],
                  onChanged: (val) {
                    if (val != null) setBottomSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 14),

                // ── รูปแบบการให้: ตามโซน หรือ รายตัว ──
                Text(
                  'รูปแบบการให้',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.subText(context),
                  ),
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
                                Icons.location_on_outlined,
                                size: 18,
                                color: targetType == 'zone' ? AppColors.primary : AppColors.subText(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ตามโซน',
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
                            cowSelectionError = null;
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
}
