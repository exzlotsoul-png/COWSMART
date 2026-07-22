import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/cow.dart';
import '../../../domain/breed.dart';
import '../../../providers/breed_provider.dart';
import '../../../providers/cow_provider.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../farm/providers/zone_provider.dart';
import '../../../../market/providers/market_price_provider.dart';

class BasicInfoTab extends ConsumerWidget {
  final Cow cow;

  const BasicInfoTab({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCows = ref.watch(cowProvider).allCows;

    String formatCowName(String? id) {
      if (id == null || id.isEmpty) return 'ไม่ทราบข้อมูล';
      final matches = allCows.where((c) => c.id == id || c.tagNumber == id || c.name == id).toList();
      if (matches.isNotEmpty) {
        final c = matches.first;
        if (c.name.isNotEmpty && c.tagNumber.isNotEmpty && c.name != c.tagNumber) {
          return '${c.name} (${c.tagNumber})';
        } else if (c.name.isNotEmpty) {
          return c.name;
        } else if (c.tagNumber.isNotEmpty) {
          return c.tagNumber;
        }
      }
      return id;
    }
    final breeds = ref.watch(breedProvider);
    final breedName = breeds
        .firstWhere(
          (b) => b.id == cow.breed,
          orElse: () => Breed(id: cow.breed, name: cow.breed),
        )
        .name;

    final marketPrice =
        ref.watch(marketPriceProvider).latest?.pricePerKg ?? 120.0;

    final zones = ref.watch(zoneProvider).zones;
    final zoneName = zones.isNotEmpty
        ? zones
              .firstWhere((z) => z.id == cow.zoneId, orElse: () => zones.first)
              .name
        : cow.zoneId;

    // Use latest weight from growth records if available, otherwise fallback to cow.latestWeight
    final growthRecords = ref.watch(cowDetailProvider).growthRecords;
    final latestWeight = growthRecords.isNotEmpty
        ? growthRecords.first.weight
        : cow.latestWeight;
    final estimatedValue = latestWeight * marketPrice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Stats Row
          _buildQuickStats(context, cow, latestWeight, estimatedValue),
          const SizedBox(height: 18),

          _buildInfoCard(
            context,
            icon: Icons.info_outline,
            iconColor: AppColors.primary,
            title: 'ข้อมูลเบื้องต้น',
            children: [
              _buildInfoRow(Icons.nfc, 'หมายเลขประจำตัว', cow.tagNumber),
              _buildInfoRow(Icons.label_outline, 'ชื่อ', cow.name.isNotEmpty ? cow.name : '-'),
              _buildInfoRow(Icons.category_outlined, 'สายพันธุ์', breedName),
              _buildInfoRow(Icons.pets, 'ประเภท', cow.type.label),
              _buildInfoRow(cow.gender == 'M' ? Icons.male : Icons.female, 'เพศ', cow.gender == 'M' ? 'ผู้' : 'เมีย'),
              _buildInfoRow(Icons.cake_outlined, 'อายุ', cow.ageDetailed),
              _buildInfoRow(
                Icons.calendar_today,
                'วันเกิด/เข้าฟาร์ม',
                DateFormat('dd MMM yyyy', 'th_TH').format(cow.birthDate),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            icon: Icons.monitor_heart_outlined,
            iconColor: AppColors.success,
            title: 'สถานะปัจจุบัน',
            children: [
              _buildInfoRowStatus(
                'สถานะสุขภาพ',
                cow.status,
              ),
              _buildInfoRow(
                Icons.scale_outlined,
                'น้ำหนักล่าสุด',
                latestWeight > 0
                    ? '${latestWeight.toStringAsFixed(1)} กก.'
                    : 'ยังไม่มีข้อมูล',
              ),
              _buildInfoRow(
                Icons.monetization_on_outlined,
                'มูลค่าประเมิน',
                latestWeight > 0
                    ? '฿${NumberFormat('#,##0').format(estimatedValue)}'
                    : '-',
              ),
              _buildInfoRow(Icons.location_on_outlined, 'โซน/คอกปัจจุบัน', zoneName),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            icon: Icons.account_tree_outlined,
            iconColor: AppColors.secondary,
            title: 'สายเลือด/พ่อแม่',
            children: [
              _buildInfoRow(Icons.male, 'พ่อกำเนิด', formatCowName(cow.fatherId)),
              _buildInfoRow(Icons.female, 'แม่กำเนิด', formatCowName(cow.motherId)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/cull_cow', extra: cow),
              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
              label: const Text(
                'จำหน่าย/คัดออกวัวตัวนี้',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, Cow cow, double weight, double value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D7552), Color(0xFF4A6040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.scale,
              label: 'น้ำหนัก',
              value: weight > 0 ? '${weight.toStringAsFixed(0)} กก.' : '-',
            ),
          ),
          Container(width: 1, height: 45, color: Colors.white24),
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.payments,
              label: 'มูลค่าประเมิน',
              value: weight > 0 ? '฿${NumberFormat('#,##0').format(value)}' : '-',
            ),
          ),
          Container(width: 1, height: 45, color: Colors.white24),
          Expanded(
            child: _buildQuickStatItem(
              icon: Icons.cake,
              label: 'อายุ',
              value: cow.ageDetailed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowStatus(String label, CowStatus status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.favorite, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(CowStatus status) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status) {
      case CowStatus.normal:
        bgColor = AppColors.success;
        break;
      case CowStatus.sick:
        bgColor = AppColors.error;
        break;
      case CowStatus.pregnant:
        bgColor = AppColors.info;
        break;
      case CowStatus.recovering:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
      case CowStatus.sold:
        bgColor = AppColors.textHint;
        break;
      case CowStatus.deceased:
        bgColor = AppColors.error;
        break;
      case CowStatus.removed:
        bgColor = AppColors.warning;
        textColor = AppColors.textPrimary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
