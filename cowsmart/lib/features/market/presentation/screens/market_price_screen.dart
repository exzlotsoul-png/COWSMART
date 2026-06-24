import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import '../../providers/market_price_provider.dart';
import '../../domain/market_price.dart';

class MarketPriceScreen extends ConsumerStatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  ConsumerState<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends ConsumerState<MarketPriceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketPriceProvider.notifier).fetchLatest();
    });
  }

  void _showAddPriceDialog() {
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final sourceController = TextEditingController(text: 'บันทึกด้วยตนเอง');
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('บันทึกราคาตลาด'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ราคา (บาท/กก.) *',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'หมวดหมู่ (เช่น วัวขุน, แม่พันธุ์)',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'แหล่งที่มา',
                    prefixIcon: Icon(Icons.source_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
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
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('กรุณากรอกราคาให้ถูกต้อง'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await ref
                          .read(marketPriceProvider.notifier)
                          .addPrice(
                            pricePerKg: price,
                            effectiveDate: selectedDate,
                            category: categoryController.text.trim().isNotEmpty
                                ? categoryController.text.trim()
                                : null,
                            source: sourceController.text.trim().isNotEmpty
                                ? sourceController.text.trim()
                                : null,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('บันทึกราคาตลาดแล้ว')),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketPriceProvider);
    final formatter = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ราคาตลาดวัว'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(marketPriceProvider.notifier).fetchLatest(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPriceDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('บันทึกราคา'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(marketPriceProvider.notifier).fetchLatest(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Latest Price Card
                    _buildLatestPriceCard(state, formatter),
                    const SizedBox(height: 24),

                    // Estimated value info
                    _buildEstimatedValueCard(state),
                    const SizedBox(height: 24),

                    // Category breakdown
                    if (state.byCategory.isNotEmpty) ...[
                      const Text(
                        'ราคาแยกตามหมวดหมู่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...state.byCategory.map(
                        (p) => _buildCategoryCard(p, formatter),
                      ),
                    ],

                    if (state.latest == null && !state.isLoading)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.show_chart,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ยังไม่มีข้อมูลราคาตลาด',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'กดปุ่ม "บันทึกราคา" เพื่อเพิ่มข้อมูล',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLatestPriceCard(MarketPriceState state, NumberFormat formatter) {
    final latest = state.latest;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ราคาตลาดกลางวัว',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (latest != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(latest.effectiveDate),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            latest != null
                ? '฿ ${formatter.format(latest.pricePerKg)} / กก.'
                : 'ยังไม่มีข้อมูล',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (latest?.source != null) ...[
            const SizedBox(height: 8),
            Text(
              'แหล่งที่มา: ${latest!.source}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstimatedValueCard(MarketPriceState state) {
    final pricePerKg = state.latest?.pricePerKg ?? 120.0;
    final formatter = NumberFormat('#,##0');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'มูลค่าประเมินตามราคาตลาดปัจจุบัน',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildWeightRow('วัว 300 กก.', pricePerKg * 300, formatter),
          _buildWeightRow('วัว 400 กก.', pricePerKg * 400, formatter),
          _buildWeightRow('วัว 500 กก.', pricePerKg * 500, formatter),
          _buildWeightRow('วัว 600 กก.', pricePerKg * 600, formatter),
        ],
      ),
    );
  }

  Widget _buildWeightRow(String label, double value, NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            '฿ ${formatter.format(value)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(MarketPrice price, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price.category ?? 'ทั่วไป',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(price.effectiveDate),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            '฿ ${formatter.format(price.pricePerKg)} / กก.',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
