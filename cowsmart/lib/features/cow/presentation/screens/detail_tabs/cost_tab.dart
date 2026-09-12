import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/widgets/custom_date_range_picker.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/health_record.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import 'package:cowsmart/features/calendar/domain/calendar_event.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/calendar/providers/appointment_type_provider.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../health/providers/master_data_provider.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/features/health/presentation/widgets/calf_vaccine_dialog.dart';
import 'package:cowsmart/features/health/services/calf_vaccine_schedule_service.dart';

class CostTab extends ConsumerStatefulWidget {
  final Cow cow;
  const CostTab({super.key, required this.cow});

  @override
  ConsumerState<CostTab> createState() => _CostTabState();
}

class _CostTabState extends ConsumerState<CostTab> {
  Map<String, dynamic>? _costData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCostData();
  }

  Future<void> _fetchCostData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/cow_costs/${widget.cow.id}');
      setState(() {
        _costData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[CostTab] Error fetching cow_costs: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _costData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'โหลดข้อมูลไม่สำเร็จ',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _fetchCostData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    final summary = (_costData!['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final breakdown = (_costData!['breakdown'] as Map?)?.cast<String, dynamic>() ?? {};

    final totalCost = _parseDouble(summary['total_cost']);
    final healthCost = _parseDouble(summary['health_cost']);
    final feedCost = _parseDouble(summary['feed_cost']);
    final directCost = _parseDouble(summary['direct_cost']);
    final purchasePrice = _parseDouble(summary['purchase_price']);
    final totalIncome = _parseDouble(summary['total_income']);
    final netCost = _parseDouble(summary['net_cost']);

    // Health details
    final healthDetails = (breakdown['health'] as List?)
            ?.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList() ??
        [];
    // Feed details
    final feedDetails = (breakdown['feed'] as List?)
            ?.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList() ??
        [];
    // Direct cost details
    final directDetails = (breakdown['direct'] as List?)
            ?.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList() ??
        [];

    // Cost breakdown for proportion bar
    final costParts = <_CostPart>[
      if (purchasePrice > 0)
        _CostPart(
          'ราคาซื้อวัว',
          purchasePrice,
          Colors.purple,
          Icons.payments_outlined,
        ),
      if (healthCost > 0)
        _CostPart(
          'ค่ารักษา/วัคซีน',
          healthCost,
          AppColors.error,
          Icons.medical_services_outlined,
        ),
      if (feedCost > 0)
        _CostPart(
          'ค่าอาหาร',
          feedCost,
          Colors.green,
          Icons.grass_rounded,
        ),
    ];

    final isBornInFarm =
        purchasePrice <= 0 &&
        (widget.cow.motherId != null ||
            widget.cow.type == CowType.calf ||
            widget.cow.purchasePrice <= 0);

    return RefreshIndicator(
      onRefresh: _fetchCostData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total cost card
          _buildTotalCostCard(totalCost, totalIncome, netCost),
          const SizedBox(height: 12),

          // Estimated value comparison
          _buildValueComparisonCard(totalCost, widget.cow),
          const SizedBox(height: 16),

          // Summary cards row (3 cards: ราคาซื้อ, ค่ารักษา, ค่าอาหาร)
          Row(
            children: [
              Expanded(
                child: _buildMiniSummary(
                  'ราคาซื้อ',
                  purchasePrice,
                  Colors.purple,
                  isBornInFarm: isBornInFarm,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummary(
                  'ค่ารักษา',
                  healthCost,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummary('ค่าอาหาร', feedCost, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proportion bar
          if (costParts.isNotEmpty) ...[
            _buildSectionTitle('สัดส่วนต้นทุน'),
            const SizedBox(height: 8),
            _buildProportionBar(costParts, totalCost),
            const SizedBox(height: 20),
          ],

          // Health cost history
          if (healthDetails.isNotEmpty) ...[
            _buildSectionTitle(
              'ประวัติค่ารักษา/วัคซีน (${healthDetails.length} รายการ)',
            ),
            const SizedBox(height: 8),
            ...healthDetails.map((h) => _buildHealthDetailCard(h)),
            const SizedBox(height: 16),
          ],

          // Feed cost history
          if (feedDetails.isNotEmpty) ...[
            _buildSectionTitle('ประวัติค่าอาหาร (เฉลี่ยตามโซน)'),
            const SizedBox(height: 8),
            ...feedDetails.take(10).map((f) => _buildFeedDetailCard(f)),
            if (feedDetails.length > 10)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'แสดง 10 จาก ${feedDetails.length} รายการ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Direct costs
          if (directDetails.isNotEmpty) ...[
            _buildSectionTitle(
              'ค่าใช้จ่ายตรงรายตัว (${directDetails.length} รายการ)',
            ),
            const SizedBox(height: 8),
            ...directDetails.map((d) => _buildDirectCostCard(d)),
            const SizedBox(height: 16),
          ],

          // Empty state
          if (healthDetails.isEmpty &&
              feedDetails.isEmpty &&
              directDetails.isEmpty &&
              purchasePrice <= 0)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีข้อมูลค่าใช้จ่ายของวัวตัวนี้',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เมื่อมีการบันทึกค่ารักษาพยาบาล ค่าอาหาร\nหรือค่าใช้จ่ายอื่นๆ จะแสดงที่นี่',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  Widget _buildTotalCostCard(double total, double income, double net) {
    return Card(
      elevation: 3,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'ค่าเลี้ยงดูสะสมทั้งหมด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${NumberFormat('#,##0').format(total)} ฿',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (income > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'รายได้: ${NumberFormat('#,##0').format(income)} ฿  |  สุทธิ: ${NumberFormat('#,##0').format(net)} ฿',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSummary(
    String label,
    double amount,
    Color color, {
    bool isBornInFarm = false,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: (isBornInFarm ? Colors.teal : color).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                label.contains('รักษา')
                    ? Icons.medical_services_outlined
                    : label.contains('อาหาร')
                    ? Icons.grass_outlined
                    : isBornInFarm
                    ? Icons.child_care_outlined
                    : label.contains('ซื้อ')
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
                color: isBornInFarm ? Colors.teal : color,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.subText(context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            isBornInFarm
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'เกิดในฟาร์ม',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.isDark(context) ? const Color(0xFF2DD4BF) : Colors.teal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${NumberFormat('#,##0').format(amount)} ฿',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: amount > 0
                            ? AppColors.text(context)
                            : AppColors.hint(context),
                      ),
                      maxLines: 1,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: AppColors.text(context),
      ),
    );
  }

  Widget _buildProportionBar(List<_CostPart> parts, double total) {
    final partsSum = parts.fold<double>(0, (sum, p) => sum + p.amount);
    final effectiveTotal = partsSum > 0 ? partsSum : total;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: parts.map((p) {
                    final ratio = effectiveTotal > 0 ? p.amount / effectiveTotal : 0.0;
                    return Expanded(
                      flex: (ratio * 100).round().clamp(1, 100),
                      child: Container(color: p.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            ...parts.map((p) {
              final pct = effectiveTotal > 0
                  ? (p.amount / effectiveTotal * 100).toStringAsFixed(0)
                  : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(p.icon, size: 16, color: p.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0').format(p.amount)} ฿ ($pct%)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
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

  Widget _buildHealthDetailCard(Map<String, dynamic> h) {
    final date = AppDateUtils.formatDynamicDate(h['record_date']);
    final cost = _parseDouble(h['cost']);
    final disease = h['disease_name'];
    final medicine = h['medicine_name'];
    final vaccine = h['vaccine_name'];

    String description = '';
    if (disease != null) description += 'โรค: $disease';
    if (medicine != null)
      description += '${description.isNotEmpty ? ' | ' : ''}ยา: $medicine';
    if (vaccine != null)
      description += '${description.isNotEmpty ? ' | ' : ''}วัคซีน: $vaccine';
    if (description.isEmpty) description = 'บันทึกสุขภาพ';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.medical_services_outlined,
            color: AppColors.error,
            size: 20,
          ),
        ),
        title: Text(
          description,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
            const SizedBox(width: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(cost)} ฿',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.isDark(context) ? const Color(0xFFF87171) : AppColors.error,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedDetailCard(Map<String, dynamic> f) {
    final rawDate = f['date'] ?? '-';
    final feedType = f['type'] ?? 'อาหาร';
    final costPerCow = _parseDouble(f['cost_per_cow']);
    final totalCost = _parseDouble(f['cost']);

    String displayDate = AppDateUtils.formatDynamicDate(rawDate);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.grass_outlined,
            color: Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          feedType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
            const SizedBox(width: 4),
            Text(
              displayDate,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '(ทั้งโซน ${NumberFormat('#,##0').format(totalCost)} ฿)',
                style: TextStyle(fontSize: 11, color: AppColors.subText(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(costPerCow)} ฿',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.isDark(context) ? const Color(0xFF4ADE80) : Colors.green,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectCostCard(Map<String, dynamic> d) {
    final date = AppDateUtils.formatDynamicDate(d['transaction_date']);
    final amount = _parseDouble(d['amount']);
    final title = d['title'] ?? d['category'] ?? 'ค่าใช้จ่าย';
    final notes = d['notes'];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          title.toString(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppColors.hint(context)),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subText(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (notes != null && notes.toString().isNotEmpty)
              Text(
                notes.toString(),
                style: TextStyle(fontSize: 12, color: AppColors.hint(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(amount)} ฿',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.isDark(context) ? const Color(0xFF60A5FA) : Colors.blue,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildValueComparisonCard(double totalCost, Cow cow) {
    final marketState = ref.watch(marketPriceProvider);
    final breeds = ref.watch(breedProvider);
    final breedName = breeds
        .firstWhere(
          (b) => b.id == cow.breed,
          orElse: () => Breed(id: cow.breed, name: cow.breed),
        )
        .name;
    final pricePerKg = marketState.calculatePricePerKg(breedName: breedName, weight: cow.latestWeight);
    final estimatedValue = cow.latestWeight * pricePerKg;
    final profit = estimatedValue - totalCost;
    final isProfitable = profit >= 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'การวิเคราะห์ความคุ้มค่า',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'มูลค่าประมาณ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[750],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(estimatedValue)} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '(${cow.latestWeight.toStringAsFixed(0)} กก. × ${pricePerKg.toStringAsFixed(2)} ฿/กก.)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey[200]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'ค่าเลี้ยงดูสะสม',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[750],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(totalCost)} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: (isProfitable ? Colors.green : Colors.red).withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isProfitable ? Icons.trending_up : Icons.trending_down,
                    color: isProfitable ? Colors.green : AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isProfitable
                        ? 'กำไรประมาณ ${NumberFormat('#,##0').format(profit)} ฿'
                        : 'ขาดทุนประมาณ ${NumberFormat('#,##0').format(profit.abs())} ฿',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isProfitable ? Colors.green : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostPart {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  _CostPart(this.label, this.amount, this.color, this.icon);
}