import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/feed/providers/feed_provider.dart';
import 'package:cowsmart/features/feed/domain/feed.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';

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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'บันทึกคลังอาหาร',
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

    if (state.inventory.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีข้อมูลบันทึก',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Calculate totals
    final totalQuantity = state.inventory.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalCost = state.inventory.fold<double>(
      0,
      (sum, item) => sum + item.cost,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'จำนวนรวม',
                value: '${totalQuantity.toStringAsFixed(1)} กก.',
                icon: Icons.scale,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'มูลค่ารวม',
                value: '${totalCost.toStringAsFixed(0)} บาท',
                icon: Icons.payments,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'รายการอาหาร',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...state.inventory.map((item) => _FeedCard(item: item)),
      ],
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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

    final categories = ['หญ้า', 'ข้น', 'เสริม'];

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
                      name: name,
                      category: FeedCategory.fromString(selectedCategory),
                      quantity: quantity,
                      cost: cost,
                      recordedAt: DateTime.now(),
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

class _FeedCard extends StatelessWidget {
  final FeedItem item;

  const _FeedCard({required this.item});

  @override
  Widget build(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.scale, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${item.quantity.toStringAsFixed(1)} กก.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${item.cost.toStringAsFixed(0)} บาท',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'บันทึกเมื่อ: ${DateFormat('dd/MM/yyyy').format(item.recordedAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
