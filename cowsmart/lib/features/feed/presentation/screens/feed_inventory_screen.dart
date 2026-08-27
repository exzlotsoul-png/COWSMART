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
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                              'คลังและการให้อาหาร',
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

    // Calculate totals for all items
    final totalQuantity = allItems.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalCost = allItems.fold<double>(
      0,
      (sum, item) => sum + item.cost,
    );

    // Category breakdown from all items
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
                title: 'รายการทั้งหมด',
                value: '${allItems.length} รายการ',
                icon: Icons.list_alt_rounded,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
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
                title: 'มูลค่ารวม',
                value: '${NumberFormat('#,##0').format(totalCost)} ฿',
                icon: Icons.payments_rounded,
                color: Colors.green[700]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
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
                const Text(
                  'สัดส่วนตามหมวดหมู่',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _buildCategoryBreakdown(categoryMap, categoryCostMap, totalQuantity),
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
            const Text(
              'ประวัติการให้อาหารล่าสุด',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'ยังไม่มีบันทึกประวัติการให้อาหาร',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else ...[
          ...allItems.take(5).map((item) => _buildFeedCard(item)),
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

  Widget _buildCategoryBreakdown(Map<String, double> categoryMap, Map<String, double> categoryCostMap, double total) {
    final entries = categoryMap.entries.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        catName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      '${qty.toStringAsFixed(1)} กก. ($pct%)',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${NumberFormat('#,##0').format(cost)} ฿',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedCard(FeedItem item) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.quantity.toStringAsFixed(1)} กก.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'หมายเหตุ: ${item.notes}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.formatThaiDate(item.recordedAt, includeTime: true),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  visualDensity: VisualDensity.compact,
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

  void _showAddFeedDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    final noteController = TextEditingController();

    String selectedCategory = 'grass';
    String? selectedZoneId;
    DateTime selectedDate = DateTime.now();

    final zones = ref.read(zoneProvider).zones;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'บันทึกการให้อาหาร',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่ออาหาร / รายการ',
                    hintText: 'เช่น หญ้าเนเปียร์, อาหารข้น 16%...',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'หมวดหมู่อาหาร',
                    prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'grass', child: Text('หญ้า / อาหารหยาบ')),
                    DropdownMenuItem(value: 'concentrate', child: Text('อาหารข้น')),
                    DropdownMenuItem(value: 'supplement', child: Text('อาหารเสริม / แร่ธาตุ')),
                  ],
                  onChanged: (val) {
                    if (val != null) setBottomSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 14),

                // Zone Dropdown
                DropdownButtonFormField<String?>(
                  initialValue: selectedZoneId,
                  decoration: InputDecoration(
                    labelText: 'ให้ในโซน (ระบุโซนที่ให้อาหาร)',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('ทุกโซน / ไม่ระบุโซน'),
                    ),
                    ...zones.map(
                      (z) => DropdownMenuItem<String?>(
                        value: z.id,
                        child: Text(z.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setBottomSheetState(() => selectedZoneId = val),
                ),
                const SizedBox(height: 14),

                // Quantity and Cost fields row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'ปริมาณ (กก.)',
                          prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'มูลค่า (บาท)',
                          prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primary),
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
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'วันที่บันทึก: ${AppDateUtils.formatThaiDate(selectedDate)}',
                          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Note field
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ (ถ้ามี)',
                    hintText: 'รายละเอียดเพิ่มเติม...',
                    prefixIcon: const Icon(Icons.notes_outlined, color: AppColors.primary),
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

                      if (name.isEmpty || qty <= 0) {
                        AppFeedback.showError(context, 'กรุณากรอกชื่อและปริมาณอาหารให้ถูกต้องและมากกว่า 0');
                        return;
                      }

                      final currentFarm = ref.read(farmProvider).currentFarm;
                      if (currentFarm == null) return;

                      final category = FeedCategory.fromString(selectedCategory);

                      final item = FeedItem(
                        id: '',
                        farmId: currentFarm.id,
                        zoneId: selectedZoneId,
                        name: name,
                        category: category,
                        quantity: qty,
                        cost: cost,
                        recordedAt: selectedDate,
                        notes: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                      );

                      Navigator.pop(ctx);
                      await ref.read(feedProvider.notifier).addFeed(item);
                      if (context.mounted) {
                        AppFeedback.showSuccess(context, 'บันทึกรายการอาหารเรียบร้อยแล้ว');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'บันทึกข้อมูล',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
