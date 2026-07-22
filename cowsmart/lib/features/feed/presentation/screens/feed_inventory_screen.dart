import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/feed/providers/feed_provider.dart';
import 'package:cowsmart/features/feed/domain/feed.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';

/// หน้าบันทึกคลังอาหารอย่างง่าย - ไม่มีระบบสต็อกอัตโนมัติ
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
      appBar: AppBar(
        title: const Text(
          'อาหาร',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: feedState.errorMessage != null
          ? Center(child: Text(feedState.errorMessage!))
          : _buildBody(context, feedState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFeedDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่ม',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedState state) {
    if (state.isLoading && state.inventory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final allItems = state.inventory;

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards Row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'รายการทั้งหมด',
                value: '${allItems.length} รายการ',
                icon: Icons.list_alt,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'ปริมาณรวม',
                value: '${totalQuantity.toStringAsFixed(1)} กก.',
                icon: Icons.scale,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'มูลค่ารวม',
                value: '${NumberFormat('#,##0').format(totalCost)} บาท',
                icon: Icons.payments,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'ราคาเฉลี่ย/กก.',
                value: totalQuantity > 0
                    ? '${(totalCost / totalQuantity).toStringAsFixed(1)} บาท'
                    : '- บาท',
                icon: Icons.analytics,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Category Breakdown
        if (categoryMap.isNotEmpty) ...[
          Text(
            'สัดส่วนตามหมวดหมู่',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(categoryMap, categoryCostMap, totalQuantity),
          const SizedBox(height: 20),
        ],

        // Feed List Header
        Row(
          children: [
            Text(
              'ประวัติการให้อาหาร',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/feed_history'),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('ดูประวัติทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (allItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีบันทึกประวัติการให้อาหาร',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...allItems.take(5).map((item) => _buildFeedCard(item)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/feed_history'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(
              allItems.length > 5
                  ? 'ดูประวัติทั้งหมด (${allItems.length} รายการ)'
                  : 'ดูประวัติและการกรองทั้งหมด',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryBreakdown(Map<String, double> categoryMap, Map<String, double> categoryCostMap, double total) {
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.purple];
    final entries = categoryMap.entries.toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Simple bar chart
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: entries.asMap().entries.map((e) {
                      final ratio = e.value.value / total;
                      return Expanded(
                        flex: (ratio * 100).round().clamp(1, 100),
                        child: Container(color: colors[e.key % colors.length]),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Legend
            ...entries.asMap().entries.map((e) {
              final catName = e.value.key;
              final qty = e.value.value;
              final cost = categoryCostMap[catName] ?? 0;
              final pct = total > 0 ? (qty / total * 100).toStringAsFixed(0) : '0';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[e.key % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(catName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                fontSize: 22,
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
        : (item.zoneId != null && item.zoneId!.isNotEmpty ? item.zoneId! : 'ทุกโซน / ไม่ได้ระบุ');

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
        categoryColor = Colors.blue;
        categoryIcon = Icons.medication;
        break;
      default:
        categoryColor = Colors.grey;
        categoryIcon = Icons.inventory_2;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.category.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Text(
                                  'โซน: $zoneText',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
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
                      '${NumberFormat('#,##0').format(item.cost)} บาท',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity.toStringAsFixed(1)} กก.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
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
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.notes!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[650]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(item.recordedAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (item.quantity > 0) ...[
                  const Spacer(),
                  Text(
                    'ราคา/กก.: ${(item.cost / item.quantity).toStringAsFixed(1)} ฿',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFeedDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'หญ้า';
    String? selectedZoneId;
    DateTime selectedDate = DateTime.now();

    final categories = ['หญ้า', 'ข้น', 'เสริม'];
    final zones = ref.read(zoneProvider).zones;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('บันทึกอาหารใหม่'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่ออาหาร',
                  hintText: 'เช่น หญ้าเนเปียร์',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'หมวดหมู่',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String?>(
                  initialValue: selectedZoneId,
                  decoration: const InputDecoration(
                    labelText: 'ระบุโซน/คอก (สำหรับเฉลี่ยต้นทุน)',
                    border: OutlineInputBorder(),
                    helperText: 'หากไม่ระบุ จะถือเป็นคลังกลางไม่ปันส่วนรายตัว',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('คลังกลาง (ไม่ระบุคอก)'),
                    ),
                    ...zones.map((z) => DropdownMenuItem<String?>(
                          value: z.id,
                          child: Text(z.name),
                        )),
                  ],
                  onChanged: (val) => setState(() => selectedZoneId = val),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'วันที่บันทึก',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ปริมาณ (กก.)',
                  hintText: '0.0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ราคา (บาท)',
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ถ้ามี)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final quantity =
                        double.tryParse(quantityController.text) ?? 0;
                    final cost = double.tryParse(costController.text) ?? 0;

                    if (name.isEmpty || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณากรอกชื่อและปริมาณ')),
                      );
                      return;
                    }

                    final currentFarm = ref.read(farmProvider).currentFarm;
                    if (currentFarm == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ไม่พบข้อมูลฟาร์ม')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    final newFeed = FeedItem(
                      id: '',
                      farmId: currentFarm.id,
                      zoneId: selectedZoneId,
                      name: name,
                      category: FeedCategory.fromString(selectedCategory),
                      quantity: quantity,
                      cost: cost,
                      recordedAt: selectedDate,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );

                    await ref.read(feedProvider.notifier).addFeed(newFeed);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('บันทึก $name สำเร็จ'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
